#include <iostream>
#include "vec3.h"
#include "ray.h"

double hit_sphere(const Vector3& center, double radius, const Ray& ray){
    Vector3 oc = ray.origin - center;
    Vector3 d = ray.direction;
    double a = dot(d,d);
    double b = 2 * (dot(d, oc));
    double c = dot(oc, oc) - (radius*radius);
    double disc = b*b - 4*a*c;

    return (disc < 0) ? -1.0 : (-b - sqrt(disc)) / (2*a);
}

Vector3 ray_color(const Ray& ray){
    double t = hit_sphere(Vector3(0,0,-1), 0.5, ray);
    if (t > 0) {
        Vector3 P = ray.at(t);
        Vector3 N = unit(P - Vector3(0,0,-1));
        return 0.5 * (N + Vector3(1,1,1));

    }else{
        Vector3 unit_direction = unit(ray.direction);
        double a = 0.5 * (unit_direction.y + 1.0);
        return (1.0 - a) * Vector3(1,1,1) + a * Vector3(0.5, 0.7, 1.0); 
    }
    return Vector3();
}



int main() {
    const int height = 256;
    const int width = 256;
    const int size = 255;
    std::cout << "P3" << std::endl;
    std::cout << width << " " <<  height << std::endl;
    std::cout << size << std::endl;
    
    Vector3 camera_center = Vector3(0,0,0);
    Vector3 viewport_u = Vector3(2,0,0);
    Vector3 viewport_v = Vector3(0,-2,0);
    Vector3 pixel_delta_u = viewport_u/256;
    Vector3 pixel_delta_v = viewport_v/256;
    Vector3 pixel00 = 0.5 * (pixel_delta_u + pixel_delta_v) +  camera_center - Vector3(0,0,1) - viewport_u/2 - viewport_v/2;
    
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