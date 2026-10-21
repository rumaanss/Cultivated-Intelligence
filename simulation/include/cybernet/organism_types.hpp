#pragma once

#include <cstdint>
#include <optional>

namespace cybernet {

enum class OrganismType : std::uint8_t {
    Cyanobacteria,
    Bacterivore,
    BodoSaltans
};

struct OrganismProfile {
    float startingEnergy;
    float maximumEnergy;
    float reproductionEnergy;
    float postReproductionEnergy;

    float photosynthesisRate{0.0F};
    float photosynthesisLightThreshold{0.0F};

    float baseSpeed;
    float speedMutationStrength;
    float minimumSpeed;
    float maximumSpeed;

    float movementCost;
    std::uint32_t maximumAgeTicks;
    std::uint32_t minimumReproductionAgeTicks;

    std::optional<OrganismType> preyType;
    float assimilationEfficiency;
    std::uint32_t feedingIntervalTicks;
    std::uint32_t reproductionIntervalTicks;
};

inline constexpr OrganismProfile CyanobacteriaProfile{
    .startingEnergy = 20.0F,
    .maximumEnergy = 100.0F,
    .reproductionEnergy = 90.0F,
    .postReproductionEnergy = 36.0F,

    .photosynthesisRate = 0.55F,
    .photosynthesisLightThreshold = 0.05F,

    .baseSpeed = 0.30F,
    .speedMutationStrength = 0.10F,
    .minimumSpeed = 0.05F,
    .maximumSpeed = 0.50F,

    .movementCost = 0.010F,
    .maximumAgeTicks = 3750U,
    .minimumReproductionAgeTicks = 30U,

    .preyType = std::nullopt,
    .assimilationEfficiency = 0.0F,
    .feedingIntervalTicks = 0U,
    .reproductionIntervalTicks = 30U,
};

inline constexpr OrganismProfile BacterivoreProfile{
    .startingEnergy = 44.0F,
    .maximumEnergy = 150.0F,
    .reproductionEnergy = 110.0F,
    .postReproductionEnergy = 54.0F,

    .photosynthesisRate = 0.0F,
    .photosynthesisLightThreshold = 1.0F,

    .baseSpeed = 0.90F,
    .speedMutationStrength = 0.35F,
    .minimumSpeed = 0.05F,
    .maximumSpeed = 2.00F,

    .movementCost = 0.018F,
    .maximumAgeTicks = 4250U,
    .minimumReproductionAgeTicks = 500U,

    .preyType = OrganismType::Cyanobacteria,
    .assimilationEfficiency = 0.75F,
    .feedingIntervalTicks = 12U,
    .reproductionIntervalTicks = 100U,
};

inline constexpr OrganismProfile BodoSaltansProfile{
    .startingEnergy = 75.0F,
    .maximumEnergy = 250.0F,
    .reproductionEnergy = 150.0F,
    .postReproductionEnergy = 75.0F,

    .photosynthesisRate = 0.0F,
    .photosynthesisLightThreshold = 1.0F,

    .baseSpeed = 0.90F,
    .speedMutationStrength = 0.25F,
    .minimumSpeed = 0.05F,
    .maximumSpeed = 1.20F,

    .movementCost = 0.030F,
    .maximumAgeTicks = 5000U,
    .minimumReproductionAgeTicks = 2500U,

    .preyType = OrganismType::Bacterivore,
    .assimilationEfficiency = 0.70F,
    .feedingIntervalTicks = 40U,
    .reproductionIntervalTicks = 400U,
};

[[nodiscard]] inline constexpr const OrganismProfile&
profileFor(OrganismType species) noexcept {
    switch (species) {
    case OrganismType::Cyanobacteria:
        return CyanobacteriaProfile;

    case OrganismType::Bacterivore:
        return BacterivoreProfile;

    case OrganismType::BodoSaltans:
        return BodoSaltansProfile;
    }

    return CyanobacteriaProfile;
}

} // namespace cybernet
