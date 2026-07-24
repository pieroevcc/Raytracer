#include <stdio.h>
#include <cuda_runtime.h>
#include <curand_kernel.h>
#include <fstream>
#include "vec3.h"
#include "ray.h"
#include "raytracer.cuh"

int main(){
    float* fb = nullptr;
    int width = 400;
    int height = 225;
    int samples_per_pixel = 100;
    int n = 488;
    int* actual;
    Sphere* world;
    curandState* rs;
    
    cudaMallocManaged(&actual, sizeof(int));
    cudaMallocManaged((void **)&rs, width * height * sizeof(curandState));
    cudaMallocManaged(&world, n * sizeof(Sphere));
    cudaMallocManaged(&fb, 3*width*height*sizeof(float));

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

    render<<<blocks,threads>>>(fb, world, n, width, height, rs, cam, samples_per_pixel);
    
    cudaError_t err = cudaGetLastError();
    if (err != cudaSuccess) printf("CUDA error : %s\n", cudaGetErrorString(err));

    std::ofstream out("image.ppm");
    out << "P3\n" << width << " " << height << "\n255\n";
    for (int j = 0; j < height; j++){
        for (int i = 0; i < width; i++){
            int idx = 3 * (j * width + i);
            int x = static_cast<int>(fb[idx] * 255.999f);
            int y = static_cast<int>(fb[idx+1] * 255.999f);
            int z = static_cast<int>(fb[idx+2] * 255.999f);
            out << x << " " << y << " " << z << "\n";
        }
    }
    cudaFree(fb);
    cudaFree(actual);
    cudaFree(world);
    cudaFree(rs);
    return 0;
}