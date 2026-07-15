#include <iostream>
#include "vec3.h"
#include "ray.h"
#include "hittable.h"
#include <limits>

Vector3 ray_color(const Ray& r, const Hittable& world){
    const float infinity = std::numeric_limits<float>::infinity();
    hit_record rec;
    if (world.hit(r, 0.001f, infinity, rec)){
        return 0.5f * (rec.N + Vector3(1.0f, 1.0f, 1.0f));
    }else{
        Vector3 unit_direction = unit(r.direction);
        float a = 0.5f * (unit_direction.y + 1.0f);
        return (1.0f - a) * Vector3(1.0f,1.0f,1.0f) + a * Vector3(0.5f, 0.7f, 1.0f); 
    }
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
    
    Ray ray;

    HittableList world;
    world.add(std::make_shared<Sphere>(Sphere()));
    

    for (int i = 0; i < height; i++){
        for(int j = 0; j < width; j++){
            Vector3 pixel_center = pixel00 + j*pixel_delta_u + i*pixel_delta_v;
            Vector3 ray_direction = pixel_center - camera_center;

            ray.origin = camera_center;
            ray.direction = ray_direction;
 
            Vector3 color = ray_color(ray, world) * 255.999f;

            int x = static_cast<int>(color.x);
            int y = static_cast<int>(color.y);
            int z = static_cast<int>(color.z);
            std::cout << x << " " << y << " " << z << std::endl;
            
        }
        std::cout << '\n' << std::endl;
    }
    
    return 0;
}