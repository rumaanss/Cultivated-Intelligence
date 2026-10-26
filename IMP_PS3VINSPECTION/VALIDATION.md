# Validation — IMP_PS3VINSPECTION-1

Date: 2026-10-26 UTC. Environment: Linux, GCC 13, Release build, native C++ HTTP, standalone Luau and Rojo. No Roblox Studio or Windows/MSVC execution was available here. This is a tested integration candidate, not a certification of the user's running place.

## Completed

| Check | Result |
|---|---|
| Full native suite | **41/41 passed**, 76.25 seconds on this machine |
| Final inspection-index refinement | Both affected tests rerun: Stage3Inspection and NativeInspectionIntegration passed |
| Checkpoint and migration regressions | Existing Stage 3 and PDNARNA migration, exact stochastic resume and runtime-isolation tests passed |
| New native inspection tests | Identity, unknown vs dead, tombstones, child pagination, restart recovery, invalid IDs and page bounds passed |
| Scene light tests | Complete-coverage validation, identity/tick rejection, conflicting retries, open-light equivalence, shade reduction, C/N/P/oxygen/photon validation passed |
| Recorded input | Exact biological checkpoint equality after recorded scene-input replay passed |
| Executable HTTP scene test | Missing-feed pause, six complete input batches, authentication, malformed coverage rejection, recorded tick sequence and four observer regions passed |
| Relay measurement | An earlier instrumented HTTP run measured 33 exchanges: median **1.050 ms**, p95 **1.476 ms**, maximum **1.972 ms** |
| Independent UI state logic | Fresh/stale/disconnected/run-changed and all display classes passed; disappearance cannot generate biological death |
| Changed/new Luau sources | Compilation passed, including the generated geometry fixture |
| Existing Roblox headless behavioral suite | Research UI, frame transforms, solar cycle, interpolation, presentation, sky and celestial checks passed |
| Native-packet renderer replay | Both grazers, all four algal forms, identity reuse, part budgets, offspring visibility, unpaid tissue rejection, terrain hide/recovery and stale cleanup passed |
| Rojo source build | Full source DataModel built successfully; this does not include or replace the user's terrain place |
| PowerShell installer | Preflight, install, repeat install and exact rollback passed for both clean `ac10418` and the grounding-patched baseline, using PowerShell Core on Linux |
| Conflict refusal | A deliberately modified CMakeLists.txt prevented installation without changing any source file |
| Source integrity | `git diff --check` passed; manifest records baseline/accepted/target hashes; no tokens, generated transport credentials or live runtime data included |

The relay measurement is request-processing time, not total simulation CPU, Studio sampling cost, network latency or an investor-hardware guarantee. No per-organism screenshots are taken. Typed native inspection records are published at one-second intervals and only queried records are encoded to JSON. Population growth still increases native index work; measure this separately from the relay before scaling future neural populations.

## Required local acceptance

1. **Windows build:** run the existing Build.ps1 after installation; all native tests must pass under the actual compiler. Installer tests here do not establish MSVC compatibility by themselves.
2. **Terrain:** run all **754 generated geometry probes** in the actual place. Archive the full `CI_GEOMETRY_REPORT`, including missing-hit mismatches, oblique/clearance probes, errors and normals. Thresholds are fixed in the fixture before measurement. Do not use a visual grounding offset as a geometry fix.
3. **Optical controls:** run `InspectionCalibration.Sensors`. Confirm open=1, opaque=0 and declared 0.5 transmission=0.5 for that controlled ray. Move a registered blocker above an occupied water column and confirm native accepted input and PAR/fixation respond after the declared batch delay. Remove it and confirm recovery.
4. **Daylight:** record native tick, intended direction and `EngineDirectionErrorDegrees` at dawn/noon/dusk/night. Initial reference-lake target: at most 5 degrees. Report unreachable engine direction separately; do not declare a decorative sun or matching ClockTime sufficient.
5. **Camera independence:** move the player camera above/below water and change exposure/graphics settings while keeping native tick, pose and scene fixed. Server samples must be unchanged. Changing displayed sample/part budgets must not affect the scalar biological light input.
6. **Inspector:** select a real cohort, leave its interest region, exhaust the display budget, temporarily make terrain unavailable, disconnect/reconnect, restart native, follow a child and query a dead ancestor. Confirm biological status always comes from native records and historical observations remain labelled with their tick/age.
7. **Multiplayer/performance:** use four players and representative populations. Record native tick CPU, relay work, Studio SceneSampleMs, query count, end-to-end delay and memory separately. No player should own the biological light through their client camera.
8. **Pixel capability:** optionally run the client probe and retain its actual result, permissions, Studio version and timing. A successful main-view readback is not yet an independent organism visual feed. Failure must not silently switch the meaning of vision.
9. **Ecology:** compare scene mode and native-reference only in separate matched experiments with recorded inputs. The deliberate scene occlusion changes food supply; existing long-run ecology acceptance is not automatically transferable to this new optical mode.

## Not claimed / deliberately deferred

- Every Roblox triangle, cave, edge and native collision agrees to a pinpoint; finite probes and source hashes cannot prove that.
- Final rendered pixels or engine global illumination feed organism controllers.
- The diagnostic retina sees a complete population of biologically scaled bodies. Such a proxy requires the deferred cell/body-size and phenotype rules.
- Multiple sensory modalities, founder sensory variation, neural consumers, novel sensory biochemistry, a periodic table or IMP_PS3GF.
- A scientific calibration of the 15% diffuse fraction, six-degree batch angular span, individual sub-cell shading, spectral effects, refraction, caustics or local light emitters.
- Investor showcase readiness without running the above checks in the actual place.

## Reproduction commands for developers

```text
cmake -S . -B build/native -DCMAKE_BUILD_TYPE=Release
cmake --build build/native --config Release
ctest --test-dir build/native -C Release --output-on-failure
python tests/native_inspection.py --executable <ci_stage3 path>
luau planet/tests/inspection_state_assertions.lua
python planet/tests/run_checks.py --luau <luau path>
python planet/tests/run_aquatic_checks.py --luau <luau path> --native-packet <native snapshot>
python tests/inspection_installer.py --package <extracted package> --powershell <pwsh path>
```

Python is used for optional offline acceptance and packaging only. Native biology, scene-input processing, lineage queries, recording and relay remain C++; Roblox integration remains Luau.
