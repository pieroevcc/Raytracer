#include <stdio.h>
#include <cuda_runtime.h>
#include <curand_kernel.h>
#include <fstream>
#include "vec3.h"
#include "ray.h"
#include "raytracer.cuh"

double psnr(const float* a, const float* b, int count){
    double mse = 0;
    for(int i = 0; i < count; i++){
        float x = a[i] - b[i];
        mse += ((x*x));
    }
    mse /= count;
    if (mse == 0) return INFINITY;
    return 10 * log10(1.0/mse);
}

int main(){
    //float* fb = nullptr;
    int width = 400;
    int height = 225;
    int samples_per_pixel = 1000;
    int n = 488;
    int* actual;
    Sphere* world;
    curandState* rs;
    float* fb_ref = nullptr;
    float* fb_rr = nullptr;
    
    cudaMallocManaged(&actual, sizeof(int));
    cudaMallocManaged((void **)&rs, width * height * sizeof(curandState));
    cudaMallocManaged(&world, n * sizeof(Sphere));
    //cudaMallocManaged(&fb, 3*width*height*sizeof(float));
    cudaMallocManaged(&fb_ref, 3*width*height*sizeof(float));
    cudaMallocManaged(&fb_rr, 3*width*height*sizeof(float));

    scene<<<1,1>>>(world, actual, rs);
    cudaDeviceSynchronize();
    n = *actual;

    Camera cam = make_camera(width, height, Vector3(13,2,3), Vector3(0,0,0));

    dim3 initThreads(8, 8);
    dim3 initBlocks((width + 7) / 8, (height + 7) / 8);
    render_init<<<initBlocks, initThreads>>>(rs, width, height);

    const int TX = 32, TY = 4;
    dim3 threads(TX, TY);
    dim3 blocks((width + TX - 1) / TX, (height + TY - 1) / TY);

    render<<<blocks,threads>>>(fb_ref, world, n, width, height, rs, cam, samples_per_pixel, true, 50, 999);
    render<<<blocks,threads>>>(fb_rr, world, n, width, height, rs, cam, samples_per_pixel, true, 50, 3);
    cudaDeviceSynchronize();
    cudaError_t err = cudaGetLastError();
    if (err != cudaSuccess) printf("CUDA error : %s\n", cudaGetErrorString(err));
    
    double res = psnr(fb_ref, fb_rr, 3*width*height);
    printf("RR: %f\n", res);
    

    std::ofstream out("image.ppm");
    out << "P3\n" << width << " " << height << "\n255\n";
    for (int j = 0; j < height; j++){
        for (int i = 0; i < width; i++){
            int idx = 3 * (j * width + i);
            int x = static_cast<int>(fb_ref[idx] * 255.999f);
            int y = static_cast<int>(fb_ref[idx+1] * 255.999f);
            int z = static_cast<int>(fb_ref[idx+2] * 255.999f);
            out << x << " " << y << " " << z << "\n";
        }
    }
    //cudaFree(fb);
    cudaFree(actual);
    cudaFree(world);
    cudaFree(rs);
    cudaFree(fb_ref);
    cudaFree(fb_rr);
    return 0;
}