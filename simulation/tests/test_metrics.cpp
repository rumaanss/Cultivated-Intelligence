#include "cybernet/simulation/metrics.hpp"

#ifdef NDEBUG
#undef NDEBUG
#endif

#include <cassert>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <string>
#include <vector>

int main() {
    const std::filesystem::path outputDirectory = "test_metrics_output";
    std::filesystem::remove_all(outputDirectory);

    {
        cybernet::Metrics metrics{outputDirectory, 1U, 98765U, 2U, 1U, 1U};
        std::vector<cybernet::Organism> population(1U);
        population[0].id = 1U;
        population[0].position = {50.0F, 50.0F, 30.0F};
        population[0].energy = population[0].profile().reproductionEnergy;
        population[0].ageTicks = population[0].profile().minimumReproductionAgeTicks;
        cybernet::PopulationChanges changes{};
        changes.births = 2U;
        changes.deaths = 1U;
        changes.events.push_back({
            .type = cybernet::PopulationEventType::Birth,
            .id = 2U,
            .parentId = 1U,
            .rootAncestorId = 1U,
            .species = cybernet::OrganismType::Cyanobacteria,
            .generation = 1U,
            .tick = 1U,
            .ageTicks = 0U,
            .parentAgeTicks = 42U,
            .mutatedGeneCount = 3U,
            .energy = 20.0F,
            .speed = 0.3F,
            .parentSpeed = 0.2F,
            .totalMutationDistance = 0.25F
        });
        changes.events.push_back({
            .type = cybernet::PopulationEventType::Death,
            .id = 3U,
            .parentId = 0U,
            .rootAncestorId = 3U,
            .species = cybernet::OrganismType::Cyanobacteria,
            .generation = 0U,
            .tick = 1U,
            .ageTicks = 100U,
            .energy = 0.0F,
            .speed = 0.4F,
            .deathCause = cybernet::DeathCause::Starvation
        });
        metrics.recordPopulationChanges(changes);
        cybernet::LifecycleAction action{};
        action.inputs[cybernet::inputIndex(
            cybernet::BrainInput::BoundaryInwardX)] = 1.0F;
        action.inputs[cybernet::inputIndex(
            cybernet::BrainInput::BoundaryProximity)] = 1.0F;
        action.inputs[cybernet::inputIndex(
            cybernet::BrainInput::PreyVisible)] = 1.0F;
        action.inputs[cybernet::inputIndex(
            cybernet::BrainInput::ThreatX)] = 1.0F;
        action.inputs[cybernet::inputIndex(
            cybernet::BrainInput::ThreatDensity)] = 0.0F;
        action.outputs[cybernet::actionIndex(
            cybernet::BrainAction::Strafe)] = 1.0F;
        action.feedAttempt = 1.0F;
        action.feedSucceeded = true;
        action.photosyntheticEnergyGained = 1.5F;
        action.preyEnergyCaptured = 10.0F;
        action.predatorEnergyGained = 7.5F;
        action.movementEnergySpent = 0.25F;
        action.isAtBoundary = true;
        metrics.recordBehavior(population[0], action);
        metrics.endTick(1U, 1.0F, 1.0F, population);
        metrics.endTick(2U, 1.0F, 1.0F, population);
        population.clear();
        metrics.endTick(3U, 1.0F, 1.0F, population);
    }

    std::ifstream metricsFile{outputDirectory / "metrics.csv"};
    std::string header{};
    std::string row{};
    std::getline(metricsFile, header);
    std::getline(metricsFile, row);

    assert(header.starts_with("seed,tick,"));
    assert(row.starts_with("98765,1,1.000000,1.000000,1,2,1,"));

    metricsFile.close();

    std::ifstream framesFile{outputDirectory / "world_frames.csv"};
    std::string frameHeader{};
    std::string frame{};
    std::string extraFrame{};
    std::getline(framesFile, frameHeader);
    std::getline(framesFile, frame);
    std::getline(framesFile, extraFrame);

    assert(frameHeader.starts_with("tick,id,"));
    assert(frame.starts_with("2,1,0,0,cyanobacteria,"));
    assert(extraFrame.empty());

    framesFile.close();

    std::ifstream metadataFile{outputDirectory / "run_metadata.csv"};
    std::ifstream evolutionFile{outputDirectory / "evolution_metrics.csv"};
    std::ifstream behaviorFile{outputDirectory / "behavior_metrics.csv"};
    std::ifstream learningFile{outputDirectory / "learning_metrics.csv"};
    std::ifstream benchmarkFile{outputDirectory / "benchmark_metrics.csv"};
    std::ifstream demographyFile{outputDirectory / "demography_metrics.csv"};
    std::ifstream energyFlowFile{outputDirectory / "energy_flow_metrics.csv"};
    std::ifstream mortalityFile{outputDirectory / "mortality_metrics.csv"};
    std::ifstream spatialFile{outputDirectory / "spatial_metrics.csv"};
    std::ifstream reproductionFile{outputDirectory / "reproduction_metrics.csv"};
    std::ifstream traitSelectionFile{outputDirectory / "trait_selection_metrics.csv"};
    std::ifstream extinctionFile{outputDirectory / "extinction_events.csv"};
    std::ifstream lineageFile{outputDirectory / "lineage.csv"};
    std::string metadataHeader{};
    std::string metadataRow{};
    std::string evolutionHeader{};
    std::string evolutionRow{};
    std::string behaviorHeader{};
    std::string behaviorRow{};
    std::string learningHeader{};
    std::string learningRow{};
    std::string benchmarkHeader{};
    std::string benchmarkRow{};
    std::string demographyHeader{};
    std::string demographyRow{};
    std::string energyFlowHeader{};
    std::string energyFlowRow{};
    std::string mortalityHeader{};
    std::string mortalityRow{};
    std::string spatialHeader{};
    std::string spatialRow{};
    std::string reproductionHeader{};
    std::string reproductionRow{};
    std::string traitSelectionHeader{};
    std::string traitSelectionRow{};
    std::string extinctionHeader{};
    std::string extinctionRow{};
    std::string lineageHeader{};
    std::string lineageRow{};
    std::getline(metadataFile, metadataHeader);
    std::getline(metadataFile, metadataRow);
    std::getline(evolutionFile, evolutionHeader);
    std::getline(evolutionFile, evolutionRow);
    std::getline(behaviorFile, behaviorHeader);
    std::getline(behaviorFile, behaviorRow);
    std::getline(learningFile, learningHeader);
    std::getline(learningFile, learningRow);
    std::getline(benchmarkFile, benchmarkHeader);
    std::getline(benchmarkFile, benchmarkRow);
    std::getline(demographyFile, demographyHeader);
    std::getline(demographyFile, demographyRow);
    std::getline(energyFlowFile, energyFlowHeader);
    std::getline(energyFlowFile, energyFlowRow);
    std::getline(mortalityFile, mortalityHeader);
    std::getline(mortalityFile, mortalityRow);
    std::getline(spatialFile, spatialHeader);
    std::getline(spatialFile, spatialRow);
    std::getline(reproductionFile, reproductionHeader);
    std::getline(reproductionFile, reproductionRow);
    std::getline(traitSelectionFile, traitSelectionHeader);
    std::getline(traitSelectionFile, traitSelectionRow);
    std::getline(extinctionFile, extinctionHeader);
    std::getline(extinctionFile, extinctionRow);
    std::getline(lineageFile, lineageHeader);
    std::getline(lineageFile, lineageRow);

    assert(metadataHeader.starts_with("seed,sample_interval"));
    assert(metadataRow.starts_with("98765,1,2,1,1,"));
    assert(evolutionHeader.starts_with("seed,tick,species,"));
    assert(evolutionRow.starts_with("98765,1,cyanobacteria,"));
    assert(behaviorHeader.starts_with("seed,tick,species,"));
    assert(behaviorRow.starts_with(
        "98765,1,cyanobacteria,1,1,1,1000.000000,100.000000,"));
    assert(learningHeader.starts_with("seed,tick,species,"));
    assert(learningRow.starts_with("98765,1,cyanobacteria,"));
    assert(benchmarkHeader.starts_with("seed,tick,species,"));
    assert(benchmarkRow.starts_with("98765,1,cyanobacteria,"));
    assert(demographyHeader.starts_with("seed,tick,species,"));
    assert(demographyRow == "98765,1,cyanobacteria,1,1,1,1,0,1,0,42.000000");
    assert(energyFlowHeader.starts_with("seed,tick,species,"));
    assert(energyFlowRow == "98765,1,cyanobacteria,1.500000,10.000000,"
        "7.500000,0.250000,0.000000,75.000000");
    assert(mortalityHeader.starts_with("seed,tick,species,"));
    assert(mortalityRow == "98765,1,cyanobacteria,1,1,0,0");
    assert(spatialHeader.starts_with("seed,tick,species,"));
    assert(spatialRow == "98765,1,cyanobacteria,1,1,0.166667,0.000000,"
        "30.000000,0.000000");
    assert(reproductionHeader.starts_with("seed,tick,species,"));
    assert(reproductionRow == "98765,1,cyanobacteria,1,1,1,100.000000,"
        "42.000000,3.000000,0.250000");
    assert(traitSelectionHeader.starts_with("seed,tick,species,"));
    assert(traitSelectionRow == "98765,1,cyanobacteria,1,0.300000,1,"
        "0.200000,0.300000,0.100000,1,0.400000,100.000000");
    assert(extinctionHeader == "seed,tick,species,extinction_sequence");
    assert(extinctionRow == "98765,3,cyanobacteria,1");
    assert(lineageHeader.starts_with("event,tick,id,"));
    assert(lineageRow.starts_with("birth,1,2,1,1,cyanobacteria,1,"));

    metadataFile.close();
    evolutionFile.close();
    behaviorFile.close();
    learningFile.close();
    benchmarkFile.close();
    demographyFile.close();
    energyFlowFile.close();
    mortalityFile.close();
    spatialFile.close();
    reproductionFile.close();
    traitSelectionFile.close();
    extinctionFile.close();
    lineageFile.close();
    std::filesystem::remove_all(outputDirectory);
    std::cout << "Metrics tests passed.\n";
    return 0;
}
