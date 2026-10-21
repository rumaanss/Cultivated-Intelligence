#include "cybernet/world/ecology.hpp"

#include "cybernet/simulation/simulation.hpp"
#include "cybernet/world/chemistry.hpp"

#include <algorithm>
#include <cmath>
#include <iterator>
#include <limits>
#include <vector>

namespace cybernet {
namespace {

constexpr float ObservationMinimum = -1.0F;
constexpr float ObservationMaximum = 1.0F;
constexpr float DirectionEpsilon = 0.00000001F;
constexpr float BodoReproductionPreyRatio = 10.0F;
constexpr float CrowdingReference = 8.0F;
constexpr float FoodReference = 8.0F;
constexpr float ThreatReference = 4.0F;
constexpr float MutationChance = 0.05F;
constexpr float MutationMagnitude = 0.10F;

[[nodiscard]] float clampObservation(float value) noexcept {
    return std::clamp(value, ObservationMinimum, ObservationMaximum);
}

[[nodiscard]] float signedUnit(float value) noexcept {
    return (std::clamp(value, 0.0F, 1.0F) * 2.0F) - 1.0F;
}

[[nodiscard]] float boundaryInwardSignal(
    float coordinate,
    float worldSize) noexcept {

    const float normalized = std::clamp(coordinate / worldSize, 0.0F, 1.0F);
    return normalized <= 0.5F
        ? 1.0F - (normalized * 2.0F)
        : -(normalized * 2.0F - 1.0F);
}

[[nodiscard]] bool closerOrLowerId(
    float distanceSquared,
    const Organism& candidate,
    float bestDistanceSquared,
    const Organism* bestCandidate) noexcept {

    return distanceSquared < bestDistanceSquared
        || (distanceSquared == bestDistanceSquared
            && (bestCandidate == nullptr || candidate.id < bestCandidate->id));
}

[[nodiscard]] bool isValidPrey(
    const Organism& predator,
    const Organism* candidate) noexcept {

    return candidate != nullptr
        && candidate->alive()
        && !candidate->liveQuarantined
        && predator.profile().preyType.has_value()
        && candidate->species == predator.profile().preyType.value();
}

[[nodiscard]] float distanceSquared(
    const Organism& left,
    const Organism& right) noexcept {

    return (left.position - right.position).lengthSquared();
}

Organism makeChild(
    const Organism& parent,
    std::uint32_t id,
    std::uint32_t tick,
    Random& random) {

    Organism child{};
    child.id = id;
    child.parentId = parent.id;
    child.rootAncestorId = parent.rootAncestorId;
    child.generation = parent.generation + 1U;
    child.birthTick = tick;
    child.birthCohort = parent.birthCohort + 1U;
    child.configureSpecies(parent.species);
    child.position = parent.position;
    child.velocity = {};
    child.acceleration = {};
    child.genome = parent.genome;

    for (std::size_t index = 0; index < child.genome.size(); ++index) {
        float& gene = child.genome[index];
        if (random.uniform_float(0.0F, 1.0F) < MutationChance) {
            const float mutationMagnitude = index == SpeedGeneIndex
                ? child.profile().speedMutationStrength
                : MutationMagnitude;
            gene = std::clamp(
                gene + random.uniform_float(
                    -mutationMagnitude,
                    mutationMagnitude),
                -1.0F,
                1.0F);
        }
    }

    child.initializeBrain();
    return child;
}

} // namespace

void Ecology::setChemistry(ChemistryField* chemistry) noexcept {
    chemistry_ = chemistry;
}

void Ecology::beginTick(std::span<const Organism> population) noexcept {
    cyanobacteriaCount_ = 0U;
    bacterivoreCount_ = 0U;
    bodoCount_ = 0U;
    refreshSpatialIndex(population);

    for (const Organism& organism : population) {
        if (!organism.alive()) {
            continue;
        }

        if (organism.species == OrganismType::Cyanobacteria) {
            ++cyanobacteriaCount_;
        } else if (organism.species == OrganismType::Bacterivore) {
            ++bacterivoreCount_;
        } else if (organism.species == OrganismType::BodoSaltans) {
            ++bodoCount_;
        }
    }

}

void Ecology::refreshSpatialIndex(
    std::span<const Organism> population, const CelestialCycle* celestial) noexcept {

    opticalRanges_.clear(); // Any position/index refresh invalidates the optical cache.
    spatialGrid_.rebuild(population);
    if (celestial != nullptr && celestial->usesOpticsV2()) {
        opticalTick_ = celestial->optics().tick();
        opticalSource_ = celestial;
        opticalConfig_ = celestial->optics().config();
        opticalRanges_.reserve(population.size());
        for (const auto& organism : population) {
            const float sensor=celestial->optics().sampleLight(organism.position).sensor;
            opticalRanges_.push_back({organism.position,
                celestial->optics().visibilityRangeForLight(sensor,VisionRadiusDay),
                sensor >= celestial->optics().config().detectionThreshold});
        }
    }
}

ObservationResult Ecology::buildObservation(
    const Organism& agent,
    std::span<Organism> population,
    const CelestialCycle& celestial,
    const ObservationNoise& noise) const {

    ObservationResult result{};
    const float localSensor = celestial.usesOpticsV2() ? celestial.optics().sampleLight(agent.position).sensor : celestial.state().ambientLight;
    const float visionRadius = std::max(
        celestial.usesOpticsV2() ? celestial.optics().visibilityRangeForLight(localSensor,VisionRadiusDay)
            : VisionRadiusDay * celestial.state().ambientLight,
        DirectionEpsilon);
    const float visionRadiusSquared = visionRadius * visionRadius;

    const bool cachedOptics = opticalRanges_.size() == population.size()
        && opticalSource_ == &celestial && opticalTick_ == celestial.optics().tick()
        && opticalConfig_ == celestial.optics().config();
    Organism* nearestPrey = nullptr;
    Organism* nearestThreat = nullptr;
    float nearestPreyDistanceSquared = std::numeric_limits<float>::infinity();
    float nearestThreatDistanceSquared =
        std::numeric_limits<float>::infinity();
    std::size_t sameSpeciesCount = 0U;
    std::size_t localFoodCount = 0U;
    std::size_t threatCount = 0U;

    spatialGrid_.forEachNearby(
        agent.position,
        visionRadius,
        [&](std::size_t candidateIndex) {
            Organism& candidate = population[candidateIndex];
            if (!candidate.alive() || candidate.liveQuarantined || candidate.id == agent.id) {
                return;
            }

            const float candidateDistanceSquared =
                (candidate.position - agent.position).lengthSquared();
            if (candidateDistanceSquared > visionRadiusSquared) {
                return;
            }

            if (celestial.usesOpticsV2()) {
                // min(observerLight,targetLight)*exp(-c*d) >= threshold is
                // equivalent to two precomputed distance bounds. No per-pair exp.
                float targetRange;
                bool targetDetectable;
                if (cachedOptics && opticalRanges_[candidateIndex].position.x == candidate.position.x
                    && opticalRanges_[candidateIndex].position.y == candidate.position.y
                    && opticalRanges_[candidateIndex].position.z == candidate.position.z) {
                    targetRange = opticalRanges_[candidateIndex].range;
                    targetDetectable = opticalRanges_[candidateIndex].detectable;
                } else {
                    const float sensor=celestial.optics().sampleLight(candidate.position).sensor;
                    targetRange=celestial.optics().visibilityRangeForLight(sensor,VisionRadiusDay);
                    targetDetectable=sensor>=celestial.optics().config().detectionThreshold;
                }
                if (!targetDetectable || candidateDistanceSquared > targetRange*targetRange ||
                    localSensor < celestial.optics().config().detectionThreshold) return;
            }

            if (geometry_ != nullptr && geometry_->blockedBetweenBodies(agent.position,candidate.position,true)) return;
            if (candidate.species == agent.species) {
                ++sameSpeciesCount;
            }

            if (agent.profile().preyType.has_value()
                && candidate.species == agent.profile().preyType.value()) {
                ++localFoodCount;
                if (closerOrLowerId(
                        candidateDistanceSquared,
                        candidate,
                        nearestPreyDistanceSquared,
                        nearestPrey)) {
                    nearestPrey = &candidate;
                    nearestPreyDistanceSquared = candidateDistanceSquared;
                }
            }

            if (candidate.profile().preyType.has_value()
                && candidate.profile().preyType.value() == agent.species) {
                ++threatCount;
                if (closerOrLowerId(
                        candidateDistanceSquared,
                        candidate,
                        nearestThreatDistanceSquared,
                        nearestThreat)) {
                    nearestThreat = &candidate;
                    nearestThreatDistanceSquared = candidateDistanceSquared;
                }
            }
        });

    float preyDirectionX = 0.0F;
    float preyDirectionY = 0.0F;
    float preyDirectionZ = 0.0F;
    float normalizedPreyDistance = 1.0F;
    float preyVisible = -1.0F;

    if (nearestPrey != nullptr) {
        const Vec3 offset = nearestPrey->position - agent.position;
        const float distance = std::sqrt(nearestPreyDistanceSquared);
        const float inverseDistance = 1.0F / (distance + DirectionEpsilon);
        preyDirectionX = offset.x * inverseDistance;
        preyDirectionY = offset.y * inverseDistance;
        preyDirectionZ = offset.z * inverseDistance;
        normalizedPreyDistance = std::min(distance / visionRadius, 1.0F);
        preyVisible = 1.0F;
    }

    float threatDirectionX = 0.0F;
    float threatDirectionY = 0.0F;
    float threatDirectionZ = 0.0F;
    float normalizedThreatDistance = 1.0F;

    if (nearestThreat != nullptr) {
        const Vec3 offset = nearestThreat->position - agent.position;
        const float distance = std::sqrt(nearestThreatDistanceSquared);
        const float inverseDistance = 1.0F / (distance + DirectionEpsilon);
        threatDirectionX = offset.x * inverseDistance;
        threatDirectionY = offset.y * inverseDistance;
        threatDirectionZ = offset.z * inverseDistance;
        normalizedThreatDistance = std::min(distance / visionRadius, 1.0F);
    }

    const float boundaryInwardX = boundaryInwardSignal(
        agent.position.x,
        config::WORLD_SIZE_X);
    const float boundaryInwardY = boundaryInwardSignal(
        agent.position.y,
        config::WORLD_SIZE_Y);
    const float boundaryInwardZ = boundaryInwardSignal(
        agent.position.z,
        config::WORLD_SIZE_Z);
    const float boundaryProximity = std::max({
        std::abs(boundaryInwardX),
        std::abs(boundaryInwardY),
        std::abs(boundaryInwardZ)
    });

    const float normalizedEnergy = signedUnit(
        agent.energy / agent.profile().maximumEnergy);
    const float normalizedDepth =
        ((agent.position.z / config::WORLD_SIZE_Z) * 2.0F) - 1.0F;
    const float normalizedAge = signedUnit(
        static_cast<float>(agent.ageTicks)
            / static_cast<float>(agent.profile().maximumAgeTicks));
    const float normalizedLight = signedUnit(localSensor);
    const float normalizedVelocityX = std::clamp(
        agent.velocity.x / agent.profile().maximumSpeed,
        ObservationMinimum,
        ObservationMaximum);
    const float normalizedVelocityY = std::clamp(
        agent.velocity.y / agent.profile().maximumSpeed,
        ObservationMinimum,
        ObservationMaximum);
    const float normalizedVelocityZ = std::clamp(
        agent.velocity.z / agent.profile().maximumSpeed,
        ObservationMinimum,
        ObservationMaximum);
    const float localFood = agent.profile().preyType.has_value()
        ? signedUnit(static_cast<float>(localFoodCount) / FoodReference)
        : signedUnit(chemistry_ == nullptr
            ? 0.0F
            : chemistry_->nutrientSupport(agent.position));
    const float energyReadiness = agent.energy
        / agent.profile().reproductionEnergy;
    const float ageReadiness = static_cast<float>(agent.ageTicks)
        / static_cast<float>(agent.profile().minimumReproductionAgeTicks);
    const float cooldownReadiness = agent.reproductionCooldownTicks == 0U
        ? 1.0F
        : 0.0F;
    const float reproductionReadiness = signedUnit(std::min({
        energyReadiness,
        ageReadiness,
        cooldownReadiness
    }));
    const float reproductionCooldown = signedUnit(
        agent.profile().reproductionIntervalTicks == 0U
            ? 1.0F
            : 1.0F - (static_cast<float>(agent.reproductionCooldownTicks)
                / static_cast<float>(agent.profile().reproductionIntervalTicks)));

    result.observation[inputIndex(BrainInput::PreyX)] = preyDirectionX;
    result.observation[inputIndex(BrainInput::PreyY)] = preyDirectionY;
    result.observation[inputIndex(BrainInput::PreyZ)] = preyDirectionZ;
    result.observation[inputIndex(BrainInput::PreyDistance)] =
        signedUnit(normalizedPreyDistance);
    result.observation[inputIndex(BrainInput::Energy)] = normalizedEnergy;
    result.observation[inputIndex(BrainInput::VelocityX)] = normalizedVelocityX;
    result.observation[inputIndex(BrainInput::VelocityY)] = normalizedVelocityY;
    result.observation[inputIndex(BrainInput::VelocityZ)] = normalizedVelocityZ;
    result.observation[inputIndex(BrainInput::Depth)] = normalizedDepth;
    result.observation[inputIndex(BrainInput::Age)] = normalizedAge;
    result.observation[inputIndex(BrainInput::Noise)] = noise.primary;
    result.observation[inputIndex(BrainInput::NoiseSecondary)] = noise.secondary;
    result.observation[inputIndex(BrainInput::Light)] = normalizedLight;
    result.observation[inputIndex(BrainInput::PreyVisible)] = preyVisible;
    result.observation[inputIndex(BrainInput::BoundaryInwardX)] =
        boundaryInwardX;
    result.observation[inputIndex(BrainInput::BoundaryInwardY)] =
        boundaryInwardY;
    result.observation[inputIndex(BrainInput::BoundaryInwardZ)] =
        boundaryInwardZ;
    result.observation[inputIndex(BrainInput::BoundaryProximity)] =
        boundaryProximity;
    result.observation[inputIndex(BrainInput::ThreatX)] = threatDirectionX;
    result.observation[inputIndex(BrainInput::ThreatY)] = threatDirectionY;
    result.observation[inputIndex(BrainInput::ThreatZ)] = threatDirectionZ;
    result.observation[inputIndex(BrainInput::ThreatDistance)] =
        signedUnit(normalizedThreatDistance);
    result.observation[inputIndex(BrainInput::Crowding)] = signedUnit(
        static_cast<float>(sameSpeciesCount) / CrowdingReference);
    result.observation[inputIndex(BrainInput::FoodLocal)] = localFood;
    result.observation[inputIndex(BrainInput::ReproductionReadiness)] =
        reproductionReadiness;
    result.observation[inputIndex(BrainInput::ReproductionCooldown)] =
        reproductionCooldown;
    result.observation[inputIndex(BrainInput::ThreatDensity)] = signedUnit(
        static_cast<float>(threatCount) / ThreatReference);
    result.observation[inputIndex(BrainInput::Bias)] = 1.0F;

    for (float& input : result.observation) {
        input = clampObservation(input);
    }

    result.nearestPrey = nearestPrey;
    return result;
}

bool Ecology::tryFeed(
    Organism& predator,
    Organism* cachedPrey,
    std::span<Organism> population,
    bool feedRequested,
    FeedingResult* result) const noexcept {

    if (result != nullptr) {
        *result = {};
    }

    if (!predator.alive() || predator.liveQuarantined
        || !feedRequested
        || !predator.profile().preyType.has_value()
        || predator.feedingCooldownTicks > 0U) {
        return false;
    }

    const float captureRadiusSquared = CaptureRadius * CaptureRadius;
    Organism* prey = nullptr;

    if (isValidPrey(predator, cachedPrey)
        && distanceSquared(predator, *cachedPrey) <= captureRadiusSquared
        && (geometry_ == nullptr || !geometry_->blockedBetweenBodies(predator.position,cachedPrey->position,false))) {
        prey = cachedPrey;
    } else {
        spatialGrid_.forEachNearby(
            predator.position,
            CaptureRadius,
            [&](std::size_t candidateIndex) {
                Organism& candidate = population[candidateIndex];
                if (isValidPrey(predator, &candidate)
                    && distanceSquared(predator, candidate) <= captureRadiusSquared
                    && (geometry_ == nullptr || !geometry_->blockedBetweenBodies(predator.position,candidate.position,false))
                    && (prey == nullptr || candidate.id < prey->id)) {
                    prey = &candidate;
                }
            });
    }

    if (prey == nullptr) {
        return false;
    }

    const float preyEnergyCaptured = prey->energy;
    const float gainedEnergy =
        preyEnergyCaptured * predator.profile().assimilationEfficiency;
    const float predatorEnergyBefore = predator.energy;
    prey->kill(DeathCause::Predation);
    predator.foodIntake += gainedEnergy;
    predator.gainEnergy(gainedEnergy);
    predator.feedingCooldownTicks = predator.profile().feedingIntervalTicks;

    if (result != nullptr) {
        result->preyEnergyCaptured = preyEnergyCaptured;
        result->predatorEnergyGained = predator.energy - predatorEnergyBefore;
    }

    return true;
}

PopulationChanges Ecology::processPopulation(
    std::vector<Organism>& population,
    std::uint32_t tick,
    std::uint32_t& nextId,
    Random& random) const {

    PopulationChanges changes{};
    additions_.clear();
    if (additions_.capacity() < (population.size() / 2U)) {
        additions_.reserve(population.size() / 2U);
    }

    for (Organism& organism : population) {
        if (!organism.alive() || organism.liveQuarantined
            || organism.energy < organism.profile().reproductionEnergy
            || organism.ageTicks < organism.profile().minimumReproductionAgeTicks
            || organism.reproductionCooldownTicks > 0U) {
            continue;
        }

        // Readiness is permission, never a command in intent-v2.
        if (reproductionIntentV2_ &&
            !(organism.brain.outputState()[actionIndex(BrainAction::ReproduceIntentV2)] > 0.5F)) {
            continue;
        }

        float birthChance = 1.0F;
        if (organism.species == OrganismType::Bacterivore) {
            const float preySupport = std::clamp(
                static_cast<float>(cyanobacteriaCount_)
                    / static_cast<float>(std::max<std::size_t>(
                        bacterivoreCount_,
                        1U))
                    / 20.0F,
                0.0F,
                1.0F);
            birthChance *= preySupport;
        } else if (organism.species == OrganismType::BodoSaltans) {
            const float preySupport = std::clamp(
                static_cast<float>(bacterivoreCount_)
                    / static_cast<float>(std::max<std::size_t>(bodoCount_, 1U))
                    / BodoReproductionPreyRatio,
                0.0F,
                1.0F);
            birthChance *= preySupport;
        }

        if (chemistry_ != nullptr) {
            birthChance *= std::clamp(
                chemistry_->nutrientSupport(organism.position),
                0.0F,
                1.0F);
        }

        if (birthChance < 0.99999F
            && random.uniform_float(0.0F, 1.0F) > birthChance) {
            continue;
        }

        organism.energy = organism.profile().postReproductionEnergy;
        organism.starvationTicks = 0U;
        organism.reproductionCooldownTicks =
            organism.profile().reproductionIntervalTicks;
        Organism child = makeChild(organism, nextId++, tick, random);
        std::uint32_t mutatedGeneCount = 0U;
        float totalMutationDistance = 0.0F;
        for (std::size_t index = 0U; index < child.genome.size(); ++index) {
            const float mutationDistance = std::abs(
                child.genome[index] - organism.genome[index]);
            if (mutationDistance > 0.0F) {
                ++mutatedGeneCount;
                totalMutationDistance += mutationDistance;
            }
        }
        changes.events.push_back({
            .type = PopulationEventType::Birth,
            .id = child.id,
            .parentId = child.parentId,
            .rootAncestorId = child.rootAncestorId,
            .species = child.species,
            .generation = child.generation,
            .tick = tick,
            .ageTicks = child.ageTicks,
            .parentAgeTicks = organism.ageTicks,
            .mutatedGeneCount = mutatedGeneCount,
            .energy = child.energy,
            .speed = child.speed,
            .parentSpeed = organism.speed,
            .totalMutationDistance = totalMutationDistance
        });
        additions_.push_back(std::move(child));
    }

    for (const Organism& organism : population) {
        if (!organism.alive()) {
            changes.events.push_back({
                .type = PopulationEventType::Death,
                .id = organism.id,
                .parentId = organism.parentId,
                .rootAncestorId = organism.rootAncestorId,
                .species = organism.species,
                .generation = organism.generation,
                .tick = tick,
                .ageTicks = organism.ageTicks,
                .energy = organism.energy,
                .speed = organism.speed,
                .deathCause = organism.deathCause
            });
            if (chemistry_ != nullptr) {
                chemistry_->recycleBiomass(organism.position);
            }
            ++changes.deaths;
        }
    }

    population.erase(
        std::remove_if(
            population.begin(),
            population.end(),
            [](const Organism& organism) {
                return !organism.alive();
            }),
        population.end());
    const std::size_t requiredPopulationCapacity =
        population.size() + additions_.size();
    if (population.capacity() < requiredPopulationCapacity) {
        population.reserve(requiredPopulationCapacity);
    }
    population.insert(
        population.end(),
        std::make_move_iterator(additions_.begin()),
        std::make_move_iterator(additions_.end()));
    changes.births = additions_.size();
    return changes;
}

} // namespace cybernet
