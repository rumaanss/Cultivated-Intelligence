#pragma once

#include <cstddef>
#include <cstdint>
#ifdef CI_PLANET_LAKE
#include "cybernet/world/planet_contract_generated.hpp"
#endif

namespace cybernet::config {

// Full pond builds preserve one simulation unit per Roblox stud.
#if defined(CI_PLANET_LAKE)
inline constexpr float WORLD_SIZE_X=planet_contract::Width,WORLD_SIZE_Y=planet_contract::Length,WORLD_SIZE_Z=planet_contract::Depth;
#elif defined(CI_FULL_POND)
inline constexpr float WORLD_SIZE_X=208.0F,WORLD_SIZE_Y=176.0F,WORLD_SIZE_Z=68.0F;
#else
// Legacy standalone tests and recordings.
inline constexpr float WORLD_SIZE_X = 100.0F;
inline constexpr float WORLD_SIZE_Y = 100.0F;
inline constexpr float WORLD_SIZE_Z = 60.0F;

#endif

// Simulation settings.
inline constexpr std::size_t GENERATION_TICKS = 500;
inline constexpr std::size_t TOTAL_GENERATIONS = 1000;
inline constexpr std::uint32_t DEFAULT_WORLD_FRAME_INTERVAL_TICKS = 100U;
inline constexpr std::uint32_t DEFAULT_MAXIMUM_WORLD_FRAMES = 1000U;
inline constexpr std::uint32_t DEFAULT_MAXIMUM_LINEAGE_EVENTS = 500000U;

// Celestial settings.
inline constexpr std::size_t DAY_NIGHT_CYCLE_TICKS = 600;
inline constexpr float MOONLIGHT_LEVEL = 0.08F;

// Ecology settings.
inline constexpr float VISION_RADIUS_DAY = 30.0F;
inline constexpr float CAPTURE_RADIUS = 2.0F;

// Physics settings.
inline constexpr float DRAG = 0.88F;
inline constexpr float BOUNDARY_RESTITUTION = 0.50F;

// Neural-network architecture.
inline constexpr std::size_t INPUT_COUNT = 28;
inline constexpr std::size_t HIDDEN_COUNT = 20;
inline constexpr std::size_t OUTPUT_COUNT = 5;

// 28*20 + 20*20 + 20 + 20*5 + 5 + 20 + 1 + 4 = 1,110.
inline constexpr std::size_t GENOME_SIZE = 1110;

// Deterministic default seed. Change later when desired.
inline constexpr std::uint64_t DEFAULT_RANDOM_SEED = 42ULL;

} // namespace cybernet::config
