#ifndef VEC3_H
#define VEC3_H

#include <iostream>
#include <cmath>
#include <cstdlib>

class Vector3 {
public:
    float x, y, z;

    // Default Constructor
    Vector3() {
        x = 0;
        y = 0;
        z = 0;
    }

    // Parameterized Constructor
    Vector3(float x, float y, float z) {
        this->x = x;
        this->y = y;
        this->z = z;
    }

    // Member function to print the vector
    void print() const {
        std::cout << x << " " << y << " " << z << std::endl;
    }
}; 


inline Vector3 operator+(const Vector3& v1, const Vector3& v2) {
    return Vector3(v1.x + v2.x, v1.y + v2.y, v1.z + v2.z);
}

inline Vector3 operator-(const Vector3& v1, const Vector3& v2) {
    return Vector3(v1.x - v2.x, v1.y - v2.y, v1.z - v2.z);
}

inline Vector3 operator*(const Vector3& v1, const Vector3& v2) {
    return Vector3(v1.x * v2.x, v1.y * v2.y, v1.z * v2.z);
}

inline Vector3 operator*(const Vector3& v, float scalar) {
    return Vector3(v.x * scalar, v.y * scalar, v.z * scalar);
}

// Allows scalar * vector order multiplication (e.g., 2.5 * velocity)
inline Vector3 operator*(float scalar, const Vector3& v) {
    return Vector3(v.x * scalar, v.y * scalar, v.z * scalar);
}

inline Vector3 operator/(const Vector3& v1, const Vector3& v2) {
    return Vector3(v1.x / v2.x, v1.y / v2.y, v1.z / v2.z);
}

inline Vector3 operator/(const Vector3& v1, float scalar) {
    return Vector3(v1.x / scalar, v1.y / scalar, v1.z / scalar);
}

inline Vector3 neg(const Vector3& v) {
    return Vector3(-v.x, -v.y, -v.z);
}

inline Vector3 operator-(const Vector3& v){ return neg(v); }


inline float dot(const Vector3& v1, const Vector3& v2) {
    return v1.x * v2.x + v1.y * v2.y + v1.z * v2.z;
}

inline Vector3 unit(const Vector3& v) {
    return v / std::sqrt(dot(v, v));
}

inline float rand_float(){
    return rand() / (RAND_MAX + 1.0f);
}

inline float random_float(float min, float max){
    return min + (max - min) * rand_float();
}

inline Vector3 random_vector(float min , float max){
    return Vector3(random_float(min, max), random_float(min, max), random_float(min, max));
}

inline Vector3 random_unit_vector(){
    while(true){
        Vector3 p = random_vector(-1.0f, 1.0f);
        float lensq = dot(p,p);
        if (1e-30f < lensq && lensq <= 1.0f) return p /sqrtf(lensq);
    }
}

inline bool near_zero(const Vector3& v){
    return fabsf(v.x) < 1e-8f && fabsf(v.y) < 1e-8f && fabsf(v.z) < 1e-8f;
}

inline Vector3 reflect(const Vector3& v, const Vector3& n){
    return v - 2.0f * dot(v, n) * n;
}

inline Vector3 refract(const Vector3& uv, const Vector3& n, float etai_over_etat) {
    float cos_theta = fminf(dot(-uv, n), 1.0f);
    Vector3 r_out_perp = etai_over_etat * (uv + cos_theta * n);
    Vector3 r_out_parallel = -sqrtf(fabsf(1.0f - dot(r_out_perp, r_out_perp))) * n;
    return r_out_parallel + r_out_perp;
}

#endif