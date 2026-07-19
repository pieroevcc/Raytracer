#include <stdio.h>
#include <cuda_runtime.h>
#include <curand_kernel.h>
#include <fstream>
#include <iostream>
#include "vec3.h"
#include "ray.h"





__global__ void render (float* fb, int width, int height){
    int i = threadIdx.x + blockIdx.x * blockDim.x;
    int j = threadIdx.y + blockIdx.y * blockDim.y;
    if (i >= width || j >= height) return;
    float vfov = 20.0f;
    Vector3 lookfrom = Vector3(13,2,3), lookat = Vector3(0,0,0), vup = Vector3(0,1,0);
    float defocus_angle = 0.6f, focus_dist = 10.0f;
    Vector3 center, pixel00_loc, pixel_delta_u, pixel_delta_v;
    Vector3 u, v, w, defocus_disk_u, defocus_disk_v;

    center = lookfrom;
    w = unit(lookfrom - lookat);   
    u = unit(cross(vup, w));     
    v = cross(w, u);    
        
    float defocus_radius = focus_dist * tanf(degrees_to_radians(defocus_angle / 2.0f));
    defocus_disk_u = u * defocus_radius;   
    defocus_disk_v = v * defocus_radius;   

    float theta = degrees_to_radians(vfov);
    float h = tanf(theta / 2.0f);
    float viewport_height = 2.0f * h * focus_dist;
    float viewport_width  = viewport_height * (float(width) / height);

    Vector3 viewport_u = viewport_width * u;
    Vector3 viewport_v = viewport_height * neg(v);
    pixel_delta_u = viewport_u/ float(width);
    pixel_delta_v = viewport_v/ float(height);
    Vector3 viewport_upper_left = center - focus_dist * w - viewport_u / 2.0f - viewport_v / 2.0f;
    pixel00_loc = 0.5f * (pixel_delta_u + pixel_delta_v) +  viewport_upper_left;

    Vector3 ray_origin = center + defocus_disk_u + defocus_disk_v; //needs curand
    Vector3 sample = pixel00_loc + i * pixel_delta_u + j * pixel_delta_v;
    Ray r = Ray(ray_origin, sample - ray_origin);
    Vector3 unit_direction = unit(r.direction);
    float a = 0.5f * (unit_direction.y + 1.0f);
    Vector3 pixel_color = (1.0f - a) * Vector3(1.0f,1.0f,1.0f) + a * Vector3(0.5f, 0.7f, 1.0f); 

    int idx = 3 * (j * width + i);
    fb[idx] = pixel_color.x;
    fb[idx+1] = pixel_color.y;
    fb[idx+2] = pixel_color.z;

}



int main(){
    float* fb = nullptr;
    int width = 400;
    int height = 225;

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