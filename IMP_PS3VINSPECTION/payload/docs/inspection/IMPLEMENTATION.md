# Integrated implementation record

This document supplements the saved IMP_PS3VINSPECTION plan. It records the actual delivered scope and remaining acceptance gates, rather than converting the original plan into a claim that every engine feature has been demonstrated.

## Included changes

1. **Inspection:** native status/lineage endpoint; bounded child pages; durable birth/death facts from existing ancestry; pinned native identity; explicit parent/child navigation; independent biological, connection and display states; RNA/protein/expression and C/N/P available in query output; compact lineage UI with native pose, cohort equivalents, PAR and cosmetic grounding correction.
2. **Shared world:** existing geometry retained; native fixture generator; 754 radial, oblique, shoreline and clearance probes; Studio position/normal/transform comparison; live occupied-column height diagnostics. There is no terrain overwrite or unrequested geometry redesign.
3. **Sensing/light:** versioned authenticated sensor input; server-only native-defined column samples; optical-surface registry; scalar scene-light assimilation into existing native photon accounting; separate native-reference/scene/replay modes; explicit pause on missing input; per-boot recording; exact replay validation; selected-pose 16-ray administrative diagnostic; common world-illumination owner and separate cosmetic water grading; opt-in pixel capability test.
4. **Delivery:** same-root launch flags; reviewed hash-based overlay; accepted original/grounding-patched baselines; exact backups and conflict-protected rollback; source/validation/calibration documents; no generated credentials, worlds or runtime checkpoint payloads.

## Source map

| Responsibility | Primary source |
|---|---|
| Native physiology light and persistence | simulation/src/aquatic/stage3.cpp |
| Inspection index, queries, sensor validation/replay | simulation/src/aquatic/inspection.cpp |
| Native lifecycle wiring and mode persistence | applications/stage3/main.cpp |
| Authenticated extension routes | transport/src/native_server.cpp |
| Roblox server observations and client query relay | planet/src/biology/server/InspectionService.lua |
| Native-identity lineage panel | planet/src/biology/client/Inspection.client.lua |
| State axes | planet/src/biology/shared/InspectionState.lua |
| Illumination ownership | planet/src/biology/shared/WorldLighting.lua |
| Physical comparison | tools/inspection/geometry_probe.cpp and InspectionCalibration.lua |
| Pixel capability gate | planet/src/biology/client/PixelCapability.client.lua |

## Next acceptance boundary

Install and validate this candidate in the actual Roblox place and Windows build. Resolve measured geometry or engine-direction failures before claiming shared-world accuracy. Establish the world's governing physical/biological science before adding sensory modalities, founder sensory diversity, biological vision proxies or genetic sensor trade-offs. Keep the existing IMP_PS3GF plan separate.
