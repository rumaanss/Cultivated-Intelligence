#include "cybernet/random.hpp"
#include "cybernet/simulation/snapshot_recorder.hpp"
#include <filesystem>
#include <fstream>
#include <chrono>
#include "cybernet/simulation/lifecycle.hpp"
#include "cybernet/simulation/deterministic_worker_pool.hpp"
#include "cybernet/simulation/simulation.hpp"
#include "cybernet/simulation/spawning.hpp"
#include "cybernet/world/celestial.hpp"
#include "cybernet/world/chemistry.hpp"
#include "cybernet/world/ecology.hpp"

#ifdef NDEBUG
#undef NDEBUG
#endif

#include <cassert>
#include <cmath>
#include <cstdint>
#include <set>
#include <span>
#include <string_view>
#include <vector>

namespace {

struct SimulationState {
    cybernet::Random random;
    cybernet::CelestialCycle celestial{};
    cybernet::ChemistryField chemistry{};
    cybernet::Ecology ecology{};
    std::vector<cybernet::Organism> population{};
    std::uint32_t nextId{1U};
    std::uint32_t tick{0U};

    explicit SimulationState(std::uint64_t seed)
        : random(seed) {
        ecology.setChemistry(&chemistry);
        population.reserve(256U);
    }
};

void addFounder(
    SimulationState& state,
    cybernet::OrganismType species) {

    cybernet::Organism organism{};
    const cybernet::Vec3 position{
        state.random.uniform_float(0.0F, cybernet::config::WORLD_SIZE_X),
        state.random.uniform_float(0.0F, cybernet::config::WORLD_SIZE_Y),
        state.random.uniform_float(0.0F, cybernet::config::WORLD_SIZE_Z)
    };

    cybernet::spawnOrganism(
        organism,
        state.nextId++,
        species,
        position,
        0U,
        0U,
        state.random);
    cybernet::randomizeFounderAge(organism, state.random);
    state.population.push_back(organism);
}

void initialize(SimulationState& state) {
    for (std::uint32_t index = 0U; index < 100U; ++index) {
        addFounder(state, cybernet::OrganismType::Cyanobacteria);
    }
    for (std::uint32_t index = 0U; index < 10U; ++index) {
        addFounder(state, cybernet::OrganismType::Bacterivore);
    }
    for (std::uint32_t index = 0U; index < 2U; ++index) {
        addFounder(state, cybernet::OrganismType::BodoSaltans);
    }
}

void runTick(SimulationState& state) {
    ++state.tick;
    state.celestial.update(static_cast<int>(state.tick));
    state.chemistry.beginTick(std::span<const cybernet::Organism>(state.population));
    state.ecology.refreshSpatialIndex(std::span<const cybernet::Organism>(state.population), &state.celestial);
    state.chemistry.diffuse();

    cybernet::LifecycleContext context{};
    context.population = std::span<cybernet::Organism>(state.population);
    context.celestial = &state.celestial;
    context.chemistry = &state.chemistry;
    context.ecology = &state.ecology;
    context.random = &state.random;
    context.worldWidth = cybernet::config::WORLD_SIZE_X;
    context.worldHeight = cybernet::config::WORLD_SIZE_Y;
    context.worldDepth = cybernet::config::WORLD_SIZE_Z;

    std::vector<cybernet::LifecycleAction> actions{};
    actions.reserve(state.population.size());
    for (cybernet::Organism& organism : state.population) {
        actions.push_back(cybernet::Lifecycle::decide(organism, context));
    }

    for (std::size_t index = 0U; index < state.population.size(); ++index) {
        cybernet::Lifecycle::applyMovement(
            state.population[index],
            actions[index],
            cybernet::config::DRAG, state.celestial.geometry());
    }

    state.chemistry.beginTick(std::span<const cybernet::Organism>(state.population));
    state.ecology.beginTick(std::span<const cybernet::Organism>(state.population));

    for (std::size_t index = 0U; index < state.population.size(); ++index) {
        cybernet::Lifecycle::completeTick(
            state.population[index],
            actions[index],
            context);
    }

    (void)state.ecology.processPopulation(
        state.population,
        state.tick,
        state.nextId,
        state.random);
}

void runTickWithPreGeneratedNoise(
    SimulationState& state,
    cybernet::DeterministicWorkerPool* workerPool = nullptr, bool cacheOptics = true) {
    ++state.tick;
    state.celestial.update(static_cast<int>(state.tick));
    state.chemistry.beginTick(std::span<const cybernet::Organism>(state.population));
    state.ecology.refreshSpatialIndex(std::span<const cybernet::Organism>(state.population), cacheOptics ? &state.celestial : nullptr);
    state.chemistry.diffuse();

    cybernet::LifecycleContext context{};
    context.population = std::span<cybernet::Organism>(state.population);
    context.celestial = &state.celestial;
    context.chemistry = &state.chemistry;
    context.ecology = &state.ecology;
    context.random = &state.random;
    context.worldWidth = cybernet::config::WORLD_SIZE_X;
    context.worldHeight = cybernet::config::WORLD_SIZE_Y;
    context.worldDepth = cybernet::config::WORLD_SIZE_Z;

    std::vector<cybernet::ObservationNoise> noises(state.population.size());
    for (std::size_t index = 0U; index < state.population.size(); ++index) {
        if (state.population[index].alive()) {
            noises[index] = {
                .primary = state.random.uniform_float(-1.0F, 1.0F),
                .secondary = state.random.uniform_float(-1.0F, 1.0F)
            };
        }
    }

    std::vector<cybernet::LifecycleAction> actions(state.population.size());
    const auto decideRange = [&](std::size_t begin, std::size_t end) {
        for (std::size_t index = begin; index < end; ++index) {
            actions[index] = cybernet::Lifecycle::decide(
                state.population[index],
                context,
                noises[index]);
        }
    };
    const auto moveRange = [&](std::size_t begin, std::size_t end) {
        for (std::size_t index = begin; index < end; ++index) {
            cybernet::Lifecycle::applyMovement(
                state.population[index],
                actions[index],
                cybernet::config::DRAG, state.celestial.geometry());
        }
    };

    if (workerPool == nullptr) {
        decideRange(0U, state.population.size());
        moveRange(0U, state.population.size());
    } else {
        workerPool->parallelFor(state.population.size(), decideRange);
        workerPool->parallelFor(state.population.size(), moveRange);
    }

    state.chemistry.beginTick(std::span<const cybernet::Organism>(state.population));
    state.ecology.beginTick(std::span<const cybernet::Organism>(state.population));

    for (std::size_t index = 0U; index < state.population.size(); ++index) {
        cybernet::Lifecycle::completeTick(
            state.population[index],
            actions[index],
            context);
    }

    (void)state.ecology.processPopulation(
        state.population,
        state.tick,
        state.nextId,
        state.random);
}

void assertValidState(const SimulationState& state) {
    std::set<std::uint32_t> organismIds{};

    for (const cybernet::Organism& organism : state.population) {
        assert(organism.alive());
        assert(organismIds.insert(organism.id).second);
        assert(std::isfinite(organism.energy));
        assert(std::isfinite(organism.speed));
        assert(std::isfinite(organism.position.x));
        assert(std::isfinite(organism.position.y));
        assert(std::isfinite(organism.position.z));
        assert(organism.position.x >= 0.0F);
        assert(organism.position.x <= cybernet::config::WORLD_SIZE_X);
        assert(organism.position.y >= 0.0F);
        assert(organism.position.y <= cybernet::config::WORLD_SIZE_Y);
        assert(organism.position.z >= 0.0F);
        assert(organism.position.z <= cybernet::config::WORLD_SIZE_Z);
        assert(organism.speed >= organism.profile().minimumSpeed);
        assert(organism.speed <= organism.profile().maximumSpeed);
    }
}

void assertEquivalent(
    const SimulationState& left,
    const SimulationState& right) {

    assert(left.population.size() == right.population.size());
    assert(left.nextId == right.nextId);
    assert(left.tick == right.tick);
    assert(left.random.sameState(right.random));
    assert(left.chemistry.sameState(right.chemistry));

    for (std::size_t index = 0U; index < left.population.size(); ++index) {
        const cybernet::Organism& leftOrganism = left.population[index];
        const cybernet::Organism& rightOrganism = right.population[index];

        assert(leftOrganism.id == rightOrganism.id);
        assert(leftOrganism.parentId == rightOrganism.parentId);
        assert(leftOrganism.rootAncestorId == rightOrganism.rootAncestorId);
        assert(leftOrganism.species == rightOrganism.species);
        assert(leftOrganism.generation == rightOrganism.generation);
        assert(leftOrganism.birthTick == rightOrganism.birthTick);
        assert(leftOrganism.birthCohort == rightOrganism.birthCohort);
        assert(leftOrganism.ageTicks == rightOrganism.ageTicks);
        assert(leftOrganism.energy == rightOrganism.energy);
        assert(leftOrganism.health == rightOrganism.health);
        assert(leftOrganism.foodIntake == rightOrganism.foodIntake);
        assert(leftOrganism.speed == rightOrganism.speed);
        assert(leftOrganism.position.x == rightOrganism.position.x);
        assert(leftOrganism.position.y == rightOrganism.position.y);
        assert(leftOrganism.position.z == rightOrganism.position.z);
        assert(leftOrganism.velocity.x == rightOrganism.velocity.x);
        assert(leftOrganism.velocity.y == rightOrganism.velocity.y);
        assert(leftOrganism.velocity.z == rightOrganism.velocity.z);
        assert(leftOrganism.starvationTicks == rightOrganism.starvationTicks);
        assert(leftOrganism.feedingCooldownTicks == rightOrganism.feedingCooldownTicks);
        assert(leftOrganism.reproductionCooldownTicks
            == rightOrganism.reproductionCooldownTicks);
        assert(leftOrganism.state == rightOrganism.state);
        assert(leftOrganism.genome == rightOrganism.genome);

        const auto leftBrain = leftOrganism.brain.inspectionSnapshot();
        const auto rightBrain = rightOrganism.brain.inspectionSnapshot();
        assert(leftBrain.inputs == rightBrain.inputs);
        assert(leftBrain.hidden == rightBrain.hidden);
        assert(leftBrain.outputs == rightBrain.outputs);
        assert(leftBrain.plasticWeights == rightBrain.plasticWeights);
        assert(leftBrain.eligibilityTraces == rightBrain.eligibilityTraces);
        assert(leftBrain.lastPlasticWeightUpdates
            == rightBrain.lastPlasticWeightUpdates);
        assert(leftBrain.modulatorSignal == rightBrain.modulatorSignal);
    }
}

void assertNotAllOnBoundary(const SimulationState& state) {
    std::size_t boundaryCount{0U};

    for (const cybernet::Organism& organism : state.population) {
        const bool onBoundary = organism.position.x == 0.0F
            || organism.position.x == cybernet::config::WORLD_SIZE_X
            || organism.position.y == 0.0F
            || organism.position.y == cybernet::config::WORLD_SIZE_Y
            || organism.position.z == 0.0F
            || organism.position.z == cybernet::config::WORLD_SIZE_Z;

        if (onBoundary) {
            ++boundaryCount;
        }
    }

    assert(boundaryCount < state.population.size());
}

} // namespace

