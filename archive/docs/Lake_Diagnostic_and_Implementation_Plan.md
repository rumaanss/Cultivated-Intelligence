# Lake diagnostic and implementation plan

2026-10-20 · Source commit bd3f3cd8adf93f07f446d113feb19189d9c63cf9

Status: original diagnostic and implementation sequence, retained for traceability. See `Lake_Complete_Release.md` for the combined implementation, validation and explicit Studio/planetary expansion gates.

## Objective and constraints

Keep the accepted animated glass lake, surveyed terrain, player controller, existing organism designs and current saved ecosystem. Restore dependable observation before changing biological parameters. C++ remains the biological authority. No new island/water generation, silent population resets, forced predator respawns or unmeasured carbon additions. Build regional interfaces that can expand to a planet without sending a planet-sized population to each observer.

## Evidence and findings

Inputs: source repository; uploaded Studio output and six-minute video; snapshot.json, plants.json, bridge_status.json and matching habitat survey. The files are not an atomic capture, and their upload time does not establish their original capture order.

| Finding | Evidence | Confidence / limitation |
|---|---|---|
| Simulator can pause because observer input expires | live_bridge.cpp refuses a tick when input is older than three seconds. Uploaded status is stale-input with inputAgeMs 3463825.8, approximately 57m44s. | Confirmed state in that status file. It could reflect stopping Studio while collecting files; does not explain every video interruption. |
| Current packets are valid | Actual snapshot passes Python relay load, all 3724 rows pass Luau LiveProtocol and radial mapping, first 384 pass buffer round-trip, and actual plant relay packet passes PlantProtocol. | Rules out a persistent malformed-packet problem in this capture, not transient I/O/session failures. |
| Frame work remains too expensive while Live | Video samples show client frame time about 27–35ms, state apply about 30–40ms, simulation about 5–7 ticks/s; one sample shows HTTP 116.9ms and relay 65.1ms. | Sampled dashboard values, not a complete profiler trace or percentiles. An apply callback duration is not automatically identical to a render-frame duration. |
| Reconnection diagnosis loses evidence | LiveStateService clears CI_LiveError after each success. Sampled video panels read None. | Confirmed observability defect. No exact intermittent exception established. |
| Celestial initialization aborts | Studio warns “Regional solar fit unavailable”; Celestial.client.lua returns before creating celestial bodies/atmosphere and updating the clock when fit.maximum < .99 or fit.minimum >= 0. | Confirmed failure path. Engine direction reachability versus immediate update timing still needs a Studio experiment. |
| Spheres are often intentional fallback rendering | AgentDetail permits 48 rigs / 768 parts; remaining live markers are balls even within the general visibility range. | Confirmed. Does not prove every visible sphere is a live organism. |
| Dead-marker leak not established | Full membership packets remove absent IDs; stale feeds can leave last-known markers frozen. | Need compare displayed ID against authoritative membership and boot/sequence. |
| Selected orange object is consistent with a seed | Video inspection identifies plant P131; stage-zero asset is a small orange ball. | High confidence from selection/asset match. P131 is absent from the later snapshot, so its exact earlier stage cannot be verified from that file. |
| Plant carbon is uneven | At world tick 35445: 41 plants, including 39 active, one seed and one dead; 15 non-dead plants have mobile C < .12, 11 have C > 100, maximum 3092.93. Seventeen decisions say unfunded. | Confirmed resource distribution. Unfunded is not specific to carbon; water/nutrient/action costs can also block growth. |
| Atmospheric exhaustion is not demonstrated | Actual atmosphere pool is absent from these exports. Plant ledger C = expected C = 8625.24433. | Ledger equality supports this accounting check, not ecological stability or proof of adequate atmosphere. |
| Bodo are present | At tick 35459: 3452 cyanobacteria, 219 bacterivores, 53 Bodo; total 3724. | One snapshot cannot establish long-run persistence, extinction risk or balance. |

The microbial and plant world ticks differ by 14, consistent with separate publication cadence; this alone is not evidence of clock drift. Run IDs and habitat digest match. Snapshot state “running” is the last published state, and is not proof that a later bridge status is healthy.

### Controlled carbon experiment

An isolated 36000-world-tick plant run using the surveyed surface and current optical/plant code retained approximately 991850 atmospheric carbon units out of one million. Repeating with ten million initial units produced an identical final plant-state hash. This excludes full microbial coupling and is not a replay of the user's ecosystem. It demonstrates that a simple CO2 increase does not remedy these plant outcomes in that controlled model.

The current uptake function caps requested carbon against an available pool; it does not implement an atmospheric concentration response unless the pool becomes limiting. Leaf area/health, light, water, nutrients, maintenance, growth policy and age therefore need separate accounting. At plant tick 11815, species-specific aging is also material. Do not reinterpret model carbon units as measured atmospheric ppm.

