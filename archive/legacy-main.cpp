#include "cybernet/random.hpp"
#include "cybernet/simulation/lifecycle.hpp"
#include "cybernet/simulation/metrics.hpp"
#include "cybernet/simulation/organism.hpp"
#include "cybernet/simulation/deterministic_worker_pool.hpp"
#include "cybernet/simulation/run_options.hpp"
#include "cybernet/simulation/snapshot_recorder.hpp"
#include "cybernet/simulation/live_bridge.hpp"
#include <thread>
#include <csignal>
#include <memory>
#include "cybernet/world/island_world.hpp"
#include "cybernet/simulation/plant_publisher_lock.hpp"
#include "cybernet/world/shared_geometry_generated.hpp"
#include "cybernet/world/lake_geometry_generated.hpp"
#include "cybernet/world/pond_geometry_generated.hpp"
#ifdef CI_PLANET_LAKE
#include "cybernet/world/planet_founders.hpp"
#endif
#include "cybernet/simulation/selection.hpp"
#include "cybernet/simulation/simulation.hpp"
#include "cybernet/simulation/spawning.hpp"
#include "cybernet/world/celestial.hpp"
#include "cybernet/world/chemistry.hpp"
#include "cybernet/world/ecology.hpp"
#include "brain/brain_inspector.hpp"
#include "raylib.h"

#include <algorithm>
#include <array>
#include <bit>
#include <chrono>
#include <cmath>
#include <cstdint>
#include <deque>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <optional>
#include <span>
#include <vector>

