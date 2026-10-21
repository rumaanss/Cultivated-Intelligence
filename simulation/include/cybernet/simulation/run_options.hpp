#pragma once

#include "cybernet/simulation/simulation.hpp"

#include "cybernet/world/optics.hpp"
#include <charconv>
#include <cstdint>
#include <limits>
#include <string>
#include <string_view>
#include <system_error>

namespace cybernet {

struct RunOptions {
    std::string liveDirectory{};
    std::string islandSurface{};
    bool sharedGeometry{false};
    bool lakeGeometry{false};
    OpticalModel opticalModel{OpticalModel::LegacyV1};
    std::uint64_t seed{config::DEFAULT_RANDOM_SEED};
    std::uint32_t worldFrameIntervalTicks{
        config::DEFAULT_WORLD_FRAME_INTERVAL_TICKS};
    std::uint32_t maximumWorldFrames{config::DEFAULT_MAXIMUM_WORLD_FRAMES};
    std::uint32_t maximumLineageEvents{config::DEFAULT_MAXIMUM_LINEAGE_EVENTS};
    std::uint32_t benchmarkTicks{0U};
    std::uint32_t workerCount{1U};
    std::string archiveDirectory{"output"};
    std::string recordingPath{}; // Empty disables recording.
    std::uint32_t recordingIntervalTicks{10U};
    bool reproductionIntentV2{false};
    bool headless{false};
    bool trace{false};
};

[[nodiscard]] inline bool parseUnsignedInteger(
    std::string_view text,
    std::uint64_t& value) noexcept {

    if (text.empty()) {
        return false;
    }

    const auto [end, error] = std::from_chars(
        text.data(),
        text.data() + text.size(),
        value);
    return error == std::errc{} && end == text.data() + text.size();
}

struct RunOptionsParseResult {
    RunOptions options{};
    std::string error{};

