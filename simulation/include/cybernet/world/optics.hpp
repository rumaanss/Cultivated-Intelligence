#pragma once
#include "cybernet/vec3.hpp"
#include "cybernet/world/geometry.hpp"
#include <algorithm>
#include <cmath>
#include <cstdint>
#include <stdexcept>

namespace cybernet {
enum class OpticalModel { LegacyV1, OpticsV2 };
// Normalized broadband research model; coefficients are per simulation-unit.
// These are explicit experimental defaults, NOT measured lake properties or SI PAR.
struct OpticalConfig {
    float directExtinction{0.045F};
    float diffuseExtinction{0.055F};
    float beamExtinction{0.08F};
    float diffuseFraction{0.25F};
    float diffuseTransmission{0.94F};
    float refractiveIndex{1.333F};
    float detectionThreshold{0.015F};
    bool operator==(const OpticalConfig&) const = default;
    void validate() const {
        for (float x : {directExtinction,diffuseExtinction,beamExtinction})
            if (!std::isfinite(x) || x < 0 || x > 10) throw std::invalid_argument("Invalid optical extinction");
        for (float x : {diffuseFraction,diffuseTransmission,detectionThreshold})
            if (!std::isfinite(x) || x < 0 || x > 1) throw std::invalid_argument("Invalid optical fraction");
        if (detectionThreshold <= 0 || !std::isfinite(refractiveIndex) || refractiveIndex <= 1 || refractiveIndex > 2)
            throw std::invalid_argument("Invalid optical index/threshold");
    }
};
struct LightSample {
    float direct{0}, diffuse{0}, photosynthetic{0}, sensor{0};
};
struct VisibilitySample {
    float distance{0}, transmission{0}, signal{0};
    bool detectable{false};
};
// Immutable between celestial updates. No RNG, allocation, engine dependency,
// cached entity pointers or mutable query state. Safe for parallel decisions.
struct CanopyField {virtual ~CanopyField()=default;virtual float transmission(const Vec3&)const noexcept=0;};
class OpticalField {
public:
    OpticalField() = default;
    void setCanopy(const CanopyField* canopy) noexcept { canopy_=canopy; }
    OpticalField(const OpticalConfig& config, float daylight, float moonlight,
                 float surfaceZ, std::uint32_t tick, const GeometryWorld* geometry = nullptr,
                 float sunHorizontal = 0)
        : config_(config), geometry_(geometry), sunHorizontal_(sunHorizontal), surfaceZ_(surfaceZ), tick_(tick) {
        config_.validate();
        if (!std::isfinite(daylight) || daylight < 0 || daylight > 1 ||
            !std::isfinite(moonlight) || moonlight < 0 || moonlight > 1 ||
            !std::isfinite(surfaceZ) || surfaceZ <= 0)
            throw std::invalid_argument("Invalid optical environment");
        // Existing daylight is positive sine elevation. Refract at a flat surface.
        airDaylight_=daylight;airMoonlight_=moonlight*(1-daylight);
        const float cosAir = daylight;
        cosWater_ = std::sqrt(1 - (1-cosAir*cosAir)/(config_.refractiveIndex*config_.refractiveIndex));
        float transmission = 0;
        if (daylight > 0) {
            const float n = config_.refractiveIndex;
            const float rs = (cosAir-n*cosWater_)/(cosAir+n*cosWater_);
            const float rp = (n*cosAir-cosWater_)/(n*cosAir+cosWater_);
            transmission = 1 - 0.5F*(rs*rs+rp*rp);
        }
        directSurface_ = daylight*(1-config_.diffuseFraction)*transmission;
        diffuseSurface_ = daylight*config_.diffuseFraction*config_.diffuseTransmission;
        // Legacy moon floor retained only as a sensor baseline. No lunar photosynthesis.
        moonSurface_ = moonlight*(1-daylight)*config_.diffuseTransmission;
    }
    [[nodiscard]] LightSample sampleLight(const Vec3& position) const noexcept {
        if (!finite(position)) return {};
        const float transmission=canopy_?canopy_->transmission(position):1.F;
        if(position.z>surfaceZ_) {
          LightSample air;air.direct=airDaylight_*(1-config_.diffuseFraction)*transmission;air.diffuse=airDaylight_*config_.diffuseFraction*transmission;air.photosynthetic=air.direct+air.diffuse;air.sensor=std::clamp(air.photosynthetic+airMoonlight_*transmission,0.F,1.F);return air;
        }
        const float depth = std::max(0.0F, surfaceZ_-position.z);
        const float diffuseLoss = std::exp(-config_.diffuseExtinction*depth);
        LightSample s;
        s.direct = directSurface_*std::exp(-config_.directExtinction*depth/cosWater_);
        if (geometry_ != nullptr && s.direct > 0 && depth > 0) {
            const Vec3 surfacePoint = position + Vec3{sunHorizontal_/config_.refractiveIndex,0,cosWater_}*(depth/cosWater_);
            if (geometry_->blocked(position,surfacePoint,true)) s.direct = 0;
        }
        s.diffuse = diffuseSurface_*diffuseLoss;
        s.direct*=transmission;s.diffuse*=transmission;
        s.photosynthetic = std::clamp(s.direct+s.diffuse,0.0F,1.0F);
        s.sensor = std::clamp(s.photosynthetic+moonSurface_*diffuseLoss,0.0F,1.0F);
        return s;
    }
    // Conservative broad-phase bound: target signal cannot exceed observer light.
    [[nodiscard]] float visibilityRange(const Vec3& observer, float maximumRange) const noexcept {
        if (!std::isfinite(maximumRange) || maximumRange < 0) return 0;
        return visibilityRangeForLight(sampleLight(observer).sensor, maximumRange);
    }
    [[nodiscard]] float visibilityRangeForLight(float light, float maximumRange) const noexcept {
        if (!std::isfinite(light) || !std::isfinite(maximumRange) || maximumRange<0) return 0;
        if (light < config_.detectionThreshold) return 0;
        if (config_.beamExtinction == 0) return maximumRange;
        return std::min(maximumRange,std::log(light/config_.detectionThreshold)/config_.beamExtinction);
    }
    // Species-independent point-target signal. Caller supplies geometry LOS;
    // future shared player/object geometry must compute this in C++, not the camera.
    [[nodiscard]] VisibilitySample sampleVisibility(const Vec3& observer,
        const Vec3& target, float maximumRange, bool lineOfSight = true) const noexcept {
        VisibilitySample s;
        if (!finite(observer) || !finite(target) || !std::isfinite(maximumRange) || maximumRange < 0) return s;
        s.distance = std::sqrt((target-observer).lengthSquared());
        if (!std::isfinite(s.distance)) return {};
        s.transmission = std::exp(-config_.beamExtinction*s.distance);
        s.signal = std::min(sampleLight(observer).sensor,sampleLight(target).sensor)*s.transmission;
        s.detectable = lineOfSight && (geometry_ == nullptr || !geometry_->blocked(observer,target,true)) && sampleLight(observer).sensor >= config_.detectionThreshold
            && sampleLight(target).sensor >= config_.detectionThreshold
            && s.distance <= std::min(visibilityRange(observer,maximumRange),visibilityRange(target,maximumRange));
        return s;
    }
    [[nodiscard]] std::uint32_t tick() const noexcept { return tick_; }
    [[nodiscard]] const OpticalConfig& config() const noexcept { return config_; }
private:
    static bool finite(const Vec3& p) noexcept { return std::isfinite(p.x)&&std::isfinite(p.y)&&std::isfinite(p.z); }
    const CanopyField* canopy_{nullptr};
    float airDaylight_{1},airMoonlight_{0};
    OpticalConfig config_{};
    const GeometryWorld* geometry_{nullptr};
    float sunHorizontal_{0};
    float surfaceZ_{60}, cosWater_{1}, directSurface_{0}, diffuseSurface_{0}, moonSurface_{0};
    std::uint32_t tick_{0};
};
} // namespace cybernet
