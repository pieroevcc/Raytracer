#ifndef RAY_H
#define RAY_H

#include "vec3.h"

class Ray {
    public:
        Vector3 origin, direction;

    Ray(){}

    Ray (const Vector3& origin, const Vector3& direction){
        this->origin = origin;
        this->direction = direction;
    }

    Vector3 at(float t) const{
        return origin + t * direction;
    }
};

#endif