## Implementation order

### 0. Preserve and establish a repeatable baseline

Create a development branch from the audited commit. Snapshot the stopped runtime/checkpoint with run, boot, habitat digest and schema identity. Keep the accepted place as the visual reference. Replay the supplied mature population alongside a fresh run. Record hardware, graphics quality, camera route, organism counts and water settings for comparable benchmarks.

Deliverable: one reproducible baseline command and a recorded research route, with frame/transport/simulation timings separated. No world reset required.

### 1. Make interruptions diagnosable and recovery reliable

Primary files: simulation/src/simulation/live_bridge.cpp; simulation/tools/live_bridge/relay.py and platform_io.py; planet/src/biology/server/LiveStateService.lua; research telemetry/UI.

* Retain a bounded transition/error history with error class, timestamp, run, boot, session, batch, sequence and tick. Never record credentials. Track last success separately from last failure.
* Distinguish connected transport, advancing simulation, intentionally paused observation, stale publisher, validation failure and fenced owner. A healthy HTTP response must not label frozen biology as live.
* Publish coherent status timestamps and boot identity, observer heartbeat age, publication age and tick duration. Carry these into the research GUI.
* Instrument request/queue, JSON decode, validation, state apply, disk publish and C++ phases independently. Capture p50/p95/p99 rather than a single changing number.
* Ensure expensive state response work cannot indefinitely starve lease/heartbeat renewal. If separating heartbeat from state transport, retain authentication, owner fencing and monotonic counters. Never let an arbitrary second observer renew the active owner's lease.
* Preserve the deliberate pause-on-observer-loss policy by default. An independent headless mode is an explicit setting, not removal of stale-input checks.
* Reproduce transient file replacement failures, delayed HTTP, duplicate requests, restart, stale boot, owner takeover and Stop/Play. Retry only transient errors; retain deterministic protocol failures for investigation.

Gate: a 60-minute active-observer run has no unexplained reconnect/pause; injected disconnects produce a specific recorded reason and recover without resetting populations or duplicating updates. Do not claim the intermittent root cause fixed until the captured transition identifies it.

### 2. Remove whole-population work from the observation path

Primary files: relay.py, LiveStateService.lua, LiveProtocol.lua, Microbes.client.lua; native publishing/phase timings.

* Cache immutable geometry by digest and validated snapshots by sequence. Repeated delivery of the same sequence must not redo full state application or reset interpolation timestamps.
* Maintain a spatial index on authoritative changes. Select observer regions upstream so Roblox receives bounded local state, with a separate inspection record for the selected organism. Keep global aggregate counters separate.
* Use bounded deltas with explicit base sequence and reliable membership/removal reconciliation. On a gap, request a region reset. Region exit is not organism death.
* Avoid repeatedly sorting/validating every organism per observer fetch. Share indexing and encoding work where safe.
* Replace the fixed first-64 partial-update preference with fair rotating or age-prioritized delivery; always prioritize the inspected organism. Otherwise lower-ranked organisms receive updates much less often.
* Interpolate between genuine simulation samples using tick/sequence and receive times. Bound extrapolation; stop honestly when stale. Do not invent motion or alter biological tick rate to hide lag.
* Profile C++ chemistry, sensing, reproduction, collision, serialization and publishing separately before choosing further native optimizations. Preserve deterministic ordering and compare state hashes where appropriate.

Gate: at the observed population and fixed hardware, target client p95 frame <=16.67ms, biology application <=2ms per frame at p95, and local HTTP round-trip <=100ms at p95 as initial engineering budgets, not promises. Report end-to-end displayed state age separately. Keep queue/memory bounded; compare 1k/4k/10k observation loads. Test configured simulation throughput independently of rendering FPS. If a budget is missed, publish the measured bottleneck rather than relabeling its metric.

### 3. Restore organism identity and inspection

Primary files: AgentDetail.client.lua, Microbes.client.lua, plant renderer and organism inspection provider.

* Reuse original detailed designs close to the camera; reserve a detail slot for the selected organism.
* Replace generic sphere-only intermediate LOD with inexpensive species-specific silhouettes. Use projected size, hysteresis, pooling and per-frame creation budgets.
* Expose ID, species, lifecycle stage, detail level and data age on inspection. Mark cached values stale instead of silently blanking them.
* Reconcile removals against authoritative membership; clear old boot/run entities. Retain biological corpses only if explicitly represented in authoritative state, with a clear dead-state display.
* Keep decorative lake particles unselectable and distinguish their visual ownership from organisms.
* Label seeds, living plants and dead plants. Display mobile carbon, structural carbon and growth limitation separately; carbon is not interchangeable with energy.

Gate: selected organisms get their designed model; crowding does not make all species visually identical; known removals disappear at the next committed membership update; connection failure shows stale observation rather than falsely declaring death. Preserve the Phase 2 frame budget.

