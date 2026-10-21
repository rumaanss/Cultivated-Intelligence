#pragma once

#include "cybernet/random.hpp"
#include "cybernet/simulation/external_actor.hpp"
#include "cybernet/simulation/organism.hpp"

#include <span>

namespace cybernet {

class CelestialCycle;
class GeometryWorld;
class Ecology;
class ChemistryField;
struct ObservationNoise;

struct LifecycleContext {
    std::span<Organism> population{};
    std::span<const ExternalActor> externalActors{};
    const CelestialCycle* celestial{nullptr};
    Ecology* ecology{nullptr};
    ChemistryField* chemistry{nullptr};
    Random* random{nullptr};

    float worldWidth{100.0F};
    float worldHeight{100.0F};
    float worldDepth{60.0F};
};

struct LifecycleAction {
    RnnBrain::Outputs outputs{};
    RnnBrain::Inputs inputs{};
    float feedAttempt{0.0F};
    float photosyntheticEnergyGained{0.0F};
    float preyEnergyCaptured{0.0F};
    float predatorEnergyGained{0.0F};
    float movementEnergySpent{0.0F};
    Organism* nearestPrey{nullptr};
    bool wasAtBoundary{false};
    bool isAtBoundary{false};
    bool feedSucceeded{false};
};

class Lifecycle {
public:
    [[nodiscard]] static LifecycleAction decide(
        Organism& organism,
        const LifecycleContext& context) noexcept;

    [[nodiscard]] static LifecycleAction decide(
        Organism& organism,
        const LifecycleContext& context,
        const ObservationNoise& noise) noexcept;

    static void applyMovement(
        Organism& organism,
        LifecycleAction& action,
        float drag, const GeometryWorld* geometry = nullptr) noexcept;

    static void completeTick(
        Organism& organism,
        LifecycleAction& action,
        const LifecycleContext& context) noexcept;

    static void tick(
        Organism& organism,
        const LifecycleContext& context,
        float drag) noexcept;
};

} // namespace cybernet

