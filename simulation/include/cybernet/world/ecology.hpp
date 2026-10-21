#pragma once

#include "cybernet/brain/rnn_brain.hpp"
#include "cybernet/random.hpp"
#include "cybernet/simulation/organism.hpp"
#include "cybernet/world/celestial.hpp"
#include "cybernet/world/spatial_grid.hpp"

#include <cstdint>
#include <span>
#include <vector>

namespace cybernet {

class ChemistryField;

struct ObservationResult {
    RnnBrain::Inputs observation{};
    Organism* nearestPrey{nullptr};
};

struct ObservationNoise {
    float primary{0.0F};
    float secondary{0.0F};
};

enum class PopulationEventType : std::uint8_t {
    Birth,
    Death
};

struct PopulationEvent {
    PopulationEventType type{PopulationEventType::Birth};
    std::uint32_t id{0U};
    std::uint32_t parentId{0U};
    std::uint32_t rootAncestorId{0U};
    OrganismType species{OrganismType::Cyanobacteria};
    std::uint32_t generation{0U};
    std::uint32_t tick{0U};
    std::uint32_t ageTicks{0U};
    std::uint32_t parentAgeTicks{0U};
    std::uint32_t mutatedGeneCount{0U};
    float energy{0.0F};
    float speed{0.0F};
    float parentSpeed{0.0F};
    float totalMutationDistance{0.0F};
    DeathCause deathCause{DeathCause::None};
};

struct PopulationChanges {
    std::size_t births{0U};
    std::size_t deaths{0U};
    std::vector<PopulationEvent> events{};
};

struct FeedingResult {
    float preyEnergyCaptured{0.0F};
    float predatorEnergyGained{0.0F};
};

class Ecology {
public:
    static constexpr float VisionRadiusDay = 30.0F;
    static constexpr float CaptureRadius = 2.0F;
    static constexpr float FeedAttemptThreshold = 0.5F;

    // No genome resizing: opt-in schema changes meaning of reserved output 3.
    void setReproductionIntentV2(bool enabled) noexcept { reproductionIntentV2_ = enabled; }
    [[nodiscard]] bool reproductionIntentV2() const noexcept { return reproductionIntentV2_; }
    void setChemistry(ChemistryField* chemistry) noexcept;
    void setGeometry(const GeometryWorld* geometry) noexcept { geometry_ = geometry; opticalRanges_.clear(); }
    void beginTick(std::span<const Organism> population) noexcept;
    void refreshSpatialIndex(std::span<const Organism> population, const CelestialCycle* celestial = nullptr) noexcept;

    [[nodiscard]] ObservationResult buildObservation(
        const Organism& agent,
        std::span<Organism> population,
        const CelestialCycle& celestial,
        const ObservationNoise& noise) const;

    [[nodiscard]] bool tryFeed(
        Organism& predator,
        Organism* cachedPrey,
        std::span<Organism> population,
        bool feedRequested,
        FeedingResult* result = nullptr) const noexcept;

    [[nodiscard]] PopulationChanges processPopulation(
        std::vector<Organism>& population,
        std::uint32_t tick,
        std::uint32_t& nextId,
        Random& random) const;

private:
    bool reproductionIntentV2_{false};
    struct OpticalRange { Vec3 position; float range; bool detectable; };
    std::vector<OpticalRange> opticalRanges_{};
    std::uint32_t opticalTick_{0};
    const CelestialCycle* opticalSource_{nullptr};
    OpticalConfig opticalConfig_{};
    const GeometryWorld* geometry_{nullptr};
    ChemistryField* chemistry_{nullptr};
    std::size_t cyanobacteriaCount_{0};
    std::size_t bacterivoreCount_{0};
    std::size_t bodoCount_{0};
    SpatialGrid spatialGrid_{};
    mutable std::vector<Organism> additions_{};
};

} // namespace cybernet

