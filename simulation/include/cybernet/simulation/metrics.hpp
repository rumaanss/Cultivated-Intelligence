#pragma once

#include "cybernet/simulation/async_record_writer.hpp"
#include "cybernet/simulation/organism.hpp"
#include "cybernet/simulation/simulation.hpp"
#include "cybernet/simulation/lifecycle.hpp"
#include "cybernet/world/ecology.hpp"

#include <array>
#include <cstddef>
#include <cstdint>
#include <filesystem>
#include <fstream>
#include <unordered_map>
#include <vector>

namespace cybernet {

struct SpeciesMetrics {
    std::size_t livingCount{0};
    float totalEnergy{0.0F};
    float totalAge{0.0F};
    float totalSpeed{0.0F};
    float totalGeneration{0.0F};
    float totalFoodIntake{0.0F};
    float totalHealth{0.0F};
    float minimumEnergy{0.0F};
    std::uint32_t maximumAge{0};

    float averageEnergy() const noexcept;
    float averageAge() const noexcept;
    float averageSpeed() const noexcept;
    float averageGeneration() const noexcept;
    float averageFoodIntake() const noexcept;
    float averageHealth() const noexcept;
};

struct PopulationMetrics {
    std::uint32_t tick{0};
    float daylight{0.0F};
    float ambientLight{0.0F};

    SpeciesMetrics cyanobacteria{};
    SpeciesMetrics bacterivores{};
    SpeciesMetrics bodoSaltans{};

    std::size_t totalLiving{0};
    std::size_t birthsSinceLastSample{0};
    std::size_t deathsSinceLastSample{0};
};

struct AdvancedSpeciesMetrics {
    std::size_t livingCount{0U};
    std::size_t activeLineages{0U};
    std::size_t sampledBrains{0U};
    float averageGeneration{0.0F};
    float generationStandardDeviation{0.0F};
    float averageSpeed{0.0F};
    float speedStandardDeviation{0.0F};
    float genomeDiversity{0.0F};
    float boundaryContactsPerThousand{0.0F};
    float boundaryDwellPercent{0.0F};
    float inwardActionPercent{0.0F};
    float preyVisiblePercent{0.0F};
    float threatVisiblePercent{0.0F};
    float feedPrecisionPercent{0.0F};
    float threatRetreatPercent{0.0F};
    float meanPlasticWeightMagnitude{0.0F};
    float meanEligibilityTraceMagnitude{0.0F};
    float meanPlasticWeightUpdateMagnitude{0.0F};
    float meanModulatorSignal{0.0F};
    float hiddenStateVariance{0.0F};
    float outputVariance{0.0F};
    float outputSaturationPercent{0.0F};
    float boundaryProbeAlignment{0.0F};
    float preyProbeAlignment{0.0F};
    float threatProbeRetreatAlignment{0.0F};
};

struct AdvancedMetrics {
    std::uint32_t tick{0U};
    std::uint32_t lineageEventsWritten{0U};
    std::uint32_t maximumLineageEvents{0U};
    std::array<AdvancedSpeciesMetrics, 3U> species{};
};

class Metrics {
public:
    explicit Metrics(
        std::filesystem::path outputDirectory = "output",
        std::uint32_t sampleIntervalTicks = 100U,
        std::uint64_t runSeed = 0U,
        std::uint32_t worldFrameIntervalTicks =
            config::DEFAULT_WORLD_FRAME_INTERVAL_TICKS,
        std::uint32_t maximumWorldFrames =
            config::DEFAULT_MAXIMUM_WORLD_FRAMES,
        std::uint32_t maximumLineageEvents =
            config::DEFAULT_MAXIMUM_LINEAGE_EVENTS);

    ~Metrics();

    Metrics(const Metrics&) = delete;
    Metrics& operator=(const Metrics&) = delete;

    void recordPopulationChanges(const PopulationChanges& changes);

    void recordBehavior(
        const Organism& organism,
        const LifecycleAction& action) noexcept;

    void endTick(
        std::uint32_t tick,
        float daylight,
        float ambientLight,
        const std::vector<Organism>& population);

    [[nodiscard]] const PopulationMetrics& latest() const noexcept;
    [[nodiscard]] const AdvancedMetrics& advancedLatest() const noexcept;

private:
    struct BehaviorAccumulator {
        std::size_t observations{0U};
        std::size_t boundaryContacts{0U};
        std::size_t boundaryDwellTicks{0U};
        std::size_t boundaryActionSamples{0U};
        std::size_t inwardActions{0U};
        std::size_t preyVisibleTicks{0U};
        std::size_t threatVisibleTicks{0U};
        std::size_t feedAttempts{0U};
        std::size_t feedSuccesses{0U};
        std::size_t threatActionSamples{0U};
        std::size_t threatRetreatActions{0U};
        std::array<float, RnnBrain::OutputCount> outputSums{};
        std::array<float, RnnBrain::OutputCount> outputSquareSums{};
        std::size_t outputValues{0U};
        std::size_t saturatedOutputs{0U};
    };

