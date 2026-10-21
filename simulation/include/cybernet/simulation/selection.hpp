#pragma once

#include "cybernet/simulation/organism.hpp"

#include <algorithm>
#include <cstddef>
#include <cstdint>
#include <optional>
#include <vector>

namespace cybernet {

[[nodiscard]] inline const Organism* findOrganismById(
    const std::vector<Organism>& population,
    std::optional<std::uint32_t> organismId) {

    if (!organismId.has_value()) {
        return nullptr;
    }

    const auto selected = std::find_if(
        population.begin(),
        population.end(),
        [organismId](const Organism& organism) {
            return organism.id == organismId.value();
        });

    return selected == population.end() ? nullptr : &*selected;
}

[[nodiscard]] inline std::optional<std::size_t> findOrganismIndexById(
    const std::vector<Organism>& population,
    std::optional<std::uint32_t> organismId) {

    const Organism* selected = findOrganismById(population, organismId);
    if (selected == nullptr) {
        return std::nullopt;
    }

    return static_cast<std::size_t>(selected - population.data());
}

} // namespace cybernet
