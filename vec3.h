#ifndef VEC3_H
#define VEC3_H

#include <iostream>
#include <cmath>

class Vector3 {
public:
    double x, y, z;

    // Default Constructor
    Vector3() {
        x = 0;
        y = 0;
        z = 0;
    }

    // Parameterized Constructor
    Vector3(double x, double y, double z) {
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

inline Vector3 operator*(const Vector3& v, double scalar) {
    return Vector3(v.x * scalar, v.y * scalar, v.z * scalar);
}

// Allows scalar * vector order multiplication (e.g., 2.5 * velocity)
inline Vector3 operator*(double scalar, const Vector3& v) {
    return Vector3(v.x * scalar, v.y * scalar, v.z * scalar);
}

inline Vector3 operator/(const Vector3& v1, const Vector3& v2) {
    return Vector3(v1.x / v2.x, v1.y / v2.y, v1.z / v2.z);
}

inline Vector3 operator/(const Vector3& v1, double scalar) {
    return Vector3(v1.x / scalar, v1.y / scalar, v1.z / scalar);
}

inline Vector3 neg(const Vector3& v) {
    return Vector3(-v.x, -v.y, -v.z);
}

inline double dot(const Vector3& v1, const Vector3& v2) {
    return v1.x * v2.x + v1.y * v2.y + v1.z * v2.z;
}

inline Vector3 unit(const Vector3& v) {
    return v / std::sqrt(dot(v, v));
}

#endif