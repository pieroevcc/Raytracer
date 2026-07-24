#include <stdio.h>
#include <stdlib.h>
#include <cuda_runtime.h>
#include <vector>
#include "vec3.h"
#include <glad/glad.h>
#include <GLFW/glfw3.h>
#include <cuda_gl_interop.h>
#include "raytracer.cuh"
#include "gl_display.cuh"

extern "C" {
    __declspec(dllexport) unsigned long NvOptimusEnablement = 0x00000001;
}

//convert drawn pixels to render in display
__global__ void float_to_uchar4(uchar4* out, const float* fb, float* accum, int count, int W, int H){
    int x = blockIdx.x * blockDim.x + threadIdx.x;
    int y = blockIdx.y * blockDim.y + threadIdx.y;
    if (x >= W || y >= H) return;

    int fbi = 3*(y*W + x);
    accum[fbi] += fb[fbi]; accum[fbi+1] += fb[fbi+1]; accum[fbi+2] += fb[fbi+2];
    int r = static_cast<unsigned char>(fminf(fmaxf(sqrtf(accum[fbi]/count),0), 1) * 255.999f);
    int g = static_cast<unsigned char>(fminf(fmaxf(sqrtf(accum[fbi+1]/count),0), 1) * 255.999f);
    int b = static_cast<unsigned char>(fminf(fmaxf(sqrtf(accum[fbi+2]/count),0), 1) * 255.999f);

    out[y*W+x] = make_uchar4(r, g, b, 255);
}

//key binds
bool update_camera(GLFWwindow* win, Vector3& lookfrom, Vector3& lookat){
    bool moved = false;
    Vector3 forward = unit(lookat - lookfrom);
    Vector3 right = unit(cross(forward, Vector3(0,1,0)));
    float speed = 0.1f;
    Vector3 fs = forward*speed;
    Vector3 rs = right*speed;
    if (glfwGetKey(win, GLFW_KEY_W) == GLFW_PRESS){
        lookfrom += fs;
        lookat += fs;
        moved = true;
    }
    if (glfwGetKey(win, GLFW_KEY_D) == GLFW_PRESS){
        lookfrom += rs;
        lookat += rs;
        moved = true;
    }
    if (glfwGetKey(win, GLFW_KEY_S) == GLFW_PRESS){
        lookfrom -= fs;
        lookat -= fs;
        moved = true;
    }
    if (glfwGetKey(win, GLFW_KEY_A) == GLFW_PRESS){
        lookfrom -= rs;
        lookat -= rs;
        moved = true;
    }
    if (glfwGetKey(win, GLFW_KEY_SPACE) == GLFW_PRESS){
        lookfrom += Vector3(0,1,0)*speed;
        lookat += Vector3(0,1,0)*speed;
        moved = true;
    }
    if (glfwGetKey(win, GLFW_KEY_LEFT_SHIFT) == GLFW_PRESS){
        lookfrom -= Vector3(0,1,0)*speed;
        lookat -= Vector3(0,1,0)*speed;
        moved = true;
    }
    return moved;
}

//spawns spheres in the sky
void reset_physics(Sphere* world, std::vector<Vector3>& vel, int n){
    for(int k = 4; k < n; k++){
        world[k].center.y = random_float(5,20);
        vel[k] = Vector3(0,0,0);
    }
}

// sets spheres on the ground
void rest_physics(Sphere* world, std::vector<Vector3>& vel, int n){
    for(int k = 4; k < n; k++){
        world[k].center.y = world[k].radius;
        vel[k] = Vector3(0,0,0);
    }
}

//toggle physcis
bool poll_physics_toggle(GLFWwindow* win, bool& physics_on, bool& g_was_down, Sphere* world, std::vector<Vector3>& vel, int n){
    bool check_toggle = glfwGetKey(win, GLFW_KEY_G) == GLFW_PRESS;
    bool toggled = check_toggle && !g_was_down;
    if (toggled){
        physics_on = !physics_on;
        if (physics_on) reset_physics(world, vel, n);
        else rest_physics(world, vel, n);
    }
    g_was_down = check_toggle;
    return toggled;
}