    [[nodiscard]] bool valid() const noexcept {
        return error.empty();
    }
};

[[nodiscard]] inline RunOptionsParseResult parseRunOptions(
    int argumentCount,
    char* const arguments[]) {

    RunOptionsParseResult result{};

    for (int index = 1; index < argumentCount; ++index) {
        const std::string_view argument{arguments[index]};
        std::string_view valueText{};
        enum class Option {
            Seed,
            WorldFrameInterval,
            MaximumWorldFrames,
            MaximumLineageEvents,
            BenchmarkTicks,
            WorkerCount,
            RecordingInterval
        };
        Option option{};

        if(argument=="--reproduction" || argument.starts_with("--reproduction=")) {
            if(argument=="--reproduction") {if(++index>=argumentCount){result.error="Missing --reproduction";return result;}valueText=arguments[index];}
            else valueText=argument.substr(15);
            if(valueText!="legacy-v1" && valueText!="intent-v2"){result.error="--reproduction must be legacy-v1 or intent-v2";return result;}
            result.options.reproductionIntentV2=valueText=="intent-v2";continue;
        }
        if(argument=="--island-surface" || argument.starts_with("--island-surface=")) {
            if(argument=="--island-surface") {
                if(++index>=argumentCount){result.error="Missing --island-surface";return result;}
                valueText=arguments[index];
            } else valueText=argument.substr(17);
            if(valueText.empty()||valueText.starts_with("--")){result.error="Empty or missing --island-surface path";return result;}
            result.options.islandSurface=valueText;continue;
        }
        if(argument=="--live-dir" || argument.starts_with("--live-dir=")) {
            if(argument=="--live-dir") {if(++index>=argumentCount){result.error="Missing --live-dir";return result;}valueText=arguments[index];}
            else valueText=argument.substr(11);
            if(valueText.empty()){result.error="Empty --live-dir";return result;}
            result.options.liveDirectory=valueText;continue;
        }
        if (argument == "--geometry" || argument.starts_with("--geometry=")) {
            if (argument == "--geometry") {
                if (++index >= argumentCount) { result.error = "Missing --geometry value"; return result; }
                valueText = arguments[index];
            } else valueText = argument.substr(11);
            if (valueText != "demo" && valueText != "lake" && valueText != "none") { result.error = "--geometry must be none, demo or lake"; return result; }
            result.options.sharedGeometry = valueText != "none";
            result.options.lakeGeometry = valueText == "lake";
            continue;
        }
        if (argument == "--optics" || argument.starts_with("--optics=")) {
            if (argument == "--optics") {
                if (++index >= argumentCount) { result.error = "Missing --optics value"; return result; }
                valueText = arguments[index];
            } else valueText = argument.substr(9);
            if (valueText == "v2") result.options.opticalModel = OpticalModel::OpticsV2;
            else if (valueText == "legacy") result.options.opticalModel = OpticalModel::LegacyV1;
            else { result.error = "--optics must be legacy or v2"; return result; }
            continue;
        }
        if (argument == "--recording" || argument.starts_with("--recording=")) {
        if (argument == "--recording") {
                if (index + 1 >= argumentCount) {
                    result.error = "Missing value after --recording.";
                    return result;
                }
                result.options.recordingPath = arguments[++index];
            } else {
                result.options.recordingPath = argument.substr(std::string_view{"--recording="}.size());
            }
            if (result.options.recordingPath.empty()) {
                result.error = "--recording must not be empty.";
                return result;
            }
            continue;
        } else if (argument == "--recording-interval" || argument.starts_with("--recording-interval=")) {
            if (argument == "--recording-interval") {
                if (index + 1 >= argumentCount) {
                    result.error = "Missing value after --recording-interval.";
                    return result;
                }
                valueText = arguments[++index];
            } else {
                valueText = argument.substr(std::string_view{"--recording-interval="}.size());
            }
            option = Option::RecordingInterval;
        } else if (argument == "--headless") {
            result.options.headless = true;
            continue;
        } else if (argument == "--trace") {
            result.options.trace = true;
            continue;
        } else if (argument == "--archive-dir") {
            if (index + 1 >= argumentCount) {
                result.error = "Missing value after --archive-dir.";
                return result;
            }

            result.options.archiveDirectory = arguments[++index];
            if (result.options.archiveDirectory.empty()) {
                result.error = "--archive-dir must not be empty.";
                return result;
            }
            continue;
        } else if (argument.starts_with("--archive-dir=")) {
            result.options.archiveDirectory = argument.substr(
                std::string_view{"--archive-dir="}.size());
            if (result.options.archiveDirectory.empty()) {
                result.error = "--archive-dir must not be empty.";
                return result;
            }
            continue;
        } else if (argument == "--seed") {
            if (index + 1 >= argumentCount) {
                result.error = "Missing value after --seed.";
                return result;
            }

            valueText = arguments[++index];
            option = Option::Seed;
        } else if (argument.starts_with("--seed=")) {
            valueText = argument.substr(std::string_view{"--seed="}.size());
            option = Option::Seed;
        } else if (argument == "--frame-interval") {
            if (index + 1 >= argumentCount) {
                result.error = "Missing value after --frame-interval.";
                return result;
            }

            valueText = arguments[++index];
            option = Option::WorldFrameInterval;
        } else if (argument.starts_with("--frame-interval=")) {
            valueText = argument.substr(
                std::string_view{"--frame-interval="}.size());
            option = Option::WorldFrameInterval;
        } else if (argument == "--max-world-frames") {
            if (index + 1 >= argumentCount) {
                result.error = "Missing value after --max-world-frames.";
                return result;
            }

            valueText = arguments[++index];
            option = Option::MaximumWorldFrames;
        } else if (argument.starts_with("--max-world-frames=")) {
            valueText = argument.substr(
                std::string_view{"--max-world-frames="}.size());
            option = Option::MaximumWorldFrames;
        } else if (argument == "--max-lineage-events") {
            if (index + 1 >= argumentCount) {
                result.error = "Missing value after --max-lineage-events.";
                return result;
            }

            valueText = arguments[++index];
            option = Option::MaximumLineageEvents;
        } else if (argument.starts_with("--max-lineage-events=")) {
            valueText = argument.substr(
                std::string_view{"--max-lineage-events="}.size());
            option = Option::MaximumLineageEvents;
        } else if (argument == "--benchmark-ticks") {
            if (index + 1 >= argumentCount) {
                result.error = "Missing value after --benchmark-ticks.";
                return result;
            }

            valueText = arguments[++index];
            option = Option::BenchmarkTicks;
        } else if (argument.starts_with("--benchmark-ticks=")) {
            valueText = argument.substr(
                std::string_view{"--benchmark-ticks="}.size());
            option = Option::BenchmarkTicks;
        } else if (argument == "--workers") {
            if (index + 1 >= argumentCount) {
                result.error = "Missing value after --workers.";
                return result;
            }

            valueText = arguments[++index];
            option = Option::WorkerCount;
        } else if (argument.starts_with("--workers=")) {
            valueText = argument.substr(
                std::string_view{"--workers="}.size());
            option = Option::WorkerCount;
        } else {
            result.error = "Unknown argument: " + std::string{argument};
            return result;
        }

        std::uint64_t parsedValue{0U};
        if (!parseUnsignedInteger(valueText, parsedValue)) {
            result.error = "Option values must be unsigned integers.";
            return result;
        }

        if (option == Option::Seed) {
            result.options.seed = parsedValue;
        } else if (parsedValue == 0U
            || parsedValue > std::numeric_limits<std::uint32_t>::max()) {
            result.error = "Numeric options must be positive 32-bit integers.";
            return result;
        } else if (option == Option::WorldFrameInterval) {
            result.options.worldFrameIntervalTicks =
                static_cast<std::uint32_t>(parsedValue);
        } else if (option == Option::MaximumWorldFrames) {
            result.options.maximumWorldFrames =
                static_cast<std::uint32_t>(parsedValue);
        } else if (option == Option::BenchmarkTicks) {
            result.options.benchmarkTicks =
                static_cast<std::uint32_t>(parsedValue);
            result.options.headless = true;
        } else if (option == Option::RecordingInterval) {
            result.options.recordingIntervalTicks = static_cast<std::uint32_t>(parsedValue);
        } else if (option == Option::WorkerCount) {
            result.options.workerCount =
                static_cast<std::uint32_t>(parsedValue);
        } else {
            result.options.maximumLineageEvents =
                static_cast<std::uint32_t>(parsedValue);
        }
    }

    if ((result.options.headless || result.options.trace) && result.options.benchmarkTicks == 0U) {
        result.error = "--headless and --trace require --benchmark-ticks.";
    }

    if(!result.options.liveDirectory.empty() && (!result.options.lakeGeometry || result.options.opticalModel!=OpticalModel::OpticsV2)) {
        result.error="Live mode requires --optics v2 --geometry lake";return result;
    }
    if (result.options.sharedGeometry && result.options.opticalModel != OpticalModel::OpticsV2)
        result.error = "--geometry requires --optics v2";
    return result;
}

} // namespace cybernet