### 4. Restore a shared biological and visual solar cycle

Primary files: Celestial.client.lua, SolarClock.lua, native world/celestial.cpp and optical/light export.

* Measure actual engine sun direction over clock/latitude samples in Studio, allowing engine updates between samples. Log fit residuals and the failure cause.
* Separate physical sky/body creation from the engine-fit adapter so an unavailable fit cannot disable the entire presentation.
* Establish a canonical simulation solar direction, phase and irradiance interface. For a globe, local elevation derives from dot(local radial up, sun direction). Regional adapters consume that interface; avoid treating one lake's zenith as the entire planet's zenith.
* Prefer mapping the engine light trajectory into the biological frame where scientifically consistent. If the engine cannot represent a requested direction, disclose the visual approximation and test it; drawing a sun sphere alone does not align shadows or irradiance.
* Restore sun/moon, sky and atmospheric appearance using that clock. Hold phase during paused biology. Moonlight may affect sensors but must not accidentally become photosynthetic sunlight.
* Coordinate ownership of atmosphere, scattering and postprocessing with the accepted water controller. Match dawn/noon/dusk/night and above/below-water transitions.
* Expose actual plant light input in inspection. Current air-light/canopy model does not automatically match all rendered terrain shadows; track this limitation explicitly.

Gate: visible daytime agrees with model daytime throughout a complete cycle; exported photosynthetic input is zero at model night; sun direction/elevation residual is measured; underwater appearance and accepted water animation remain intact. Repeat at multiple radial positions before claiming planetary lighting correctness.

### 5. Diagnose and then tune plant/ecosystem budgets

Primary files: plant_world.cpp, chemistry.cpp, plant export/protocol and organism GUI.

* Export atmospheric pool, uptake requested/granted, assimilation, respiration, structural investment, seed investment, canopy light, leaf health, water/nutrient limitations and age stress.
* Replace generic unfunded with explicit limiting resource and required/available amounts. Preserve original decision information.
* For each plant record the budget: delta mobile C = assimilation - respiration - construction - reproduction + returned resources. Separate transfers from carbon creation/destruction in whole-world accounting.
* Investigate plants with almost no carbon versus successful neighbors before changing parameters. Check first-leaf viability, maintenance obligations, light interception, age and policy choices; P275 also has zero water in the capture, illustrating a different constraint.
* Introduce any biological adjustment as a versioned model change with a control run. A concentration-based CO2 law requires documented units and calibration, not a larger arbitrary pool.
* Track species births/deaths and causes, biomass, prey/predator ratios, nutrient recycling and extinction frequency across multiple seeds and several lifetimes. Current Bodo count 53 is encouraging but not proof of stability.

Gate: resource budgets close within declared numerical tolerance, displayed limitation agrees with source values, and control/changed runs quantify effects. No ecological change ships merely because plants look larger or counts stop declining.

### 6. Planetary expansion gate

Use region/habitat IDs, versioned geometry, one global clock, deterministic migration and regional material/energy budgets. Separate simulation partitioning from observer streaming. Test two regions and ownership transfer before adding world-sized population. Bound per-observer CPU, bandwidth and instance counts regardless of total population; document any remaining global O(N) simulation cost.

## Release and rollback

Implement each phase as a small reviewable commit with relevant automated checks and a Studio acceptance record. Keep transport, rendering, sky and biological parameter changes separable. Transport/render changes must preserve biology; model changes need explicit version/migration handling. Roll back the latest phase if it regresses water, habitat containment, deterministic outcomes, frame budgets or accounting. Do not overwrite a live checkpoint as a debugging step.

## Verification performed in this diagnostic

* Actual 3724-agent snapshot accepted by Python relay habitat/row validation.
* Actual snapshot accepted by Luau manifest/row checks and radial coordinate round trips; first 384 organisms passed binary buffer pack/unpack.
* Actual plant file converted through PlantChannel and accepted by Luau PlantProtocol.
* Controlled plant carbon experiment and tenfold-atmosphere comparison described above.
* Source tracing, supplied output review and sampled video telemetry.

Not performed: live Roblox profiler capture, a reproduced reconnect exception, a GPU/frame benchmark on the user's machine, or proof that every observed sphere was orphaned.

## External references

Roblox official performance guidance uses 16.67ms as the frame duration for 60 FPS and recommends MicroProfiler analysis rather than conflating networking delay with frame time:
https://create.roblox.com/docs/performance-optimization/identify
https://create.roblox.com/docs/performance-optimization/microprofiler/use-microprofiler

Official Lighting API describes ClockTime, GeographicLatitude and GetSunDirection; it does not establish that the current regional fitting algorithm is valid for every spherical orientation:
https://create.roblox.com/docs/reference/engine/classes/Lighting
