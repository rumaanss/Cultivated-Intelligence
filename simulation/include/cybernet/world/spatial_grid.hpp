#pragma once

#include "cybernet/simulation/organism.hpp"
#include "cybernet/simulation/simulation.hpp"

#include <algorithm>
#include <array>
#include <cmath>
#include <cstddef>
#include <span>
#include <vector>

namespace cybernet {

class SpatialGrid {
public:
	static constexpr std::size_t GridX = static_cast<std::size_t>((config::WORLD_SIZE_X+9)/10);
	static constexpr std::size_t GridY = static_cast<std::size_t>((config::WORLD_SIZE_Y+9)/10);
	static constexpr std::size_t GridZ = static_cast<std::size_t>((config::WORLD_SIZE_Z+9)/10);
	static constexpr std::size_t CellCount = GridX * GridY * GridZ;

	void rebuild(std::span<const Organism> population) {
		for (std::vector<std::size_t>& bucket : buckets_) {
			bucket.clear();
		}

		for (std::size_t index = 0; index < population.size(); ++index) {
			if (population[index].alive()) {
				buckets_[cellIndex(population[index].position)].push_back(index);
			}
		}
	}

	template <typename Visitor>
	void forEachNearby(
		const Vec3& position,
		float radius,
		Visitor&& visitor) const {

		const CellCoordinates center = coordinates(position);
		const std::size_t xRange = cellRange(
			radius,
			config::WORLD_SIZE_X,
			GridX);
		const std::size_t yRange = cellRange(
			radius,
			config::WORLD_SIZE_Y,
			GridY);
		const std::size_t zRange = cellRange(
			radius,
			config::WORLD_SIZE_Z,
			GridZ);

		const std::size_t minimumX = center.x > xRange ? center.x - xRange : 0U;
		const std::size_t minimumY = center.y > yRange ? center.y - yRange : 0U;
		const std::size_t minimumZ = center.z > zRange ? center.z - zRange : 0U;
		const std::size_t maximumX = std::min(center.x + xRange, GridX - 1U);
		const std::size_t maximumY = std::min(center.y + yRange, GridY - 1U);
		const std::size_t maximumZ = std::min(center.z + zRange, GridZ - 1U);
		const float radiusSquared = nonnegativeRadiusSquared(radius);

		for (std::size_t z = minimumZ; z <= maximumZ; ++z) {
			for (std::size_t y = minimumY; y <= maximumY; ++y) {
				for (std::size_t x = minimumX; x <= maximumX; ++x) {
					if (minimumDistanceSquaredToCell(position, x, y, z)
						> radiusSquared) {
						continue;
					}
					for (const std::size_t index : buckets_[indexOf(x, y, z)]) {
						visitor(index);
					}
				}
			}
		}
	}

private:
	struct CellCoordinates {
		std::size_t x{0U};
		std::size_t y{0U};
		std::size_t z{0U};
	};

	[[nodiscard]] static std::size_t coordinate(
		float value,
		float worldSize,
		std::size_t cellCount) noexcept {

		const float normalized = std::clamp(value / worldSize, 0.0F, 0.999999F);
		return static_cast<std::size_t>(
			normalized * static_cast<float>(cellCount));
	}

	[[nodiscard]] static CellCoordinates coordinates(
		const Vec3& position) noexcept {

		return {
			coordinate(position.x, config::WORLD_SIZE_X, GridX),
			coordinate(position.y, config::WORLD_SIZE_Y, GridY),
			coordinate(position.z, config::WORLD_SIZE_Z, GridZ)
		};
	}

	[[nodiscard]] static std::size_t cellRange(
		float radius,
		float worldSize,
		std::size_t cellCount) noexcept {

		const float nonnegativeRadius = std::max(radius, 0.0F);
		const float cellSize = worldSize / static_cast<float>(cellCount);
		return static_cast<std::size_t>(
			std::ceil(nonnegativeRadius / cellSize));
	}

	[[nodiscard]] static float nonnegativeRadiusSquared(float radius) noexcept {
		const float nonnegativeRadius = std::max(radius, 0.0F);
		return nonnegativeRadius * nonnegativeRadius;
	}

	[[nodiscard]] static float distanceToInterval(
		float value,
		float minimum,
		float maximum) noexcept {

		if (value < minimum) {
			return minimum - value;
		}
		if (value > maximum) {
			return value - maximum;
		}
		return 0.0F;
	}

	[[nodiscard]] static float minimumDistanceSquaredToCell(
		const Vec3& position,
		std::size_t x,
		std::size_t y,
		std::size_t z) noexcept {

		const float cellWidth = config::WORLD_SIZE_X / static_cast<float>(GridX);
		const float cellHeight = config::WORLD_SIZE_Y / static_cast<float>(GridY);
		const float cellDepth = config::WORLD_SIZE_Z / static_cast<float>(GridZ);
		const float deltaX = distanceToInterval(
			position.x,
			static_cast<float>(x) * cellWidth,
			static_cast<float>(x + 1U) * cellWidth);
		const float deltaY = distanceToInterval(
			position.y,
			static_cast<float>(y) * cellHeight,
			static_cast<float>(y + 1U) * cellHeight);
		const float deltaZ = distanceToInterval(
			position.z,
			static_cast<float>(z) * cellDepth,
			static_cast<float>(z + 1U) * cellDepth);

		return (deltaX * deltaX) + (deltaY * deltaY) + (deltaZ * deltaZ);
	}

	[[nodiscard]] static std::size_t indexOf(
		std::size_t x,
		std::size_t y,
		std::size_t z) noexcept {

		return (z * GridY * GridX) + (y * GridX) + x;
	}

	[[nodiscard]] static std::size_t cellIndex(const Vec3& position) noexcept {
		const CellCoordinates cell = coordinates(position);
		return indexOf(cell.x, cell.y, cell.z);
	}

	std::array<std::vector<std::size_t>, CellCount> buckets_{};
};

} // namespace cybernet
