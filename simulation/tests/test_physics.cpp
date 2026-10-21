#include "cybernet/brain/rnn_brain.hpp"
#include "cybernet/simulation/organism.hpp"
#include "cybernet/simulation/simulation.hpp"
#include "cybernet/world/physics.hpp"

#ifdef NDEBUG
#undef NDEBUG
#endif

#include <array>
#include <cassert>
#include <cmath>
#include <iostream>

namespace {

bool approximatelyEqual(float left, float right, float tolerance = 0.00001F) {
    return std::fabs(left - right) <= tolerance;
}

cybernet::Organism makeOrganism(cybernet::OrganismType species) {
    cybernet::Organism organism{};
    organism.configureSpecies(species);
    organism.position = {50.0F, 50.0F, 30.0F};
    return organism;
}

std::array<float, cybernet::RnnBrain::OutputCount> neutralAction() {
    std::array<float, cybernet::RnnBrain::OutputCount> action{};
    action.fill(0.5F);
    return action;
}

} // namespace

int main() {
    using cybernet::BrainAction;
    using cybernet::actionIndex;

	 {
		 cybernet::Organism organism = makeOrganism(
			 cybernet::OrganismType::Bacterivore);
		 organism.velocity = {1.0F, 0.0F, 0.0F};

		 cybernet::applyPhysics(organism, neutralAction(), 0.5F);

		 assert(approximatelyEqual(organism.velocity.x, 0.5F));
		 assert(approximatelyEqual(organism.position.x, 50.5F));
	 }

	{
		cybernet::Organism organism = makeOrganism(
			cybernet::OrganismType::Bacterivore);
		organism.position.x = 99.5F;
		organism.velocity.x = organism.speed;

		cybernet::applyPhysics(organism, neutralAction(), 1.0F);

		assert(approximatelyEqual(
			organism.position.x,
			cybernet::config::WORLD_SIZE_X));
		assert(approximatelyEqual(
			organism.velocity.x,
			-organism.speed * cybernet::config::BOUNDARY_RESTITUTION));
	}

	{
		cybernet::Organism organism = makeOrganism(
			cybernet::OrganismType::Bacterivore);
		organism.position.y = 0.5F;
		organism.velocity.y = -organism.speed;

		cybernet::applyPhysics(organism, neutralAction(), 1.0F);

		assert(approximatelyEqual(organism.position.y, 0.0F));
		assert(approximatelyEqual(
			organism.velocity.y,
			organism.speed * cybernet::config::BOUNDARY_RESTITUTION));
	}

	{
		cybernet::Organism organism = makeOrganism(
			cybernet::OrganismType::Bacterivore);
		organism.speed = organism.profile().maximumSpeed;
		organism.position = {99.5F, 99.5F, 59.5F};
		organism.velocity = {1.0F, 1.0F, 1.0F};

		cybernet::applyPhysics(organism, neutralAction(), 1.0F);

		assert(approximatelyEqual(
			organism.position.x,
			cybernet::config::WORLD_SIZE_X));
		assert(approximatelyEqual(
			organism.position.y,
			cybernet::config::WORLD_SIZE_Y));
		assert(approximatelyEqual(
			organism.position.z,
			cybernet::config::WORLD_SIZE_Z));
		assert(organism.velocity.x < 0.0F);
		assert(organism.velocity.y < 0.0F);
		assert(organism.velocity.z < 0.0F);
	}

	 {
		 cybernet::Organism organism = makeOrganism(
			 cybernet::OrganismType::Bacterivore);
		 organism.position = {
			 cybernet::config::WORLD_SIZE_X,
			 cybernet::config::WORLD_SIZE_Y,
			 cybernet::config::WORLD_SIZE_Z
		 };
		 organism.velocity = {100.0F, 100.0F, 100.0F};
		 std::array<float, cybernet::RnnBrain::OutputCount> action =
			 neutralAction();
		 action[actionIndex(BrainAction::Forward)] = 1.0F;
		 action[actionIndex(BrainAction::Strafe)] = 1.0F;
		 action[actionIndex(BrainAction::Vertical)] = 1.0F;

		 cybernet::applyPhysics(organism, action, cybernet::config::DRAG);

		 assert(organism.velocity.length() <= organism.speed + 0.00001F);
		 assert(approximatelyEqual(
			 organism.position.x,
			 cybernet::config::WORLD_SIZE_X));
		 assert(approximatelyEqual(
			 organism.position.y,
			 cybernet::config::WORLD_SIZE_Y));
		 assert(approximatelyEqual(
			 organism.position.z,
			 cybernet::config::WORLD_SIZE_Z));
	 }

	 {
		 cybernet::Organism organism = makeOrganism(
			 cybernet::OrganismType::Cyanobacteria);
		 const float energyBefore = organism.energy;

		 cybernet::applyPhysics(
			 organism,
			 neutralAction(),
			 cybernet::config::DRAG);

		 assert(approximatelyEqual(
			 organism.energy,
			 energyBefore - (organism.profile().movementCost * 0.75F)));
	 }

	 {
		 cybernet::Organism organism = makeOrganism(
			 cybernet::OrganismType::Bacterivore);
		 organism.kill(cybernet::DeathCause::Predation);
		 const cybernet::Vec3 positionBefore = organism.position;
		 const cybernet::Vec3 velocityBefore = organism.velocity;

		 cybernet::applyPhysics(
			 organism,
			 neutralAction(),
			 cybernet::config::DRAG);

		 assert(approximatelyEqual(organism.position.x, positionBefore.x));
		 assert(approximatelyEqual(organism.position.y, positionBefore.y));
		 assert(approximatelyEqual(organism.position.z, positionBefore.z));
		 assert(approximatelyEqual(organism.velocity.x, velocityBefore.x));
		 assert(approximatelyEqual(organism.velocity.y, velocityBefore.y));
		 assert(approximatelyEqual(organism.velocity.z, velocityBefore.z));
	 }

	 std::cout << "Physics tests passed.\n";
	 return 0;
 }
