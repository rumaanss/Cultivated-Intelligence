#pragma once

#include "cybernet/simulation/organism.hpp"

#include <algorithm>

namespace cybernet {

[[nodiscard]] inline float photosynthesize(
    Organism& organism,
    float daylight,
    float worldDepth,
    float nutrientSupport = 1.0F) noexcept {

    if (!organism.alive() ||
        organism.species != OrganismType::Cyanobacteria) {
        return 0.0F;
    }

    const OrganismProfile& profile = organism.profile();

    if (daylight < profile.photosynthesisLightThreshold) {
        return 0.0F;
    }

    // Z=0 is deepest; Z=worldDepth is the surface.
    const float depthBelowSurface =
        worldDepth - organism.position.z;

    const float effectiveLightDepth = 40.0F;

    const float depthFactor = std::clamp(
        (effectiveLightDepth - depthBelowSurface) / effectiveLightDepth,
        0.0F,
        1.0F);

    const float gainedEnergy =
        profile.photosynthesisRate
        * std::clamp(daylight, 0.0F, 1.0F)
        * depthFactor
        * std::clamp(nutrientSupport, 0.0F, 1.25F);

    const float energyBefore = organism.energy;

    organism.gainEnergy(gainedEnergy);

    return organism.energy - energyBefore;
}

// Optical field supplies availability; species traits and nutrients determine response.
[[nodiscard]] inline float photosynthesizeLocal(Organism& organism,
    float localLight, float nutrientSupport = 1.0F) noexcept {
    if (!organism.alive() || organism.species != OrganismType::Cyanobacteria ||
        localLight < organism.profile().photosynthesisLightThreshold) return 0;
    const float before = organism.energy;
    organism.gainEnergy(organism.profile().photosynthesisRate
        * std::clamp(localLight,0.0F,1.0F)*std::clamp(nutrientSupport,0.0F,1.25F));
    return organism.energy-before;
}
} // namespace cybernet

