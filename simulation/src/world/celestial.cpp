#include "cybernet/world/celestial.hpp"

#include <algorithm>
#include "cybernet/simulation/simulation.hpp"
#include <cmath>

namespace cybernet {

CelestialCycle::CelestialCycle(int cycleTicks, float moonlight)
    : cycleTicks_(std::max(cycleTicks, 1)),
      moonlight_(std::clamp(moonlight, 0.0F, 1.0F)) {
}

void CelestialCycle::update(int worldTick) {
    lastTick_ = worldTick;
    constexpr float Pi = 3.14159265358979323846F;

    const int tickInCycle =
        ((worldTick % cycleTicks_) + cycleTicks_) % cycleTicks_;

    const float phase =
        static_cast<float>(tickInCycle) /
        static_cast<float>(cycleTicks_);

    // Exact Python equivalent:
    // sin(2.0 * pi * phase)
    const float sunHeight = std::sin(2.0F * Pi * phase);

    state_.daylight = std::max(0.0F, sunHeight);
    state_.isDay = sunHeight > 0.0F;

    // Python moonlight baseline is present in light_level at all times.
    state_.moonlight = moonlight_;

    // Exact Python equivalent:
    // moonlight + ((1.0 - moonlight) * daylight)
    state_.ambientLight =
        moonlight_ + ((1.0F - moonlight_) * state_.daylight);
    if (usesOpticsV2()) optics_ = OpticalField(opticalConfig_, state_.daylight,
        moonlight_, config::WORLD_SIZE_Z, static_cast<std::uint32_t>(std::max(0,worldTick)), geometry_, std::cos(2.0F*Pi*phase));
    optics_.setCanopy(canopy_);
}

const CelestialState& CelestialCycle::state() const noexcept {
    return state_;
}

} // namespace cybernet