// End-to-end optical regression, also emits a small reproducible comparison.
void opticalRegression() {
 std::ofstream report("optical_comparison.csv");
 report << "seed,model,ticks,population,cyano,bacterivores,bodo,total_energy,mean_depth,elapsed_ms\n";
 for (std::uint64_t seed : {42U,73U,101U}) {
  for (auto model : {cybernet::OpticalModel::LegacyV1,cybernet::OpticalModel::OpticsV2}) {
   SimulationState a(seed),b(seed);initialize(a);initialize(b);
   a.celestial.setOpticalModel(model);b.celestial.setOpticalModel(model);
   cybernet::DeterministicWorkerPool workers(4);
   const auto path=std::filesystem::path("optics_"+std::to_string(seed)+(model==cybernet::OpticalModel::OpticsV2?"_v2.jsonl":"_legacy.jsonl"));
   std::filesystem::remove(path);
   cybernet::SnapshotRecorder recorder(path,seed,20,model);
   const auto start=std::chrono::steady_clock::now();
   for (int i=0;i<600;++i) {
    runTickWithPreGeneratedNoise(a,nullptr,false);
    runTickWithPreGeneratedNoise(b,&workers);
    recorder.capture(b.tick,b.celestial.state(),b.population);
    if(i%100==0) assertEquivalent(a,b);
   }
   recorder.finish();assertEquivalent(a,b);assertValidState(a);
   for(std::size_t i=0;i<a.population.size();++i) {
    const auto& x=a.population[i].opticalDiagnostics;const auto& y=b.population[i].opticalDiagnostics;
    assert(x.tick==y.tick && x.sensorLight==y.sensorLight && x.photosyntheticLight==y.photosyntheticLight && x.photosyntheticEnergy==y.photosyntheticEnergy);
   }
   const double ms=std::chrono::duration<double,std::milli>(std::chrono::steady_clock::now()-start).count();
   std::size_t counts[3]={};double energy=0,depth=0;
   for(const auto& o:a.population) {++counts[static_cast<int>(o.species)];energy+=o.energy;depth+=60-o.position.z;}
   report<<seed<<','<<(model==cybernet::OpticalModel::OpticsV2?"v2":"legacy")<<",600,"<<a.population.size()<<','<<counts[0]<<','<<counts[1]<<','<<counts[2]<<','<<energy<<','<<(a.population.empty()?0:depth/a.population.size())<<','<<ms<<'\n';
  }
 }
}

