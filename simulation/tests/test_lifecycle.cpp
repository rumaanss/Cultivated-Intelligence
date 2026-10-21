#include "cybernet/brain/rnn_brain.hpp"
#include "cybernet/random.hpp"
#include "cybernet/simulation/lifecycle.hpp"
#include "cybernet/simulation/organism.hpp"
#include "cybernet/simulation/simulation.hpp"
#include "cybernet/world/celestial.hpp"
#include "cybernet/world/chemistry.hpp"
#include "cybernet/world/ecology.hpp"

#ifdef NDEBUG
#undef NDEBUG
#endif

#include <cassert>
#include <iostream>
#include <span>
#include <vector>

namespace {

constexpr std::size_t FeedOutputBiasIndex =
    cybernet::RnnBrain::InputWeightsSize
    + cybernet::RnnBrain::RecurrentWeightsSize
    + cybernet::RnnBrain::HiddenBiasesSize
    + cybernet::RnnBrain::OutputWeightsSize
    + static_cast<std::size_t>(cybernet::BrainAction::Feed);

cybernet::Organism makeOrganism(
    cybernet::OrganismType species,
    std::uint32_t id,
    cybernet::Vec3 position) {

    cybernet::Organism organism{};
    organism.id = id;
    organism.configureSpecies(species);
    organism.position = position;
    organism.initializeBrain();
    return organism;
}

cybernet::LifecycleContext makeContext(
    std::vector<cybernet::Organism>& population,
    cybernet::CelestialCycle& celestial,
    cybernet::ChemistryField& chemistry,
    cybernet::Ecology& ecology,
    cybernet::Random& random) {

    cybernet::LifecycleContext context{};
    context.population = std::span<cybernet::Organism>(population);
    context.celestial = &celestial;
    context.chemistry = &chemistry;
    context.ecology = &ecology;
    context.random = &random;
    context.worldWidth = cybernet::config::WORLD_SIZE_X;
    context.worldHeight = cybernet::config::WORLD_SIZE_Y;
    context.worldDepth = cybernet::config::WORLD_SIZE_Z;
    return context;
}

} // namespace

