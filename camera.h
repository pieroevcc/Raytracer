#ifndef CAMERA_H
#define CAMERA_H

#include <iostream>
#include "vec3.h"
#include "ray.h"
#include "hittable.h"
#include "material.h"
#include <limits>
#include <algorithm>
#include <fstream>
#include <chrono>

class Camera {
    public:
        float   aspect_ratio     = 16.0f / 9.0f;
        int     image_width      = 400;
        int     samples_per_pixel = 100;
        int     max_depth        = 50;
        float   vfov             = 20.0f;
        Vector3 lookfrom = Vector3(13,2,3), lookat = Vector3(0,0,0), vup = Vector3(0,1,0);
        float   defocus_angle = 0.6f, focus_dist = 10.0f;
    
        void render(const Hittable& world) {
            initialize();
            std::ofstream out("image.ppm");
            out << "P3\n" << image_width << " " << image_height << "\n255\n";

            auto start = std::chrono::steady_clock::now();
            for (int i = 0; i < image_height; i++){
                std::cerr << "\rScanlines remaining: " << (image_height - i) << "    " << std::flush;
                for(int j = 0; j < image_width; j++){
                    Vector3 pixel_color(0,0,0);
                    for (int s = 0; s < samples_per_pixel; s++){
                        pixel_color = pixel_color + ray_color(get_ray(i,j), world, max_depth);
                    }
                    pixel_color = pixel_color * pixel_samples_scale;
                    write_color(out, pixel_color) << '\n';
                }
            }
            auto end = std::chrono::steady_clock::now();
            double secs = std::chrono::duration<double>(end - start).count();
            std::cerr << "\rRender time: " << secs << " s  ("
                      << image_width << "x" << image_height << ", "
                      << samples_per_pixel << " spp, max depth " << max_depth << ")\n";
        }
    
    private:
        int     image_height;
        float   pixel_samples_scale;
        Vector3 center, pixel00, pixel_delta_u, pixel_delta_v;
        Vector3 u, v, w, defocus_disk_u, defocus_disk_v;

        std::ostream& write_color(std::ostream& str, Vector3 color){
            int x = static_cast<int>(256 * std::clamp(std::sqrt(color.x), 0.0f, 0.999f));
            int y = static_cast<int>(256 * std::clamp(std::sqrt(color.y), 0.0f, 0.999f));
            int z = static_cast<int>(256 * std::clamp(std::sqrt(color.z), 0.0f, 0.999f));
            str << x << " " << y << " " << z;
            return str;
        }
    
        void initialize() {
            image_height = int(image_width / aspect_ratio);
            pixel_samples_scale = 1.0f / samples_per_pixel;
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
            float viewport_width  = viewport_height * (float(image_width) / image_height);

            Vector3 viewport_u = viewport_width * u;
            Vector3 viewport_v = viewport_height * neg(v);
            pixel_delta_u = viewport_u/ float(image_width);
            pixel_delta_v = viewport_v/ float(image_height);
            Vector3 viewport_upper_left = center - focus_dist * w - viewport_u / 2.0f - viewport_v / 2.0f;
            pixel00 = 0.5f * (pixel_delta_u + pixel_delta_v) +  viewport_upper_left;
        }
    
        Ray get_ray(int i, int j) const {
            Vector3 p = random_in_unit_disk();
            Vector3 ray_origin = center + p.x * defocus_disk_u + p.y * defocus_disk_v;
            float ox = rand_float() - 0.5f;
            float oy = rand_float() - 0.5f;
            Vector3 sample = pixel00 + (j + ox) * pixel_delta_u + (i + oy) * pixel_delta_v;
            return Ray(ray_origin, sample - ray_origin);

        }

        const float infinity = std::numeric_limits<float>::infinity();

        Vector3 ray_color(const Ray& r, const Hittable& world, int depth) const {
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
};


#endif