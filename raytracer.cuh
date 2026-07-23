#pragma once

#include <cuda_runtime.h>
#include <curand_kernel.h>
#include "vec3.h"
#include "ray.h"

enum MatType { LAMBERTIAN, METAL, DIELECTRIC };
struct Material { MatType type; Vector3 albedo; float fuzz; float ior; };

struct Sphere { Vector3 center; float radius; Material mat; };
struct HitRecord { Vector3 p; Vector3 normal; float t; bool front_face; Material mat; };
struct Camera {
    Vector3 center;
    Vector3 pixel00_loc;
    Vector3 pixel_delta_u, pixel_delta_v;
    Vector3 defocus_disk_u, defocus_disk_v;
};

__device__ Vector3 random_unit_vector(curandState* rs){
    while(true){
        float rand = 2.0f*curand_uniform(rs) - 1.0f;
        Vector3 p = Vector3(rand, rand, rand);
        float lensq = length_squared(p);
        if (1e-30f < lensq && lensq <= 1.0f) return p /sqrtf(lensq);
    }
}

__device__ Vector3 random_in_unit_disk(curandState* rs) {
    while (true) {
        float rand = 2.0f*curand_uniform(rs) - 1.0f;
        Vector3 p = Vector3(rand, rand, 0.0f);
        if (length(p) < 1.0f) return p;
    }
}

__device__ Vector3 random_vector(curandState* rs){
    return Vector3(curand_uniform(rs), curand_uniform(rs), curand_uniform(rs));
}

__device__ bool scatter(const Material& m, const Ray& r_in, const HitRecord& rec,
    Vector3& attenuation, Ray& scattered, curandState* rs){
        bool res = false;
        switch(m.type){
            case (LAMBERTIAN) : {
                Vector3 dir = rec.normal + random_unit_vector(rs);
                if(near_zero(dir)) dir = rec.normal;
                scattered = Ray(rec.p, dir);
                attenuation = m.albedo;
                res = true;
                break;
            }

            case (METAL): {
                Vector3 reflected = reflect(unit(r_in.direction), rec.normal);
                reflected = unit(reflected) + m.fuzz * random_unit_vector(rs);
                scattered = Ray(rec.p, reflected);
                attenuation = m.albedo;
                res = (dot(scattered.direction, rec.normal) > 0);
                break;
            }

            case (DIELECTRIC): {
                attenuation = Vector3(1.0f, 1.0f, 1.0f);
                float ri = rec.front_face ? (1.0f / m.ior) : m.ior;
        
                Vector3 unit_dir = unit(r_in.direction);
                float cos_theta = fminf(dot(neg(unit_dir), rec.normal), 1.0f);
                float sin_theta = sqrtf(1.0f - cos_theta * cos_theta);
        
                bool cannot_refract = ri * sin_theta > 1.0f; 
                Vector3 direction;
                float r0 = (1.0f - ri) / (1.0f + ri);
                r0 = r0 * r0;
                float reflectance = r0 + (1.0f - r0) * powf(1.0f - cos_theta, 5.0f);
                if (cannot_refract || reflectance > curand_uniform(rs))
                    direction = reflect(unit_dir, rec.normal);
                else
                    direction = refract(unit_dir, rec.normal, ri);
        
                scattered = Ray(rec.p, direction);
                res = true;
                break;
            }   
            default:
                return res;       
        }
        return res;
    }


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
    rec.mat = s.mat;
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

__device__ Vector3 ray_color(Ray r, const Sphere* world, int n, curandState* rs){
    Vector3 throughput = Vector3(1,1,1);
    for (int depth = 0; depth < 50; depth++){
        HitRecord rec;
        if (hit_world(world, n, r, 0.001f, 1e30f, rec)){
            Vector3 attenuation; Ray scattered; 
            if (scatter(rec.mat, r, rec, attenuation, scattered, rs)){
                throughput = throughput * attenuation;
                r = scattered;          
            } else return Vector3(0,0,0);  
        } else {
            Vector3 unit_direction = unit(r.direction);
            float a = 0.5f * (unit_direction.y + 1.0f);
            Vector3 sky = (1.0f - a) * Vector3(1.0f,1.0f,1.0f) + a * Vector3(0.5f, 0.7f, 1.0f); 
            return throughput * sky;
        }
    }
    return Vector3(0,0,0);             
}

