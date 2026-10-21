#pragma once

#include "cybernet/brain/rnn_brain.hpp"
#include "cybernet/organism_types.hpp"
#include "cybernet/vec3.hpp"

#include <algorithm>
#include <array>
#include <cstddef>
#include <cstdint>

namespace cybernet {

inline constexpr std::size_t SpeedGeneIndex = RnnBrain::GenomeSize;
inline constexpr std::size_t GenomeSize = RnnBrain::GenomeSize + 1U;
inline constexpr std::uint32_t StarvationDeathTicks = 100;
inline constexpr float StarvationHealthDamage = 1.0F;

enum class OrganismState : std::uint8_t {
    Alive,
    Dead
};

enum class DeathCause : std::uint8_t {
    None,
    Starvation,
    Age,
    Predation
};

struct OpticalDiagnostics {
    // -1 means no decision this tick (e.g. a newborn at end-of-tick).
    std::int64_t tick{-1};
    float sensorLight{0}, photosyntheticLight{0}, photosyntheticEnergy{0};
};
struct Organism {
    OpticalDiagnostics opticalDiagnostics{};
    bool liveQuarantined{false}; // Live transport recovery only; never a death.
    std::array<float,5> liveIntent{.5F,.5F,.5F,0,0};
    std::uint32_t liveTarget{0};
    std::uint32_t id{0};
    std::uint32_t parentId{0};
    std::uint32_t rootAncestorId{0};

    std::uint32_t generation{0};
    std::uint32_t birthTick{0};
    std::uint32_t birthCohort{0};

    OrganismType species{OrganismType::Cyanobacteria};

    RnnBrain brain{};
    bool brainInitialized{false};

    Vec3 position{};
    Vec3 velocity{};
    Vec3 acceleration{};

    // Python-compatible inherited physical trait.
    float speed{CyanobacteriaProfile.baseSpeed};

    float energy{CyanobacteriaProfile.startingEnergy};
    float health{100.0F};
    float foodIntake{0.0F};

    std::uint32_t starvationTicks{0};
    std::uint32_t ageTicks{0};
    std::uint32_t feedingCooldownTicks{0};
    std::uint32_t reproductionCooldownTicks{0};

    OrganismState state{OrganismState::Alive};
    DeathCause deathCause{DeathCause::None};

    std::array<float, GenomeSize> genome{};

    [[nodiscard]] bool alive() const noexcept {
        return state == OrganismState::Alive;
    }

    [[nodiscard]] const OrganismProfile& profile() const noexcept {
        return profileFor(species);
    }

    void configureSpecies(OrganismType newSpecies) noexcept {
        species = newSpecies;

        const OrganismProfile& speciesProfile = profile();

        speed = speciesProfile.baseSpeed;
        energy = speciesProfile.startingEnergy;

        starvationTicks = 0;
        ageTicks = 0;
        feedingCooldownTicks = 0;
        reproductionCooldownTicks = 0;
        state = OrganismState::Alive;
        deathCause = DeathCause::None;
    }

    void initializeBrain() {
        RnnBrain::Genome neuralGenome{};
        std::copy_n(
            genome.begin(),
            RnnBrain::GenomeSize,
            neuralGenome.begin());
        brain.decodeGenome(neuralGenome);

        const float normalizedSpeedGene = std::clamp(
            (genome[SpeedGeneIndex] + 1.0F) * 0.5F,
            0.0F,
            1.0F);
        speed = profile().minimumSpeed
            + ((profile().maximumSpeed - profile().minimumSpeed)
                * normalizedSpeedGene);
        brainInitialized = true;
    }

    void kill(DeathCause cause) noexcept {
        if (!alive()) {
            return;
        }

        state = OrganismState::Dead;
        health = 0.0F;
        deathCause = cause;
    }

    void die(DeathCause cause) noexcept {
        kill(cause);
    }

    void spendEnergy(float amount) noexcept {
        if (!alive()) {
            return;
        }

        energy -= std::max(0.0F, amount);

        if (energy <= 0.0F) {
            energy = 0.0F;
            health = std::max(0.0F, health - StarvationHealthDamage);
            ++starvationTicks;

            if (starvationTicks >= StarvationDeathTicks) {
                die(DeathCause::Starvation);
            }
        }
    }

    void gainEnergy(float amount) noexcept {
        if (!alive()) {
            return;
        }

        energy = std::min(
            profile().maximumEnergy,
            energy + std::max(0.0F, amount));

        if (energy > 0.0F) {
            starvationTicks = 0;
        }
    }

    void tickAge() noexcept {
        if (!alive()) {
            return;
        }

        ++ageTicks;

        if (feedingCooldownTicks > 0U) {
            --feedingCooldownTicks;
        }

        if (reproductionCooldownTicks > 0U) {
            --reproductionCooldownTicks;
        }

        if (ageTicks >= profile().maximumAgeTicks) {
            die(DeathCause::Age);
        }
    }

    void applyPhysics(float drag) noexcept {
        velocity += acceleration;
        velocity = velocity * drag;
        position += velocity;
        acceleration = {};
    }
};

} // namespace cybernet

