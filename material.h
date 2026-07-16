#ifndef MATERIAL_H
#define MATERIAL_H

#include "hittable.h"
#include <memory>
#include "ray.h"
#include "vec3.h"


class Material {
    public:
        virtual ~Material() = default;
        virtual bool scatter(const Ray& r_in, const hit_record& rec, Vector3& attenuation, Ray& scattered) const = 0;
};

class Lambertian : public Material {
    public:
        Vector3 albedo;
        Lambertian(){}

        Lambertian(const Vector3& albedo){
            this->albedo = albedo;
        }

        bool scatter(const Ray& r_in, const hit_record& rec, Vector3& attenuation, Ray& scattered) const override{
            Vector3 dir = rec.N + random_unit_vector();
            if(near_zero(dir)) dir = rec.N;
            scattered = Ray(rec.p, dir);
            attenuation = albedo;
            return true;
        }
};

class Metal : public Material{
    public:
        Vector3 albedo;
        float fuzz;

        Metal(){}

        Metal(const Vector3& albedo, float fuzz){
            this->albedo = albedo;
            this->fuzz = (fuzz < 1.0f) ? fuzz : 1.0f;
        }

        bool scatter(const Ray& r_in, const hit_record& rec, Vector3& attenuation, Ray& scattered) const override{
            Vector3 reflected = reflect(unit(r_in.direction), rec.N);
            reflected = unit(reflected) + fuzz * random_unit_vector();
            scattered = Ray(rec.p, reflected);
            attenuation = albedo;
            return (dot(scattered.direction, rec.N) > 0);
        }

};

class Dielectric : public Material {
    public:
        float refraction_index;
        Dielectric(float ri) : refraction_index(ri) {}
    
        bool scatter(const Ray& r_in, const hit_record& rec,
                     Vector3& attenuation, Ray& scattered) const override {
            attenuation = Vector3(1.0f, 1.0f, 1.0f);
            float ri = rec.front_face ? (1.0f / refraction_index) : refraction_index;
    
            Vector3 unit_dir = unit(r_in.direction);
            float cos_theta = fminf(dot(neg(unit_dir), rec.N), 1.0f);
            float sin_theta = sqrtf(1.0f - cos_theta * cos_theta);
    
            bool cannot_refract = ri * sin_theta > 1.0f; 
            Vector3 direction;
            if (cannot_refract || reflectance(cos_theta, ri) > rand_float())
                direction = reflect(unit_dir, rec.N);
            else
                direction = refract(unit_dir, rec.N, ri);
    
            scattered = Ray(rec.p, direction);
            return true;
        }
    
    private:
        static float reflectance(float cosine, float ri) {
            float r0 = (1.0f - ri) / (1.0f + ri);
            r0 = r0 * r0;
            return r0 + (1.0f - r0) * powf(1.0f - cosine, 5.0f);
        }
};

#endif