//physics math
bool step_physics(Sphere* world, std::vector<Vector3>& vel, int n, float dt){
    bool res = false;
    Vector3 g_dt = Vector3(0, -9.81f, 0) * dt;
    float sq_g_dt = -g_dt.y * -g_dt.y;
    for(int k = 4; k < n; k++){
        vel[k] += g_dt;
        world[k].center += vel[k] * dt;
        if (world[k].center.y - world[k].radius <= 0){
            world[k].center.y = world[k].radius;
            vel[k].y = -vel[k].y * 0.6f;
            if (fabsf(vel[k].y) < -g_dt.y){
                vel[k].y = 0;
            }
        }
        if (length_squared(vel[k]) >= sq_g_dt){
            res = true;
        }
    }
    return res;
}

int main(){
    //window display
    const int W = 800, H = 450;
    Display d = init_display(W, H);

    //pixel color
    Camera cam;
    int* actual;
    int spp = 1;
    curandState* rs;
    Sphere* world;
    int n = 488;
    float* fb = nullptr;
    Vector3 lookfrom(13,2,3);
    Vector3 lookat(0,0,0);
    float* accum;
    int count = 0;

    //event handles
    cudaEvent_t start, stop;
    float ms_sum = 0;
    int frames = 0;

    //physics
    std::vector<Vector3> vel(n);
    bool physics_on = false;
    bool g_was_down = false;
    bool scene_moving = false;
    float dt;
    double prev_time;

    cudaMallocManaged(&accum, 3*W*H*sizeof(float));
    cudaMemset(accum, 0, 3*W*H*sizeof(float));
    cudaMallocManaged(&actual, sizeof(int));
    cudaMallocManaged((void **)&rs, W * H * sizeof(curandState));
    cudaMallocManaged(&world, n * sizeof(Sphere));
    cudaMallocManaged(&fb, 3*W*H*sizeof(float));

    scene<<<1,1>>>(world, actual, rs);
    cudaDeviceSynchronize();
    n = *actual;

    dim3 initThreads(8, 8);
    dim3 initBlocks((W + 7) / 8, (H + 7) / 8);
    render_init<<<initBlocks, initThreads>>>(rs, W, H);

    const int TX = 32, TY = 4;
    dim3 threads(TX, TY);
    dim3 blocks((W + TX - 1) / TX, (H + TY - 1) / TY);
   
    cudaEventCreate(&start);
    cudaEventCreate(&stop);
    prev_time = glfwGetTime();

    while(!glfwWindowShouldClose(d.window)){ //poll -> clear -> bind (program/vao/tex) -> draw -> swap
        glfwPollEvents();
        bool toggled = poll_physics_toggle(d.window, physics_on, g_was_down, world, vel, n);
        double now = glfwGetTime();
        bool moved = update_camera(d.window, lookfrom, lookat);
        cam = make_camera(W, H, lookfrom, lookat);

        dt = fminf(now - prev_time, 0.033f);
        prev_time = now;

        if (physics_on) scene_moving = step_physics(world, vel, n, dt);
        else scene_moving = false;
        if (moved || scene_moving || toggled) { //a toggle is a scene change in either direction
            count = 0;
            cudaMemset(accum, 0, 3*W*H*sizeof(float));
        }
        count++;

        uchar4* devPtr = map_pbo(d);

        cudaEventRecord(start, 0);
        render<<<blocks,threads>>>(fb, world, n, W, H, rs, cam, spp, false, 8);
    
        CUDA_CHECK(cudaGetLastError());
        
        dim3 block(16,16);
        dim3 grid((W + block.x - 1)/block.x, (H + block.y - 1)/block.y);
    
        float_to_uchar4<<<grid, block>>>(devPtr, fb, accum, count, W , H);
        cudaEventRecord(stop, 0);
        cudaEventSynchronize(stop);
        float ms;
        cudaEventElapsedTime(&ms, start, stop);

        ms_sum += ms; frames++;
        if (frames == 30){
            float avg = ms_sum / frames;
            ms_sum = 0; frames = 0;
            char buf[128];
            snprintf(buf, sizeof(buf), "CUDA Ray Tracer | %.2f ms | %.0f fps", avg, 1000.0f/avg);
            glfwSetWindowTitle(d.window, buf);
        }
        CUDA_CHECK(cudaGetLastError());
        present(d);
    }
    cudaEventDestroy(start);
    cudaEventDestroy(stop);
    glfwTerminate();
    return 0;
}