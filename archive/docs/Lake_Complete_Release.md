# Combined lake observation release — 2026-10-20

This release includes the earlier observation patch and the remaining integrated source changes. It accepts either original commit `bd3f3cd8adf93f07f446d113feb19189d9c63cf9` or the earlier patch's file contents, including Windows CRLF line endings. Unknown edits cause a preflight refusal before any source is replaced.

## Install once

Stop Roblox Play, the simulation, the relay and Rojo. Let the simulation exit normally so its checkpoint is saved. Save `apply_ci_lake_complete.py` in the CultivatedIntelligence project root and run:

```powershell
py .\apply_ci_lake_complete.py
if ($LASTEXITCODE -eq 0) { cmake --build simulation/build-planet --config Release --target cybernet_sim }
```

Check that the build finishes successfully before restarting. The updater prints its backup directory under `archives/source-updates`. It changes source only: it does not change runtime files, saved populations, credentials, the surveyed lake, the Roblox place, or PGO folders. Do not rebuild the planet place or generate another island.

Start these in three separate PowerShell terminals at the project root:

```powershell
py simulation/tools/live_bridge/relay.py --directory runtime/planet-native-v1 --roblox-root planet
```

```powershell
rojo serve planet/default.project.json --port 47126
```

```powershell
py tools/run_planet.py --runtime runtime/planet-native-v1
```

Connect/sync Rojo to the existing planet and press Play. Keep Allow HTTP Requests and EditableMesh enabled in the existing experience. The simulation may wait for Roblox authority until Play begins; that is expected. Start only one relay for this runtime.

**Do not use `--ticks 30000` on your restored run.** That argument is an absolute ending tick, not 30,000 additional ticks. Your checkpoint already passed tick 35,459. Omitting the argument resumes the saved run until interrupted.

Optional source rollback, using the exact backup path printed by the installer:

```powershell
py .\apply_ci_lake_complete.py --rollback archives/source-updates/YOUR_BACKUP_DIRECTORY
cmake --build simulation/build-planet --config Release --target cybernet_sim
```

Stop services before rollback as well. Rollback refuses to overwrite files edited after installation. The source backup does not roll back biological time.

## What changes together

- **Bounded upstream observation:** the relay builds a spatial index per native snapshot and sends at most 384 nearby/selected microbes per research observer, up to four concurrent regions. Global population counts remain global. Moving outside the streamed region never kills an organism. Selected organisms are retained in the view. Simulation remains native and retains all organisms.
- **Connection and transport:** acknowledged, unchanged snapshots avoid duplicate motion work; lost responses resend membership and motion; boot fencing rejects stale status. Observer-only retry fingerprints no longer require a durable database transaction each request. Durable ownership and biological event journaling remain intact. Combined exchanges supply telemetry, avoiding an extra snapshot decode/poll each second while healthy. Full phase-specific errors and recent transition history are accessible from Diagnostics. Transient disconnects retain stale data explicitly, rather than presenting a cached pose as current biology.
- **Authored organism identity:** every streamed organism is eligible for an inexpensive silhouette built from its original design. Near and selected organisms use the full authored model; the selected inspection preview also uses that design. Rendering uses pooling, projected-size selection, hysteresis, bounded construction and adaptive high-detail counts. Native detail parts are capped at 2,048, plus at most 12 detached pooled rigs. Markers removed by authoritative membership are cleared. Seed/living/dead plant stages are explicit.
- **Solar and atmospheric presentation:** an unreachable exact zenith no longer aborts the entire sky. Physical sun/moon and sky orientation use the native biological cycle in the surveyed radial frame. Engine fitting yields between samples; the canonical solar direction is also consumed by existing water daylight logic. Existing water surface, animation and scattering settings are retained. The water controller continues to own underwater atmosphere. Photosynthesis is not driven by a decorative Roblox object or by moonlight.
- **Plant resource diagnosis:** actual atmospheric carbon pool, requested/granted uptake, maintenance demand/paid respiration, effective leaf light, water/nutrient factors, age stress, structural carbon and growth requirements are exported through the relay and inspection UI. Generic unfunded decisions become carbon/water/nutrient-limited with identical eligibility decisions. Carbon remains model carbon units, not an invented energy percentage or CO2 ppm.
- **Native sensing:** avoid clearing unused heightfield ray scratch memory and redundant light sampling when the same light result is already available. These changes preserve the tested observation values exactly.

