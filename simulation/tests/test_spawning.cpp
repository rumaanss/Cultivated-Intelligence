#include "cybernet/simulation/spawning.hpp"

#ifdef NDEBUG
#undef NDEBUG
#endif

#include <cassert>
#include <cstdint>
#include <iostream>
#include <set>

namespace {

cybernet::Organism makeFounder(
    std::uint32_t id,
    cybernet::Random& random) {

    cybernet::Organism organism{};
    cybernet::spawnOrganism(
        organism,
        id,
        cybernet::OrganismType::Cyanobacteria,
        {50.0F, 50.0F, 30.0F},
        0U,
        0U,
        random);
    cybernet::randomizeFounderAge(organism, random);
    return organism;
}

} // namespace

int main() {
    {
        cybernet::Organism slow{};
        slow.configureSpecies(cybernet::OrganismType::Bacterivore);
        slow.genome[cybernet::SpeedGeneIndex] = -1.0F;
        slow.initializeBrain();

        cybernet::Organism fast{};
        fast.configureSpecies(cybernet::OrganismType::Bacterivore);
        fast.genome[cybernet::SpeedGeneIndex] = 1.0F;
        fast.initializeBrain();

        assert(slow.speed == slow.profile().minimumSpeed);
        assert(fast.speed == fast.profile().maximumSpeed);
    }

    cybernet::Random firstRandom{123U};
    cybernet::Random secondRandom{123U};
    std::set<std::uint32_t> observedAges{};

    for (std::uint32_t id = 1U; id <= 128U; ++id) {
        const cybernet::Organism first = makeFounder(id, firstRandom);
        const cybernet::Organism second = makeFounder(id, secondRandom);

        assert(first.ageTicks < first.profile().maximumAgeTicks);
        assert(first.ageTicks == second.ageTicks);
        assert(first.genome == second.genome);
        assert(first.parentId == 0U);
        assert(first.rootAncestorId == id);
        assert(first.speed >= first.profile().minimumSpeed);
        assert(first.speed <= first.profile().maximumSpeed);
        observedAges.insert(first.ageTicks);
    }

    assert(observedAges.size() > 1U);

    cybernet::Random newbornRandom{99U};
    cybernet::Organism newborn{};
    cybernet::spawnOrganism(
        newborn,
        1U,
        cybernet::OrganismType::Bacterivore,
        {50.0F, 50.0F, 30.0F},
        100U,
        1U,
        newbornRandom);

    assert(newborn.ageTicks == 0U);
    assert(newborn.parentId == 0U);
    assert(newborn.rootAncestorId == newborn.id);
    std::cout << "Spawning tests passed.\n";
    return 0;
}
