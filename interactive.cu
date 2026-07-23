#include <stdio.h>
#include <stdlib.h>
#include <fstream>
#include <iostream>
#include <vector>
#include <cuda_runtime.h>
#include <glad/glad.h>
#include <GLFW/glfw3.h>
#include <cuda_gl_interop.h>
#include "raytracer.cuh"

extern "C" {
    __declspec(dllexport) unsigned long NvOptimusEnablement = 0x00000001;
}


static GLFWwindow* init_window(int W, int H) {
    if (!glfwInit()) { fprintf(stderr, "glfwInit failed\n"); exit(1); } //boots GLFW library
    glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 3); //3 glfwWindowHint; grabs OpenGL 3.3 context
    glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 3);
    glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE);
    GLFWwindow* win = glfwCreateWindow(W, H, "CUDA Ray Tracer - interactive", nullptr, nullptr); //creates windwo
    if (!win) { fprintf(stderr, "window create failed\n"); glfwTerminate(); exit(1); }
    glfwMakeContextCurrent(win); // makes curr GL context window 
    if (!gladLoadGLLoader((GLADloadproc)glfwGetProcAddress)) { fprintf(stderr, "GLAD load failed\n"); exit(1); }
    glfwSwapInterval(0);  //Vsync off; 0 = swap buffers immediately  
    glViewport(0, 0, W, H); //mapos normalized device coords
    return win;
}

static GLuint make_texture(int W, int H) { //gen name -> bind -> configure
    GLuint tex; 
    glGenTextures(1, &tex);  //reserve 1 texture name and write to tex
    glBindTexture(GL_TEXTURE_2D, tex);//make tex the current 2D texture
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, W, H, 0, GL_RGBA, GL_UNSIGNED_BYTE, nullptr); //allocates storage; GL_RGBA8 = GPU storage
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST); //minified
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST); //magnified
    return tex;
}

static GLuint compile_shader(GLenum type, const char* src) { //stages the shader
    GLuint s = glCreateShader(type); 
    glShaderSource(s, 1, &src, nullptr);
    glCompileShader(s);
    GLint ok; glGetShaderiv(s, GL_COMPILE_STATUS, &ok);
    if (!ok) { char log[1024]; glGetShaderInfoLog(s, sizeof log, nullptr, log); // else print why it failed
               fprintf(stderr, "shader compile:\n%s\n", log); exit(1); }
    return s;
}

static GLuint make_program() {
    const char* VERT =
        "#version 330 core\n"
        "out vec2 uv;\n"
        "void main() {\n"
        "    vec2 p = vec2(float((gl_VertexID << 1) & 2), float(gl_VertexID & 2));\n"
        "    uv = p;                              // 0..2 across the screen\n"
        "    gl_Position = vec4(p * 2.0 - 1.0, 0.0, 1.0);\n"
        "}\n";
    const char* FRAG =
        "#version 330 core\n"
        "in vec2 uv;\n"
        "out vec4 frag;\n"
        "uniform sampler2D tex;\n"
        "void main() { frag = texture(tex, vec2(uv.x, 1.0 - uv.y)); }\n";
    GLuint v = compile_shader(GL_VERTEX_SHADER, VERT);
    GLuint f = compile_shader(GL_FRAGMENT_SHADER, FRAG);
    GLuint p = glCreateProgram();
    glAttachShader(p, v); glAttachShader(p, f);
    glLinkProgram(p);
    GLint ok; glGetProgramiv(p, GL_LINK_STATUS, &ok);
    if (!ok) { char log[1024]; glGetProgramInfoLog(p, sizeof log, nullptr, log);
               fprintf(stderr, "program link:\n%s\n", log); exit(1); }
    glDeleteShader(v); glDeleteShader(f);
    return p;                         
}

static GLuint make_fullscreen_vao() { //Vertex Array Object
    GLuint vao; glGenVertexArrays(1, &vao); 
    return vao;
}

static GLuint make_pbo(int W, int H){ //make Picture Buffer Object
    GLuint buf;
    glGenBuffers(1, &buf);
    glBindBuffer(GL_PIXEL_UNPACK_BUFFER, buf);
    glBufferData(GL_PIXEL_UNPACK_BUFFER, W*H*sizeof(uchar4), nullptr, GL_DYNAMIC_DRAW);
    glBindBuffer(GL_PIXEL_UNPACK_BUFFER, 0);
    return buf;
}

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

bool update_camera(GLFWwindow* win, Vector3& lookfrom, Vector3& lookat){
    bool moved = false;
    Vector3 forward = unit(lookat - lookfrom);
    Vector3 right = unit(cross(forward, Vector3(0,1,0)));
    float speed = 0.1f;
    Vector3 fs = forward*speed;
    Vector3 rs = right*speed;
    if (glfwGetKey(win, GLFW_KEY_W) == GLFW_PRESS){
        lookfrom = lookfrom + fs;
        lookat = lookat + fs;
        moved = true;
    }
    if (glfwGetKey(win, GLFW_KEY_D) == GLFW_PRESS){
        lookfrom = lookfrom + rs;
        lookat = lookat + rs;
        moved = true;
    }
    if (glfwGetKey(win, GLFW_KEY_S) == GLFW_PRESS){
        lookfrom = lookfrom - fs;
        lookat = lookat - fs;
        moved = true;
    }
    if (glfwGetKey(win, GLFW_KEY_A) == GLFW_PRESS){
        lookfrom = lookfrom - rs;
        lookat = lookat - rs;
        moved = true;
    }
    if (glfwGetKey(win, GLFW_KEY_SPACE) == GLFW_PRESS){
        lookfrom = lookfrom + Vector3(0,1,0)*speed;
        lookat = lookat + Vector3(0,1,0)*speed;
        moved = true;
    }
    if (glfwGetKey(win, GLFW_KEY_LEFT_SHIFT) == GLFW_PRESS){
        lookfrom = lookfrom - Vector3(0,1,0)*speed;
        lookat = lookat - Vector3(0,1,0)*speed;
        moved = true;
    }
    return moved;
}