## Biological findings and preservation

Your supplied snapshot contains 3,724 microbes, including 53 Bodo. It does not demonstrate Bodo extinction. The plants show uneven mobile carbon, and at least one seed has no water. A controlled plant-only experiment retained approximately 991,850 of 1,000,000 atmospheric carbon units after 36,000 world ticks; increasing starting atmospheric carbon tenfold produced identical plant outcomes. This is not a replay of the complete coupled ecosystem, but it does not support adding arbitrary atmospheric carbon as a treatment.

This release therefore changes observation and exposes the actual limiting resource. It does not change uptake constants, founder counts, RNG, reproduction, predator survival, chemistry, habitat geometry or checkpoint layout. Runtime diagnostic arrays are intentionally not persisted; they become valid after a resumed biological update. No new species balance or planetary simulation model is claimed.

## Validation completed

- All **25 native CTest tests passed**, including full live checkpoint restoration, recovery/ownership, plants, long producer cycles, pond containment, surveyed habitat and generated geometry.
- **200,000** randomized heightfield rays match the previous implementation exactly for hit, hit fraction and normal.
- **22,344** native sensing observations over six day phases match the original observation hash exactly. A three-run container comparison improved median sensing time from 823 ms to 756 ms, approximately 8%; this is not full simulation throughput or a Roblox frame measurement.
- A **6,000-tick** plant run matches all original biological snapshot fields exactly after excluding additive diagnostic fields and normalizing the more specific limitation labels.
- Original uploaded 3,724-agent data and new native plant diagnostic packets pass mapped Roblox protocol validation and buffer/radial checks.
- All **65** mapped Lua sources compile; UI checks, 17,472 habitat round trips, 12,010 solar phases, reachable non-zenith solar arcs, authored species silhouettes, interpolation and bounded metrics checks pass.
- Relay tests cover exact nearest selection at 10,000 organisms, four-region limits, migration, lost replies, duplicate/changed retry handling, ownership persistence, boot fencing, paged plants, legacy durable events, authentication and quota behavior.
- Actual advancing 3,724-agent fixture: **384** observed records, median response **84,664 bytes**, median relay exchange **24.94 ms**, p95 **29.4 ms** in this container. These measurements include loading/indexing/selection and input publication, but exclude HTTP transit, Roblox decoding and drawing. They are not a promise of 60 FPS.
- Updater checks cover both source baselines, read-only preflight, application, repeat application, source rollback, refusal of unknown edits and recovery from an injected interrupted write.

## Remaining environment verification and scale boundaries

The complete combined source implementation is supplied; a live Studio acceptance run cannot be performed in this environment. Windows/MSVC linking and GPU/Studio execution must happen on your computer. The C++ application translation unit passes syntax compilation; the full application could not link here because the container lacks the X11 development libraries required by the existing raylib dependency. All headless native tests build and run.

During a sustained run, inspect HTTP p95, apply p95, client frame time and displayed state age separately. A 16.67 ms frame budget and a 100 ms local HTTP p95 remain targets, not verified outcomes. The previous intermittent HTTP exception was not captured in full; the Diagnostics history now preserves the exact error. It would be inaccurate to claim every possible reconnect cause has been proven eliminated.

Roblox's engine sun trajectory cannot represent every desired globe direction. Physical celestial objects follow the canonical native direction; engine shadows use a fitted approximation. `CI_PlanetCelestial.EngineDirectionErrorDegrees` exposes the residual, and rays are disabled when the mismatch exceeds five degrees. Multiple-position visual validation remains required before calling lighting globally exact. Photosynthetic light is explicitly the native model's sampled light, not a guarantee of agreement with every rendered terrain shadow.

The new regional observation protocol is a scaling foundation, not a planet-sized simulation: native snapshot ingestion/simulation still have global work and the existing 10,000-agent limit. Four simultaneous research regions are supported; a fifth gets an explicit capacity message. Deterministic planetary migration and partitioned chemistry require their own model design and validation before expansion. No world-size population is silently enabled by this update.
