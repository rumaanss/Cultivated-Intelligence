#pragma once
#include "cybernet/simulation/snapshot_recorder.hpp"
#ifdef CI_FULL_POND
#include "cybernet/world/pond_geometry_generated.hpp"
#endif
namespace cybernet {
inline std::string liveManifest(std::uint64_t seed,const std::string& run) {
 const auto model=OpticalModel::OpticsV2; const OpticalConfig opticalConfig{}; const bool geometry=true,lake=true;const int interval=1;
        std::ostringstream out;
        out.imbue(std::locale::classic());
        out << std::setprecision(std::numeric_limits<float>::max_digits10)
            << "{\"type\":\"header\",\"schemaVersion\":" << (geometry ? 3 : model == OpticalModel::OpticsV2 ? 2 : 1) << ",\"runId\":\"" << run
            << "\",\"seed\":\"" << seed << "\",\"modelVersion\":\"civ0.77-live-hybrid-v1.0\","
            << "\"bounds\":[" << config::WORLD_SIZE_X << ',' << config::WORLD_SIZE_Y << ',' << config::WORLD_SIZE_Z
            << "],\"coordinates\":\"xyz-z-up\",\"positionUnit\":\"simulation-unit\","
            << "\"velocityUnit\":\"simulation-unit/tick\",\"energyUnit\":\"model-energy\",\"timeUnit\":\"tick\","
            << "\"sampleStage\":\"end-of-tick\",\"opticalModel\":\"" << (geometry ? "normalized-flat-water-geometry-v3" : model == OpticalModel::OpticsV2 ? "normalized-flat-water-v2" : "legacy-linear-depth40-global-vision-v1") << "\","
            << "\"cycleTicks\":" << config::DAY_NIGHT_CYCLE_TICKS << ",\"moonlight\":" << config::MOONLIGHT_LEVEL
            << ",\"intervalTicks\":" << interval << ",\"agentColumns\":[\"id\",\"species\",\"x\",\"y\",\"z\","
            << "\"vx\",\"vy\",\"vz\",\"energy\",\"ageTicks\",\"parentId\",\"generation\",\"birthTick\"";
        if (model == OpticalModel::OpticsV2) {
            out << ",\"opticalTick\",\"sensorLight\",\"photosyntheticLight\",\"photosyntheticEnergy\"],"
                << "\"opticalStages\":[\"pre-movement\",\"post-movement\",\"actual-gain\"],"
                << "\"opticalParameters\":[" << opticalConfig.directExtinction << ',' << opticalConfig.diffuseExtinction
                << ',' << opticalConfig.beamExtinction << ',' << opticalConfig.diffuseFraction << ','
                << opticalConfig.diffuseTransmission << ',' << opticalConfig.refractiveIndex << ',' << opticalConfig.detectionThreshold << "]";
            if (geometry) out << ",\"geometry\":" <<
#ifdef CI_FULL_POND
                pond_geometry::Json;
#else
                (lake ? lake_geometry::Json : shared_geometry::Json);
#endif
#ifdef CI_PLANET_LAKE
            out << ",\"motionAuthority\":\"cpp-v1\"";
#endif
            out << "}";
        } else out << "]}";
 return out.str();
}
}