int main(){
    //window display
    const int W = 800, H = 450;
    GLFWwindow* window = init_window(W,H);
    GLuint tex = make_texture(W,H);
    GLuint prog = make_program();
    GLuint vao = make_fullscreen_vao();
    GLuint pbo = make_pbo(W,H);
    cudaGraphicsResource* cudaPbo;

    //pixel color
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

    cudaMallocManaged(&accum, 3*W*H*sizeof(float));
    cudaMemset(accum, 0, 3*W*H*sizeof(float));
    cudaMallocManaged(&actual, sizeof(int));
    cudaMallocManaged((void **)&rs, W * H * sizeof(curandState));
    cudaMallocManaged(&world, n * sizeof(Sphere));
    cudaMallocManaged(&fb, 3*W*H*sizeof(float));

    scene<<<1,1>>>(world, actual, rs);
    cudaDeviceSynchronize();
    n = *actual;

    Camera cam = make_camera(W,H, lookfrom, lookat);

    dim3 initThreads(8, 8);
    dim3 initBlocks((W + 7) / 8, (H + 7) / 8);
    render_init<<<initBlocks, initThreads>>>(rs, W, H);

    const int TX = 32, TY = 4;
    dim3 threads(TX, TY);
    dim3 blocks((W + TX - 1) / TX, (H + TY - 1) / TY);
    

    cudaError_t err = cudaGraphicsGLRegisterBuffer(&cudaPbo, pbo, cudaGraphicsRegisterFlagsWriteDiscard);
    if (err != cudaSuccess){ printf("CUDA error : %s\n", cudaGetErrorString(err)); exit(1); } 
   
    cudaEventCreate(&start);
    cudaEventCreate(&stop);

    while(!glfwWindowShouldClose(window)){ //poll -> clear -> bind (program/vao/tex) -> draw -> swap
        glfwPollEvents();

        bool moved = update_camera(window, lookfrom, lookat);
        cam = make_camera(W, H, lookfrom, lookat);

        if (moved) {
            count = 0;
            cudaMemset(accum, 0, 3*W*H*sizeof(float));
        }
        count++;

        cudaError_t err1 = cudaGraphicsMapResources(1, &cudaPbo, 0);
        if (err1 != cudaSuccess){ printf("CUDA error : %s\n", cudaGetErrorString(err1)); exit(1); } 
        uchar4* devPtr;
        size_t numBytes;

        cudaError_t err2 = cudaGraphicsResourceGetMappedPointer((void**)&devPtr, &numBytes, cudaPbo);
        if (err2 != cudaSuccess){ printf("CUDA error : %s\n", cudaGetErrorString(err2)); exit(1); } 

        cudaEventRecord(start, 0);
        render<<<blocks,threads>>>(fb, world, n, W, H, rs, cam, spp, false, 8);
    
        cudaError_t err5 = cudaGetLastError();
        if (err5 != cudaSuccess) printf("CUDA error : %s\n", cudaGetErrorString(err5));
        
        dim3 block(16,16);
        dim3 grid((W + block.x - 1)/block.x, (H + block.y - 1)/block.y);
    
        float_to_uchar4<<<grid, block>>>(devPtr, fb, accum, count, W , H);
        cudaEventRecord(stop, 0);
        cudaEventSynchronize(stop);
        float ms;
        cudaEventElapsedTime(&ms, start, stop);

        ms_sum += ms; frames++;
        float avg = 0;
        if (frames == 30){
            avg = ms_sum / frames;
            ms_sum = 0; frames = 0;
            char buf[128];
            snprintf(buf, sizeof(buf), "CUDA Ray Tracer | %.2f ms | %.0f fps", avg, 1000.0f/avg);
            glfwSetWindowTitle(window, buf);
        }
    
        cudaError_t err3 = cudaGetLastError();
        if (err3 != cudaSuccess) { printf("CUDA error : %s\n", cudaGetErrorString(err3)); exit(1);}
        cudaDeviceSynchronize();

        cudaError_t err4 = cudaGraphicsUnmapResources(1, &cudaPbo, 0);
        if (err4 != cudaSuccess){ printf("CUDA error : %s\n", cudaGetErrorString(err4)); exit(1); } 

        glBindBuffer(GL_PIXEL_UNPACK_BUFFER, pbo);
        glBindTexture(GL_TEXTURE_2D, tex);
        glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, W, H, GL_RGBA, GL_UNSIGNED_BYTE, (void*)0);
        glBindBuffer(GL_PIXEL_UNPACK_BUFFER, 0);
        glClear(GL_COLOR_BUFFER_BIT);
        glUseProgram(prog);
        glBindVertexArray(vao);
        glBindTexture(GL_TEXTURE_2D, tex);
        glDrawArrays(GL_TRIANGLES, 0, 3);
        glfwSwapBuffers(window);
    
    }
    cudaEventDestroy(start);
    cudaEventDestroy(stop);
    glfwTerminate();
    return 0;
}