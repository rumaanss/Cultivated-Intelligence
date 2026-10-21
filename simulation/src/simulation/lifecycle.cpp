#include "cybernet/simulation/lifecycle.hpp"

#include "cybernet/simulation/simulation.hpp"
#include "cybernet/world/celestial.hpp"
#include "cybernet/world/chemistry.hpp"
#include "cybernet/world/ecology.hpp"
#include "cybernet/world/physics.hpp"
#include "cybernet/world/photosynthesis.hpp"

#include <algorithm>
#include <array>
#include <cassert>

namespace cybernet {
namespace {

[[nodiscard]] bool isAtBoundary(const Organism& organism) noexcept {
    return organism.position.x == 0.0F
        || organism.position.x == config::WORLD_SIZE_X
        || organism.position.y == 0.0F
        || organism.position.y == config::WORLD_SIZE_Y
        || organism.position.z == 0.0F
        || organism.position.z == config::WORLD_SIZE_Z;
}

[[nodiscard]] LifecycleAction think(
    Organism& organism,
    const LifecycleContext& context,
    const ObservationNoise& noise) noexcept {

    assert(context.ecology != nullptr);
    assert(context.celestial != nullptr);
    assert(context.random != nullptr);

    ObservationResult observation =
        context.ecology->buildObservation(
            organism,
            context.population,
            *context.celestial,
            noise);

    organism.liveTarget=0;
    const float visionRange=context.externalActors.empty()?30.0F:std::max(.0001F,context.celestial->optics().visibilityRange(organism.position,Ecology::VisionRadiusDay));
    float preyDistance=observation.nearestPrey?(observation.nearestPrey->position-organism.position).length():visionRange;
    float threatDistance=(observation.observation[inputIndex(BrainInput::ThreatDistance)]+1)*.5F*visionRange;
    for(const auto& actor:context.externalActors) {
        const Vec3 offset=actor.position-organism.position;
        const float distance=offset.length();
        // Query toward the near surface; the actor must not occlude its own target point.
        const Vec3 nearPoint=actor.position-offset.normalized()*(actor.radius+0.001F);
        if(distance>visionRange || !context.celestial->optics().sampleVisibility(organism.position,nearPoint,30).detectable)continue;
        const Vec3 direction=offset.normalized();
        if(distance<threatDistance){
            threatDistance=distance;
            observation.observation[inputIndex(BrainInput::ThreatX)]=direction.x;
            observation.observation[inputIndex(BrainInput::ThreatY)]=direction.y;
            observation.observation[inputIndex(BrainInput::ThreatZ)]=direction.z;
            observation.observation[inputIndex(BrainInput::ThreatDistance)]=2*std::min(distance/visionRange,1.0F)-1;
        }
        if(actor.kind==1 && organism.species!=OrganismType::Cyanobacteria && distance<preyDistance){
            preyDistance=distance;organism.liveTarget=actor.id;
            observation.observation[inputIndex(BrainInput::PreyX)]=direction.x;
            observation.observation[inputIndex(BrainInput::PreyY)]=direction.y;
            observation.observation[inputIndex(BrainInput::PreyZ)]=direction.z;
            observation.observation[inputIndex(BrainInput::PreyDistance)]=2*std::min(distance/visionRange,1.0F)-1;
            observation.observation[inputIndex(BrainInput::PreyVisible)]=1;
            observation.nearestPrey=nullptr;
        }
    }
    if (context.celestial->usesOpticsV2()) {
        organism.opticalDiagnostics = {context.celestial->optics().tick(),
            context.celestial->optics().sampleLight(organism.position).sensor,0,0};
    }
    const RnnBrain::Outputs outputs =
        organism.brain.step(observation.observation);

    organism.liveIntent=outputs;
    LifecycleAction actions{};
    actions.outputs = outputs;
    actions.inputs = observation.observation;
    actions.feedAttempt = outputs[actionIndex(BrainAction::Feed)];
    actions.nearestPrey = observation.nearestPrey;

    return actions;
}

} // namespace

LifecycleAction Lifecycle::decide(
    Organism& organism,
    const LifecycleContext& context) noexcept {

    if (!organism.alive() || organism.liveQuarantined) {
        return {};
    }

    assert(context.random != nullptr);
    return decide(
        organism,
        context,
        {
            .primary = context.random->uniform_float(-1.0F, 1.0F),
            .secondary = context.random->uniform_float(-1.0F, 1.0F)
        });
}

LifecycleAction Lifecycle::decide(
    Organism& organism,
    const LifecycleContext& context,
    const ObservationNoise& noise) noexcept {

    if (!organism.alive() || organism.liveQuarantined) {
        return {};
    }

    return think(organism, context, noise);
}

void Lifecycle::applyMovement(
    Organism& organism,
    LifecycleAction& action,
    float drag, const GeometryWorld* geometry) noexcept {

    if (!organism.alive() || organism.liveQuarantined) {
        return;
    }

    action.wasAtBoundary = isAtBoundary(organism);
    const float energyBeforeMovement = organism.energy;
    applyPhysics(organism, action.outputs, drag, geometry);
    action.movementEnergySpent = std::max(
        energyBeforeMovement - organism.energy,
        0.0F);
    action.isAtBoundary = isAtBoundary(organism);
}

void Lifecycle::completeTick(
    Organism& organism,
    LifecycleAction& action,
    const LifecycleContext& context) noexcept {

    if (!organism.alive() || organism.liveQuarantined) {
        return;
    }

    assert(context.celestial != nullptr);
    assert(context.ecology != nullptr);
    assert(context.chemistry != nullptr);

    const float nutrientSupport = context.chemistry->nutrientSupport(
        organism.position);

    const bool opticsV2 = context.celestial->usesOpticsV2();
    const float localLight = opticsV2 ? context.celestial->optics().sampleLight(organism.position).photosynthetic : 0;
    const float photosyntheticIntake = opticsV2 ? photosynthesizeLocal(organism,localLight,nutrientSupport) : photosynthesize(
        organism,
        context.celestial->state().daylight,
        context.worldDepth,
        nutrientSupport);
    action.photosyntheticEnergyGained = photosyntheticIntake;
    if (opticsV2) {
        organism.opticalDiagnostics.photosyntheticLight = localLight;
        organism.opticalDiagnostics.photosyntheticEnergy = photosyntheticIntake;
    }

    if (organism.species == OrganismType::Cyanobacteria) {
        organism.foodIntake += photosyntheticIntake;
    }

    if (organism.species == OrganismType::Cyanobacteria) {
        context.chemistry->processPrimaryProducer(
            organism.position,
            photosyntheticIntake);
    }

    if (organism.alive()) {
        FeedingResult feeding{};
        action.feedSucceeded = context.ecology->tryFeed(
            organism,
            action.nearestPrey,
            context.population,
            action.feedAttempt >= Ecology::FeedAttemptThreshold,
            &feeding);
        action.preyEnergyCaptured = feeding.preyEnergyCaptured;
        action.predatorEnergyGained = feeding.predatorEnergyGained;
    }

    if (organism.alive()) {
        organism.tickAge();
    }
}

void Lifecycle::tick(
    Organism& organism,
    const LifecycleContext& context,
    float drag) noexcept {

    LifecycleAction action = decide(organism, context);
    applyMovement(organism, action, drag, context.celestial->geometry());
    completeTick(organism, action, context);
}

} // namespace cybernet

