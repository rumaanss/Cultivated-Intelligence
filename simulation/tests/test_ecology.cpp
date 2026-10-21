#include "cybernet/random.hpp"
#include "cybernet/simulation/organism.hpp"
#include "cybernet/world/celestial.hpp"
#include "cybernet/world/chemistry.hpp"
#include "cybernet/world/ecology.hpp"

#ifdef NDEBUG
#undef NDEBUG
#endif

#include <algorithm>
#include <cassert>
#include <cmath>
#include <iostream>
#include <span>
#include <vector>

namespace {

bool approximatelyEqual(float left, float right, float tolerance = 0.00001F) {
	return std::fabs(left - right) <= tolerance;
}

cybernet::Organism makeOrganism(
	cybernet::OrganismType species,
	std::uint32_t id,
	cybernet::Vec3 position) {

	cybernet::Organism organism{};
	organism.id = id;
	organism.rootAncestorId = id;
	organism.configureSpecies(species);
	organism.position = position;
	return organism;
}

} // namespace

int main() {
	using cybernet::OrganismType;

	{
		cybernet::Ecology ecology{};
		cybernet::Random random{42U};
		cybernet::CelestialCycle celestial{};
		std::vector<cybernet::Organism> population{};
		population.push_back(makeOrganism(
			OrganismType::Bacterivore,
			1U,
			{50.0F, 50.0F, 30.0F}));
		population.push_back(makeOrganism(
			OrganismType::Cyanobacteria,
			2U,
			{60.0F, 50.0F, 30.0F}));
		population.push_back(makeOrganism(
			OrganismType::Bacterivore,
			3U,
			{52.0F, 50.0F, 30.0F}));
		population.push_back(makeOrganism(
			OrganismType::BodoSaltans,
			4U,
			{51.0F, 50.0F, 30.0F}));
		population[0].energy = population[0].profile().reproductionEnergy;
		population[0].ageTicks = population[0].profile().minimumReproductionAgeTicks;
		population[2].energy = population[2].profile().reproductionEnergy;
		population[2].ageTicks = population[2].profile().minimumReproductionAgeTicks;
		ecology.beginTick(std::span<const cybernet::Organism>(population));

		celestial.update(150);
		const cybernet::ObservationResult daytime = ecology.buildObservation(
			population[0],
			std::span<cybernet::Organism>(population),
			celestial,
			cybernet::ObservationNoise{
				random.uniform_float(-1.0F, 1.0F),
				random.uniform_float(-1.0F, 1.0F)});

		assert(daytime.nearestPrey == &population[1]);
		assert(approximatelyEqual(daytime.observation[13], 1.0F));
		assert(approximatelyEqual(
			daytime.observation[
				cybernet::inputIndex(cybernet::BrainInput::BoundaryInwardX)],
			0.0F));
		assert(approximatelyEqual(
			daytime.observation[
				cybernet::inputIndex(cybernet::BrainInput::BoundaryProximity)],
			0.0F));
		assert(approximatelyEqual(
			daytime.observation[cybernet::inputIndex(cybernet::BrainInput::ThreatX)],
			1.0F));
		assert(daytime.observation[
			cybernet::inputIndex(cybernet::BrainInput::ThreatDistance)] < 1.0F);
		assert(daytime.observation[
			cybernet::inputIndex(cybernet::BrainInput::ThreatDensity)] > -1.0F);
		assert(daytime.observation[
			cybernet::inputIndex(cybernet::BrainInput::Crowding)] > -1.0F);
		assert(daytime.observation[
			cybernet::inputIndex(cybernet::BrainInput::FoodLocal)] > -1.0F);
		assert(approximatelyEqual(
			daytime.observation[
				cybernet::inputIndex(cybernet::BrainInput::ReproductionReadiness)],
			1.0F));
		assert(approximatelyEqual(
			daytime.observation[
				cybernet::inputIndex(cybernet::BrainInput::ReproductionCooldown)],
			1.0F));
		assert(approximatelyEqual(
			daytime.observation[cybernet::inputIndex(cybernet::BrainInput::Bias)],
			1.0F));

		celestial.update(450);
		const cybernet::ObservationResult nighttime = ecology.buildObservation(
			population[0],
			std::span<cybernet::Organism>(population),
			celestial,
			cybernet::ObservationNoise{
				random.uniform_float(-1.0F, 1.0F),
				random.uniform_float(-1.0F, 1.0F)});

		assert(nighttime.nearestPrey == nullptr);
		assert(approximatelyEqual(nighttime.observation[13], -1.0F));
	}

	{
		cybernet::Ecology ecology{};
		std::vector<cybernet::Organism> population{};
		population.push_back(makeOrganism(
			OrganismType::Bacterivore,
			1U,
			{50.0F, 50.0F, 30.0F}));
		population.push_back(makeOrganism(
			OrganismType::Cyanobacteria,
			2U,
			{50.0F, 50.0F, 30.0F}));
		ecology.beginTick(std::span<const cybernet::Organism>(population));

		const float energyBefore = population[0].energy;
		const float preyEnergy = population[1].energy;

		assert(!ecology.tryFeed(
			population[0],
			&population[1],
			std::span<cybernet::Organism>(population),
			false));

		assert(population[1].alive());
		assert(approximatelyEqual(population[0].energy, energyBefore));

		assert(ecology.tryFeed(
			population[0],
			nullptr,
			std::span<cybernet::Organism>(population),
			true));

		assert(!population[1].alive());
		assert(approximatelyEqual(
			population[0].energy,
			energyBefore + (preyEnergy * population[0].profile().assimilationEfficiency)));
		assert(population[0].feedingCooldownTicks
			== population[0].profile().feedingIntervalTicks);
	}

	{
		cybernet::Ecology ecology{};
		cybernet::Random random{24U};
		cybernet::CelestialCycle celestial{};
		celestial.update(150);
		std::vector<cybernet::Organism> population{};
		population.push_back(makeOrganism(
			OrganismType::Bacterivore,
			1U,
			{50.0F, 50.0F, 30.0F}));
		population.push_back(makeOrganism(
			OrganismType::Cyanobacteria,
			5U,
			{40.0F, 50.0F, 30.0F}));
		population.push_back(makeOrganism(
			OrganismType::Cyanobacteria,
			2U,
			{60.0F, 50.0F, 30.0F}));
		ecology.beginTick(std::span<const cybernet::Organism>(population));

		const cybernet::ObservationResult observation = ecology.buildObservation(
			population[0],
			std::span<cybernet::Organism>(population),
			celestial,
			cybernet::ObservationNoise{
				random.uniform_float(-1.0F, 1.0F),
				random.uniform_float(-1.0F, 1.0F)});

		assert(observation.nearestPrey != nullptr);
		assert(observation.nearestPrey->id == 2U);
	}

	{
		cybernet::Ecology ecology{};
		cybernet::Random random{7U};
		std::vector<cybernet::Organism> population{};
		population.push_back(makeOrganism(
			OrganismType::Cyanobacteria,
			1U,
			{50.0F, 50.0F, 30.0F}));
		population[0].energy = population[0].profile().reproductionEnergy;
		population[0].ageTicks = population[0].profile().minimumReproductionAgeTicks;
		std::uint32_t nextId = 2U;
        population[0].liveQuarantined=true;
        ecology.beginTick(population);
        (void)ecology.processPopulation(population,100U,nextId,random);
        assert(population.size()==1U&&nextId==2U);
        population[0].liveQuarantined=false;

		ecology.beginTick(std::span<const cybernet::Organism>(population));
		(void)ecology.processPopulation(population, 100U, nextId, random);

		assert(population.size() == 2U);
		const auto child = std::find_if(
			population.begin(),
			population.end(),
			[](const cybernet::Organism& organism) {
				return organism.id == 2U;
			});
		assert(child != population.end());
		assert(child->generation == 1U);
		assert(child->parentId == 1U);
		assert(child->rootAncestorId == 1U);
		assert(approximatelyEqual(
			child->energy,
			child->profile().startingEnergy));
	}

	{
		cybernet::Ecology ecology{};
		cybernet::Random random{44U};
		cybernet::CelestialCycle celestial{};
		celestial.update(150);
		std::vector<cybernet::Organism> population{};
		population.push_back(makeOrganism(
			OrganismType::Bacterivore,
			1U,
			{0.0F, 50.0F, 30.0F}));
		population.push_back(makeOrganism(
			OrganismType::BodoSaltans,
			2U,
			{1.0F, 50.0F, 30.0F}));
		ecology.beginTick(std::span<const cybernet::Organism>(population));

		const cybernet::ObservationResult observation = ecology.buildObservation(
			population[0],
			std::span<cybernet::Organism>(population),
			celestial,
			cybernet::ObservationNoise{
				random.uniform_float(-1.0F, 1.0F),
				random.uniform_float(-1.0F, 1.0F)});

		assert(approximatelyEqual(
			observation.observation[
				cybernet::inputIndex(cybernet::BrainInput::BoundaryInwardX)],
			1.0F));
		assert(approximatelyEqual(
			observation.observation[
				cybernet::inputIndex(cybernet::BrainInput::BoundaryProximity)],
			1.0F));
		assert(approximatelyEqual(
			observation.observation[cybernet::inputIndex(cybernet::BrainInput::ThreatX)],
			1.0F));
	}

	{
		cybernet::Ecology ecology{};
		cybernet::Random random{11U};
		std::vector<cybernet::Organism> population{};
		population.push_back(makeOrganism(
			OrganismType::Cyanobacteria,
			1U,
			{40.0F, 50.0F, 30.0F}));
		population.push_back(makeOrganism(
			OrganismType::Cyanobacteria,
			2U,
			{60.0F, 50.0F, 30.0F}));
		population[1].ageTicks = 1000U;
		std::uint32_t nextId = 3U;

		ecology.beginTick(std::span<const cybernet::Organism>(population));
		(void)ecology.processPopulation(population, 100U, nextId, random);

		assert(population.size() == 2U);
		assert(population[0].id == 1U);
		assert(population[1].id == 2U);
	}

	{
		cybernet::ChemistryField chemistry{};
		cybernet::Ecology ecology{};
		ecology.setChemistry(&chemistry);
		cybernet::Random random{9U};
		std::vector<cybernet::Organism> population{};
		population.push_back(makeOrganism(
			OrganismType::Cyanobacteria,
			1U,
			{50.0F, 50.0F, 30.0F}));
		population[0].kill(cybernet::DeathCause::Predation);
		std::uint32_t nextId = 2U;
		const float carbonBefore = chemistry.summary().averageDissolvedCarbon;

		(void)ecology.processPopulation(population, 100U, nextId, random);

		assert(population.empty());
		assert(chemistry.summary().averageDissolvedCarbon > carbonBefore);
	}

    {
        cybernet::CelestialCycle sun; sun.setOpticalModel(cybernet::OpticalModel::OpticsV2); sun.update(150);
        cybernet::Ecology ecology;
        std::vector<cybernet::Organism> p{
            makeOrganism(OrganismType::Bacterivore,1,{50,50,60}),
            makeOrganism(OrganismType::Cyanobacteria,2,{51,50,60})};
        ecology.beginTick(p);
        auto observation=ecology.buildObservation(p[0],p,sun,{});
        assert(observation.nearestPrey==&p[1]);
        p[1].liveQuarantined=true;ecology.beginTick(p);
        assert(ecology.buildObservation(p[0],p,sun,{}).nearestPrey==nullptr);
        assert(!ecology.tryFeed(p[0],&p[1],p,true));
        p[1].liveQuarantined=false;ecology.beginTick(p);
        ecology.refreshSpatialIndex(p,&sun);
        const auto cached=ecology.buildObservation(p[0],p,sun,{});
        assert(cached.observation==observation.observation && cached.nearestPrey==observation.nearestPrey);
        assert(approximatelyEqual(observation.observation[cybernet::inputIndex(cybernet::BrainInput::Light)],sun.optics().sampleLight(p[0].position).sensor*2-1));
        p[0].position.z=p[1].position.z=0;sun.update(450);ecology.beginTick(p);
        observation=ecology.buildObservation(p[0],p,sun,{});
        assert(observation.nearestPrey==nullptr);
        assert(observation.observation[cybernet::inputIndex(cybernet::BrainInput::Light)]< -0.9F);
    }

	std::cout << "Ecology tests passed.\n";
	return 0;
}