    struct MortalityAccumulator {
        std::size_t starvationDeaths{0U};
        std::size_t ageDeaths{0U};
        std::size_t predationDeaths{0U};
    };

    struct DemographyAccumulator {
        std::size_t births{0U};
        std::size_t deaths{0U};
        std::uint64_t totalParentAgeAtBirth{0U};
    };

    struct EnergyFlowAccumulator {
        float photosyntheticEnergyGained{0.0F};
        float preyEnergyCaptured{0.0F};
        float predatorEnergyGained{0.0F};
        float movementEnergySpent{0.0F};
        float energyAtDeath{0.0F};
    };

    struct ReproductionAccumulator {
        std::unordered_map<std::uint32_t, std::size_t> offspringCounts{};
        std::uint64_t totalParentAgeAtBirth{0U};
        std::uint64_t totalMutatedGeneCount{0U};
        float totalMutationDistance{0.0F};
    };

    struct TraitSelectionAccumulator {
        std::size_t births{0U};
        std::size_t deaths{0U};
        float totalParentSpeed{0.0F};
        float totalChildSpeed{0.0F};
        float totalDeathSpeed{0.0F};
        std::uint64_t totalAgeAtDeath{0U};
    };

    void writeHeaders();
    void writeRunMetadata();
    void writeMetricsRow(const PopulationMetrics& metrics);
    void writeAdvancedRows(const AdvancedMetrics& metrics);
    void writeDemographyRows(
        std::uint32_t tick,
        const std::vector<Organism>& population);
    void writeEnergyFlowRows(std::uint32_t tick);
    void writeMortalityRows(const PopulationMetrics& metrics);
    void writeReproductionRows(std::uint32_t tick);
    void writeSpatialRows(
        std::uint32_t tick,
        const std::vector<Organism>& population);
    void writeTraitSelectionRows(
        std::uint32_t tick,
        const std::vector<Organism>& population);
    void recordExtinctions(
        std::uint32_t tick,
        const std::vector<Organism>& population);
    void writeExtinctionEvent(
        std::uint32_t tick,
        OrganismType species,
        std::uint32_t sequence);
    void writeLineageEvent(const PopulationEvent& event);
    void writeWorldFrame(
        std::uint32_t tick,
        const std::vector<Organism>& population);

    [[nodiscard]] static PopulationMetrics calculatePopulationMetrics(
        std::uint32_t tick,
        float daylight,
        float ambientLight,
        const std::vector<Organism>& population);

    [[nodiscard]] AdvancedMetrics calculateAdvancedMetrics(
        std::uint32_t tick,
        const std::vector<Organism>& population) const;

    [[nodiscard]] static SpeciesMetrics& metricsForSpecies(
        PopulationMetrics& metrics,
        OrganismType species) noexcept;

    std::uint32_t sampleIntervalTicks_{100U};
    std::uint64_t runSeed_{0U};
    std::uint32_t worldFrameIntervalTicks_{
        config::DEFAULT_WORLD_FRAME_INTERVAL_TICKS};
    std::uint32_t maximumWorldFrames_{
        config::DEFAULT_MAXIMUM_WORLD_FRAMES};
    std::uint32_t worldFramesWritten_{0U};
    std::uint32_t maximumLineageEvents_{
        config::DEFAULT_MAXIMUM_LINEAGE_EVENTS};
    std::uint32_t lineageEventsWritten_{0U};

    std::ofstream metricsFile_{};
    std::ofstream evolutionFile_{};
    std::ofstream behaviorFile_{};
    std::ofstream learningFile_{};
    std::ofstream benchmarkFile_{};
    std::ofstream demographyFile_{};
    std::ofstream energyFlowFile_{};
    std::ofstream mortalityFile_{};
    std::ofstream reproductionFile_{};
    std::ofstream spatialFile_{};
    std::ofstream traitSelectionFile_{};
    std::ofstream extinctionFile_{};
    std::ofstream metadataFile_{};
    AsyncRecordWriter worldFramesWriter_;
    AsyncRecordWriter lineageWriter_;

    std::size_t birthsSinceLastSample_{0};
    std::size_t deathsSinceLastSample_{0};
    std::array<BehaviorAccumulator, 3U> behavior_{};
    std::array<DemographyAccumulator, 3U> demography_{};
    std::array<bool, 3U> speciesHasRecordedBirth_{};
    std::array<std::uint32_t, 3U> lastBirthTicks_{};
    std::array<EnergyFlowAccumulator, 3U> energyFlow_{};
    std::array<MortalityAccumulator, 3U> mortality_{};
    std::array<ReproductionAccumulator, 3U> reproduction_{};
    std::array<TraitSelectionAccumulator, 3U> traitSelection_{};
    std::array<bool, 3U> speciesObserved_{};
    std::array<bool, 3U> speciesExtinct_{};
    std::array<std::uint32_t, 3U> extinctionSequences_{};

    PopulationMetrics latest_{};
    AdvancedMetrics advancedLatest_{};
};

} // namespace cybernet
