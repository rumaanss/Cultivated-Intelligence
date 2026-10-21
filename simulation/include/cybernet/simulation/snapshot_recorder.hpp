#pragma once

#include "cybernet/simulation/organism.hpp"
#include "cybernet/simulation/simulation.hpp"
#include "cybernet/world/celestial.hpp"
#include "cybernet/world/shared_geometry_generated.hpp"
#include "cybernet/world/lake_geometry_generated.hpp"
#ifdef CI_FULL_POND
#include "cybernet/world/pond_geometry_generated.hpp"
#endif

#include <algorithm>
#include <chrono>
#include <cmath>
#include <filesystem>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <limits>
#include <locale>
#include <span>
#include <sstream>
#include <stdexcept>
#include <string>
#include <vector>

namespace cybernet {

// Offline recording only. Synchronous, bounded, optional; never consumes RNG or
// modifies simulation state. Not the queue/transport for future live streaming.
class SnapshotRecorder {
public:
    static constexpr std::size_t MaximumAgents = 10000;
    static constexpr std::size_t MaximumBytes = 8 * 1024 * 1024;
    static constexpr std::size_t MaximumFrameBytes = 2 * 1024 * 1024;
    static constexpr std::uint32_t MaximumFrames = 120;

    SnapshotRecorder(const std::filesystem::path& path, std::uint64_t seed,
                     std::uint32_t interval = 10, OpticalModel model = OpticalModel::LegacyV1,
                     OpticalConfig opticalConfig = {}, bool geometry = false, bool lake = false)
        : model_(model), interval_(interval) {
        opticalConfig.validate();
        if (lake && !geometry) throw std::invalid_argument("Lake requires geometry");
        if (geometry && model != OpticalModel::OpticsV2) throw std::invalid_argument("Geometry requires OpticsV2");
        if (interval == 0) throw std::invalid_argument("Recording interval must be positive.");
        if (std::filesystem::exists(path))
            throw std::runtime_error("Recording already exists; choose a new --recording path.");
        if (!path.parent_path().empty()) std::filesystem::create_directories(path.parent_path());
        file_.open(path, std::ios::out | std::ios::binary);
        if (!file_) throw std::runtime_error("Cannot open recording output.");
        const auto stamp = std::chrono::system_clock::now().time_since_epoch().count();
        runId_ = "ci-" + std::to_string(seed) + "-" + std::to_string(stamp);
        std::ostringstream out;
        out.imbue(std::locale::classic());
        out << std::setprecision(std::numeric_limits<float>::max_digits10)
            << "{\"type\":\"header\",\"schemaVersion\":" << (geometry ? 3 : model_ == OpticalModel::OpticsV2 ? 2 : 1) << ",\"runId\":\"" << runId_
            << "\",\"seed\":\"" << seed << "\",\"modelVersion\":\"civ0.77-lake-foundation-v1.0\","
            << "\"bounds\":[" << config::WORLD_SIZE_X << ',' << config::WORLD_SIZE_Y << ',' << config::WORLD_SIZE_Z
            << "],\"coordinates\":\"xyz-z-up\",\"positionUnit\":\"simulation-unit\","
            << "\"velocityUnit\":\"simulation-unit/tick\",\"energyUnit\":\"model-energy\",\"timeUnit\":\"tick\","
            << "\"sampleStage\":\"end-of-tick\",\"opticalModel\":\"" << (geometry ? "normalized-flat-water-geometry-v3" : model_ == OpticalModel::OpticsV2 ? "normalized-flat-water-v2" : "legacy-linear-depth40-global-vision-v1") << "\","
            << "\"cycleTicks\":" << config::DAY_NIGHT_CYCLE_TICKS << ",\"moonlight\":" << config::MOONLIGHT_LEVEL
            << ",\"intervalTicks\":" << interval_ << ",\"agentColumns\":[\"id\",\"species\",\"x\",\"y\",\"z\","
            << "\"vx\",\"vy\",\"vz\",\"energy\",\"ageTicks\",\"parentId\",\"generation\",\"birthTick\"";
        if (model_ == OpticalModel::OpticsV2) {
            out << ",\"opticalTick\",\"sensorLight\",\"photosyntheticLight\",\"photosyntheticEnergy\"],"
                << "\"opticalStages\":[\"pre-movement\",\"post-movement\",\"actual-gain\"],"
                << "\"opticalParameters\":[" << opticalConfig.directExtinction << ',' << opticalConfig.diffuseExtinction
                << ',' << opticalConfig.beamExtinction << ',' << opticalConfig.diffuseFraction << ','
                << opticalConfig.diffuseTransmission << ',' << opticalConfig.refractiveIndex << ',' << opticalConfig.detectionThreshold << "]";
            if (geometry) out << ",\"geometry\":" << (lake ?
#ifdef CI_FULL_POND
                pond_geometry::Json
#else
                lake_geometry::Json
#endif
                : shared_geometry::Json);
            out << "}";
        } else out << "]}";
        writeLine(out.str());
    }

    SnapshotRecorder(const SnapshotRecorder&) = delete;
    SnapshotRecorder& operator=(const SnapshotRecorder&) = delete;
    ~SnapshotRecorder() { finish(); }

