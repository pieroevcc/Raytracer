#include <iostream>
#include "vec3.h"
#include "ray.h"

float hit_sphere(const Vector3& center, float radius, const Ray& ray){
    Vector3 oc = ray.origin - center;
    Vector3 d = ray.direction;
    float a = dot(d,d);
    float b = 2 * (dot(d, oc));
    float c = dot(oc, oc) - (radius*radius);
    float disc = b*b - 4*a*c;

    return (disc < 0) ? -1.0f : (-b - sqrtf(disc)) / (2*a);
}

Vector3 ray_color(const Ray& ray){
    float t = hit_sphere(Vector3(0,0,-1), 0.5f, ray);
    if (t > 0.0f) {
        Vector3 P = ray.at(t);
        Vector3 N = unit(P - Vector3(0.0f,0.0f,-1.0f));
        return 0.5f * (N + Vector3(1.0f,1.0f,1.0f));

    }else{
        Vector3 unit_direction = unit(ray.direction);
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

    for (int i = 0; i < height; i++){
        for(int j = 0; j < width; j++){
            Vector3 pixel_center = pixel00 + j*pixel_delta_u + i*pixel_delta_v;
            Vector3 ray_direction = pixel_center - camera_center;

            ray.origin = camera_center;
            ray.direction = ray_direction;

            Vector3 color = ray_color(ray) * 255.999;

            int x = static_cast<int>(color.x);
            int y = static_cast<int>(color.y);
            int z = static_cast<int>(color.z);
            std::cout << x << " " << y << " " << z << std::endl;
        }
        std::cout << '\n' << std::endl;
    }
    
    return 0;
}