#pragma once

#include <array>

namespace cybernet {

struct Organism;
class GeometryWorld;

void applyPhysics(
    Organism& agent,
    const std::array<float, 5>& action,
    float drag, const GeometryWorld* geometry = nullptr) noexcept;

} // namespace cybernet

