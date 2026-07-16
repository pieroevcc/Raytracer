#include <iostream>
#include "vec3.h"
#include "ray.h"
#include "hittable.h"
#include "material.h"
#include <limits>
#include <algorithm>

const float infinity = std::numeric_limits<float>::infinity();

Vector3 ray_color(const Ray& r, const Hittable& world, int depth){
    if (depth <= 0) return Vector3(0,0,0);
    hit_record rec;
    if (world.hit(r, 0.001f, infinity, rec)){
        Ray scattered;
        Vector3 attenuation;
        if(rec.mat->scatter(r, rec, attenuation, scattered)){
            return attenuation * ray_color(scattered, world, depth-1);
        }
        return Vector3(0,0,0);
    }else{
        Vector3 unit_direction = unit(r.direction);
        float a = 0.5f * (unit_direction.y + 1.0f);
        return (1.0f - a) * Vector3(1.0f,1.0f,1.0f) + a * Vector3(0.5f, 0.7f, 1.0f); 
    }
}

std::ostream& write_color(std::ostream& str, Vector3 color){
    int x = static_cast<int>(256 * std::clamp(std::sqrt(color.x), 0.0f, 0.999f));
    int y = static_cast<int>(256 * std::clamp(std::sqrt(color.y), 0.0f, 0.999f));
    int z = static_cast<int>(256 * std::clamp(std::sqrt(color.z), 0.0f, 0.999f));
    str << x << " " << y << " " << z;
    return str;
}

int main() {
    const int height = 256;
    const int width = 256;
    const int size = 255;
    std::cout << "P3" << std::endl;
    std::cout << width << " " <<  height << std::endl;
    std::cout << size << std::endl;
    
    Vector3 camera_center = Vector3(0.0f,0.0f,0.0f);
    Vector3 viewport_u = Vector3(2.0f,0.0f,0.0f);
    Vector3 viewport_v = Vector3(0.0f,-2.0f,0.0f);
    Vector3 pixel_delta_u = viewport_u/256.0f;
    Vector3 pixel_delta_v = viewport_v/256.0f;
    Vector3 pixel00 = 0.5f * (pixel_delta_u + pixel_delta_v) +  camera_center - Vector3(0.0f,0.0f,1.0f) - viewport_u/2 - viewport_v/2;
    

    HittableList world;


    auto ground = std::make_shared<Lambertian>(Vector3(0.8f, 0.8f, 0.0f));
    auto center = std::make_shared<Lambertian>(Vector3(0.1f, 0.2f, 0.5f));
    auto left   = std::make_shared<Metal>(Vector3(0.8f, 0.8f, 0.8f));
    auto right  = std::make_shared<Metal>(Vector3(0.8f, 0.6f, 0.2f));
    
    world.add(std::make_shared<Sphere>(Vector3( 0.0f, -100.5f, -1.0f), 100.0f, ground));
    world.add(std::make_shared<Sphere>(Vector3( 0.0f,    0.0f, -1.0f),   0.5f, center));
    world.add(std::make_shared<Sphere>(Vector3(-1.0f,    0.0f, -1.0f),   0.5f, left));
    world.add(std::make_shared<Sphere>(Vector3( 1.0f,    0.0f, -1.0f),   0.5f, right));

    const int samples_per_pixel = 100;
    const float pixel_samples_scale = 1.0f / samples_per_pixel;
    const int max_depth = 50;
   

    for (int i = 0; i < height; i++){
        for(int j = 0; j < width; j++){
            Vector3 pixel_color(0,0,0);
            for (int s = 0; s < samples_per_pixel; s++){
                float ox = rand_float() - 0.5f;
                float oy = rand_float() - 0.5f;
                Vector3 sample = pixel00 + (j + ox) * pixel_delta_u + (i + oy) * pixel_delta_v;
                Ray r(camera_center, sample - camera_center);
                pixel_color = pixel_color + ray_color(r,world, max_depth);
            }
            pixel_color = pixel_color * pixel_samples_scale;
            write_color(std::cout, pixel_color) << '\n';
        }
    }
    
    return 0;
}