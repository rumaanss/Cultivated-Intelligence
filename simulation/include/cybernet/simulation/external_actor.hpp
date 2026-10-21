#pragma once
#include "cybernet/vec3.hpp"
#include <cstdint>
namespace cybernet { struct ExternalActor {std::uint32_t id{};Vec3 position{};float radius{},health{};int kind{};}; }
