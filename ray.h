#ifndef RAY_H
#define RAY_H

#include "vec3.h"

class Ray {
    public:
        Vector3 origin, direction;

    HD Ray(){}

    HD Ray (const Vector3& origin, const Vector3& direction){
        this->origin = origin;
        this->direction = direction;
    }

    HD Vector3 at(float t) const{
        return origin + t * direction;
    }
};

#endif