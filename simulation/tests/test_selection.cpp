#include "cybernet/simulation/selection.hpp"

#ifdef NDEBUG
#undef NDEBUG
#endif

#include <algorithm>
#include <cassert>
#include <cstdint>
#include <iostream>
#include <vector>

namespace {

cybernet::Organism makeOrganism(std::uint32_t id) {
    cybernet::Organism organism{};
    organism.id = id;
    return organism;
}

} // namespace

int main() {
    std::vector<cybernet::Organism> population{
        makeOrganism(10U),
        makeOrganism(20U),
        makeOrganism(30U)
    };

    const std::optional<std::uint32_t> selectedId{20U};
    assert(cybernet::findOrganismById(population, selectedId)->id == 20U);
    assert(cybernet::findOrganismIndexById(population, selectedId).value() == 1U);

    std::rotate(population.begin(), population.begin() + 1, population.end());
    assert(cybernet::findOrganismById(population, selectedId)->id == 20U);
    assert(cybernet::findOrganismIndexById(population, selectedId).value() == 0U);

    population.erase(population.begin());
    assert(cybernet::findOrganismById(population, selectedId) == nullptr);
    assert(!cybernet::findOrganismIndexById(population, selectedId).has_value());

    std::cout << "Selection tests passed.\n";
    return 0;
}
