#include <stdio.h>
#include <cuda_runtime.h>
#include <fstream>
#include <iostream>


__global__ void render (float* fb, int width, int height){
    int i = threadIdx.x + blockIdx.x * blockDim.x;
    int j = threadIdx.y + blockIdx.y * blockDim.y;

    if (i >= width || j >= height) return;

    int idx = 3 * (j * width + i);
    fb[idx] = float(i)/width;
    fb[idx+1] = float(j)/height;
    fb[idx+2] = 0.2f;

}


int main(){
    int width = 400;
    int height = 225;
    float* fb = nullptr;

    cudaMallocManaged(&fb, 3*width*height*sizeof(float));

    dim3 blocks(width/8+1, height/8+1);
    dim3 threads(8,8);

    render<<<blocks,threads>>>(fb, width, height);

    cudaDeviceSynchronize();

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

    return 0;
}