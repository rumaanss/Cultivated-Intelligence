#pragma once
#include "cybernet/world/optics.hpp"

namespace cybernet {

struct CelestialState {
    float daylight{1.0F};
    float moonlight{0.08F};
    float ambientLight{1.0F};
    bool isDay{true};
};

class CelestialCycle {
public:
    explicit CelestialCycle(int cycleTicks = 600, float moonlight = 0.08F);

    void update(int worldTick);
    void setCanopy(const CanopyField* canopy) { canopy_=canopy;optics_.setCanopy(canopy); }
    void setGeometry(const GeometryWorld* geometry) { geometry_ = geometry; update(lastTick_); }
    [[nodiscard]] const GeometryWorld* geometry() const noexcept { return geometry_; }
    void setOpticalModel(OpticalModel model, OpticalConfig config = {}) {
        config.validate(); model_ = model; opticalConfig_ = config;
        update(lastTick_);
    }
    [[nodiscard]] bool usesOpticsV2() const noexcept { return model_ == OpticalModel::OpticsV2; }
    [[nodiscard]] const OpticalField& optics() const noexcept { return optics_; }


    [[nodiscard]] const CelestialState& state() const noexcept;

private:
    const CanopyField* canopy_{nullptr};
    const GeometryWorld* geometry_{nullptr};
    OpticalModel model_{OpticalModel::LegacyV1};
    OpticalConfig opticalConfig_{};
    OpticalField optics_{};
    int lastTick_{0};
    int cycleTicks_;
    float moonlight_;
    CelestialState state_{};
};

} // namespace cybernet

