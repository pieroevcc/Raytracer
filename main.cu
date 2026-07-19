#include <stdio.h>
#include <cuda_runtime.h>
#include <curand_kernel.h>
#include <fstream>
#include <iostream>
#include "vec3.h"
#include "ray.h"

struct Sphere { Vector3 center; float radius; };
struct HitRecord { Vector3 p; Vector3 normal; float t; bool front_face; };

__device__ bool hit_sphere(const Sphere& s, const Ray& r, float t_min, float t_max, HitRecord& rec) {
    Vector3 oc = s.center - r.origin;
    float a = length_squared(r.direction);
    float h = dot(r.direction, oc);
    float c = length_squared(oc) - s.radius*s.radius;
    float disc = h*h - a*c;
    if (disc < 0) return false;
    float sqrtd = sqrtf(disc);
    float root = (h - sqrtd)/a;
    if (root <= t_min || root >= t_max){
        root = (h + sqrtd)/a;
        if (root <= t_min || root >= t_max){
            return false;
        }
    }
    rec.t = root;
    rec.p = r.at(rec.t);
    Vector3 outward = (rec.p - s.center) / s.radius;
    rec.front_face = dot(r.direction, outward) < 0.0f;
    rec.normal = rec.front_face ? outward : -outward;
    return true;
}

__device__ bool hit_world(const Sphere* world, int n, const Ray& r, float t_min, float t_max, HitRecord& rec) {
    HitRecord temp_rec;
    bool hit_anything = false;
    float closest_so_far = t_max;

    for (int k = 0; k < n; k++){
        if (hit_sphere(world[k], r, t_min, closest_so_far, temp_rec)){
            hit_anything = true;
            closest_so_far = temp_rec.t;
            rec = temp_rec;
        }
    }
    return hit_anything;

}
__global__ void render_init(curandState* rand_state, int width, int height) {
    int i = threadIdx.x + blockIdx.x * blockDim.x;
    int j = threadIdx.y + blockIdx.y * blockDim.y;
    if (i >= width || j >= height) return;
    curand_init(1984, j*width + i, 0, &rand_state[j*width+i]);
}

__global__ void render (float* fb, const Sphere* world, int n, int width, int height, curandState* rand_state){
    int i = threadIdx.x + blockIdx.x * blockDim.x;
    int j = threadIdx.y + blockIdx.y * blockDim.y;
    if (i >= width || j >= height) return;
    int pixel_index = j*width + i;
    curandState local_rand = rand_state[pixel_index];

    float vfov = 20.0f;
    int samples_per_pixel = 100;
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

    Vector3 pixel_color;
    for (int s = 0; s < samples_per_pixel; s++){
        Vector3 sample_color;
        float ox = curand_uniform(&local_rand) - 0.5f;
        float oy = curand_uniform(&local_rand) - 0.5f;
        Vector3 sample = pixel00_loc + (i + ox) * pixel_delta_u + (j + oy ) * pixel_delta_v;
        Ray r = Ray(center, sample - center);

        HitRecord rec;
        if (hit_world(world, n , r , 0.001f, 1e30f, rec)){
            //sphere
            sample_color = 0.5f * (rec.normal + Vector3(1,1,1));
        }
        else{
            //sky
            Vector3 unit_direction = unit(r.direction);
            float a = 0.5f * (unit_direction.y + 1.0f);
            sample_color = (1.0f - a) * Vector3(1.0f,1.0f,1.0f) + a * Vector3(0.5f, 0.7f, 1.0f);
        } 
        pixel_color = pixel_color + sample_color;

    }
    pixel_color = pixel_color * 1.0f/samples_per_pixel;
    int idx = 3 * (j * width + i);
    fb[idx] = pixel_color.x;
    fb[idx+1] = pixel_color.y;
    fb[idx+2] = pixel_color.z;

}



int main(){
    float* fb = nullptr;
    int width = 400;
    int height = 225;
    int n = 4;
    Sphere* world;
    curandState* rand_state;

    cudaMallocManaged((void **)&rand_state, width * height * sizeof(curandState));
    cudaMallocManaged(&world, n * sizeof(Sphere));
    cudaMallocManaged(&fb, 3*width*height*sizeof(float));

    world[0] = {Vector3(0,-1000,0), 1000};
    world[1] = {Vector3(0,1,0), 1};
    world[2] = {Vector3(-4,1,0), 1};
    world[3] = {Vector3(4,1,0), 1};


    dim3 blocks(width/8+1, height/8+1);
    dim3 threads(8,8);

    render_init<<<blocks, threads>>>(rand_state, width, height);
    render<<<blocks,threads>>>(fb, world, n, width, height, rand_state);
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
    cudaFree(world);
    cudaFree(rand_state);

    return 0;
}