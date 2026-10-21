#include "cybernet/simulation/metrics.hpp"
#include "cybernet/world/spatial_grid.hpp"

#include <algorithm>
#include <cmath>
#include <iomanip>
#include <sstream>
#include <stdexcept>
#include <string>
#include <unordered_set>
#include <utility>

namespace cybernet {
namespace {

constexpr std::size_t SpeciesCount = 3U;
constexpr std::size_t BrainSampleLimitPerSpecies = 24U;
constexpr float AlignmentEpsilon = 0.00001F;

[[nodiscard]] std::size_t speciesIndex(OrganismType species) noexcept {
    return static_cast<std::size_t>(species);
}

[[nodiscard]] const char* speciesName(OrganismType species) noexcept {
    switch (species) {
    case OrganismType::Cyanobacteria:
        return "cyanobacteria";
    case OrganismType::Bacterivore:
        return "bacterivore";
    case OrganismType::BodoSaltans:
        return "bodo_saltans";
    }

    return "unknown";
}

[[nodiscard]] const char* eventName(PopulationEventType type) noexcept {
    return type == PopulationEventType::Birth ? "birth" : "death";
}

[[nodiscard]] const char* deathCauseName(DeathCause cause) noexcept {
    switch (cause) {
    case DeathCause::Starvation:
        return "starvation";
    case DeathCause::Age:
        return "age";
    case DeathCause::Predation:
        return "predation";
    case DeathCause::None:
        return "none";
    }

    return "unknown";
}

[[nodiscard]] float percentage(
    std::size_t numerator,
    std::size_t denominator) noexcept {

    return denominator == 0U
        ? 0.0F
        : (100.0F * static_cast<float>(numerator)
            / static_cast<float>(denominator));
}

[[nodiscard]] float standardDeviation(
    float sum,
    float squareSum,
    std::size_t count) noexcept {

    if (count == 0U) {
        return 0.0F;
    }

    const float mean = sum / static_cast<float>(count);
    const float variance = (squareSum / static_cast<float>(count)) - (mean * mean);
    return std::sqrt(std::max(variance, 0.0F));
}

[[nodiscard]] float actionAlignment(
    const RnnBrain::Outputs& outputs,
    float targetX,
    float targetY,
    float targetZ) noexcept {

    const float actionX =
        (outputs[actionIndex(BrainAction::Strafe)] * 2.0F) - 1.0F;
    const float actionY =
        (outputs[actionIndex(BrainAction::Forward)] * 2.0F) - 1.0F;
    const float actionZ =
        (outputs[actionIndex(BrainAction::Vertical)] * 2.0F) - 1.0F;
    const float actionMagnitude = std::sqrt(
        (actionX * actionX) + (actionY * actionY) + (actionZ * actionZ));
    const float targetMagnitude = std::sqrt(
        (targetX * targetX) + (targetY * targetY) + (targetZ * targetZ));

    if (actionMagnitude <= AlignmentEpsilon || targetMagnitude <= AlignmentEpsilon) {
        return 0.0F;
    }

    return ((actionX * targetX) + (actionY * targetY) + (actionZ * targetZ))
        / (actionMagnitude * targetMagnitude);
}

[[nodiscard]] RnnBrain::Outputs runProbe(
    const Organism& organism,
    const RnnBrain::Inputs& inputs) {

    RnnBrain probe = organism.brain;
    return probe.step(inputs);
}

[[nodiscard]] std::size_t spatialCellIndex(const Vec3& position) noexcept {
    const auto coordinate = [](float value,
                               float worldSize,
                               std::size_t cellCount) noexcept {
        const float normalized = std::clamp(value / worldSize, 0.0F, 0.999999F);
        return static_cast<std::size_t>(
            normalized * static_cast<float>(cellCount));
    };

    const std::size_t x = coordinate(
        position.x,
        config::WORLD_SIZE_X,
        SpatialGrid::GridX);
    const std::size_t y = coordinate(
        position.y,
        config::WORLD_SIZE_Y,
        SpatialGrid::GridY);
    const std::size_t z = coordinate(
        position.z,
        config::WORLD_SIZE_Z,
        SpatialGrid::GridZ);
    return (z * SpatialGrid::GridY * SpatialGrid::GridX)
        + (y * SpatialGrid::GridX) + x;
}

} // namespace

float SpeciesMetrics::averageEnergy() const noexcept {
    return livingCount == 0U
        ? 0.0F
        : totalEnergy / static_cast<float>(livingCount);
}

float SpeciesMetrics::averageAge() const noexcept {
    return livingCount == 0U
        ? 0.0F
        : totalAge / static_cast<float>(livingCount);
}

float SpeciesMetrics::averageSpeed() const noexcept {
    return livingCount == 0U
        ? 0.0F
        : totalSpeed / static_cast<float>(livingCount);
}

float SpeciesMetrics::averageGeneration() const noexcept {
    return livingCount == 0U
        ? 0.0F
        : totalGeneration / static_cast<float>(livingCount);
}

float SpeciesMetrics::averageFoodIntake() const noexcept {
    return livingCount == 0U
        ? 0.0F
        : totalFoodIntake / static_cast<float>(livingCount);
}

float SpeciesMetrics::averageHealth() const noexcept {
    return livingCount == 0U
        ? 0.0F
        : totalHealth / static_cast<float>(livingCount);
}

Metrics::Metrics(
    std::filesystem::path outputDirectory,
    std::uint32_t sampleIntervalTicks,
    std::uint64_t runSeed,
    std::uint32_t worldFrameIntervalTicks,
    std::uint32_t maximumWorldFrames,
    std::uint32_t maximumLineageEvents)
    : sampleIntervalTicks_(std::max(sampleIntervalTicks, 1U)),
      runSeed_(runSeed),
      worldFrameIntervalTicks_(std::max(worldFrameIntervalTicks, 1U)),
            maximumWorldFrames_(std::max(maximumWorldFrames, 1U)),
            maximumLineageEvents_(std::max(maximumLineageEvents, 1U)),
            worldFramesWriter_(outputDirectory / "world_frames.csv"),
            lineageWriter_(outputDirectory / "lineage.csv") {

    std::filesystem::create_directories(outputDirectory);

    metricsFile_.open(outputDirectory / "metrics.csv", std::ios::out | std::ios::trunc);
    evolutionFile_.open(
        outputDirectory / "evolution_metrics.csv",
        std::ios::out | std::ios::trunc);
    behaviorFile_.open(
        outputDirectory / "behavior_metrics.csv",
        std::ios::out | std::ios::trunc);
    learningFile_.open(
        outputDirectory / "learning_metrics.csv",
        std::ios::out | std::ios::trunc);
    benchmarkFile_.open(
        outputDirectory / "benchmark_metrics.csv",
        std::ios::out | std::ios::trunc);
    demographyFile_.open(
        outputDirectory / "demography_metrics.csv",
        std::ios::out | std::ios::trunc);
    energyFlowFile_.open(
        outputDirectory / "energy_flow_metrics.csv",
        std::ios::out | std::ios::trunc);
    mortalityFile_.open(
        outputDirectory / "mortality_metrics.csv",
        std::ios::out | std::ios::trunc);
    reproductionFile_.open(
        outputDirectory / "reproduction_metrics.csv",
        std::ios::out | std::ios::trunc);
    spatialFile_.open(
        outputDirectory / "spatial_metrics.csv",
        std::ios::out | std::ios::trunc);
    traitSelectionFile_.open(
        outputDirectory / "trait_selection_metrics.csv",
        std::ios::out | std::ios::trunc);
    extinctionFile_.open(
        outputDirectory / "extinction_events.csv",
        std::ios::out | std::ios::trunc);
    metadataFile_.open(
        outputDirectory / "run_metadata.csv",
        std::ios::out | std::ios::trunc);

    if (!metricsFile_.is_open()
        || !evolutionFile_.is_open()
        || !behaviorFile_.is_open()
        || !learningFile_.is_open()
        || !benchmarkFile_.is_open()
        || !demographyFile_.is_open()
        || !energyFlowFile_.is_open()
        || !mortalityFile_.is_open()
        || !reproductionFile_.is_open()
        || !spatialFile_.is_open()
        || !traitSelectionFile_.is_open()
        || !extinctionFile_.is_open()
        || !metadataFile_.is_open()) {
        throw std::runtime_error("Unable to create metrics output files.");
    }

    metricsFile_ << std::fixed << std::setprecision(6);
    evolutionFile_ << std::fixed << std::setprecision(6);
    behaviorFile_ << std::fixed << std::setprecision(6);
    learningFile_ << std::fixed << std::setprecision(6);
    benchmarkFile_ << std::fixed << std::setprecision(6);
    demographyFile_ << std::fixed << std::setprecision(6);
    energyFlowFile_ << std::fixed << std::setprecision(6);
    mortalityFile_ << std::fixed << std::setprecision(6);
    reproductionFile_ << std::fixed << std::setprecision(6);
    spatialFile_ << std::fixed << std::setprecision(6);
    traitSelectionFile_ << std::fixed << std::setprecision(6);

    writeHeaders();
    writeRunMetadata();
}

Metrics::~Metrics() {
    metricsFile_.flush();
    evolutionFile_.flush();
    behaviorFile_.flush();
    learningFile_.flush();
    benchmarkFile_.flush();
    demographyFile_.flush();
    energyFlowFile_.flush();
    mortalityFile_.flush();
    reproductionFile_.flush();
    spatialFile_.flush();
    traitSelectionFile_.flush();
    extinctionFile_.flush();
    metadataFile_.flush();
    worldFramesWriter_.close();
    lineageWriter_.close();
}

void Metrics::recordPopulationChanges(const PopulationChanges& changes) {
    birthsSinceLastSample_ += changes.births;
    deathsSinceLastSample_ += changes.deaths;

    for (const PopulationEvent& event : changes.events) {
        DemographyAccumulator& demography = demography_[speciesIndex(event.species)];
        if (event.type == PopulationEventType::Birth) {
            ++demography.births;
            demography.totalParentAgeAtBirth += event.parentAgeTicks;
            speciesHasRecordedBirth_[speciesIndex(event.species)] = true;
            lastBirthTicks_[speciesIndex(event.species)] = event.tick;

            ReproductionAccumulator& reproduction =
                reproduction_[speciesIndex(event.species)];
            ++reproduction.offspringCounts[event.parentId];
            reproduction.totalParentAgeAtBirth += event.parentAgeTicks;
            reproduction.totalMutatedGeneCount += event.mutatedGeneCount;
            reproduction.totalMutationDistance += event.totalMutationDistance;

            TraitSelectionAccumulator& traits =
                traitSelection_[speciesIndex(event.species)];
            ++traits.births;
            traits.totalParentSpeed += event.parentSpeed;
            traits.totalChildSpeed += event.speed;
        } else {
            ++demography.deaths;
            energyFlow_[speciesIndex(event.species)].energyAtDeath += event.energy;

            TraitSelectionAccumulator& traits =
                traitSelection_[speciesIndex(event.species)];
            ++traits.deaths;
            traits.totalDeathSpeed += event.speed;
            traits.totalAgeAtDeath += event.ageTicks;
        }

        if (event.type == PopulationEventType::Death) {
            MortalityAccumulator& mortality = mortality_[speciesIndex(event.species)];
            switch (event.deathCause) {
            case DeathCause::Starvation:
                ++mortality.starvationDeaths;
                break;
            case DeathCause::Age:
                ++mortality.ageDeaths;
                break;
            case DeathCause::Predation:
                ++mortality.predationDeaths;
                break;
            case DeathCause::None:
                break;
            }
        }

        if (lineageEventsWritten_ < maximumLineageEvents_) {
            writeLineageEvent(event);
            ++lineageEventsWritten_;
        }
    }
}

void Metrics::recordBehavior(
    const Organism& organism,
    const LifecycleAction& action) noexcept {

    EnergyFlowAccumulator& energyFlow = energyFlow_[speciesIndex(organism.species)];
    energyFlow.photosyntheticEnergyGained += action.photosyntheticEnergyGained;
    energyFlow.preyEnergyCaptured += action.preyEnergyCaptured;
    energyFlow.predatorEnergyGained += action.predatorEnergyGained;
    energyFlow.movementEnergySpent += action.movementEnergySpent;

    if (!organism.alive()) {
        return;
    }

    BehaviorAccumulator& metrics = behavior_[speciesIndex(organism.species)];
    ++metrics.observations;

    if (action.isAtBoundary) {
        ++metrics.boundaryDwellTicks;
        if (!action.wasAtBoundary) {
            ++metrics.boundaryContacts;
        }
    }

    const float boundaryX = action.inputs[
        inputIndex(BrainInput::BoundaryInwardX)];
    const float boundaryY = action.inputs[
        inputIndex(BrainInput::BoundaryInwardY)];
    const float boundaryZ = action.inputs[
        inputIndex(BrainInput::BoundaryInwardZ)];
    const float boundaryMagnitudeSquared =
        (boundaryX * boundaryX) + (boundaryY * boundaryY) + (boundaryZ * boundaryZ);

    const float actionX =
        (action.outputs[actionIndex(BrainAction::Strafe)] * 2.0F) - 1.0F;
    const float actionY =
        (action.outputs[actionIndex(BrainAction::Forward)] * 2.0F) - 1.0F;
    const float actionZ =
        (action.outputs[actionIndex(BrainAction::Vertical)] * 2.0F) - 1.0F;
    const float actionMagnitudeSquared =
        (actionX * actionX) + (actionY * actionY) + (actionZ * actionZ);

    if (action.inputs[inputIndex(BrainInput::BoundaryProximity)] > 0.20F
        && boundaryMagnitudeSquared > (AlignmentEpsilon * AlignmentEpsilon)
        && actionMagnitudeSquared > (AlignmentEpsilon * AlignmentEpsilon)) {
        ++metrics.boundaryActionSamples;
        const float inwardAlignment =
            (actionX * boundaryX) + (actionY * boundaryY) + (actionZ * boundaryZ);
        if (inwardAlignment > 0.0F) {
            ++metrics.inwardActions;
        }
    }

    if (action.inputs[inputIndex(BrainInput::PreyVisible)] > 0.0F) {
        ++metrics.preyVisibleTicks;
    }

    const float threatX = action.inputs[inputIndex(BrainInput::ThreatX)];
    const float threatY = action.inputs[inputIndex(BrainInput::ThreatY)];
    const float threatZ = action.inputs[inputIndex(BrainInput::ThreatZ)];
    const float threatMagnitudeSquared =
        (threatX * threatX) + (threatY * threatY) + (threatZ * threatZ);

    if (action.inputs[inputIndex(BrainInput::ThreatDensity)] > -1.0F) {
        ++metrics.threatVisibleTicks;
    }

    if (threatMagnitudeSquared > (AlignmentEpsilon * AlignmentEpsilon)
        && actionMagnitudeSquared > (AlignmentEpsilon * AlignmentEpsilon)) {
        ++metrics.threatActionSamples;
        const float threatAlignment =
            (actionX * threatX) + (actionY * threatY) + (actionZ * threatZ);
        if (threatAlignment < 0.0F) {
            ++metrics.threatRetreatActions;
        }
    }

    if (action.feedAttempt >= Ecology::FeedAttemptThreshold) {
        ++metrics.feedAttempts;
        if (action.feedSucceeded) {
            ++metrics.feedSuccesses;
        }
    }

    for (std::size_t output = 0U; output < RnnBrain::OutputCount; ++output) {
        const float value = action.outputs[output];
        metrics.outputSums[output] += value;
        metrics.outputSquareSums[output] += value * value;
        ++metrics.outputValues;
        if (value < 0.05F || value > 0.95F) {
            ++metrics.saturatedOutputs;
        }
    }
}

void Metrics::endTick(
    std::uint32_t tick,
    float daylight,
    float ambientLight,
    const std::vector<Organism>& population) {

    if ((tick % worldFrameIntervalTicks_) == 0U
        && worldFramesWritten_ < maximumWorldFrames_) {
        writeWorldFrame(tick, population);
        ++worldFramesWritten_;
    }

    recordExtinctions(tick, population);

    if ((tick % sampleIntervalTicks_) != 0U) {
        return;
    }

    latest_ = calculatePopulationMetrics(tick, daylight, ambientLight, population);
    latest_.birthsSinceLastSample = birthsSinceLastSample_;
    latest_.deathsSinceLastSample = deathsSinceLastSample_;
    advancedLatest_ = calculateAdvancedMetrics(tick, population);

    writeMetricsRow(latest_);
    writeAdvancedRows(advancedLatest_);
    writeDemographyRows(tick, population);
    writeEnergyFlowRows(tick);
    writeMortalityRows(latest_);
    writeReproductionRows(tick);
    writeSpatialRows(tick, population);
    writeTraitSelectionRows(tick, population);

    birthsSinceLastSample_ = 0U;
    deathsSinceLastSample_ = 0U;
    behavior_ = {};
    demography_ = {};
    energyFlow_ = {};
    mortality_ = {};
    reproduction_ = {};
    traitSelection_ = {};
}

const PopulationMetrics& Metrics::latest() const noexcept {
    return latest_;
}

const AdvancedMetrics& Metrics::advancedLatest() const noexcept {
    return advancedLatest_;
}

void Metrics::writeHeaders() {
    metricsFile_
        << "seed,tick,daylight,ambient_light,total_living,"
        << "births_since_last_sample,deaths_since_last_sample,"
        << "cyanobacteria_count,cyanobacteria_average_energy,"
        << "cyanobacteria_average_age,cyanobacteria_average_speed,"
        << "cyanobacteria_average_generation,cyanobacteria_average_food_intake,"
        << "cyanobacteria_average_health,cyanobacteria_minimum_energy,"
        << "cyanobacteria_maximum_age,"
        << "bacterivore_count,bacterivore_average_energy,"
        << "bacterivore_average_age,bacterivore_average_speed,"
        << "bacterivore_average_generation,bacterivore_average_food_intake,"
        << "bacterivore_average_health,bacterivore_minimum_energy,"
        << "bacterivore_maximum_age,"
        << "bodo_saltans_count,bodo_saltans_average_energy,"
        << "bodo_saltans_average_age,bodo_saltans_average_speed,"
        << "bodo_saltans_average_generation,bodo_saltans_average_food_intake,"
        << "bodo_saltans_average_health,bodo_saltans_minimum_energy,"
        << "bodo_saltans_maximum_age\n";

    worldFramesWriter_.write(
        "tick,id,parent_id,root_ancestor_id,species,generation,birth_tick,"
        "birth_cohort,energy,age_ticks,speed,position_x,position_y,position_z,"
        "velocity_x,velocity_y,velocity_z\n");

    evolutionFile_
        << "seed,tick,species,living_count,average_generation,"
        << "generation_standard_deviation,average_speed,speed_standard_deviation,"
        << "active_lineages,genome_diversity\n";
    behaviorFile_
        << "seed,tick,species,observations,boundary_contacts,"
        << "boundary_dwell_ticks,boundary_contacts_per_thousand,"
        << "boundary_dwell_percent,inward_action_percent,prey_visible_percent,"
        << "threat_visible_percent,feed_attempts,feed_successes,"
        << "feed_precision_percent,threat_retreat_percent\n";
    learningFile_
        << "seed,tick,species,sampled_brains,mean_plastic_weight_magnitude,"
        << "mean_eligibility_trace_magnitude,mean_plastic_weight_update_magnitude,"
        << "mean_modulator_signal,hidden_state_variance,output_variance,"
        << "output_saturation_percent\n";
    benchmarkFile_
        << "seed,tick,species,sampled_brains,boundary_probe_alignment,"
        << "prey_probe_alignment,threat_probe_retreat_alignment\n";
    demographyFile_
        << "seed,tick,species,living_count,biologically_eligible_count,"
        << "births_since_last_sample,deaths_since_last_sample,"
        << "net_population_change,has_recorded_birth,ticks_since_last_birth,"
        << "mean_parent_age_at_birth_since_last_sample\n";
    energyFlowFile_
        << "seed,tick,species,photosynthetic_energy_gained,prey_energy_captured,"
        << "predator_energy_gained,movement_energy_spent,energy_at_death,"
        << "realized_assimilation_percent\n";
    mortalityFile_
        << "seed,tick,species,living_count,starvation_deaths_since_last_sample,"
        << "age_deaths_since_last_sample,predation_deaths_since_last_sample\n";
    reproductionFile_
        << "seed,tick,species,interval_births,parents_with_offspring,"
        << "maximum_offspring_per_parent,offspring_concentration_percent,"
        << "mean_parent_age_at_birth,mean_mutated_gene_count,"
        << "mean_total_mutation_distance\n";
    spatialFile_
        << "seed,tick,species,living_count,occupied_cell_count,"
        << "occupied_cell_percent,occupancy_entropy,mean_depth,"
        << "depth_standard_deviation\n";
    traitSelectionFile_
        << "seed,tick,species,living_count,mean_living_speed,interval_births,"
        << "mean_parent_speed,mean_child_speed,mean_child_parent_speed_change,"
        << "interval_deaths,mean_speed_at_death,mean_age_at_death\n";
    extinctionFile_ << "seed,tick,species,extinction_sequence\n";
    lineageWriter_.write(
        "event,tick,id,parent_id,root_ancestor_id,species,generation,"
        "age_ticks,parent_age_ticks,energy,speed,parent_speed,death_cause,"
        "mutated_gene_count,"
        "total_mutation_distance\n");
    metadataFile_
        << "seed,sample_interval_ticks,world_frame_interval_ticks,"
        << "maximum_world_frames,maximum_lineage_events,"
        << "world_size_x,world_size_y,world_size_z,"
        << "brain_input_count,brain_hidden_count,brain_output_count,genome_size\n";
}

void Metrics::writeRunMetadata() {
    metadataFile_
        << runSeed_ << ','
        << sampleIntervalTicks_ << ','
        << worldFrameIntervalTicks_ << ','
        << maximumWorldFrames_ << ','
        << maximumLineageEvents_ << ','
        << config::WORLD_SIZE_X << ','
        << config::WORLD_SIZE_Y << ','
        << config::WORLD_SIZE_Z << ','
        << RnnBrain::InputCount << ','
        << RnnBrain::HiddenCount << ','
        << RnnBrain::OutputCount << ','
        << GenomeSize << '\n';
}

void Metrics::writeMetricsRow(const PopulationMetrics& metrics) {
    metricsFile_
        << runSeed_ << ',' << metrics.tick << ',' << metrics.daylight << ','
        << metrics.ambientLight << ',' << metrics.totalLiving << ','
        << metrics.birthsSinceLastSample << ',' << metrics.deathsSinceLastSample << ','
        << metrics.cyanobacteria.livingCount << ','
        << metrics.cyanobacteria.averageEnergy() << ','
        << metrics.cyanobacteria.averageAge() << ','
        << metrics.cyanobacteria.averageSpeed() << ','
        << metrics.cyanobacteria.averageGeneration() << ','
        << metrics.cyanobacteria.averageFoodIntake() << ','
        << metrics.cyanobacteria.averageHealth() << ','
        << metrics.cyanobacteria.minimumEnergy << ','
        << metrics.cyanobacteria.maximumAge << ','
        << metrics.bacterivores.livingCount << ','
        << metrics.bacterivores.averageEnergy() << ','
        << metrics.bacterivores.averageAge() << ','
        << metrics.bacterivores.averageSpeed() << ','
        << metrics.bacterivores.averageGeneration() << ','
        << metrics.bacterivores.averageFoodIntake() << ','
        << metrics.bacterivores.averageHealth() << ','
        << metrics.bacterivores.minimumEnergy << ','
        << metrics.bacterivores.maximumAge << ','
        << metrics.bodoSaltans.livingCount << ','
        << metrics.bodoSaltans.averageEnergy() << ','
        << metrics.bodoSaltans.averageAge() << ','
        << metrics.bodoSaltans.averageSpeed() << ','
        << metrics.bodoSaltans.averageGeneration() << ','
        << metrics.bodoSaltans.averageFoodIntake() << ','
        << metrics.bodoSaltans.averageHealth() << ','
        << metrics.bodoSaltans.minimumEnergy << ','
        << metrics.bodoSaltans.maximumAge << '\n';
}

void Metrics::writeAdvancedRows(const AdvancedMetrics& metrics) {
    constexpr std::array<OrganismType, SpeciesCount> species{
        OrganismType::Cyanobacteria,
        OrganismType::Bacterivore,
        OrganismType::BodoSaltans
    };

    for (const OrganismType type : species) {
        const AdvancedSpeciesMetrics& value = metrics.species[speciesIndex(type)];
        const char* name = speciesName(type);

        evolutionFile_
            << runSeed_ << ',' << metrics.tick << ',' << name << ','
            << value.livingCount << ',' << value.averageGeneration << ','
            << value.generationStandardDeviation << ',' << value.averageSpeed << ','
            << value.speedStandardDeviation << ',' << value.activeLineages << ','
            << value.genomeDiversity << '\n';
        behaviorFile_
            << runSeed_ << ',' << metrics.tick << ',' << name << ','
            << behavior_[speciesIndex(type)].observations << ','
            << behavior_[speciesIndex(type)].boundaryContacts << ','
            << behavior_[speciesIndex(type)].boundaryDwellTicks << ','
            << value.boundaryContactsPerThousand << ',' << value.boundaryDwellPercent
            << ',' << value.inwardActionPercent << ',' << value.preyVisiblePercent
            << ',' << value.threatVisiblePercent << ','
            << behavior_[speciesIndex(type)].feedAttempts << ','
            << behavior_[speciesIndex(type)].feedSuccesses << ','
            << value.feedPrecisionPercent << ',' << value.threatRetreatPercent << '\n';
        learningFile_
            << runSeed_ << ',' << metrics.tick << ',' << name << ','
            << value.sampledBrains << ',' << value.meanPlasticWeightMagnitude
            << ',' << value.meanEligibilityTraceMagnitude
            << ',' << value.meanPlasticWeightUpdateMagnitude
            << ',' << value.meanModulatorSignal
            << ',' << value.hiddenStateVariance << ',' << value.outputVariance
            << ',' << value.outputSaturationPercent << '\n';
        benchmarkFile_
            << runSeed_ << ',' << metrics.tick << ',' << name << ','
            << value.sampledBrains << ',' << value.boundaryProbeAlignment << ','
            << value.preyProbeAlignment << ','
            << value.threatProbeRetreatAlignment << '\n';
    }
}

void Metrics::writeMortalityRows(const PopulationMetrics& metrics) {
    constexpr std::array<OrganismType, SpeciesCount> species{
        OrganismType::Cyanobacteria,
        OrganismType::Bacterivore,
        OrganismType::BodoSaltans
    };

    for (const OrganismType type : species) {
        const std::size_t index = speciesIndex(type);
        const std::size_t livingCount = type == OrganismType::Cyanobacteria
            ? metrics.cyanobacteria.livingCount
            : type == OrganismType::Bacterivore
                ? metrics.bacterivores.livingCount
                : metrics.bodoSaltans.livingCount;
        const MortalityAccumulator& mortality = mortality_[index];

        mortalityFile_
            << runSeed_ << ',' << metrics.tick << ',' << speciesName(type) << ','
            << livingCount << ',' << mortality.starvationDeaths << ','
            << mortality.ageDeaths << ',' << mortality.predationDeaths << '\n';
    }
}

void Metrics::writeDemographyRows(
    std::uint32_t tick,
    const std::vector<Organism>& population) {

    std::array<std::size_t, SpeciesCount> livingCounts{};
    std::array<std::size_t, SpeciesCount> eligibleCounts{};

    for (const Organism& organism : population) {
        if (!organism.alive()) {
            continue;
        }

        const std::size_t index = speciesIndex(organism.species);
        ++livingCounts[index];

        const OrganismProfile& profile = organism.profile();
        if (organism.energy >= profile.reproductionEnergy
            && organism.ageTicks >= profile.minimumReproductionAgeTicks
            && organism.reproductionCooldownTicks == 0U) {
            ++eligibleCounts[index];
        }
    }

    constexpr std::array<OrganismType, SpeciesCount> species{
        OrganismType::Cyanobacteria,
        OrganismType::Bacterivore,
        OrganismType::BodoSaltans
    };

    for (const OrganismType type : species) {
        const std::size_t index = speciesIndex(type);
        const DemographyAccumulator& demography = demography_[index];
        const std::uint32_t ticksSinceLastBirth = speciesHasRecordedBirth_[index]
            ? tick - lastBirthTicks_[index]
            : 0U;
        const float meanParentAge = demography.births == 0U
            ? 0.0F
            : static_cast<float>(demography.totalParentAgeAtBirth)
                / static_cast<float>(demography.births);
        const auto netPopulationChange = static_cast<std::int64_t>(demography.births)
            - static_cast<std::int64_t>(demography.deaths);

        demographyFile_
            << runSeed_ << ',' << tick << ',' << speciesName(type) << ','
            << livingCounts[index] << ',' << eligibleCounts[index] << ','
            << demography.births << ',' << demography.deaths << ','
            << netPopulationChange << ','
            << (speciesHasRecordedBirth_[index] ? 1 : 0) << ','
            << ticksSinceLastBirth << ',' << meanParentAge << '\n';
    }
}

void Metrics::writeEnergyFlowRows(std::uint32_t tick) {
    constexpr std::array<OrganismType, SpeciesCount> species{
        OrganismType::Cyanobacteria,
        OrganismType::Bacterivore,
        OrganismType::BodoSaltans
    };

    for (const OrganismType type : species) {
        const EnergyFlowAccumulator& energyFlow = energyFlow_[speciesIndex(type)];
        const float assimilationPercent = energyFlow.preyEnergyCaptured <= 0.0F
            ? 0.0F
            : 100.0F * energyFlow.predatorEnergyGained
                / energyFlow.preyEnergyCaptured;

        energyFlowFile_
            << runSeed_ << ',' << tick << ',' << speciesName(type) << ','
            << energyFlow.photosyntheticEnergyGained << ','
            << energyFlow.preyEnergyCaptured << ','
            << energyFlow.predatorEnergyGained << ','
            << energyFlow.movementEnergySpent << ','
            << energyFlow.energyAtDeath << ',' << assimilationPercent << '\n';
    }
}

void Metrics::writeSpatialRows(
    std::uint32_t tick,
    const std::vector<Organism>& population) {

    std::array<
        std::array<std::size_t, SpatialGrid::CellCount>,
        SpeciesCount> cellCounts{};
    std::array<std::size_t, SpeciesCount> livingCounts{};
    std::array<float, SpeciesCount> depthSums{};
    std::array<float, SpeciesCount> depthSquareSums{};

    for (const Organism& organism : population) {
        if (!organism.alive()) {
            continue;
        }

        const std::size_t index = speciesIndex(organism.species);
        ++livingCounts[index];
        ++cellCounts[index][spatialCellIndex(organism.position)];
        depthSums[index] += organism.position.z;
        depthSquareSums[index] += organism.position.z * organism.position.z;
    }

    constexpr std::array<OrganismType, SpeciesCount> species{
        OrganismType::Cyanobacteria,
        OrganismType::Bacterivore,
        OrganismType::BodoSaltans
    };

    for (const OrganismType type : species) {
        const std::size_t index = speciesIndex(type);
        const std::size_t livingCount = livingCounts[index];
        std::size_t occupiedCells = 0U;
        float entropy = 0.0F;

        for (const std::size_t cellCount : cellCounts[index]) {
            if (cellCount == 0U) {
                continue;
            }

            ++occupiedCells;
            const float probability = static_cast<float>(cellCount)
                / static_cast<float>(livingCount);
            entropy -= probability * std::log(probability);
        }

        const float occupiedCellPercent = 100.0F * static_cast<float>(occupiedCells)
            / static_cast<float>(SpatialGrid::CellCount);
        const float meanDepth = livingCount == 0U
            ? 0.0F
            : depthSums[index] / static_cast<float>(livingCount);
        const float depthStandardDeviation = standardDeviation(
            depthSums[index],
            depthSquareSums[index],
            livingCount);

        spatialFile_
            << runSeed_ << ',' << tick << ',' << speciesName(type) << ','
            << livingCount << ',' << occupiedCells << ',' << occupiedCellPercent
            << ',' << entropy << ',' << meanDepth << ','
            << depthStandardDeviation << '\n';
    }
}

void Metrics::writeReproductionRows(std::uint32_t tick) {
    constexpr std::array<OrganismType, SpeciesCount> species{
        OrganismType::Cyanobacteria,
        OrganismType::Bacterivore,
        OrganismType::BodoSaltans
    };

    for (const OrganismType type : species) {
        const ReproductionAccumulator& reproduction =
            reproduction_[speciesIndex(type)];
        std::size_t intervalBirths = 0U;
        std::size_t maximumOffspring = 0U;
        for (const auto& [parentId, offspringCount] : reproduction.offspringCounts) {
            static_cast<void>(parentId);
            intervalBirths += offspringCount;
            maximumOffspring = std::max(maximumOffspring, offspringCount);
        }

        const float offspringConcentration = intervalBirths == 0U
            ? 0.0F
            : 100.0F * static_cast<float>(maximumOffspring)
                / static_cast<float>(intervalBirths);
        const float meanParentAge = intervalBirths == 0U
            ? 0.0F
            : static_cast<float>(reproduction.totalParentAgeAtBirth)
                / static_cast<float>(intervalBirths);
        const float meanMutatedGeneCount = intervalBirths == 0U
            ? 0.0F
            : static_cast<float>(reproduction.totalMutatedGeneCount)
                / static_cast<float>(intervalBirths);
        const float meanMutationDistance = intervalBirths == 0U
            ? 0.0F
            : reproduction.totalMutationDistance / static_cast<float>(intervalBirths);

        reproductionFile_
            << runSeed_ << ',' << tick << ',' << speciesName(type) << ','
            << intervalBirths << ',' << reproduction.offspringCounts.size() << ','
            << maximumOffspring << ',' << offspringConcentration << ','
            << meanParentAge << ',' << meanMutatedGeneCount << ','
            << meanMutationDistance << '\n';
    }
}

void Metrics::writeTraitSelectionRows(
    std::uint32_t tick,
    const std::vector<Organism>& population) {

    std::array<std::size_t, SpeciesCount> livingCounts{};
    std::array<float, SpeciesCount> livingSpeedSums{};

    for (const Organism& organism : population) {
        if (!organism.alive()) {
            continue;
        }

        const std::size_t index = speciesIndex(organism.species);
        ++livingCounts[index];
        livingSpeedSums[index] += organism.speed;
    }

    constexpr std::array<OrganismType, SpeciesCount> species{
        OrganismType::Cyanobacteria,
        OrganismType::Bacterivore,
        OrganismType::BodoSaltans
    };

    for (const OrganismType type : species) {
        const std::size_t index = speciesIndex(type);
        const TraitSelectionAccumulator& traits = traitSelection_[index];
        const float meanLivingSpeed = livingCounts[index] == 0U
            ? 0.0F
            : livingSpeedSums[index] / static_cast<float>(livingCounts[index]);
        const float meanParentSpeed = traits.births == 0U
            ? 0.0F
            : traits.totalParentSpeed / static_cast<float>(traits.births);
        const float meanChildSpeed = traits.births == 0U
            ? 0.0F
            : traits.totalChildSpeed / static_cast<float>(traits.births);
        const float meanDeathSpeed = traits.deaths == 0U
            ? 0.0F
            : traits.totalDeathSpeed / static_cast<float>(traits.deaths);
        const float meanAgeAtDeath = traits.deaths == 0U
            ? 0.0F
            : static_cast<float>(traits.totalAgeAtDeath)
                / static_cast<float>(traits.deaths);

        traitSelectionFile_
            << runSeed_ << ',' << tick << ',' << speciesName(type) << ','
            << livingCounts[index] << ',' << meanLivingSpeed << ','
            << traits.births << ',' << meanParentSpeed << ',' << meanChildSpeed
            << ',' << meanChildSpeed - meanParentSpeed << ',' << traits.deaths
            << ',' << meanDeathSpeed << ',' << meanAgeAtDeath << '\n';
    }
}

void Metrics::recordExtinctions(
    std::uint32_t tick,
    const std::vector<Organism>& population) {

    std::array<std::size_t, SpeciesCount> livingCounts{};
    for (const Organism& organism : population) {
        if (organism.alive()) {
            ++livingCounts[speciesIndex(organism.species)];
        }
    }

    for (std::size_t index = 0U; index < SpeciesCount; ++index) {
        if (livingCounts[index] > 0U) {
            speciesObserved_[index] = true;
            speciesExtinct_[index] = false;
            continue;
        }

        if (speciesObserved_[index] && !speciesExtinct_[index]) {
            speciesExtinct_[index] = true;
            ++extinctionSequences_[index];
            writeExtinctionEvent(
                tick,
                static_cast<OrganismType>(index),
                extinctionSequences_[index]);
        }
    }
}

void Metrics::writeExtinctionEvent(
    std::uint32_t tick,
    OrganismType species,
    std::uint32_t sequence) {

    extinctionFile_ << runSeed_ << ',' << tick << ',' << speciesName(species)
        << ',' << sequence << '\n';
}

void Metrics::writeLineageEvent(const PopulationEvent& event) {
    std::ostringstream record{};
    record << std::fixed << std::setprecision(6)
        << eventName(event.type) << ',' << event.tick << ',' << event.id << ','
        << event.parentId << ',' << event.rootAncestorId << ','
        << speciesName(event.species) << ',' << event.generation << ','
        << event.ageTicks << ',' << event.parentAgeTicks << ',' << event.energy
        << ',' << event.speed << ',' << event.parentSpeed << ','
        << deathCauseName(event.deathCause) << ','
        << event.mutatedGeneCount << ',' << event.totalMutationDistance << '\n';
    lineageWriter_.write(record.str());
}

void Metrics::writeWorldFrame(
    std::uint32_t tick,
    const std::vector<Organism>& population) {

    for (const Organism& organism : population) {
        if (!organism.alive()) {
            continue;
        }

        std::ostringstream record{};
        record << std::fixed << std::setprecision(6)
            << tick << ',' << organism.id << ',' << organism.parentId << ','
            << organism.rootAncestorId << ',' << speciesName(organism.species) << ','
            << organism.generation << ',' << organism.birthTick << ','
            << organism.birthCohort << ',' << organism.energy << ','
            << organism.ageTicks << ',' << organism.speed << ','
            << organism.position.x << ',' << organism.position.y << ','
            << organism.position.z << ',' << organism.velocity.x << ','
            << organism.velocity.y << ',' << organism.velocity.z << '\n';
        worldFramesWriter_.write(record.str());
    }
}

PopulationMetrics Metrics::calculatePopulationMetrics(
    std::uint32_t tick,
    float daylight,
    float ambientLight,
    const std::vector<Organism>& population) {

    PopulationMetrics result{};
    result.tick = tick;
    result.daylight = daylight;
    result.ambientLight = ambientLight;

    for (const Organism& organism : population) {
        if (!organism.alive()) {
            continue;
        }

        SpeciesMetrics& speciesMetrics = metricsForSpecies(result, organism.species);
        ++result.totalLiving;
        ++speciesMetrics.livingCount;
        speciesMetrics.totalEnergy += organism.energy;
        speciesMetrics.totalAge += static_cast<float>(organism.ageTicks);
        speciesMetrics.totalSpeed += organism.speed;
        speciesMetrics.totalGeneration += static_cast<float>(organism.generation);
        speciesMetrics.totalFoodIntake += organism.foodIntake;
        speciesMetrics.totalHealth += organism.health;
        speciesMetrics.minimumEnergy = speciesMetrics.livingCount == 1U
            ? organism.energy
            : std::min(speciesMetrics.minimumEnergy, organism.energy);
        speciesMetrics.maximumAge = std::max(
            speciesMetrics.maximumAge,
            organism.ageTicks);
    }

    return result;
}

AdvancedMetrics Metrics::calculateAdvancedMetrics(
    std::uint32_t tick,
    const std::vector<Organism>& population) const {

    AdvancedMetrics result{};
    result.tick = tick;
    result.lineageEventsWritten = lineageEventsWritten_;
    result.maximumLineageEvents = maximumLineageEvents_;
    std::array<float, SpeciesCount> generationSums{};
    std::array<float, SpeciesCount> generationSquareSums{};
    std::array<float, SpeciesCount> speedSums{};
    std::array<float, SpeciesCount> speedSquareSums{};
    std::array<std::unordered_set<std::uint32_t>, SpeciesCount> lineages{};

    for (const Organism& organism : population) {
        if (!organism.alive()) {
            continue;
        }

        const std::size_t index = speciesIndex(organism.species);
        AdvancedSpeciesMetrics& metrics = result.species[index];
        ++metrics.livingCount;
        generationSums[index] += static_cast<float>(organism.generation);
        generationSquareSums[index] +=
            static_cast<float>(organism.generation * organism.generation);
        speedSums[index] += organism.speed;
        speedSquareSums[index] += organism.speed * organism.speed;
        lineages[index].insert(organism.rootAncestorId);
    }

    for (std::size_t index = 0U; index < SpeciesCount; ++index) {
        AdvancedSpeciesMetrics& metrics = result.species[index];
        metrics.averageGeneration = metrics.livingCount == 0U
            ? 0.0F
            : generationSums[index] / static_cast<float>(metrics.livingCount);
        metrics.generationStandardDeviation = standardDeviation(
            generationSums[index],
            generationSquareSums[index],
            metrics.livingCount);
        metrics.averageSpeed = metrics.livingCount == 0U
            ? 0.0F
            : speedSums[index] / static_cast<float>(metrics.livingCount);
        metrics.speedStandardDeviation = standardDeviation(
            speedSums[index],
            speedSquareSums[index],
            metrics.livingCount);
        metrics.activeLineages = lineages[index].size();

        const BehaviorAccumulator& behavior = behavior_[index];
        metrics.boundaryContactsPerThousand = behavior.observations == 0U
            ? 0.0F
            : (1000.0F * static_cast<float>(behavior.boundaryContacts)
                / static_cast<float>(behavior.observations));
        metrics.boundaryDwellPercent = percentage(
            behavior.boundaryDwellTicks,
            behavior.observations);
        metrics.inwardActionPercent = percentage(
            behavior.inwardActions,
            behavior.boundaryActionSamples);
        metrics.preyVisiblePercent = percentage(
            behavior.preyVisibleTicks,
            behavior.observations);
        metrics.threatVisiblePercent = percentage(
            behavior.threatVisibleTicks,
            behavior.observations);
        metrics.feedPrecisionPercent = percentage(
            behavior.feedSuccesses,
            behavior.feedAttempts);
        metrics.threatRetreatPercent = percentage(
            behavior.threatRetreatActions,
            behavior.threatActionSamples);
        metrics.outputSaturationPercent = percentage(
            behavior.saturatedOutputs,
            behavior.outputValues);
    }

    std::array<std::vector<const Organism*>, SpeciesCount> samples{};
    std::array<std::size_t, SpeciesCount> seen{};

    for (const Organism& organism : population) {
        if (!organism.alive()) {
            continue;
        }

        const std::size_t index = speciesIndex(organism.species);
        const std::size_t livingCount = result.species[index].livingCount;
        const std::size_t targetCount = std::min(
            livingCount,
            BrainSampleLimitPerSpecies);
        const std::size_t rank = seen[index]++;

        if (((rank + 1U) * targetCount) / livingCount
            != (rank * targetCount) / livingCount) {
            samples[index].push_back(&organism);
        }
    }

    for (std::size_t index = 0U; index < SpeciesCount; ++index) {
        AdvancedSpeciesMetrics& metrics = result.species[index];
        const std::vector<const Organism*>& sample = samples[index];
        metrics.sampledBrains = sample.size();
        if (sample.empty()) {
            continue;
        }

        float plasticMagnitudeSum = 0.0F;
        std::size_t plasticWeightCount = 0U;
        float eligibilityTraceMagnitudeSum = 0.0F;
        float plasticWeightUpdateMagnitudeSum = 0.0F;
        float modulatorSignalSum = 0.0F;
        float hiddenSum = 0.0F;
        float hiddenSquareSum = 0.0F;
        std::size_t hiddenCount = 0U;
        float outputSum = 0.0F;
        float outputSquareSum = 0.0F;
        std::size_t outputCount = 0U;
        float boundaryProbeSum = 0.0F;
        float preyProbeSum = 0.0F;
        float threatProbeSum = 0.0F;

        RnnBrain::Inputs boundaryProbeInputs{};
        boundaryProbeInputs[inputIndex(BrainInput::BoundaryInwardX)] = 1.0F;
        boundaryProbeInputs[inputIndex(BrainInput::BoundaryProximity)] = 1.0F;
        boundaryProbeInputs[inputIndex(BrainInput::Bias)] = 1.0F;
        RnnBrain::Inputs preyProbeInputs{};
        preyProbeInputs[inputIndex(BrainInput::PreyX)] = 1.0F;
        preyProbeInputs[inputIndex(BrainInput::PreyDistance)] = -1.0F;
        preyProbeInputs[inputIndex(BrainInput::PreyVisible)] = 1.0F;
        preyProbeInputs[inputIndex(BrainInput::Bias)] = 1.0F;
        RnnBrain::Inputs threatProbeInputs{};
        threatProbeInputs[inputIndex(BrainInput::ThreatX)] = 1.0F;
        threatProbeInputs[inputIndex(BrainInput::ThreatDistance)] = -1.0F;
        threatProbeInputs[inputIndex(BrainInput::ThreatDensity)] = 1.0F;
        threatProbeInputs[inputIndex(BrainInput::Bias)] = 1.0F;

        for (const Organism* organism : sample) {
            const RnnBrain::InspectionSnapshot snapshot =
                organism->brain.inspectionSnapshot();
            for (std::size_t weightIndex = 0U;
                 weightIndex < snapshot.plasticWeights.size();
                 ++weightIndex) {
                const float weight = snapshot.plasticWeights[weightIndex];
                plasticMagnitudeSum += std::abs(weight);
                eligibilityTraceMagnitudeSum += std::abs(
                    snapshot.eligibilityTraces[weightIndex]);
                plasticWeightUpdateMagnitudeSum += std::abs(
                    snapshot.lastPlasticWeightUpdates[weightIndex]);
                ++plasticWeightCount;
            }
            modulatorSignalSum += snapshot.modulatorSignal;
            for (const float hidden : organism->brain.hiddenState()) {
                hiddenSum += hidden;
                hiddenSquareSum += hidden * hidden;
                ++hiddenCount;
            }
            for (const float output : organism->brain.outputState()) {
                outputSum += output;
                outputSquareSum += output * output;
                ++outputCount;
            }

            boundaryProbeSum += actionAlignment(
                runProbe(*organism, boundaryProbeInputs),
                1.0F,
                0.0F,
                0.0F);
            preyProbeSum += actionAlignment(
                runProbe(*organism, preyProbeInputs),
                1.0F,
                0.0F,
                0.0F);
            threatProbeSum += actionAlignment(
                runProbe(*organism, threatProbeInputs),
                -1.0F,
                0.0F,
                0.0F);
        }

        metrics.meanPlasticWeightMagnitude = plasticWeightCount == 0U
            ? 0.0F
            : plasticMagnitudeSum / static_cast<float>(plasticWeightCount);
        metrics.meanEligibilityTraceMagnitude = plasticWeightCount == 0U
            ? 0.0F
            : eligibilityTraceMagnitudeSum / static_cast<float>(plasticWeightCount);
        metrics.meanPlasticWeightUpdateMagnitude = plasticWeightCount == 0U
            ? 0.0F
            : plasticWeightUpdateMagnitudeSum / static_cast<float>(plasticWeightCount);
        metrics.meanModulatorSignal = modulatorSignalSum
            / static_cast<float>(sample.size());
        const float hiddenMean = hiddenSum / static_cast<float>(hiddenCount);
        metrics.hiddenStateVariance = std::max(
            (hiddenSquareSum / static_cast<float>(hiddenCount))
                - (hiddenMean * hiddenMean),
            0.0F);
        const float outputMean = outputSum / static_cast<float>(outputCount);
        metrics.outputVariance = std::max(
            (outputSquareSum / static_cast<float>(outputCount))
                - (outputMean * outputMean),
            0.0F);
        metrics.boundaryProbeAlignment =
            boundaryProbeSum / static_cast<float>(sample.size());
        metrics.preyProbeAlignment =
            preyProbeSum / static_cast<float>(sample.size());
        metrics.threatProbeRetreatAlignment =
            threatProbeSum / static_cast<float>(sample.size());

        if (sample.size() > 1U) {
            float totalDifference = 0.0F;
            std::size_t pairCount = 0U;
            for (std::size_t left = 0U; left < sample.size(); ++left) {
                for (std::size_t right = left + 1U;
                     right < sample.size();
                     ++right) {
                    float pairDifference = 0.0F;
                    for (std::size_t gene = 0U;
                         gene < GenomeSize;
                         ++gene) {
                        pairDifference += std::abs(
                            sample[left]->genome[gene]
                            - sample[right]->genome[gene]);
                    }
                    totalDifference += pairDifference
                        / static_cast<float>(GenomeSize);
                    ++pairCount;
                }
            }
            metrics.genomeDiversity = totalDifference / static_cast<float>(pairCount);
        }
    }

    return result;
}

SpeciesMetrics& Metrics::metricsForSpecies(
    PopulationMetrics& metrics,
    OrganismType species) noexcept {

    switch (species) {
    case OrganismType::Cyanobacteria:
        return metrics.cyanobacteria;
    case OrganismType::Bacterivore:
        return metrics.bacterivores;
    case OrganismType::BodoSaltans:
        return metrics.bodoSaltans;
    }

    return metrics.cyanobacteria;
}

} // namespace cybernet