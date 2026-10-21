#include "cybernet/world/chemistry.hpp"

#include "cybernet/simulation/simulation.hpp"

#include <algorithm>

namespace cybernet {
namespace {

constexpr float AmbientCarbon = 1.00F;
constexpr float AmbientOxygen = 0.50F;
constexpr float AmbientAmmonium = 0.50F;
constexpr float AmbientNitrate = 1.00F;
constexpr float AmbientPhosphate = 1.00F;

constexpr float CarbonReplenishmentRate = 0.0010F;
constexpr float OxygenExchangeRate = 0.0005F;
constexpr float NitrogenReplenishmentRate = 0.0002F;
constexpr float PhosphateReplenishmentRate = 0.0001F;

[[nodiscard]] std::size_t coordinate(
    float value,
    float worldSize,
    std::size_t cellCount) noexcept {

    const float normalized = std::clamp(value / worldSize, 0.0F, 0.999999F);
    return static_cast<std::size_t>(
        normalized * static_cast<float>(cellCount));
}

[[nodiscard]] std::size_t indexOf(
    std::size_t x,
    std::size_t y,
    std::size_t z) noexcept {

    return (z * ChemistryField::GridY * ChemistryField::GridX)
        + (y * ChemistryField::GridX)
        + x;
}

} // namespace

ChemistryField::ChemistryField() noexcept {
    reset();
}

void ChemistryField::reset() noexcept {
    islandAtmosphere_=false;atmosphereCarbon_=1000000.;atmosphereOxygen_=2000000.;
    cells_.fill(ChemistryCell{});
    scratch_.fill(ChemistryCell{});
    producerCounts_.fill(0U);
    totalCarbonConsumed_ = 0.0F;
    totalPhosphateConsumed_ = 0.0F;
    totalOxygenProduced_ = 0.0F;
}

void ChemistryField::beginTick(
    std::span<const Organism> population) noexcept {

    producerCounts_.fill(0U);
    for (const Organism& organism : population) {
        if (organism.alive() && !organism.liveQuarantined
            && organism.species == OrganismType::Cyanobacteria) {
            ++producerCounts_[cellIndex(organism.position)];
        }
    }
}

ChemistryCell ChemistryField::blend(
    const ChemistryCell& center,
    const ChemistryCell& neighbor,
    float amount) noexcept {

    const float inverse = 1.0F - amount;

    return ChemistryCell{
        .dissolvedCarbon = (center.dissolvedCarbon * inverse)
            + (neighbor.dissolvedCarbon * amount),
        .oxygen = (center.oxygen * inverse) + (neighbor.oxygen * amount),
        .ammonium = (center.ammonium * inverse)
            + (neighbor.ammonium * amount),
        .nitrate = (center.nitrate * inverse)
            + (neighbor.nitrate * amount),
        .phosphate = (center.phosphate * inverse)
            + (neighbor.phosphate * amount)
    };
}

void ChemistryField::diffuse(float rate) noexcept {
    if(islandAtmosphere_) for(std::size_t i=CellCount-GridX*GridY;i<CellCount;++i){
      auto& c=cells_[i];
      const double carbon=std::clamp((atmosphereCarbon_/1000000.-c.dissolvedCarbon)*.001,-double(c.dissolvedCarbon),atmosphereCarbon_);
      const double oxygen=std::clamp((atmosphereOxygen_/4000000.-c.oxygen)*.0005,-double(c.oxygen),atmosphereOxygen_);
      c.dissolvedCarbon+=float(carbon);atmosphereCarbon_-=carbon;
      c.oxygen+=float(oxygen);atmosphereOxygen_-=oxygen;
    }
    const float amount = std::clamp(rate, 0.0F, 0.25F);

    for (std::size_t z = 0; z < GridZ; ++z) {
        for (std::size_t y = 0; y < GridY; ++y) {
            for (std::size_t x = 0; x < GridX; ++x) {
                const std::size_t centerIndex = indexOf(x, y, z);
                const ChemistryCell& center = cells_[centerIndex];
                ChemistryCell average = center;
                std::size_t neighborCount = 0;

                const auto include = [&](std::size_t nx,
                                         std::size_t ny,
                                         std::size_t nz) {
                    average = blend(
                        average,
                        cells_[indexOf(nx, ny, nz)],
                        1.0F / static_cast<float>(neighborCount + 2));
                    ++neighborCount;
                };

                if (x > 0) {
                    include(x - 1, y, z);
                }
                if (x + 1 < GridX) {
                    include(x + 1, y, z);
                }
                if (y > 0) {
                    include(x, y - 1, z);
                }
                if (y + 1 < GridY) {
                    include(x, y + 1, z);
                }
                if (z > 0) {
                    include(x, y, z - 1);
                }
                if (z + 1 < GridZ) {
                    include(x, y, z + 1);
                }

                scratch_[centerIndex] = blend(
                    center,
                    average,
                    amount);
            }
        }
    }

    cells_.swap(scratch_);

    for (ChemistryCell& cell : cells_) {
        if (!islandAtmosphere_) {
          cell.dissolvedCarbon += (AmbientCarbon - cell.dissolvedCarbon) * CarbonReplenishmentRate;
          cell.oxygen += (AmbientOxygen - cell.oxygen) * OxygenExchangeRate;
        }
        cell.ammonium += (AmbientAmmonium - cell.ammonium)
            * NitrogenReplenishmentRate;
        cell.nitrate += (AmbientNitrate - cell.nitrate)
            * NitrogenReplenishmentRate;
        cell.phosphate += (AmbientPhosphate - cell.phosphate)
            * PhosphateReplenishmentRate;
    }
}

float ChemistryField::nutrientSupport(const Vec3& position) const noexcept {
    const ChemistryCell& cell = cellAt(position);
    const float nitrogen = std::clamp(
        std::max(cell.ammonium, cell.nitrate),
        0.0F,
        1.0F);
    const float phosphate = std::clamp(cell.phosphate, 0.0F, 1.0F);

    const std::size_t producerCount = producerCounts_[cellIndex(position)];
    const float densityPenalty = 1.0F / (1.0F
        + (0.15F * static_cast<float>(producerCount > 0
            ? producerCount - 1
            : 0)));

    return std::clamp(
        std::min({nitrogen, phosphate, std::clamp(cell.dissolvedCarbon,0.0F,1.0F)}) * densityPenalty,
        0.0F,
        1.25F);
}

void ChemistryField::processPrimaryProducer(
    const Vec3& position,
    float photosyntheticEnergy) noexcept {

    ChemistryCell& cell = cells_[cellIndex(position)];
    const float requested = std::max(0.0F, photosyntheticEnergy) * 0.001F;
    const float uptake = std::min({requested,cell.dissolvedCarbon,cell.phosphate/.05F,cell.ammonium/.10F,cell.nitrate/.10F});
    const float phosphateUptake = uptake * 0.05F;

    cell.dissolvedCarbon = std::max(0.0F, cell.dissolvedCarbon - uptake);
    cell.ammonium = std::max(0.0F, cell.ammonium - (uptake * 0.10F));
    cell.nitrate = std::max(0.0F, cell.nitrate - (uptake * 0.10F));
    cell.phosphate = std::max(0.0F, cell.phosphate - phosphateUptake);
    cell.oxygen = std::min(1.25F, cell.oxygen + (uptake * 0.25F));
    totalCarbonConsumed_ += uptake;
    totalPhosphateConsumed_ += phosphateUptake;
    totalOxygenProduced_ += uptake * 0.25F;
}

void ChemistryField::recycleBiomass(
    const Vec3& position,
    float biomass) noexcept {

    ChemistryCell& cell = cells_[cellIndex(position)];
    const float amount = std::max(0.0F, biomass);
    cell.dissolvedCarbon = std::min(1.25F, cell.dissolvedCarbon + amount);
    cell.ammonium = std::min(1.25F, cell.ammonium + (amount * 0.10F));
    cell.phosphate = std::min(1.25F, cell.phosphate + (amount * 0.05F));
}

const ChemistryCell& ChemistryField::cellAt(
    const Vec3& position) const noexcept {

    return cells_[cellIndex(position)];
}

ChemistrySummary ChemistryField::summary() const noexcept {
    ChemistrySummary result{};

    for (const ChemistryCell& cell : cells_) {
        result.averageDissolvedCarbon += cell.dissolvedCarbon;
        result.averageOxygen += cell.oxygen;
        result.averageAmmonium += cell.ammonium;
        result.averageNitrate += cell.nitrate;
        result.averagePhosphate += cell.phosphate;
    }

    const float divisor = static_cast<float>(CellCount);
    result.averageDissolvedCarbon /= divisor;
    result.averageOxygen /= divisor;
    result.averageAmmonium /= divisor;
    result.averageNitrate /= divisor;
    result.averagePhosphate /= divisor;
    result.totalCarbonConsumed = totalCarbonConsumed_;
    result.totalPhosphateConsumed = totalPhosphateConsumed_;
    result.totalOxygenProduced = totalOxygenProduced_;
    return result;
}

double ChemistryField::assimilateAtmosphericCarbon(double requested) noexcept {
 const double amount=std::min(std::max(0.,requested),atmosphereCarbon_);atmosphereCarbon_-=amount;atmosphereOxygen_+=amount*.25;return amount;
}
void ChemistryField::returnAtmosphericCarbon(double amount) noexcept {
 amount=std::max(0.,amount);atmosphereCarbon_+=amount;atmosphereOxygen_=std::max(0.,atmosphereOxygen_-amount*.25);
}
void ChemistryField::depositMineral(const Vec3& p,double amount) noexcept {
 auto& c=cells_[cellIndex(p)];c.phosphate+=float(std::max(0.,amount));
}
bool ChemistryField::sameState(const ChemistryField& other) const noexcept {
    if(islandAtmosphere_!=other.islandAtmosphere_||atmosphereCarbon_!=other.atmosphereCarbon_||atmosphereOxygen_!=other.atmosphereOxygen_)return false;
    for (std::size_t index = 0U; index < CellCount; ++index) {
        const ChemistryCell& left = cells_[index];
        const ChemistryCell& right = other.cells_[index];
        const ChemistryCell& leftScratch = scratch_[index];
        const ChemistryCell& rightScratch = other.scratch_[index];

        if (left.dissolvedCarbon != right.dissolvedCarbon
            || left.oxygen != right.oxygen
            || left.ammonium != right.ammonium
            || left.nitrate != right.nitrate
            || left.phosphate != right.phosphate
            || leftScratch.dissolvedCarbon != rightScratch.dissolvedCarbon
            || leftScratch.oxygen != rightScratch.oxygen
            || leftScratch.ammonium != rightScratch.ammonium
            || leftScratch.nitrate != rightScratch.nitrate
            || leftScratch.phosphate != rightScratch.phosphate
            || producerCounts_[index] != other.producerCounts_[index]) {
            return false;
        }
    }

    return totalCarbonConsumed_ == other.totalCarbonConsumed_
        && totalPhosphateConsumed_ == other.totalPhosphateConsumed_
        && totalOxygenProduced_ == other.totalOxygenProduced_;
}

std::size_t ChemistryField::cellIndex(const Vec3& position) noexcept {
    const std::size_t x = coordinate(
        position.x,
        config::WORLD_SIZE_X,
        GridX);
    const std::size_t y = coordinate(
        position.y,
        config::WORLD_SIZE_Y,
        GridY);
    const std::size_t z = coordinate(
        position.z,
        config::WORLD_SIZE_Z,
        GridZ);

    return indexOf(x, y, z);
}

} // namespace cybernet