int main() {
    {
        // Quarantine pauses biology without killing/removing the organism.
        auto o=makeOrganism(cybernet::OrganismType::Cyanobacteria,99,{50,50,40});
        o.liveQuarantined=true;const float energy=o.energy;const auto age=o.ageTicks;
        cybernet::LifecycleContext context{};
        auto action=cybernet::Lifecycle::decide(o,context);
        cybernet::Lifecycle::applyMovement(o,action,1);
        cybernet::Lifecycle::completeTick(o,action,context);
        assert(o.alive()&&o.energy==energy&&o.ageTicks==age&&o.position.z==40);
    }

    using cybernet::OrganismType;
    {
        using namespace cybernet;
        CelestialCycle celestial;celestial.setOpticalModel(OpticalModel::OpticsV2);celestial.update(150);
        ChemistryField chemistry;Ecology ecology;Random random{42};ecology.setChemistry(&chemistry);
        std::vector<Organism> population{makeOrganism(OrganismType::Bacterivore,1,{50,50,55})};
        chemistry.beginTick(population);ecology.beginTick(population);
        auto context=makeContext(population,celestial,chemistry,ecology,random);
        std::array<ExternalActor,1> actors{{{7,{54,50,55},1,100,1}}};context.externalActors=actors;
        GeometryObject human{0x80000007U,GeometryShape::Sphere,{54,50,55},{1,1,1},true,true};
        GeometryWorld visible(std::span(&human,1));celestial.setGeometry(&visible);ecology.setGeometry(&visible);
        auto action=Lifecycle::decide(population[0],context,ObservationNoise{});
        assert(population[0].liveTarget==7&&action.inputs[inputIndex(BrainInput::PreyVisible)]==1);
        const float range=celestial.optics().visibilityRange(population[0].position,30);
        assert(std::abs(action.inputs[inputIndex(BrainInput::PreyDistance)]-(8/range-1))<.0001F);
        std::array<GeometryObject,2> objects{{human,{3,GeometryShape::Sphere,{52,50,55},{.5,.5,.5},true,true}}};
        GeometryWorld hidden(objects);celestial.setGeometry(&hidden);ecology.setGeometry(&hidden);
        action=Lifecycle::decide(population[0],context,ObservationNoise{});
        assert(population[0].liveTarget==0&&action.inputs[inputIndex(BrainInput::PreyVisible)]==-1);
    }


    {
        cybernet::CelestialCycle celestial{};
        celestial.update(150);
        cybernet::ChemistryField chemistry{};
        cybernet::Ecology ecology{};
        ecology.setChemistry(&chemistry);
        cybernet::Random random{42U};
        std::vector<cybernet::Organism> population{};
        population.push_back(makeOrganism(
            OrganismType::Cyanobacteria,
            1U,
            {50.0F, 50.0F, cybernet::config::WORLD_SIZE_Z}));
        const float energyBefore = population[0].energy;

        chemistry.beginTick(std::span<const cybernet::Organism>(population));
        ecology.beginTick(std::span<const cybernet::Organism>(population));
        cybernet::LifecycleContext context = makeContext(
            population,
            celestial,
            chemistry,
            ecology,
            random);

        cybernet::Lifecycle::tick(
            population[0],
            context,
            cybernet::config::DRAG);

        assert(population[0].energy > energyBefore);
        assert(population[0].ageTicks == 1U);
        assert(chemistry.summary().totalCarbonConsumed > 0.0F);
    }

    for (const float feedBias : {-60.0F, 60.0F}) {
        cybernet::CelestialCycle celestial{};
        celestial.update(150);
        cybernet::ChemistryField chemistry{};
        cybernet::Ecology ecology{};
        ecology.setChemistry(&chemistry);
        cybernet::Random random{99U};
        std::vector<cybernet::Organism> population{};
        population.push_back(makeOrganism(
            OrganismType::Bacterivore,
            1U,
            {50.0F, 50.0F, 30.0F}));
        population.push_back(makeOrganism(
            OrganismType::Cyanobacteria,
            2U,
            {50.0F, 50.0F, 30.0F}));
        population[0].genome[FeedOutputBiasIndex] = feedBias;
        population[0].initializeBrain();

        chemistry.beginTick(std::span<const cybernet::Organism>(population));
        ecology.beginTick(std::span<const cybernet::Organism>(population));
        cybernet::LifecycleContext context = makeContext(
            population,
            celestial,
            chemistry,
            ecology,
            random);

        cybernet::Lifecycle::tick(
            population[0],
            context,
            cybernet::config::DRAG);

        assert(population[1].alive() == (feedBias < 0.0F));
    }

    {
        cybernet::CelestialCycle celestial{};
        celestial.update(150);
        cybernet::ChemistryField chemistry{};
        cybernet::Ecology ecology{};
        ecology.setChemistry(&chemistry);
        cybernet::Random random{55U};
        std::vector<cybernet::Organism> population{};
        population.push_back(makeOrganism(
            OrganismType::Bacterivore,
            1U,
            {47.2F, 50.0F, 30.0F}));
        population.push_back(makeOrganism(
            OrganismType::Cyanobacteria,
            2U,
            {49.3F, 50.0F, 30.0F}));
        population[0].velocity.x = population[0].speed;

        chemistry.beginTick(std::span<const cybernet::Organism>(population));
        ecology.beginTick(std::span<const cybernet::Organism>(population));
        cybernet::LifecycleContext context = makeContext(
            population,
            celestial,
            chemistry,
            ecology,
            random);
        cybernet::LifecycleAction action{};
        action.outputs.fill(0.5F);
        action.feedAttempt = 1.0F;

        cybernet::Lifecycle::applyMovement(
            population[0],
            action,
            1.0F);
        chemistry.beginTick(std::span<const cybernet::Organism>(population));
        ecology.beginTick(std::span<const cybernet::Organism>(population));
        cybernet::Lifecycle::completeTick(population[0], action, context);

        assert(!population[1].alive());
    }

    std::cout << "Lifecycle tests passed.\n";
    {
        cybernet::CelestialCycle sun; sun.setOpticalModel(cybernet::OpticalModel::OpticsV2);sun.update(150);
        cybernet::ChemistryField chemistry;cybernet::Ecology ecology;ecology.setChemistry(&chemistry);
        cybernet::Random random(1);
        std::vector<cybernet::Organism> p{makeOrganism(cybernet::OrganismType::Cyanobacteria,1,{50,50,60})};
        p[0].energy=1;ecology.beginTick(p);
        auto ctx=makeContext(p,sun,chemistry,ecology,random);
        auto action=cybernet::Lifecycle::decide(p[0],ctx,cybernet::ObservationNoise{});
        const float expectedSensor=sun.optics().sampleLight(p[0].position).sensor;
        p[0].position.z=30; // Isolate the documented pre/post phase boundary.
        const float expectedPhoto=sun.optics().sampleLight(p[0].position).photosynthetic;
        cybernet::Lifecycle::completeTick(p[0],action,ctx);
        assert(p[0].opticalDiagnostics.tick==150);
        assert(p[0].opticalDiagnostics.sensorLight==expectedSensor);
        assert(p[0].opticalDiagnostics.photosyntheticLight==expectedPhoto);
        assert(p[0].opticalDiagnostics.photosyntheticEnergy==action.photosyntheticEnergyGained);
        assert(action.photosyntheticEnergyGained>0 && expectedPhoto<expectedSensor);
    }
    return 0;
}

