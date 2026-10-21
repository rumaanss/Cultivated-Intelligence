#pragma once
#include "cybernet/simulation/simulation.hpp"

#include "cybernet/vec3.hpp"
#include "cybernet/simulation/organism.hpp"

#include <array>
#include <cstddef>
#include <span>

namespace cybernet {

struct ChemistryCell {
    float dissolvedCarbon{1.0F};
    float oxygen{0.50F};
    float ammonium{0.50F};
    float nitrate{1.00F};
    float phosphate{1.00F};
};

struct ChemistrySummary {
    float averageDissolvedCarbon{0.0F};
    float averageOxygen{0.0F};
    float averageAmmonium{0.0F};
    float averageNitrate{0.0F};
    float averagePhosphate{0.0F};
    float totalCarbonConsumed{0.0F};
    float totalPhosphateConsumed{0.0F};
    float totalOxygenProduced{0.0F};
};

class ChemistryField {
public:
    static constexpr std::size_t GridX = static_cast<std::size_t>((config::WORLD_SIZE_X+9)/10);
    static constexpr std::size_t GridY = static_cast<std::size_t>((config::WORLD_SIZE_Y+9)/10);
    static constexpr std::size_t GridZ = static_cast<std::size_t>((config::WORLD_SIZE_Z+9)/10);
    static constexpr std::size_t CellCount = GridX * GridY * GridZ;

    ChemistryField() noexcept;

    void reset() noexcept;
 void enableIslandAtmosphere() noexcept { islandAtmosphere_=true; }
 double assimilateAtmosphericCarbon(double requested) noexcept;
 void returnAtmosphericCarbon(double amount) noexcept;
 double atmosphericCarbon() const noexcept { return atmosphereCarbon_; }
 void depositMineral(const Vec3& position,double amount) noexcept;
    void diffuse(float rate = 0.02F) noexcept;

    void beginTick(std::span<const Organism> population) noexcept;

    [[nodiscard]] float nutrientSupport(const Vec3& position) const noexcept;

    void processPrimaryProducer(
        const Vec3& position,
        float photosyntheticEnergy) noexcept;

    void recycleBiomass(
        const Vec3& position,
        float biomass = 0.05F) noexcept;

    [[nodiscard]] const ChemistryCell& cellAt(
        const Vec3& position) const noexcept;

    [[nodiscard]] ChemistrySummary summary() const noexcept;
    [[nodiscard]] bool sameState(const ChemistryField& other) const noexcept;

private:
    [[nodiscard]] static std::size_t cellIndex(
        const Vec3& position) noexcept;

    [[nodiscard]] static ChemistryCell blend(
        const ChemistryCell& center,
        const ChemistryCell& neighbor,
        float amount) noexcept;

    bool islandAtmosphere_{false};
 double atmosphereCarbon_{1000000.0},atmosphereOxygen_{2000000.0};
 std::array<ChemistryCell, CellCount> cells_{};
    std::array<ChemistryCell, CellCount> scratch_{};
    std::array<std::size_t, CellCount> producerCounts_{};
    float totalCarbonConsumed_{0.0F};
    float totalPhosphateConsumed_{0.0F};
    float totalOxygenProduced_{0.0F};
};

} // namespace cybernet
