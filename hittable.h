#ifndef HITTABLE_H
#define HITTABLE_H

#include "ray.h"
#include "vec3.h"
#include <vector>
#include <memory>

class Material;

struct hit_record{
    Vector3 p, N;
    std::shared_ptr<Material> mat;
    float t;
    bool front_face;

    void set_face_normal(const Ray& r, const Vector3& outward_normal){
        front_face = dot(r.direction, outward_normal) < 0.0f;
        N = front_face ? outward_normal : neg(outward_normal);
    }
};




class Hittable {
    public:
        virtual bool hit(const Ray& r, float t_min, float t_max, hit_record& rec) const = 0;
        virtual ~Hittable() = default;
};

class Sphere : public Hittable {
    public:
        Vector3 center;
        float radius;
        std::shared_ptr<Material> mat;

        Sphere(const Vector3& center, float radius, const std::shared_ptr<Material>& mat) {
            this->center = center;
            this->radius = radius;
            this->mat = mat;
        }

        bool hit(const Ray& r, float t_min, float t_max, hit_record& rec) const override {
            //solving for t
            Vector3 oc = r.origin - center;
            Vector3 d = r.direction;
            float a = length_squared(d);
            float b = 2 * (dot(d, oc));
            float c = length_squared(oc) - (radius*radius);
            float disc = b*b - 4.0f*a*c;
            if (disc < 0) return false;
            float sqrtd = sqrtf(disc);
            float root = (-b - sqrtd) /(2.0f*a);
            //check root range
            if (root <= t_min || root >= t_max){
                root = (-b + sqrtd) / (2.0f*a);
                if (root <= t_min || root >= t_max){
                    return false;
                }
            }
            rec.t = root;
            rec.p = r.at(root);
            Vector3 outward_normal = (rec.p - center) / radius;
            rec.set_face_normal(r, outward_normal);
            rec.mat = mat;
            return true;
        }
};

class HittableList : public Hittable {
    public: 
        std::vector<std::shared_ptr<Hittable>> objects;

        HittableList(){};

        void add(std::shared_ptr<Hittable> object){
            objects.push_back(object);
        }
        
        void clear(){
            objects.clear();
        }

        bool hit (const Ray& r, float t_min, float t_max, hit_record& rec) const override{
            hit_record temp_rec;
            bool hit_anything = false;
            float closest = t_max;

            for (const auto& object : objects){
                if (object->hit(r, t_min, closest, temp_rec)){
                    hit_anything = true;
                    closest = temp_rec.t;
                    rec = temp_rec;
                }
            }
            return hit_anything;
        }
};

#endif