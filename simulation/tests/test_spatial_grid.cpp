#include "cybernet/simulation/organism.hpp"
#include "cybernet/world/spatial_grid.hpp"

#ifdef NDEBUG
#undef NDEBUG
#endif

#include <algorithm>
#include <cassert>
#include <cstddef>
#include <vector>

namespace {

cybernet::Organism makeOrganism(std::uint32_t id, cybernet::Vec3 position) {
    cybernet::Organism organism{};
    organism.id = id;
    organism.configureSpecies(cybernet::OrganismType::Cyanobacteria);
    organism.position = position;
    return organism;
}

} // namespace

int main() {
    std::vector<cybernet::Organism> population{};
    population.push_back(makeOrganism(1U, {54.9F, 50.0F, 30.0F}));
    population.push_back(makeOrganism(2U, {80.0F, 50.0F, 30.0F}));
    population.push_back(makeOrganism(3U, {0.1F, 50.0F, 30.0F}));

    cybernet::SpatialGrid grid{};
    grid.rebuild(std::span<const cybernet::Organism>(population));

    std::vector<std::size_t> centerVisited{};
    grid.forEachNearby(
        {50.0F, 50.0F, 30.0F},
        5.0F,
        [&](std::size_t index) {
            centerVisited.push_back(index);
        });

    assert(std::find(centerVisited.begin(), centerVisited.end(), 0U)
        != centerVisited.end());
    assert(std::find(centerVisited.begin(), centerVisited.end(), 1U)
        == centerVisited.end());

    std::vector<std::size_t> boundaryVisited{};
    grid.forEachNearby(
        {0.0F, 50.0F, 30.0F},
        1.0F,
        [&](std::size_t index) {
            boundaryVisited.push_back(index);
        });

    assert(std::find(boundaryVisited.begin(), boundaryVisited.end(), 2U)
        != boundaryVisited.end());
    return 0;
}