namespace {
volatile std::sig_atomic_t stopRequested=0;
void requestStop(int) { stopRequested=1; }

#ifdef CI_PLANET_LAKE
constexpr std::uint32_t CyanobacteriaCount=cybernet::PlanetFounders::Cyanobacteria;
constexpr std::uint32_t BacterivoreCount=cybernet::PlanetFounders::Bacterivores;
constexpr std::uint32_t BodoSaltansCount=cybernet::PlanetFounders::Bodo;
#else
constexpr std::uint32_t CyanobacteriaCount = 2500;
constexpr std::uint32_t BacterivoreCount = 150;
constexpr std::uint32_t BodoSaltansCount = 15;
#endif

constexpr std::uint32_t MetricsIntervalTicks = 100U;
constexpr std::uint32_t SynapseSampleIntervalTicks = 500U;
constexpr std::size_t HistoryCapacity = 2000;
constexpr std::size_t SynapseSampleLimitPerSpecies = 64U;

constexpr int WindowWidth = 1600;
constexpr int WindowHeight = 900;
constexpr int HeaderHeight = 56;

constexpr Rectangle WorldPanel = {18, 72, 1030, 810};
constexpr Rectangle MetricsPanel = {1060, 72, 522, 810};
constexpr Rectangle BrainInspectorPanel = {220, 110, 1120, 680};

constexpr Color BackgroundColor = {6, 14, 30, 255};
constexpr Color HeaderColor = {12, 32, 58, 255};
constexpr Color PanelColor = {9, 23, 45, 255};
constexpr Color BorderColor = {43, 128, 185, 255};
constexpr Color TextColor = {210, 230, 255, 255};
constexpr Color MutedTextColor = {130, 170, 205, 255};

bool paused = false;
bool showGraphs = true;
bool topDownView = false;
bool showAdvancedMetrics = false;

int ticksPerFrame = 2;

std::deque<cybernet::PopulationMetrics> metricHistory;
std::deque<cybernet::ChemistrySummary> chemistryHistory;

enum class DashboardTab {
    Organisms,
    Chemicals,
    Controls
};

DashboardTab dashboardTab = DashboardTab::Organisms;

struct SynapseSummary {
    std::array<float, cybernet::RnnBrain::RecurrentWeightsSize> averages{};
    std::array<float, cybernet::RnnBrain::InputCount * 3> pathwayScores{};
    std::size_t livingCount{0};
    std::size_t sampledCount{0};
};

using SynapseSummaries = std::array<SynapseSummary, 3>;

struct TickPhaseTimings {
    double environmentSeconds{0.0};
    double decisionSeconds{0.0};
    double movementSeconds{0.0};
    double interactionSeconds{0.0};
    double populationSeconds{0.0};
    double metricsSeconds{0.0};
};

struct SimulationRuntime {
    cybernet::CelestialCycle& celestial;
    cybernet::Ecology& ecology;
    cybernet::ChemistryField& chemistry;
    cybernet::Random& random;
    cybernet::Metrics& metrics;
    std::vector<cybernet::Organism>& population;
    std::vector<cybernet::LifecycleAction>& lifecycleActions;
    std::vector<cybernet::ObservationNoise>& observationNoises;
    cybernet::DeterministicWorkerPool& decisionWorkers;
    std::uint32_t& nextId;
    std::uint32_t& simulationTick;
    cybernet::SnapshotRecorder* recorder{nullptr};
    cybernet::LiveBridge* live{nullptr};
    const cybernet::GeometryWorld* liveTerrain{nullptr};
    cybernet::IslandWorld* island{nullptr};
};

constexpr const char* InputLabels[cybernet::RnnBrain::InputCount] = {
    "PREY X", "PREY Y", "PREY Z", "PREY DIST",
    "ENERGY", "VELOCITY X", "VELOCITY Y", "VELOCITY Z",
    "DEPTH", "AGE", "NOISE", "NOISE 2",
    "LIGHT", "PREY VISIBLE",
    "BOUNDARY X", "BOUNDARY Y", "BOUNDARY Z", "BOUNDARY NEAR",
    "THREAT X", "THREAT Y", "THREAT Z", "THREAT DIST",
    "CROWDING", "FOOD LOCAL", "READINESS", "COOLDOWN",
    "THREAT DENSITY", "BIAS"
};

constexpr const char* MotionLabels[] = {
    "FORWARD",
    "STRAFE",
    "DEPTH"
};

std::size_t speciesIndex(cybernet::OrganismType species) {
    return static_cast<std::size_t>(species);
}

const char* organismTypeName(cybernet::OrganismType species) {
    switch (species) {
    case cybernet::OrganismType::Cyanobacteria:
        return "Cyanobacteria";
    case cybernet::OrganismType::Bacterivore:
        return "Bacterivores";
    case cybernet::OrganismType::BodoSaltans:
        return "Bodo-Saltans";
    default:
        return "Unknown";
    }
}

void spawnFounder(
    std::vector<cybernet::Organism>& population,
    std::uint32_t id,
    cybernet::OrganismType species,
    cybernet::Random& random) {

    cybernet::Organism organism{};

    const cybernet::Vec3 position{
        random.uniform_float(0.0F, cybernet::config::WORLD_SIZE_X),
        random.uniform_float(0.0F, cybernet::config::WORLD_SIZE_Y),
        random.uniform_float(0.0F, cybernet::config::WORLD_SIZE_Z)
    };

    cybernet::spawnOrganism(
        organism,
        id,
        species,
        position,
        0U,
        0U,
        random);
    cybernet::randomizeFounderAge(organism, random);
    population.push_back(organism);
}

Color organismColor(cybernet::OrganismType species) {
    using cybernet::OrganismType;

    switch (species) {
    case OrganismType::Cyanobacteria:
        return {42, 214, 121, 210};

    case OrganismType::Bacterivore:
        return {255, 191, 51, 255};

    case OrganismType::BodoSaltans:
        return {255, 91, 127, 255};

    default:
        return WHITE;
    }
}

float organismRadius(cybernet::OrganismType species) {
    using cybernet::OrganismType;

    return species == OrganismType::BodoSaltans ? 6.0F
        : species == OrganismType::Bacterivore ? 4.0F
        : 2.0F;
}

Vector2 projectPosition(
    const cybernet::Organism& organism,
    const Rectangle& panel) {

    float horizontal = organism.position.x;
    float vertical = organism.position.y;
    float horizontalLimit = cybernet::config::WORLD_SIZE_X;
    float verticalLimit = cybernet::config::WORLD_SIZE_Y;

    if (!topDownView) {
        vertical = organism.position.z;
        verticalLimit = cybernet::config::WORLD_SIZE_Z;
    }

    return {
        panel.x + (horizontal / horizontalLimit) * panel.width,
        panel.y + panel.height - (vertical / verticalLimit) * panel.height
    };
}

void DrawWorldGrid(const Rectangle& panel) {
    constexpr int GridDivisions = 10;

    for (int i = 1; i < GridDivisions; ++i) {
        const float x =
            panel.x + (panel.width * static_cast<float>(i) / GridDivisions);

        const float y =
            panel.y + (panel.height * static_cast<float>(i) / GridDivisions);

        DrawLineV(
            {x, panel.y},
            {x, panel.y + panel.height},
            Color{20, 58, 90, 130});

        DrawLineV(
            {panel.x, y},
            {panel.x + panel.width, y},
            Color{20, 58, 90, 130});
    }
}

void drawPopulationGraph(
    const std::deque<cybernet::PopulationMetrics>& history,
    const Rectangle& graph) {

    if (history.size() < 2) {
        DrawText(
            "Collecting metric history...",
            static_cast<int>(graph.x + 12),
            static_cast<int>(graph.y + 12),
            16,
            MutedTextColor);
        return;
    }

    std::size_t maxPopulation = 1;

    for (const auto& metric : history) {
        maxPopulation = std::max(maxPopulation, metric.totalLiving);
    }

    auto drawLine = [&](auto populationGetter, Color color) {
        for (std::size_t i = 1; i < history.size(); ++i) {
            const float x1 = graph.x
                + (static_cast<float>(i - 1)
                    / static_cast<float>(history.size() - 1))
                    * graph.width;

            const float x2 = graph.x
                + (static_cast<float>(i)
                    / static_cast<float>(history.size() - 1))
                    * graph.width;

            const float y1 = graph.y + graph.height
                - (static_cast<float>(populationGetter(history[i - 1]))
                    / static_cast<float>(maxPopulation))
                    * graph.height;

            const float y2 = graph.y + graph.height
                - (static_cast<float>(populationGetter(history[i]))
                    / static_cast<float>(maxPopulation))
                    * graph.height;

            DrawLineEx({x1, y1}, {x2, y2}, 2.0F, color);
        }
    };

    drawLine(
        [](const cybernet::PopulationMetrics& metric) {
            return metric.cyanobacteria.livingCount;
        },
        {42, 214, 121, 255});

    drawLine(
        [](const cybernet::PopulationMetrics& metric) {
            return metric.bacterivores.livingCount;
        },
        {255, 191, 51, 255});

    drawLine(
        [](const cybernet::PopulationMetrics& metric) {
            return metric.bodoSaltans.livingCount;
        },
        {255, 91, 127, 255});
}

void drawChemistryGraph(
    const std::deque<cybernet::ChemistrySummary>& history,
    const Rectangle& graph) {

    if (history.size() < 2) {
        DrawText("Collecting chemistry history...",
                 static_cast<int>(graph.x + 12),
                 static_cast<int>(graph.y + 12),
                 16,
                 MutedTextColor);
        return;
    }

    auto drawLine = [&](auto getter, Color color) {
        float minimum = getter(history.front());
        float maximum = minimum;

        for (const cybernet::ChemistrySummary& value : history) {
            const float sample = getter(value);
            minimum = std::min(minimum, sample);
            maximum = std::max(maximum, sample);
        }

        const float padding = std::max((maximum - minimum) * 0.10F, 0.002F);
        minimum -= padding;
        maximum += padding;
        const float range = maximum - minimum;

        for (std::size_t i = 1; i < history.size(); ++i) {
            const float x1 = graph.x
                + (static_cast<float>(i - 1)
                    / static_cast<float>(history.size() - 1))
                    * graph.width;
            const float x2 = graph.x
                + (static_cast<float>(i)
                    / static_cast<float>(history.size() - 1))
                    * graph.width;
            const float y1 = graph.y + graph.height
                - ((getter(history[i - 1]) - minimum) / range) * graph.height;
            const float y2 = graph.y + graph.height
                - ((getter(history[i]) - minimum) / range) * graph.height;
            DrawLineEx({x1, y1}, {x2, y2}, 2.0F, color);
        }
    };

    drawLine([](const cybernet::ChemistrySummary& value) {
        return value.averageDissolvedCarbon;
    }, {42, 214, 121, 255});
    drawLine([](const cybernet::ChemistrySummary& value) {
        return value.averageOxygen;
    }, {90, 180, 255, 255});
    drawLine([](const cybernet::ChemistrySummary& value) {
        return value.averageNitrate;
    }, {255, 191, 51, 255});
    drawLine([](const cybernet::ChemistrySummary& value) {
        return value.averagePhosphate;
    }, {190, 110, 255, 255});
}

void sampleSynapses(
    const std::vector<cybernet::Organism>& population,
    SynapseSummaries& summaries) {

    for (SynapseSummary& summary : summaries) {
        summary.averages.fill(0.0F);
        summary.pathwayScores.fill(0.0F);
        summary.livingCount = 0;
        summary.sampledCount = 0;
    }

    for (const cybernet::Organism& organism : population) {
        if (!organism.alive()) {
            continue;
        }

        SynapseSummary& summary = summaries[speciesIndex(organism.species)];
        ++summary.livingCount;
    }

    std::array<std::size_t, 3> organismsSeen{};

    for (const cybernet::Organism& organism : population) {
        if (!organism.alive()) {
            continue;
        }

        const std::size_t organismSpeciesIndex = speciesIndex(organism.species);
        SynapseSummary& summary = summaries[organismSpeciesIndex];
        const std::size_t targetSampleCount = std::min(
            summary.livingCount,
            SynapseSampleLimitPerSpecies);
        const std::size_t currentRank = organismsSeen[organismSpeciesIndex]++;

        if (((currentRank + 1U) * targetSampleCount) / summary.livingCount
            == (currentRank * targetSampleCount) / summary.livingCount) {
            continue;
        }

        const auto& plasticWeights = organism.brain.plasticRecurrentWeights();
        const auto& inputWeights = organism.brain.inputToHiddenWeights();
        const auto& outputWeights = organism.brain.hiddenToOutputWeights();
        ++summary.sampledCount;

        for (std::size_t index = 0; index < plasticWeights.size(); ++index) {
            summary.averages[index] += plasticWeights[index];
        }

        std::array<
            float,
            cybernet::RnnBrain::HiddenCount * cybernet::RnnBrain::InputCount>
            recurrentInputProjection{};

        for (std::size_t target = 0;
             target < cybernet::RnnBrain::HiddenCount;
             ++target) {
            for (std::size_t input = 0;
                 input < cybernet::RnnBrain::InputCount;
                 ++input) {
                float projection = 0.0F;
                for (std::size_t source = 0;
                     source < cybernet::RnnBrain::HiddenCount;
                     ++source) {
                    projection += plasticWeights[
                        target * cybernet::RnnBrain::HiddenCount + source]
                        * inputWeights[
                            source * cybernet::RnnBrain::InputCount + input];
                }
                recurrentInputProjection[
                    target * cybernet::RnnBrain::InputCount + input] = projection;
            }
        }

        for (std::size_t input = 0;
             input < cybernet::RnnBrain::InputCount;
             ++input) {
            for (std::size_t output = 0; output < std::size(MotionLabels); ++output) {
                float pathwayScore = 0.0F;
                for (std::size_t target = 0;
                     target < cybernet::RnnBrain::HiddenCount;
                     ++target) {
                    pathwayScore += outputWeights[
                        output * cybernet::RnnBrain::HiddenCount + target]
                        * recurrentInputProjection[
                            target * cybernet::RnnBrain::InputCount + input];
                }
                summary.pathwayScores[
                    input * std::size(MotionLabels) + output] += pathwayScore;
            }
        }
    }

    for (SynapseSummary& summary : summaries) {
        if (summary.sampledCount == 0) {
            continue;
        }

        const float divisor = static_cast<float>(summary.sampledCount);
        for (float& weight : summary.averages) {
            weight /= divisor;
        }
        for (float& pathwayScore : summary.pathwayScores) {
            pathwayScore /= divisor;
        }
    }
}

template <typename Operation>
void timePhase(double* destination, Operation&& operation) {
    if (destination == nullptr) {
        operation();
        return;
    }

    const auto start = std::chrono::steady_clock::now();
    operation();
    *destination += std::chrono::duration<double>(
        std::chrono::steady_clock::now() - start).count();
}

void advanceSimulationTick(
    SimulationRuntime runtime,
    TickPhaseTimings* timings = nullptr) {

    using namespace cybernet;

    if(runtime.live!=nullptr) {
        if(!runtime.live->beginTick(runtime.population,*runtime.liveTerrain))return;
        const auto* scene=runtime.live->geometry();
        runtime.celestial.setGeometry(scene?scene:runtime.liveTerrain);
        runtime.ecology.setGeometry(scene?scene:runtime.liveTerrain);
    }
    ++runtime.simulationTick;
    timePhase(
        timings == nullptr ? nullptr : &timings->environmentSeconds,
        [&] {
            runtime.celestial.update(static_cast<int>(runtime.simulationTick));
            runtime.chemistry.beginTick(std::span<const Organism>(
                runtime.population.data(),
                runtime.population.size()));
            runtime.ecology.refreshSpatialIndex(std::span<const Organism>(
                runtime.population.data(),
                runtime.population.size()), &runtime.celestial);
            runtime.chemistry.diffuse();
            if(runtime.island)runtime.island->step(runtime.simulationTick,runtime.chemistry,runtime.celestial);
        });

    LifecycleContext context{};
    context.population = std::span<Organism>(
        runtime.population.data(),
        runtime.population.size());
    context.celestial = &runtime.celestial;
    context.ecology = &runtime.ecology;
    context.chemistry = &runtime.chemistry;
    context.random = &runtime.random;
    if(runtime.live)context.externalActors=runtime.live->actors();
    context.worldWidth = config::WORLD_SIZE_X;
    context.worldHeight = config::WORLD_SIZE_Y;
    context.worldDepth = config::WORLD_SIZE_Z;

    runtime.lifecycleActions.clear();
    runtime.lifecycleActions.reserve(runtime.population.size());
    runtime.observationNoises.resize(runtime.population.size());
    timePhase(
        timings == nullptr ? nullptr : &timings->decisionSeconds,
        [&] {
            // Preserve the pre-existing RNG sequence before parallel decisions.
            for (std::size_t organismIndex = 0U;
                 organismIndex < runtime.population.size();
                 ++organismIndex) {
                if (!runtime.population[organismIndex].alive()) {
                    continue;
                }

                runtime.observationNoises[organismIndex] = {
                    .primary = runtime.random.uniform_float(-1.0F, 1.0F),
                    .secondary = runtime.random.uniform_float(-1.0F, 1.0F)
                };
            }

            runtime.lifecycleActions.resize(runtime.population.size());
            runtime.decisionWorkers.parallelFor(
                runtime.population.size(),
                [&](std::size_t begin, std::size_t end) {
                    for (std::size_t organismIndex = begin;
                         organismIndex < end;
                         ++organismIndex) {
                        runtime.lifecycleActions[organismIndex] = Lifecycle::decide(
                            runtime.population[organismIndex],
                            context,
                            runtime.observationNoises[organismIndex]);
                    }
                });
        });

    timePhase(
        timings == nullptr ? nullptr : &timings->movementSeconds,
        [&] {
            runtime.decisionWorkers.parallelFor(
                runtime.population.size(),
                [&](std::size_t begin, std::size_t end) {
                    for (std::size_t organismIndex = begin;
                         organismIndex < end;
                         ++organismIndex) {
#ifndef CI_PLANET_LAKE
                        if(runtime.live)runtime.live->movement(runtime.population[organismIndex],runtime.lifecycleActions[organismIndex]);
                        else
#endif
                        Lifecycle::applyMovement(
                            runtime.population[organismIndex],
                            runtime.lifecycleActions[organismIndex],
                            config::DRAG, runtime.celestial.geometry());
                    }
                });
        });

    timePhase(
        timings == nullptr ? nullptr : &timings->interactionSeconds,
        [&] {
            runtime.chemistry.beginTick(std::span<const Organism>(
                runtime.population.data(),
                runtime.population.size()));
            runtime.ecology.beginTick(std::span<const Organism>(
                runtime.population.data(),
                runtime.population.size()));

            for (std::size_t organismIndex = 0U;
                 organismIndex < runtime.population.size();
                 ++organismIndex) {
                Lifecycle::completeTick(
                    runtime.population[organismIndex],
                    runtime.lifecycleActions[organismIndex],
                    context);
                runtime.metrics.recordBehavior(
                    runtime.population[organismIndex],
                    runtime.lifecycleActions[organismIndex]);
            }
        });

    timePhase(
        timings == nullptr ? nullptr : &timings->populationSeconds,
        [&] {
            const PopulationChanges populationChanges =
                runtime.ecology.processPopulation(
                    runtime.population,
                    runtime.simulationTick,
                    runtime.nextId,
                    runtime.random);
            runtime.metrics.recordPopulationChanges(populationChanges);
        });

    timePhase(
        timings == nullptr ? nullptr : &timings->metricsSeconds,
        [&] {
            runtime.metrics.endTick(
                runtime.simulationTick,
                runtime.celestial.state().daylight,
                runtime.celestial.state().ambientLight,
                runtime.population);
        });
    if(runtime.live){runtime.live->checkpoint(runtime.population,runtime.chemistry,runtime.random,runtime.simulationTick,runtime.nextId,runtime.island?&runtime.island->biology:nullptr);
      if(runtime.island && runtime.simulationTick%IslandWorld::PublishStride==0)runtime.live->publishPlants(runtime.island->snapshot(runtime.simulationTick));
      runtime.live->capture(runtime.simulationTick,runtime.celestial.state(),runtime.population);}
    // Sample a complete end-of-tick state; recording never participates in physics.
    if (runtime.recorder != nullptr) {
        runtime.recorder->capture(runtime.simulationTick, runtime.celestial.state(),
            std::span<const Organism>(runtime.population));
    }
}

std::uint64_t populationStateHash(
    const std::vector<cybernet::Organism>& population,
    std::uint32_t nextId,
    std::uint32_t tick) noexcept {

    std::uint64_t hash = 1469598103934665603ULL;
    const auto combine = [&hash](std::uint64_t value) {
        hash ^= value;
        hash *= 1099511628211ULL;
    };

    combine(tick);
    combine(nextId);
    for (const cybernet::Organism& organism : population) {
        combine(organism.id);
        combine(static_cast<std::uint64_t>(organism.species));
        combine(organism.generation);
        combine(organism.ageTicks);
        combine(std::bit_cast<std::uint32_t>(organism.energy));
        combine(std::bit_cast<std::uint32_t>(organism.speed));
        combine(std::bit_cast<std::uint32_t>(organism.position.x));
        combine(std::bit_cast<std::uint32_t>(organism.position.y));
        combine(std::bit_cast<std::uint32_t>(organism.position.z));
    }

    return hash;
}

void writePerformanceMetrics(
    const cybernet::RunOptions& options,
    const std::filesystem::path& archiveDirectory,
    const TickPhaseTimings& timings,
    double elapsedSeconds,
    std::size_t peakPopulation,
    std::uint64_t stateHash,
    std::uint64_t executedTicks) {

    std::ofstream file{
        archiveDirectory / "performance_metrics.csv",
        std::ios::out | std::ios::trunc};
    if (!file.is_open()) {
        throw std::runtime_error("Unable to create performance metrics output.");
    }

    const double tickRate = elapsedSeconds <= 0.0
        ? 0.0
        : static_cast<double>(executedTicks) / elapsedSeconds;
    file << "seed,executed_ticks,worker_count,trace_enabled,elapsed_seconds,ticks_per_second,"
         << "peak_population,population_state_hash,environment_seconds,"
         << "decision_seconds,movement_seconds,interaction_seconds,"
         << "population_seconds,metrics_seconds\n";
    file << std::fixed << std::setprecision(6)
         << options.seed << ',' << executedTicks << ','
         << options.workerCount << ',' << (options.trace ? 1 : 0) << ','
         << elapsedSeconds << ',' << tickRate
         << ',' << peakPopulation << ',' << stateHash << ','
         << timings.environmentSeconds << ',' << timings.decisionSeconds << ','
         << timings.movementSeconds << ',' << timings.interactionSeconds << ','
         << timings.populationSeconds << ',' << timings.metricsSeconds << '\n';
}

void drawSynapseDashboard(
    const SynapseSummaries& summaries,
    int x,
    int y) {

    constexpr int MatrixCellSize = 4;
    constexpr int MatrixSize = static_cast<int>(cybernet::RnnBrain::HiddenCount)
        * MatrixCellSize;
    constexpr int CardWidth = 150;
    constexpr float MinimumColorScale = 0.01F;

    const cybernet::OrganismType species[] = {
        cybernet::OrganismType::Cyanobacteria,
        cybernet::OrganismType::Bacterivore,
        cybernet::OrganismType::BodoSaltans
    };

    DrawText("SYNAPTIC PLASTICITY", x, y, 16, TextColor);
    y += 26;

    float colorScale = MinimumColorScale;
    for (const SynapseSummary& summary : summaries) {
        for (const float weight : summary.averages) {
            colorScale = std::max(colorScale, std::abs(weight));
        }
    }

    for (std::size_t speciesPosition = 0;
         speciesPosition < std::size(species);
         ++speciesPosition) {

        const int cardX = x + static_cast<int>(speciesPosition) * CardWidth;
        const SynapseSummary& summary =
            summaries[speciesIndex(species[speciesPosition])];
        const Color speciesColor = organismColor(species[speciesPosition]);

        DrawText(
            organismTypeName(species[speciesPosition]),
            cardX,
            y,
            12,
            speciesColor);

        if (summary.livingCount == 0) {
            DrawText("NO LIVING", cardX, y + 32, 12, MutedTextColor);
            continue;
        }

        for (std::size_t target = 0;
             target < cybernet::RnnBrain::HiddenCount;
             ++target) {
            for (std::size_t source = 0;
                 source < cybernet::RnnBrain::HiddenCount;
                 ++source) {
                const std::size_t index = target
                    * cybernet::RnnBrain::HiddenCount + source;
                const float weight = summary.averages[index];
                const float magnitude = std::abs(weight);
                const float intensity = std::clamp(magnitude / colorScale, 0.0F, 1.0F);
                const Color color = weight >= 0.0F
                    ? Color{40, static_cast<unsigned char>(80.0F + intensity * 175.0F), 230, 255}
                    : Color{230, 60, static_cast<unsigned char>(100.0F + intensity * 120.0F), 255};

                DrawRectangle(
                    cardX + static_cast<int>(source) * MatrixCellSize,
                    y + 18 + static_cast<int>(target) * MatrixCellSize,
                    MatrixCellSize - 1,
                    MatrixCellSize - 1,
                    color);
            }
        }
    }

    int statementY = y + MatrixSize + 42;
    for (const cybernet::OrganismType speciesType : species) {
        const SynapseSummary& summary = summaries[speciesIndex(speciesType)];
        if (summary.livingCount == 0) {
            continue;
        }

        std::size_t strongestPathway = 0;
        float strongestMagnitude = 0.0F;
        for (std::size_t index = 0; index < summary.pathwayScores.size(); ++index) {
            const float magnitude = std::abs(summary.pathwayScores[index]);
            if (magnitude > strongestMagnitude) {
                strongestPathway = index;
                strongestMagnitude = magnitude;
            }
        }

        const std::size_t input = strongestPathway / std::size(MotionLabels);
        const std::size_t motion = strongestPathway % std::size(MotionLabels);
        const char* change = summary.pathwayScores[strongestPathway] >= 0.0F
            ? "STRENGTHENS"
            : "INHIBITS";

        DrawText(
            TextFormat(
                "%s: %s %s -> %s",
                organismTypeName(speciesType),
                change,
                InputLabels[input],
                MotionLabels[motion]),
            x,
            statementY,
            12,
            organismColor(speciesType));
        statementY += 22;
    }
}

void drawControlsDashboard(int x, int y) {
    struct Control {
        const char* key;
        const char* action;
    };

    constexpr Control controls[] = {
        {"SPACE", "Pause"},
        {"UP/DOWN", "Speed"},
        {"V", "View"},
        {"G", "Graph"},
        {"[/]", "Select"},
        {"N", "Brain"},
        {"M", "Metrics"}
    };

    constexpr int columnWidth = 240;
    constexpr int rowHeight = 24;

    for (std::size_t index = 0; index < std::size(controls); ++index) {
        const int column = static_cast<int>(index % 2);
        const int row = static_cast<int>(index / 2);
        const int itemX = x + (column * columnWidth);
        const int itemY = y + (row * rowHeight);

        DrawText(controls[index].key, itemX, itemY, 13, TextColor);
        DrawText(controls[index].action, itemX + 76, itemY, 13, MutedTextColor);
    }
}

void drawOrganismDashboard(
    const cybernet::PopulationMetrics& populationMetrics,
    int x,
    int y) {

    const cybernet::OrganismType species[] = {
        cybernet::OrganismType::Cyanobacteria,
        cybernet::OrganismType::Bacterivore,
        cybernet::OrganismType::BodoSaltans
    };
    const cybernet::SpeciesMetrics* speciesMetrics[] = {
        &populationMetrics.cyanobacteria,
        &populationMetrics.bacterivores,
        &populationMetrics.bodoSaltans
    };

    constexpr int countColumn = 125;
    constexpr int energyColumn = 200;
    constexpr int ageColumn = 295;
    constexpr int foodColumn = 385;

    DrawText("SPECIES", x, y, 12, MutedTextColor);
    DrawText("COUNT", x + countColumn, y, 12, MutedTextColor);
    DrawText("AVG ENERGY", x + energyColumn, y, 12, MutedTextColor);
    DrawText("AVG AGE", x + ageColumn, y, 12, MutedTextColor);
    DrawText("FOOD INTAKE", x + foodColumn, y, 12, MutedTextColor);
    y += 24;

    for (std::size_t index = 0U; index < std::size(species); ++index) {
        const cybernet::SpeciesMetrics& metrics = *speciesMetrics[index];
        const Color color = organismColor(species[index]);
        DrawText(organismTypeName(species[index]), x, y, 15, color);
        DrawText(TextFormat("%zu", metrics.livingCount), x + countColumn, y, 15, color);
        DrawText(TextFormat("%.1f", metrics.averageEnergy()),
                 x + energyColumn, y, 15, color);
        DrawText(TextFormat("%.1f", metrics.averageAge()),
                 x + ageColumn, y, 15, color);
        DrawText(TextFormat("%.1f", metrics.averageFoodIntake()),
                 x + foodColumn, y, 15, color);
        y += 24;
    }
}

void drawAdvancedMetrics(
    const cybernet::AdvancedMetrics& advanced,
    const cybernet::PopulationMetrics& populationMetrics) {

    const Rectangle panel{100.0F, 82.0F, 1400.0F, 736.0F};
    const cybernet::OrganismType species[] = {
        cybernet::OrganismType::Cyanobacteria,
        cybernet::OrganismType::Bacterivore,
        cybernet::OrganismType::BodoSaltans
    };
    constexpr float ColumnWidth = 452.0F;

    DrawRectangleRec(panel, Color{7, 18, 38, 248});
    DrawRectangleLinesEx(panel, 2.0F, Color{90, 180, 255, 255});

    DrawText(
        TextFormat("ADVANCED METRICS  |  TICK %u", advanced.tick),
        static_cast<int>(panel.x + 20.0F),
        static_cast<int>(panel.y + 18.0F),
        24,
        RAYWHITE);
    DrawText(
        "PASSIVE OBSERVATION ONLY - NO TRAINING, SELECTION, OR FORCED ACTIONS",
        static_cast<int>(panel.x + 20.0F),
        static_cast<int>(panel.y + 48.0F),
        13,
        MutedTextColor);

    if (advanced.tick == 0U) {
        DrawText(
            "Collecting the first advanced sample...",
            static_cast<int>(panel.x + 20.0F),
            static_cast<int>(panel.y + 92.0F),
            18,
            TextColor);
        return;
    }

    DrawText(
        TextFormat(
            "BIRTHS %zu   DEATHS %zu   LIVING %zu",
            populationMetrics.birthsSinceLastSample,
            populationMetrics.deathsSinceLastSample,
            populationMetrics.totalLiving),
        static_cast<int>(panel.x + 900.0F),
        static_cast<int>(panel.y + 22.0F),
        14,
        Color{90, 230, 150, 255});
    DrawText(
        TextFormat(
            "LINEAGE EVENTS %u / %u",
            advanced.lineageEventsWritten,
            advanced.maximumLineageEvents),
        static_cast<int>(panel.x + 900.0F),
        static_cast<int>(panel.y + 44.0F),
        14,
        Color{145, 180, 215, 255});

    for (std::size_t index = 0U; index < std::size(species); ++index) {
        const float columnX = panel.x + 18.0F + (ColumnWidth * index);
        const cybernet::AdvancedSpeciesMetrics& metrics =
            advanced.species[speciesIndex(species[index])];
        const Color color = organismColor(species[index]);
        int y = static_cast<int>(panel.y + 88.0F);

        if (index > 0U) {
            DrawLine(
                static_cast<int>(columnX - 12.0F),
                static_cast<int>(panel.y + 78.0F),
                static_cast<int>(columnX - 12.0F),
                static_cast<int>(panel.y + panel.height - 22.0F),
                Color{35, 85, 120, 255});
        }

        DrawText(organismTypeName(species[index]), static_cast<int>(columnX), y, 19, color);
        y += 32;

        DrawText("EVOLUTION", static_cast<int>(columnX), y, 14, TextColor);
        y += 22;
        DrawText(
            TextFormat("LIVING %zu   LINEAGES %zu", metrics.livingCount, metrics.activeLineages),
            static_cast<int>(columnX), y, 14, MutedTextColor);
        y += 22;
        DrawText(
            TextFormat("GEN %.2f +/- %.2f", metrics.averageGeneration, metrics.generationStandardDeviation),
            static_cast<int>(columnX), y, 14, MutedTextColor);
        y += 22;
        DrawText(
            TextFormat("SPEED %.3f +/- %.3f", metrics.averageSpeed, metrics.speedStandardDeviation),
            static_cast<int>(columnX), y, 14, MutedTextColor);
        y += 22;
        DrawText(
            TextFormat("GENOME DIVERSITY %.3f", metrics.genomeDiversity),
            static_cast<int>(columnX), y, 14, MutedTextColor);
        y += 38;

        DrawText("BOUNDARY + BEHAVIOR", static_cast<int>(columnX), y, 14, TextColor);
        y += 22;
        DrawText(
            TextFormat("CONTACTS %.1f / 1K", metrics.boundaryContactsPerThousand),
            static_cast<int>(columnX), y, 14, MutedTextColor);
        y += 22;
        DrawText(
            TextFormat("BOUNDARY DWELL %.1f%%", metrics.boundaryDwellPercent),
            static_cast<int>(columnX), y, 14, MutedTextColor);
        y += 22;
        DrawText(
            TextFormat("INWARD ACTION %.1f%%", metrics.inwardActionPercent),
            static_cast<int>(columnX), y, 14, MutedTextColor);
        y += 22;
        DrawText(
            TextFormat("PREY SEEN %.1f%%   THREAT %.1f%%",
                metrics.preyVisiblePercent,
                metrics.threatVisiblePercent),
            static_cast<int>(columnX), y, 14, MutedTextColor);
        y += 22;
        DrawText(
            TextFormat("FEED PRECISION %.1f%%", metrics.feedPrecisionPercent),
            static_cast<int>(columnX), y, 14, MutedTextColor);
        y += 22;
        DrawText(
            TextFormat("THREAT RETREAT %.1f%%", metrics.threatRetreatPercent),
            static_cast<int>(columnX), y, 14, MutedTextColor);
        y += 38;

        DrawText("LEARNING STATE", static_cast<int>(columnX), y, 14, TextColor);
        y += 22;
        DrawText(
            TextFormat("SAMPLED BRAINS %zu", metrics.sampledBrains),
            static_cast<int>(columnX), y, 14, MutedTextColor);
        y += 22;
        DrawText(
            TextFormat("PLASTIC MAG %.4f", metrics.meanPlasticWeightMagnitude),
            static_cast<int>(columnX), y, 14, MutedTextColor);
        y += 22;
        DrawText(
            TextFormat("HIDDEN VAR %.4f", metrics.hiddenStateVariance),
            static_cast<int>(columnX), y, 14, MutedTextColor);
        y += 22;
        DrawText(
            TextFormat("OUTPUT VAR %.4f", metrics.outputVariance),
            static_cast<int>(columnX), y, 14, MutedTextColor);
        y += 22;
        DrawText(
            TextFormat("OUTPUT SATURATION %.1f%%", metrics.outputSaturationPercent),
            static_cast<int>(columnX), y, 14, MutedTextColor);
        y += 38;

        DrawText("CLONED-BRAIN PROBES", static_cast<int>(columnX), y, 14, TextColor);
        y += 22;
        DrawText(
            TextFormat("BOUNDARY ALIGN %.3f", metrics.boundaryProbeAlignment),
            static_cast<int>(columnX), y, 14, MutedTextColor);
        y += 22;
        DrawText(
            TextFormat("PREY PURSUIT %.3f", metrics.preyProbeAlignment),
            static_cast<int>(columnX), y, 14, MutedTextColor);
        y += 22;
        DrawText(
            TextFormat("THREAT RETREAT %.3f", metrics.threatProbeRetreatAlignment),
            static_cast<int>(columnX), y, 14, MutedTextColor);
    }

    DrawText(
        "M  CLOSE ADVANCED METRICS",
        static_cast<int>(panel.x + 20.0F),
        static_cast<int>(panel.y + panel.height - 28.0F),
        13,
        Color{110, 180, 255, 255});
}

} // namespace