void geometryRegression() {
 cybernet::GeometryWorld geometry(cybernet::shared_geometry::Objects,cybernet::shared_geometry::BodyRadius);
 for(std::uint64_t seed:{42U,73U,101U}) {
  SimulationState a(seed),b(seed);initialize(a);initialize(b);
  for(auto* state:{&a,&b}) {
   state->celestial.setOpticalModel(cybernet::OpticalModel::OpticsV2);state->celestial.setGeometry(&geometry);
   state->ecology.setGeometry(&geometry);
   for(auto& organism:state->population)assert(geometry.projectOutside(organism.position));
  }
  cybernet::DeterministicWorkerPool workers(4);
  const auto path=std::filesystem::path("geometry_"+std::to_string(seed)+".jsonl");std::filesystem::remove(path);
  cybernet::SnapshotRecorder recorder(path,seed,20,cybernet::OpticalModel::OpticsV2,{},true);
  for(int i=0;i<600;++i) {
   runTickWithPreGeneratedNoise(a,nullptr,false);runTickWithPreGeneratedNoise(b,&workers);
   recorder.capture(b.tick,b.celestial.state(),b.population);
   for(const auto& organism:b.population)assert(geometry.clear(organism.position));
   if(i%100==0)assertEquivalent(a,b);
  }
  assertEquivalent(a,b);recorder.finish();
 }
}

