#pragma once

#include <cmath>

namespace cybernet {

struct Vec3 {
    float x{0.0F};
    float y{0.0F};
    float z{0.0F};

    constexpr Vec3() = default;
    constexpr Vec3(float xValue, float yValue, float zValue)
        : x(xValue), y(yValue), z(zValue) {}

    [[nodiscard]] constexpr Vec3 operator+(const Vec3& other) const {
        return {x + other.x, y + other.y, z + other.z};
    }

    [[nodiscard]] constexpr Vec3 operator-(const Vec3& other) const {
        return {x - other.x, y - other.y, z - other.z};
    }

    [[nodiscard]] constexpr Vec3 operator*(float scalar) const {
        return {x * scalar, y * scalar, z * scalar};
    }

    constexpr Vec3& operator+=(const Vec3& other) {
        x += other.x;
        y += other.y;
        z += other.z;
        return *this;
    }

    [[nodiscard]] float lengthSquared() const {
        return (x * x) + (y * y) + (z * z);
    }

    [[nodiscard]] float length() const {
        return std::sqrt(lengthSquared());
    }

    [[nodiscard]] Vec3 normalized() const {
        const float magnitude = length();
        if (magnitude <= 0.000001F) {
            return {};
        }
        return *this * (1.0F / magnitude);
    }
};

} // namespace cybernet
