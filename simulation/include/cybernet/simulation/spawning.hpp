#pragma once

#include "cybernet/random.hpp"
#include "cybernet/simulation/organism.hpp"

#include <cstdint>
#include <span>

namespace cybernet {

inline void randomizeGenome(
    Organism& organism,
    Random& random) noexcept {

    for (float& gene : organism.genome) {
        gene = random.uniform_float(-1.0F, 1.0F);
    }
}

inline void spawnOrganism(
    Organism& organism,
    std::uint32_t id,
    OrganismType species,
    const Vec3& position,
    std::uint32_t birthTick,
    std::uint32_t cohort,
    Random& random) {

    organism = {};
    organism.id = id;
    organism.parentId = 0U;
    organism.rootAncestorId = id;
    organism.generation = 0;
    organism.birthTick = birthTick;
    organism.birthCohort = cohort;
    organism.position = position;

    organism.configureSpecies(species);
    randomizeGenome(organism, random);
    organism.initializeBrain();
}

inline void randomizeFounderAge(
    Organism& organism,
    Random& random) noexcept {

    const std::uint32_t maximumAge = organism.profile().maximumAgeTicks;
    organism.ageTicks = static_cast<std::uint32_t>(
        random.uniform_int(0, static_cast<int>(maximumAge - 1U)));
}

} // namespace cybernet