void lakeRegression() {
 cybernet::GeometryWorld geometry(cybernet::lake_geometry::Objects,cybernet::lake_geometry::BodyRadius,cybernet::lake_geometry::Planes);
 for(std::uint64_t seed:{42U,73U,101U}) {
  SimulationState a(seed),b(seed);initialize(a);initialize(b);
  for(auto* state:{&a,&b}) {
   state->celestial.setOpticalModel(cybernet::OpticalModel::OpticsV2);state->celestial.setGeometry(&geometry);
   state->ecology.setGeometry(&geometry);
   for(auto& organism:state->population)assert(geometry.projectOutside(organism.position));
  }
  cybernet::DeterministicWorkerPool workers(4);
  const auto path=std::filesystem::path("lake_"+std::to_string(seed)+".jsonl");std::filesystem::remove(path);
  cybernet::SnapshotRecorder recorder(path,seed,20,cybernet::OpticalModel::OpticsV2,{},true,true);
  for(int i=0;i<600;++i) {
   runTickWithPreGeneratedNoise(a,nullptr,false);runTickWithPreGeneratedNoise(b,&workers);
   recorder.capture(b.tick,b.celestial.state(),b.population);
   for(const auto& organism:b.population)assert(geometry.clear(organism.position));
   if(i%100==0)assertEquivalent(a,b);
  }
  assertEquivalent(a,b);recorder.finish();
 }
}

