#include "cybernet/world/physics.hpp"

#include "cybernet/simulation/organism.hpp"
#include "cybernet/simulation/simulation.hpp"

#include <algorithm>
#include <cmath>
#include <exception>
#include "cybernet/world/geometry.hpp"

namespace cybernet {
namespace {

constexpr float AccelerationScale = 0.20F;
constexpr float MovementThresholdSquared = 0.0225F;

void resolveBoundary(
    float& position,
    float& velocity,
    float maximumPosition) noexcept {

    if (position < 0.0F) {
        position = 0.0F;
        if (velocity < 0.0F) {
            velocity = -velocity * config::BOUNDARY_RESTITUTION;
        }
    } else if (position > maximumPosition) {
        position = maximumPosition;
        if (velocity > 0.0F) {
            velocity = -velocity * config::BOUNDARY_RESTITUTION;
        }
    }
}

} // namespace

void applyPhysics(
    Organism& agent,
    const std::array<float, 5>& action,
    float drag, const GeometryWorld* geometry) noexcept {

    if (!agent.alive()) {
        return;
    }

    const float forward =
        (action[actionIndex(BrainAction::Forward)] * 2.0F) - 1.0F;
    const float strafe =
        (action[actionIndex(BrainAction::Strafe)] * 2.0F) - 1.0F;
    const float vertical =
        (action[actionIndex(BrainAction::Vertical)] * 2.0F) - 1.0F;

    // X/Y are horizontal; Z is depth/vertical.
    const Vec3 direction{strafe, forward, vertical};

    const Vec3 acceleration =
        direction * (agent.speed * AccelerationScale);

    agent.velocity = (agent.velocity + acceleration)
        * std::clamp(drag, 0.0F, 1.0F);

    const float velocitySquaredBeforeCap =
        agent.velocity.lengthSquared();

    const float maximumSpeedSquared = agent.speed * agent.speed;

    if (velocitySquaredBeforeCap > maximumSpeedSquared) {
        const float inverseMagnitude =
            1.0F / std::sqrt(velocitySquaredBeforeCap);

        agent.velocity =
            agent.velocity * (inverseMagnitude * agent.speed);
    }

    const Vec3 previousPosition = agent.position;
    agent.position += agent.velocity;
    if (geometry != nullptr) {
        if (!geometry->move(previousPosition,agent.position,agent.velocity)) {
            if (!geometry->clear(previousPosition)) std::terminate();
            agent.position = previousPosition; agent.velocity = {};
        }
    }

    resolveBoundary(
        agent.position.x,
        agent.velocity.x,
        config::WORLD_SIZE_X);
    resolveBoundary(
        agent.position.y,
        agent.velocity.y,
        config::WORLD_SIZE_Y);
    resolveBoundary(
        agent.position.z,
        agent.velocity.z,
        config::WORLD_SIZE_Z);

    const bool moving =
        direction.lengthSquared() > MovementThresholdSquared;

    const float movementCost = moving
        ? agent.profile().movementCost
            + (std::sqrt(velocitySquaredBeforeCap) * 0.01F)
        : agent.profile().movementCost * 0.75F;

    agent.spendEnergy(movementCost);
}

} // namespace cybernet

