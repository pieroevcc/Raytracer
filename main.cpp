#include <iostream>
#include "vec3.h"
#include "ray.h"
#include "hittable.h"
#include "material.h"
#include "camera.h"
#include <algorithm>


int main() {
    HittableList world;

    auto ground = std::make_shared<Lambertian>(Vector3(0.5f, 0.5f, 0.5f));
    world.add(std::make_shared<Sphere>(Vector3(0.0f, -1000.0f, 0.0f), 1000.0f, ground));

    for (int a = -11; a < 11; a++) {
        for (int b = -11; b < 11; b++) {
            float choose = rand_float();
            Vector3 center(a + 0.9f*rand_float(), 0.2f, b + 0.9f*rand_float());
            Vector3 d = center - Vector3(4.0f, 0.2f, 0.0f);
            if (length(d) > 0.9f) {              // skip spheres that hit the big one
                std::shared_ptr<Material> mat;
                if (choose < 0.8f) {                    // 80% diffuse
                    Vector3 albedo = random_vector(0.0f,1.0f) * random_vector(0.0f,1.0f);
                    mat = std::make_shared<Lambertian>(albedo);
                } else if (choose < 0.95f) {            // 15% metal
                    mat = std::make_shared<Metal>(random_vector(0.5f,1.0f), random_float(0.0f,0.5f));
                } else {                                // 5% glass
                    mat = std::make_shared<Dielectric>(1.5f);
                }
                world.add(std::make_shared<Sphere>(center, 0.2f, mat));
            }
        }
    }
    world.add(std::make_shared<Sphere>(Vector3( 0.0f, 1.0f, 0.0f), 1.0f, std::make_shared<Dielectric>(1.5f)));
    world.add(std::make_shared<Sphere>(Vector3(-4.0f, 1.0f, 0.0f), 1.0f, std::make_shared<Lambertian>(Vector3(0.4f,0.2f,0.1f))));
    world.add(std::make_shared<Sphere>(Vector3( 4.0f, 1.0f, 0.0f), 1.0f, std::make_shared<Metal>(Vector3(0.7f,0.6f,0.5f), 0.0f)));

    Camera cam; 
    cam.image_width = 400;
    cam.samples_per_pixel = 100;
    
    cam.render(world);
    return 0;
}