Camera make_camera(int width, int height, Vector3 lookfrom, Vector3 lookat) {
    float vfov = 20.0f;
    Vector3 vup = Vector3(0,1,0);
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

    Camera cam;
    cam.center         = center;
    cam.pixel00_loc    = pixel00_loc;
    cam.pixel_delta_u  = pixel_delta_u;
    cam.pixel_delta_v  = pixel_delta_v;
    cam.defocus_disk_u = defocus_disk_u;
    cam.defocus_disk_v = defocus_disk_v;
    return cam;
}

__global__ void render_init(curandState* rand_state, int width, int height) {
    int i = threadIdx.x + blockIdx.x * blockDim.x;
    int j = threadIdx.y + blockIdx.y * blockDim.y;
    if (i >= width || j >= height) return;
    curand_init(1984, j*width + i, 0, &rand_state[j*width+i]);
}

__global__ void render (float* fb, const Sphere* world, int n, int width, int height, curandState* rs, Camera cam, int spp){
    int i = threadIdx.x + blockIdx.x * blockDim.x;
    int j = threadIdx.y + blockIdx.y * blockDim.y;
    if (i >= width || j >= height) return;
    int pixel_index = j*width + i;
    curandState local_rand = rs[pixel_index];
 
    Vector3 pixel_color;
    for (int s = 0; s < spp; s++){
        Vector3 p = random_in_unit_disk(&local_rand);
        Vector3 ray_origin = cam.center + p.x * cam.defocus_disk_u + p.y * cam.defocus_disk_v;
        float ox = curand_uniform(&local_rand) - 0.5f;
        float oy = curand_uniform(&local_rand) - 0.5f;
        Vector3 sample = cam.pixel00_loc + (i + ox) * cam.pixel_delta_u + (j + oy) * cam.pixel_delta_v;
        Ray r = Ray(ray_origin, sample - ray_origin);
        pixel_color = pixel_color + ray_color(r, world, n, &local_rand);;
    }
    rs[pixel_index] = local_rand;
    pixel_color = pixel_color * 1.0f/spp;
    int idx = 3 * (j * width + i);
    fb[idx] = sqrtf(pixel_color.x);
    fb[idx+1] = sqrtf(pixel_color.y);
    fb[idx+2] = sqrtf(pixel_color.z);

}
__global__ void scene(Sphere* world, int* actual, curandState* rs){
    curandState sc;
    curand_init(1984,0,0,&sc);
    world[0] = {Vector3(0,-1000,0), 1000, Material{LAMBERTIAN, Vector3(0.5,0.5,0.5), 0.0f, 0.0f}};
    world[1] = {Vector3(0,1,0), 1 , Material{DIELECTRIC, Vector3(), 0.0F, 1.5f}};
    world[2] = {Vector3(-4,1,0), 1, Material{LAMBERTIAN, Vector3(0.4,0.2,0.1), 0.0f, 0.0f}};
    world[3] = {Vector3(4,1,0), 1, Material{METAL, Vector3(0.7,0.6,0.5), 0.0f, 0.0f}};
    int k = 4;
    for (int a = -11; a < 11; a++) {
        for (int b = -11; b < 11; b++) {
            float choose = curand_uniform(&sc);
            Vector3 center(a + 0.9f*curand_uniform(&sc), 0.2f, b + 0.9f*curand_uniform(&sc));
            Vector3 d = center - Vector3(4.0f, 0.2f, 0.0f);
            if (length(d) > 0.9f) {              // skip spheres that hit the big one
                Material mat;
                if (choose < 0.8f) {                    // 80% diffuse
                    mat.type = LAMBERTIAN;
                    Vector3 albedo = random_vector(&sc) * random_vector(&sc);
                    mat.albedo = albedo;
                } else if (choose < 0.95f) {            // 15% metal
                    mat.type = METAL;
                    mat.albedo = random_vector(&sc);
                    mat.fuzz = curand_uniform(&sc);
                } else {                                // 5% glass
                    mat.type = DIELECTRIC;
                    mat.ior = 1.5f;
                }
                world[k] = {center, 0.2f, mat};
                k++;
            }
        }
    }
    *actual = k;

}