    void capture(std::uint32_t tick, const CelestialState& light,
                 std::span<const Organism> population) noexcept {
        if (closed_) return;
        try {
            if (hasTick_ && tick <= lastObservedTick_)
                throw std::runtime_error("Non-increasing recording tick.");
            lastObservedTick_ = tick;
            hasTick_ = true;
            if (frames_ != 0 && tick - lastWrittenTick_ < interval_) return;
            std::vector<const Organism*> alive;
            alive.reserve(std::min(population.size(), MaximumAgents));
            for (const auto& agent : population) {
                if (agent.alive()) {
                    if (alive.size() == MaximumAgents) { finish("population-limit"); return; }
                    alive.push_back(&agent);
                }
            }
            std::sort(alive.begin(), alive.end(), [](const auto* a, const auto* b) { return a->id < b->id; });
            for (float value : {light.daylight, light.moonlight, light.ambientLight})
                if (!std::isfinite(value) || value < 0 || value > 1)
                    throw std::runtime_error("Invalid celestial state.");
            std::ostringstream out;
            out.imbue(std::locale::classic());
            out << std::setprecision(std::numeric_limits<float>::max_digits10)
                << "{\"type\":\"frame\",\"runId\":\"" << runId_ << "\",\"sequence\":" << frames_
                << ",\"tick\":" << tick << ",\"complete\":true,\"count\":" << alive.size()
                << ",\"light\":[" << light.daylight << ',' << light.moonlight << ',' << light.ambientLight
                << "],\"agents\":[";
            std::uint32_t previousId = 0;
            bool first = true;
            for (const Organism* a : alive) {
                for (float value : {a->position.x,a->position.y,a->position.z,a->velocity.x,a->velocity.y,a->velocity.z,a->energy})
                    if (!std::isfinite(value)) throw std::runtime_error("Non-finite organism state.");
                if (a->id == 0 || a->id <= previousId || static_cast<unsigned>(a->species) > 2
                    || a->position.x < 0 || a->position.x > config::WORLD_SIZE_X
                    || a->position.y < 0 || a->position.y > config::WORLD_SIZE_Y
                    || a->position.z < 0 || a->position.z > config::WORLD_SIZE_Z || a->energy < 0
                    || a->birthTick > tick)
                    throw std::runtime_error("Invalid organism identity or bounds.");
                previousId = a->id;
                if (!first) out << ',';
                first = false;
                out << '[' << a->id << ',' << static_cast<unsigned>(a->species) << ','
                    << a->position.x << ',' << a->position.y << ',' << a->position.z << ','
                    << a->velocity.x << ',' << a->velocity.y << ',' << a->velocity.z << ','
                    << a->energy << ',' << a->ageTicks << ',' << a->parentId << ','
                    << a->generation << ',' << a->birthTick;
                if (model_ == OpticalModel::OpticsV2) {
                    const auto& d = a->opticalDiagnostics;
                    if ((d.tick != -1 && d.tick != tick) ||
                        !std::isfinite(d.sensorLight) || d.sensorLight < 0 || d.sensorLight > 1 ||
                        !std::isfinite(d.photosyntheticLight) || d.photosyntheticLight < 0 || d.photosyntheticLight > 1 ||
                        !std::isfinite(d.photosyntheticEnergy) || d.photosyntheticEnergy < 0 ||
                        (d.tick == -1 && (d.sensorLight != 0 || d.photosyntheticLight != 0 || d.photosyntheticEnergy != 0)))
                        throw std::runtime_error("Invalid phase-specific optical diagnostics");
                    out << ',' << d.tick << ',' << d.sensorLight << ',' << d.photosyntheticLight << ',' << d.photosyntheticEnergy;
                }
                out << ']';
            }
            out << "]}";
            const std::string record = out.str();
            if (record.size() > MaximumFrameBytes) { finish("frame-byte-limit"); return; }
            if (bytes_ + record.size() + 1 + 4096 > MaximumBytes) { finish("byte-limit"); return; }
            writeLine(record);
            ++frames_;
            lastWrittenTick_ = tick;
            if (frames_ >= MaximumFrames) finish("frame-limit");
        } catch (const std::exception& error) {
            std::cerr << "[CI Recording] Disabled: " << error.what() << '\n';
            finish("error");
        }
    }

    void finish(const char* reason = "completed") noexcept {
        if (closed_) return;
        closed_ = true;
        try {
            writeLine("{\"type\":\"end\",\"runId\":\"" + runId_ + "\",\"frames\":"
                + std::to_string(frames_) + ",\"reason\":\"" + reason + "\"}");
            file_.flush();
            if (!file_) throw std::runtime_error("Recording flush failed.");
            std::cout << "[CI Recording] " << frames_ << " complete frames; " << reason << '\n';
        } catch (const std::exception& error) {
            std::cerr << "[CI Recording] Output incomplete: " << error.what() << '\n';
        }
        file_.close();
    }

private:
    void writeLine(const std::string& value) {
        file_ << value << '\n';
        if (!file_) throw std::runtime_error("Recording write failed.");
        bytes_ += value.size() + 1;
    }
    OpticalModel model_;
    std::ofstream file_;
    std::string runId_;
    std::uint32_t interval_, frames_{0}, lastWrittenTick_{0}, lastObservedTick_{0};
    std::size_t bytes_{0};
    bool closed_{false}, hasTick_{false};
};
} // namespace cybernet
