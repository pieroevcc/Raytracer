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

    Vector3 lookfrom = Vector3(-2.0f, 2.0f,  1.0f);   
    Vector3 lookat   = Vector3(0.0f, 0.0f, -1.0f); 
    Vector3 vup      = Vector3(0.0f, 1.0f,  0.0f);  

    Vector3 camera_center = lookfrom;
    Vector3 w = unit(lookfrom - lookat);   
    Vector3 u = unit(cross(vup, w));     
    Vector3 v = cross(w, u);    

    float defocus_angle = 10.0f;
    float focus_dist = 3.4f; 

    float defocus_radius = focus_dist * tanf(degrees_to_radians(defocus_angle / 2.0f));
    Vector3 defocus_disk_u = u * defocus_radius;   
    Vector3 defocus_disk_v = v * defocus_radius;   

    float vfov = 30.0f;
    float theta = degrees_to_radians(vfov);
    float h = tanf(theta / 2.0f);
    float viewport_height = 2.0f * h * focus_dist;
    float viewport_width  = viewport_height * (float(width) / height);

 
    Vector3 viewport_u = viewport_width * u;
    Vector3 viewport_v = viewport_height * neg(v);
    Vector3 pixel_delta_u = viewport_u/ float(width);
    Vector3 pixel_delta_v = viewport_v/ float(height);
    Vector3 viewport_upper_left = camera_center - focus_dist * w - viewport_u / 2.0f - viewport_v / 2.0f;
    Vector3 pixel00 = 0.5f * (pixel_delta_u + pixel_delta_v) +  viewport_upper_left;
    

    HittableList world;


    auto ground = std::make_shared<Lambertian>(Vector3(0.8f, 0.8f, 0.0f));
    auto center = std::make_shared<Lambertian>(Vector3(0.1f, 0.2f, 0.5f));
    auto left = std::make_shared<Dielectric>(1.5f);
    auto right  = std::make_shared<Metal>(Vector3(0.8f, 0.6f, 0.2f), 1.0f);
    
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
                Vector3 p = random_in_unit_disk();
                Vector3 ray_origin = camera_center + p.x * defocus_disk_u + p.y * defocus_disk_v;  
                float ox = rand_float() - 0.5f;
                float oy = rand_float() - 0.5f;
                Vector3 sample = pixel00 + (j + ox) * pixel_delta_u + (i + oy) * pixel_delta_v;
                Ray r(ray_origin, sample - ray_origin); 
                pixel_color = pixel_color + ray_color(r,world, max_depth);
            }
            pixel_color = pixel_color * pixel_samples_scale;
            write_color(std::cout, pixel_color) << '\n';
        }
    }
    
    return 0;
}