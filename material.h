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

        Metal(){}

        Metal(const Vector3& albedo){
            this->albedo = albedo;
        }

        bool scatter(const Ray& r_in, const hit_record& rec, Vector3& attenuation, Ray& scattered) const override{
            Vector3 reflected = reflect(unit(r_in.direction), rec.N);
            scattered = Ray(rec.p, reflected);
            attenuation = albedo;
            return true;
        }

};

#endif