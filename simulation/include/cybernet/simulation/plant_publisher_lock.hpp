#pragma once
#include <filesystem>
#include <cstdint>
namespace cybernet {
// Same lock as the standalone plant publisher. Platform headers stay in the
// implementation so Windows macros cannot collide with the raylib application.
class PlantPublisherLock {
 std::intptr_t handle_{-1};
public:
 explicit PlantPublisherLock(const std::filesystem::path& directory);
 ~PlantPublisherLock();
 PlantPublisherLock(const PlantPublisherLock&)=delete;
 PlantPublisherLock& operator=(const PlantPublisherLock&)=delete;
};
}