int main(int argumentCount, char* arguments[]) {
    using namespace cybernet;

    RunOptionsParseResult runOptions = parseRunOptions(
        argumentCount,
        arguments);
    if (!runOptions.valid()) {
        std::cerr << runOptions.error
              << "\nUsage: cybernet_sim [--seed <unsigned-integer>]"
              << " [--frame-interval <positive-integer>]"
              << " [--max-world-frames <positive-integer>]"
              << " [--max-lineage-events <positive-integer>]"
              << " [--archive-dir <directory>]"
              << " [--headless] [--benchmark-ticks <positive-integer>]"
              << " [--workers <positive-integer>]"
              << " [--recording <new-output.jsonl>] [--recording-interval <ticks>]"
              << " [--island-surface <export.txt>] [--live-dir <directory>] [--optics legacy|v2] [--geometry none|demo|lake] [--trace] [--reproduction legacy-v1|intent-v2]\n";
        return 1;
    }

#ifdef CI_PLANET_LAKE
    if(!runOptions.options.headless||runOptions.options.liveDirectory.empty()||runOptions.options.islandSurface.empty()||!runOptions.options.lakeGeometry||runOptions.options.opticalModel!=OpticalModel::OpticsV2){
        std::cerr << "Planet mode requires --headless --live-dir <new planet directory> --island-surface <planet_surface.txt> --geometry lake --optics v2\n";return 1;
    }
    std::cout << "Planet habitat: " << planet_contract::Digest << '\n';
#endif
    std::cout << "Simulation seed: " << runOptions.options.seed << '\n';

    CelestialCycle celestial{
        static_cast<int>(config::DAY_NIGHT_CYCLE_TICKS),
        config::MOONLIGHT_LEVEL
    };

    celestial.setOpticalModel(runOptions.options.opticalModel);
    std::cout << "Optical model: " << (celestial.usesOpticsV2() ? "OpticsV2 (experimental)" : "LegacyV1") << '\n';
    std::optional<GeometryWorld> geometry;
    if (runOptions.options.sharedGeometry) {
        if(runOptions.options.lakeGeometry)geometry.emplace(pond_geometry::Objects,lake_geometry::BodyRadius,std::span<const Vec3>{},&pond_geometry::Field,pond_geometry::Bounds);
        else {std::cerr<<"This full-pond application requires --geometry lake; the legacy shared fixture has different bounds.\n";return 1;}
        celestial.setGeometry(&*geometry);
        std::cout << "Shared geometry: " << (runOptions.options.lakeGeometry ? 
#ifdef CI_PLANET_LAKE
"planet-lake-1"
#else
"isafe-full-pond-1"
#endif
 : shared_geometry::Revision) << " (" << geometry->objects().size() << " static proxies)\n";
    }
    Ecology ecology{};
    ecology.setReproductionIntentV2(runOptions.options.reproductionIntentV2);
    const std::string reproductionSchema=runOptions.options.reproductionIntentV2?"intent-v2":"legacy-v1";
    std::cout << "Reproduction policy: " << reproductionSchema << '\n';
    // Explicit semantics companion preserves old checkpoint ABI and rejects accidental reinterpretation.
    if(!runOptions.options.liveDirectory.empty()) {
        const auto directory=std::filesystem::path(runOptions.options.liveDirectory);
        std::filesystem::create_directories(directory);
        const auto marker=directory/"reproduction.schema";
        if(std::filesystem::exists(marker)) {
            std::ifstream f(marker);std::string saved;f>>saved;
            if(saved!=reproductionSchema){std::cerr<<"Reproduction schema mismatch; use the saved policy or a new live directory.\n";return 1;}
        } else {
            if(std::filesystem::exists(directory/"checkpoint.bin") && runOptions.options.reproductionIntentV2){std::cerr<<"Legacy checkpoint cannot silently enter intent-v2; use a new live directory.\n";return 1;}
            LiveBridge::atomicWrite(marker,reproductionSchema+"\n");
        }
    }

    ecology.setGeometry(geometry ? &*geometry : nullptr);
    // The planetary grid is large; leave stack space for checkpoint loading.
    auto chemistryStorage=std::make_unique<ChemistryField>();
    ChemistryField& chemistry=*chemistryStorage;
    ecology.setChemistry(&chemistry);
    Random random{runOptions.options.seed};
    if(!runOptions.options.liveDirectory.empty()) {
        // Preserve pre-crash research archives; each process writes a separate segment.
        runOptions.options.archiveDirectory=(std::filesystem::path(runOptions.options.archiveDirectory)/
            ("segment-"+std::to_string(std::chrono::system_clock::now().time_since_epoch().count()))).string();
    }
    Metrics metrics{
        runOptions.options.archiveDirectory,
        MetricsIntervalTicks,
        runOptions.options.seed,
        runOptions.options.worldFrameIntervalTicks,
        runOptions.options.maximumWorldFrames,
        runOptions.options.maximumLineageEvents
    };

    // Sidecar accompanies all research archives, even when snapshot recording is off.
    // Existing CSV layouts stay compatible. Use a separate archive directory per run.
    {
        const OpticalConfig c{};
        std::ofstream reproductionMetadata(std::filesystem::path(runOptions.options.archiveDirectory) / "reproduction_schema.txt");
        reproductionMetadata << reproductionSchema << "\nGenome layout unchanged; output 3 interpreted as reproductive intent only in intent-v2.\n";
        std::ofstream opticalMetadata(std::filesystem::path(runOptions.options.archiveDirectory) / "optical_metadata.json");
        opticalMetadata << std::setprecision(std::numeric_limits<float>::max_digits10)
            << "{\"implementation\":\"civ0.77-lake-foundation-v1.0\",\"seed\":\"" << runOptions.options.seed
            << "\",\"model\":\"" << (geometry ? "normalized-flat-water-geometry-v3" : celestial.usesOpticsV2() ? "normalized-flat-water-v2" : "legacy-linear-depth40-global-vision-v1")
            << "\",\"lightUnit\":\"normalized-broadband\",\"extinctionUnit\":\"per-simulation-unit\","
            << "\"v2Parameters\":[" << c.directExtinction << ',' << c.diffuseExtinction << ',' << c.beamExtinction
            << ',' << c.diffuseFraction << ',' << c.diffuseTransmission << ',' << c.refractiveIndex << ',' << c.detectionThreshold << "],\"geometry\":" << (geometry ? (runOptions.options.lakeGeometry ? pond_geometry::Json : shared_geometry::Json) : "null") << "}\n";
        opticalMetadata.flush();
        if (!opticalMetadata) { std::cerr << "Cannot write optical run metadata.\n"; return 1; }
    }

    std::vector<Organism> population{};
    population.reserve(
        CyanobacteriaCount
        + BacterivoreCount
        + BodoSaltansCount);

    std::uint32_t nextId = 1;
    std::uint32_t simulationTick = 0;
    std::vector<LifecycleAction> lifecycleActions{};
    std::vector<ObservationNoise> observationNoises{};
    DeterministicWorkerPool decisionWorkers{runOptions.options.workerCount};
    lifecycleActions.reserve(population.capacity());
    observationNoises.reserve(population.capacity());

    std::optional<std::uint32_t> selectedOrganismId{};
    bool showBrainInspector = false;
    cybernet::ui::BrainInspectorState brainInspectorState{};

    for (std::uint32_t i = 0; i < CyanobacteriaCount; ++i) {
        spawnFounder(population, nextId++, OrganismType::Cyanobacteria, random);
    }

    for (std::uint32_t i = 0; i < BacterivoreCount; ++i) {
        spawnFounder(population, nextId++, OrganismType::Bacterivore, random);
    }

    for (std::uint32_t i = 0; i < BodoSaltansCount; ++i) {
        spawnFounder(population, nextId++, OrganismType::BodoSaltans, random);
    }

    SynapseSummaries synapseSummaries{};
    sampleSynapses(population, synapseSummaries);

#ifdef CI_PLANET_LAKE
    PlanetFounders founderHabitat(*geometry);
    for(auto& organism:population){
        organism.position=founderHabitat.sample(random);
        // Stagger a young founding cohort instead of introducing individuals
        // already within a few ticks of their maximum model age.
        organism.ageTicks/=4;
        if(!geometry->clear(organism.position))throw std::runtime_error("Invalid native founder placement");
    }
    std::cout<<"[Planet founders] 1000 / 60 / 6; occupied wet volume fraction "<<founderHabitat.occupiedVolume/founderHabitat.fullVolume<<" (existing checkpoints retain their population)\n";
#endif
    if (geometry) for (auto& organism : population) {
        // Uniform founder habitat sampling; projecting dry land into the nearest
        // shoreline cell would pile most founders into a narrow crowded band.
        if(geometry->heightfield())for(unsigned attempt=0;attempt<1024&&!geometry->clear(organism.position);++attempt)
            organism.position={random.uniform_float(0.0F,config::WORLD_SIZE_X),random.uniform_float(0.0F,config::WORLD_SIZE_Y),random.uniform_float(0.0F,config::WORLD_SIZE_Z)};
        if (!geometry->projectOutside(organism.position)) { std::cerr << "Cannot place founder outside geometry\n"; return 1; }
    }
    std::optional<SnapshotRecorder> recorder;
    if (!runOptions.options.recordingPath.empty()) {
        try {
            recorder.emplace(runOptions.options.recordingPath, runOptions.options.seed,
                runOptions.options.recordingIntervalTicks, runOptions.options.opticalModel, OpticalConfig{}, geometry.has_value(), runOptions.options.lakeGeometry);
        } catch (const std::exception& error) {
            std::cerr << "[CI Recording] " << error.what() << '\n';
            return 1;
        }
    }

    std::optional<IslandWorld> island;
    if(!runOptions.options.islandSurface.empty()) {
        if(runOptions.options.liveDirectory.empty()||!runOptions.options.lakeGeometry||runOptions.options.opticalModel!=OpticalModel::OpticsV2){std::cerr<<"Island mode requires --live-dir, --geometry lake and --optics v2\n";return 1;}
        island.emplace(runOptions.options.seed);
    }
    std::unique_ptr<PlantPublisherLock> plantPublisherLock;
    std::optional<LiveBridge> live;
    if(!runOptions.options.liveDirectory.empty()) {
        try {
          live.emplace(runOptions.options.liveDirectory,runOptions.options.seed);
          if(island)plantPublisherLock=std::make_unique<PlantPublisherLock>(runOptions.options.liveDirectory);
          std::string savedIsland;
          const bool restored=live->restore(population,chemistry,random,simulationTick,nextId,island?&savedIsland:nullptr);
          if(island){
            if(restored){
              if(savedIsland.empty())throw std::runtime_error("Old pond-only checkpoint: start a new live directory for island mode");
              island->restore(savedIsland);
              if(island->biology.tick!=simulationTick/IslandWorld::PlantStride)throw std::runtime_error("Checkpoint island clock mismatch");
            }else{
              const auto path=std::filesystem::path(runOptions.options.islandSurface);
              if(!std::filesystem::is_regular_file(path))throw std::runtime_error("Plant habitat contract is missing: "+path.string()+". Use the planet launcher with contracts/planet_surface.txt.");
              if(std::filesystem::file_size(path)>2*1024*1024)throw std::runtime_error("Island export exceeds budget");
              std::ifstream f(path);std::string text{std::istreambuf_iterator<char>(f),{}};
              island->initialize(text);island->biology.run=live->runId();
            }
            island->bind(chemistry,celestial);
            live->publishPlants(island->snapshot(simulationTick));
            std::cout<<"[Habitat] Surveyed land; "<<island->biology.plants.size()<<" land plants; microbes confined to pond; one world clock\n";
          }
          celestial.update(static_cast<int>(simulationTick));
          live->checkpoint(population,chemistry,random,simulationTick,nextId,island?&island->biology:nullptr);
          live->capture(simulationTick,celestial.state(),population);
        }
        catch(const std::exception& e){std::cerr<<"[CI Live] "<<e.what()<<'\n';return 1;}
    }
    SimulationRuntime runtime{
        .celestial = celestial,
        .ecology = ecology,
        .chemistry = chemistry,
        .random = random,
        .metrics = metrics,
        .population = population,
        .lifecycleActions = lifecycleActions,
        .observationNoises = observationNoises,
        .decisionWorkers = decisionWorkers,
        .nextId = nextId,
        .simulationTick = simulationTick,
        .recorder = recorder ? &*recorder : nullptr,
        .live=live?&*live:nullptr,
        .liveTerrain=geometry?&*geometry:nullptr,
        .island=island?&*island:nullptr
    };

    if (runOptions.options.headless) {
        std::signal(SIGINT,requestStop);
        std::signal(SIGTERM,requestStop);
        TickPhaseTimings timings{};
        std::size_t peakPopulation = population.size();
        const auto startTick = runtime.simulationTick;
        const auto start = std::chrono::steady_clock::now();

        while (!stopRequested && runtime.simulationTick < runOptions.options.benchmarkTicks) {
            const auto liveStart=std::chrono::steady_clock::now();
            advanceSimulationTick(
                runtime,
                runOptions.options.trace ? &timings : nullptr);
            peakPopulation = std::max(peakPopulation, population.size());
            if(live)std::this_thread::sleep_until(liveStart+std::chrono::microseconds(33333));
        }

        const double elapsedSeconds = std::chrono::duration<double>(
            std::chrono::steady_clock::now() - start).count();
        writePerformanceMetrics(
            runOptions.options,
            runOptions.options.archiveDirectory,
            timings,
            elapsedSeconds,
            peakPopulation,
            populationStateHash(population, nextId, simulationTick),
            runtime.simulationTick-startTick);
        std::cout << "Headless benchmark completed: "
                  << runtime.simulationTick << " ticks in "
                  << elapsedSeconds << " seconds.\n";
        if(live)live->checkpoint(population,chemistry,random,simulationTick,nextId,island?&island->biology:nullptr,true);
        return 0;
    }

    #ifndef CI_PLANET_LAKE
    InitWindow(WindowWidth, WindowHeight, "CyberNet Ecosystem Simulation");
    SetTargetFPS(60);
    auto nextLiveTick=std::chrono::steady_clock::now();

    while (!WindowShouldClose()) {
        const Rectangle organismsTabButton{
            MetricsPanel.x + 18,
            MetricsPanel.y + 590,
            150,
            32
        };
        const Rectangle chemicalsTabButton{
            MetricsPanel.x + 176,
            MetricsPanel.y + 590,
            150,
            32
        };
        const Rectangle controlsTabButton{
            MetricsPanel.x + 334,
            MetricsPanel.y + 590,
            150,
            32
        };

        if (IsMouseButtonPressed(MOUSE_BUTTON_LEFT)) {
            const Vector2 mouse = GetMousePosition();
            if (CheckCollisionPointRec(mouse, organismsTabButton)) {
                dashboardTab = DashboardTab::Organisms;
            }
            if (CheckCollisionPointRec(mouse, chemicalsTabButton)) {
                dashboardTab = DashboardTab::Chemicals;
            }
            if (CheckCollisionPointRec(mouse, controlsTabButton)) {
                dashboardTab = DashboardTab::Controls;
            }

            if (CheckCollisionPointRec(mouse, WorldPanel)
                && (!showBrainInspector
                    || !CheckCollisionPointRec(mouse, BrainInspectorPanel))) {
                const Organism* nearestOrganism = nullptr;
                float nearestDistanceSquared = 0.0F;

                for (const Organism& organism : population) {
                    if (!organism.alive()) {
                        continue;
                    }

                    const Vector2 point = projectPosition(organism, WorldPanel);
                    const float deltaX = mouse.x - point.x;
                    const float deltaY = mouse.y - point.y;
                    const float distanceSquared = (deltaX * deltaX) + (deltaY * deltaY);
                    const float hitRadius = organismRadius(organism.species) + 3.0F;

                    if (distanceSquared <= (hitRadius * hitRadius)
                        && (nearestOrganism == nullptr
                            || distanceSquared < nearestDistanceSquared)) {
                        nearestOrganism = &organism;
                        nearestDistanceSquared = distanceSquared;
                    }
                }

                if (nearestOrganism != nullptr) {
                    selectedOrganismId = nearestOrganism->id;
                }
            }
        }

        if (IsKeyPressed(KEY_N)) {
            showBrainInspector = !showBrainInspector;
        }

        if (IsKeyPressed(KEY_M)) {
            showAdvancedMetrics = !showAdvancedMetrics;
        }

        const std::optional<std::size_t> selectedOrganismIndex =
            cybernet::findOrganismIndexById(population, selectedOrganismId);

        if (population.empty()) {
            selectedOrganismId.reset();
        } else if (IsKeyPressed(KEY_RIGHT_BRACKET)) {
            const std::size_t nextIndex = selectedOrganismIndex.has_value()
                ? (selectedOrganismIndex.value() + 1U) % population.size()
                : 0U;
            selectedOrganismId = population[nextIndex].id;
        } else if (IsKeyPressed(KEY_LEFT_BRACKET)) {
            const std::size_t previousIndex = selectedOrganismIndex.has_value()
                ? (selectedOrganismIndex.value() + population.size() - 1U)
                    % population.size()
                : population.size() - 1U;
            selectedOrganismId = population[previousIndex].id;
        }

        if (IsKeyPressed(KEY_SPACE)) {
            paused = !paused;
        }

        if (IsKeyPressed(KEY_G)) {
            showGraphs = !showGraphs;
        }

        if (IsKeyPressed(KEY_V)) {
            topDownView = !topDownView;
        }

        if (IsKeyPressed(KEY_UP)) {
            ticksPerFrame = std::min(ticksPerFrame + 1, 1000);
        }

        if (IsKeyPressed(KEY_DOWN)) {
            ticksPerFrame = std::max(ticksPerFrame - 1, 1);
        }

        if (!paused) {
            const auto liveNow=std::chrono::steady_clock::now();
            const int frameTicks=live?(liveNow>=nextLiveTick?1:0):ticksPerFrame;
            if(live && frameTicks>0)nextLiveTick=liveNow+std::chrono::microseconds(33333);
            for (int i = 0; i < frameTicks; ++i) {
                const auto beforeTick=runtime.simulationTick;
                advanceSimulationTick(runtime);
                if(runtime.simulationTick==beforeTick)continue;

                if (cybernet::findOrganismById(
                    population,
                    selectedOrganismId) == nullptr) {
                    selectedOrganismId.reset();
                }

                if ((simulationTick % MetricsIntervalTicks) == 0U) {
                    metricHistory.push_back(metrics.latest());
                    chemistryHistory.push_back(chemistry.summary());

                    if ((simulationTick % SynapseSampleIntervalTicks) == 0U) {
                        sampleSynapses(population, synapseSummaries);
                    }

                    if (metricHistory.size() > HistoryCapacity) {
                        metricHistory.pop_front();
                    }
                    if (chemistryHistory.size() > HistoryCapacity) {
                        chemistryHistory.pop_front();
                    }
                }
            }
        }

        const cybernet::Organism* inspectedOrganism =
            cybernet::findOrganismById(population, selectedOrganismId);
        if (showBrainInspector && inspectedOrganism != nullptr) {
            cybernet::ui::UpdateBrainInspectorInteraction(
                brainInspectorState,
                BrainInspectorPanel);
        }

        BeginDrawing();
        ClearBackground(BackgroundColor);

        DrawRectangle(0, 0, WindowWidth, HeaderHeight, HeaderColor);
        DrawText("CYBERNET // ECOSYSTEM VISUALIZER", 18, 17, 22, TextColor);

        DrawText(
            TextFormat(
                "Tick: %u   |   Speed: %d ticks/frame   |   %s",
                simulationTick,
                ticksPerFrame,
                paused ? "PAUSED" : "RUNNING"),
            640,
            19,
            18,
            paused ? ORANGE : Color{90, 230, 150, 255});

        DrawRectangleRec(WorldPanel, PanelColor);
        DrawRectangleLinesEx(WorldPanel, 2.0F, BorderColor);
        DrawWorldGrid(WorldPanel);
        if(geometry && (!geometry->terrainPlanes().empty() || geometry->heightfield())) {
            if(topDownView) {
                for(int y=0;y<20;++y)for(int x=0;x<20;++x) {
                    const float h=geometry->floorHeight((x+.5F)*config::WORLD_SIZE_X/20,(y+.5F)*config::WORLD_SIZE_Y/20);
                    const unsigned char shade=static_cast<unsigned char>(std::clamp(60+h*2,0.F,255.F));
                    DrawRectangleRec({WorldPanel.x+x*WorldPanel.width/20,WorldPanel.y+(19-y)*WorldPanel.height/20,WorldPanel.width/20+1,WorldPanel.height/20+1},Color{shade,shade,70,255});
                }
            } else {
                for(int x=0;x<100;++x) {
                    const float h=geometry->floorHeight((x+.5F)*config::WORLD_SIZE_X/100,config::WORLD_SIZE_Y/2);
                    DrawRectangleRec({WorldPanel.x+x*WorldPanel.width/100,WorldPanel.y+WorldPanel.height*(1-h/config::WORLD_SIZE_Z),WorldPanel.width/100+1,WorldPanel.height*h/config::WORLD_SIZE_Z},Color{110,101,76,255});
                }
                DrawText("Terrain section: pond center; agents projected",static_cast<int>(WorldPanel.x+14),static_cast<int>(WorldPanel.y+36),14,TextColor);
            }
        }
        const auto* displayedGeometry=(live && live->geometry())?live->geometry():(geometry?&*geometry:nullptr);
        if (displayedGeometry) for (const auto& object : displayedGeometry->objects()) {
            Organism proxy{};proxy.position=object.center;
            const Vector2 center=projectPosition(proxy,WorldPanel);
            const float rx=object.halfSize.x/config::WORLD_SIZE_X*WorldPanel.width;
            const float ry=(topDownView ? object.halfSize.y/config::WORLD_SIZE_Y : object.halfSize.z/config::WORLD_SIZE_Z)*WorldPanel.height;
            const Color color=object.id>=0x80000000U?Color{70,220,230,210}:Color{100,115,130,155};
            if(object.shape==GeometryShape::Sphere)
                DrawEllipse(static_cast<int>(center.x),static_cast<int>(center.y),rx,ry,color);
            else DrawRectangleRec({center.x-rx,center.y-ry,2*rx,2*ry},color);
        }


        DrawText(
            topDownView ? "WORLD VIEW — TOP DOWN (X/Y)"
                        : "WORLD VIEW — CROSS SECTION (X/Z)",
            static_cast<int>(WorldPanel.x + 14),
            static_cast<int>(WorldPanel.y + 12),
            18,
            TextColor);

        for (std::size_t organismIndex = 0;
             organismIndex < population.size();
             ++organismIndex) {

            const Organism& organism = population[organismIndex];
            const Vector2 point = projectPosition(organism, WorldPanel);

            if (point.x < WorldPanel.x
                || point.x > WorldPanel.x + WorldPanel.width
                || point.y < WorldPanel.y
                || point.y > WorldPanel.y + WorldPanel.height) {
                continue;
            }

            const float radius = organismRadius(organism.species);

            DrawCircleV(point, radius, organismColor(organism.species));

            if (selectedOrganismId.has_value()
                && organism.id == selectedOrganismId.value()) {
                DrawCircleLinesV(point, radius + 3.0F, WHITE);
            }
        }

        DrawRectangleRec(MetricsPanel, PanelColor);
        DrawRectangleLinesEx(MetricsPanel, 2.0F, BorderColor);

        const int metricsX = static_cast<int>(MetricsPanel.x + 18);
        drawSynapseDashboard(
            synapseSummaries,
            metricsX,
            static_cast<int>(MetricsPanel.y + 16));

        if (showGraphs) {
            const Rectangle graph{
                MetricsPanel.x + 18,
                MetricsPanel.y + 270,
                MetricsPanel.width - 36,
                300
            };

            DrawText(
                     dashboardTab == DashboardTab::Chemicals
                         ? "CHEMISTRY HISTORY (RELATIVE CHANGE)"
                         : "POPULATION HISTORY",
                     static_cast<int>(graph.x),
                     static_cast<int>(graph.y - 28),
                     18,
                     TextColor);

            DrawRectangleLinesEx(graph, 1.0F, Color{35, 85, 120, 255});
            if (dashboardTab == DashboardTab::Chemicals) {
                drawChemistryGraph(chemistryHistory, graph);
            } else {
                drawPopulationGraph(metricHistory, graph);
            }
        }

        const Color organismsTabColor = dashboardTab == DashboardTab::Organisms
            ? Color{43, 128, 185, 255}
            : Color{18, 45, 70, 255};
        const Color chemicalsTabColor = dashboardTab == DashboardTab::Chemicals
            ? Color{43, 128, 185, 255}
            : Color{18, 45, 70, 255};
        const Color controlsTabColor = dashboardTab == DashboardTab::Controls
            ? Color{43, 128, 185, 255}
            : Color{18, 45, 70, 255};

        DrawRectangleRec(organismsTabButton, organismsTabColor);
        DrawRectangleLinesEx(organismsTabButton, 1.0F, BorderColor);
        DrawText("ORGANISMS",
                 static_cast<int>(organismsTabButton.x + 22),
                 static_cast<int>(organismsTabButton.y + 9),
                 13,
                 RAYWHITE);

        DrawRectangleRec(chemicalsTabButton, chemicalsTabColor);
        DrawRectangleLinesEx(chemicalsTabButton, 1.0F, BorderColor);
        DrawText("CHEMICALS",
                 static_cast<int>(chemicalsTabButton.x + 24),
                 static_cast<int>(chemicalsTabButton.y + 9),
                 13,
                 RAYWHITE);

        DrawRectangleRec(controlsTabButton, controlsTabColor);
        DrawRectangleLinesEx(controlsTabButton, 1.0F, BorderColor);
        DrawText("CONTROLS",
             static_cast<int>(controlsTabButton.x + 26),
             static_cast<int>(controlsTabButton.y + 9),
             13,
             RAYWHITE);

        if (dashboardTab == DashboardTab::Organisms) {
            drawOrganismDashboard(
                metrics.latest(),
                static_cast<int>(MetricsPanel.x + 18),
                static_cast<int>(MetricsPanel.y + 646));
        } else if (dashboardTab == DashboardTab::Chemicals) {
            const ChemistrySummary chemistrySummary = chemistry.summary();
            DrawText(
                TextFormat(
                    "DISSOLVED CARBON %.3f   OXYGEN %.3f",
                    chemistrySummary.averageDissolvedCarbon,
                    chemistrySummary.averageOxygen),
                static_cast<int>(MetricsPanel.x + 18),
                static_cast<int>(MetricsPanel.y + 646),
                15,
                TextColor);
            DrawText(
                TextFormat(
                    "AMMONIUM %.3f   NITRATE %.3f   PHOSPHATE %.3f",
                    chemistrySummary.averageAmmonium,
                    chemistrySummary.averageNitrate,
                    chemistrySummary.averagePhosphate),
                static_cast<int>(MetricsPanel.x + 18),
                static_cast<int>(MetricsPanel.y + 672),
                15,
                MutedTextColor);
            DrawText(
                TextFormat(
                    "CONSUMED C %.2f   CONSUMED P %.2f   PRODUCED O2 %.2f",
                    chemistrySummary.totalCarbonConsumed,
                    chemistrySummary.totalPhosphateConsumed,
                    chemistrySummary.totalOxygenProduced),
                static_cast<int>(MetricsPanel.x + 18),
                static_cast<int>(MetricsPanel.y + 698),
                13,
                MutedTextColor);
        } else {
            drawControlsDashboard(
                static_cast<int>(MetricsPanel.x + 18),
                static_cast<int>(MetricsPanel.y + 646));
        }

        const cybernet::Organism* selectedOrganism =
            cybernet::findOrganismById(population, selectedOrganismId);

        if (showBrainInspector && selectedOrganism != nullptr) {
            cybernet::ui::DrawBrainInspector(
                *selectedOrganism,
                BrainInspectorPanel,
                brainInspectorState);
        }

        if (showAdvancedMetrics) {
            drawAdvancedMetrics(metrics.advancedLatest(), metrics.latest());
        }

        EndDrawing();
    }

    CloseWindow();
    if(live)live->checkpoint(population,chemistry,random,simulationTick,nextId,island?&island->biology:nullptr,true);
    #endif
    return 0;
}