int main(int argumentCount, char* arguments[]) {
    if (argumentCount == 2 && std::string_view{arguments[1]} == "--lake-only") { lakeRegression(); return 0; }
    if (argumentCount == 2 && std::string_view{arguments[1]} == "--geometry-only") { geometryRegression(); return 0; }
    lakeRegression();
    geometryRegression();
    if (argumentCount == 2 && std::string_view{arguments[1]} == "--optics-only") { opticalRegression(); return 0; }
    opticalRegression();
    const bool equivalenceOnly = argumentCount == 2
        && std::string_view{arguments[1]} == "--equivalence-only";
    assert(argumentCount == 1 || equivalenceOnly);

    // Recording must not alter RNG, chemistry, genomes, brain state or biology.
    {
        SimulationState baseline{73U};
        SimulationState recorded{73U};
        initialize(baseline);
        initialize(recorded);
        const auto path = std::filesystem::path{"recording_equivalence.jsonl"};
        std::filesystem::remove(path);
        cybernet::SnapshotRecorder recorder{path, 73U, 20U};
        for (std::uint32_t tick = 0; tick < 600; ++tick) {
            runTickWithPreGeneratedNoise(baseline);
            runTickWithPreGeneratedNoise(recorded);
            recorder.capture(recorded.tick, recorded.celestial.state(), recorded.population);
            if (tick % 100 == 0) assertEquivalent(baseline, recorded);
        }
        assertEquivalent(baseline, recorded);
        recorder.finish();
        assert(std::filesystem::file_size(path) > 0);
    }

    SimulationState first{42U};
    SimulationState second{42U};
    initialize(first);
    initialize(second);

    for (std::uint32_t tick = 0U; tick < 1000U; ++tick) {
        runTick(first);
        runTick(second);
    }

    assert(!first.population.empty());
    assertValidState(first);
    assertEquivalent(first, second);

    SimulationState preGeneratedNoise{42U};
    initialize(preGeneratedNoise);
    for (std::uint32_t tick = 0U; tick < 1000U; ++tick) {
        runTickWithPreGeneratedNoise(preGeneratedNoise);
    }
    assertEquivalent(first, preGeneratedNoise);

    SimulationState oneWorker{42U};
    initialize(oneWorker);
    cybernet::DeterministicWorkerPool workerPool{1U};
    for (std::uint32_t tick = 0U; tick < 1000U; ++tick) {
        runTickWithPreGeneratedNoise(oneWorker, &workerPool);
    }
    assertEquivalent(first, oneWorker);

    SimulationState twoWorkers{42U};
    initialize(twoWorkers);
    cybernet::DeterministicWorkerPool twoWorkerPool{2U};
    for (std::uint32_t tick = 0U; tick < 1000U; ++tick) {
        runTickWithPreGeneratedNoise(twoWorkers, &twoWorkerPool);
    }
    assertEquivalent(first, twoWorkers);

    SimulationState fourWorkers{42U};
    initialize(fourWorkers);
    cybernet::DeterministicWorkerPool fourWorkerPool{4U};
    for (std::uint32_t tick = 0U; tick < 1000U; ++tick) {
        runTickWithPreGeneratedNoise(fourWorkers, &fourWorkerPool);
    }
    assertEquivalent(first, fourWorkers);

    SimulationState eightWorkers{42U};
    initialize(eightWorkers);
    cybernet::DeterministicWorkerPool eightWorkerPool{8U};
    for (std::uint32_t tick = 0U; tick < 1000U; ++tick) {
        runTickWithPreGeneratedNoise(eightWorkers, &eightWorkerPool);
    }
    assertEquivalent(first, eightWorkers);

    SimulationState sixteenWorkers{42U};
    initialize(sixteenWorkers);
    cybernet::DeterministicWorkerPool sixteenWorkerPool{16U};
    for (std::uint32_t tick = 0U; tick < 1000U; ++tick) {
        runTickWithPreGeneratedNoise(sixteenWorkers, &sixteenWorkerPool);
    }
    assertEquivalent(first, sixteenWorkers);

    if (equivalenceOnly) {
        return 0;
    }

    SimulationState longRun{43U};
    initialize(longRun);

    for (std::uint32_t tick = 0U; tick < 10000U; ++tick) {
        runTick(longRun);
    }

    assert(!longRun.population.empty());
    assertValidState(longRun);
    assertNotAllOnBoundary(longRun);
    return 0;
}

