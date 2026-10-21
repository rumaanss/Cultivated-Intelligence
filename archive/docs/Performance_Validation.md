# Lake performance release — 2026-10-20

## What changed

- Cached validation of the immutable habitat by file metadata. Changed files still invalidate the cache; geometry/dataset/digest binding is checked on each new snapshot.
- Moved planetary microbial movement into C++ with biology. Roblox sends observer heartbeats and consumes authoritative motion. The old full-population Roblox physics loop is removed. Native worlds reject incoming poses, actors and combat events; legacy mode retains its previous protocol.
- Cached static shoreline recovery candidates once per geometry instance. Their positions, row order and nearest-point tie rules are unchanged. This removes repeated terrain evaluation from the recovery path.
- Added conservative Luau sweep rejection and scalar height evaluation; exact contact traversal remains the fallback. Coalesced organism-list refreshes and bounded visual updates.
- Restored original microbial model data/factory under 48-rig, 768-part and distance budgets. Up to 384 nearby microbial markers remain available; detail is cosmetic and does not alter biology.
- Plant inspection displays carbon reserves in model units. Added client frame, state-apply and exchange-error diagnostics. Relay work now measures the combined microbial/plant processing function, excluding response serialization/network transit. HTTP round-trip remains separate.
- Added physical sun/moon presentation and a regional native-lighting fit driven by the biological clock, with underwater scattering coordination. This requires native Studio visual acceptance.
- Fixed resumed benchmark accounting: throughput divides by ticks actually executed, rather than the absolute stop tick.

## Measured performance

Same host and inputs for each before/after pair; these are not Windows/Roblox FPS measurements.

| Workload | Before | After | Scope |
|---|---:|---:|---|
| Warm snapshot load, stored 2,665-agent population | 175.14 ms median | 12.01 ms median | Python load/validation only; ~14.6× faster |
| C++ movement, same mature checkpoint, 100 ticks | 183.31 ms/tick | 4.65 ms/tick | ~39.4× faster; identical final population state hash |
| Entire resumed 100-tick native run | 20.36 s | 3.58 s | ~4.91 to 27.95 ticks/sec; live run targets 30 Hz |
| 30,000 Luau collision sweeps | 2,030.97 ms | 580.82 ms | ~3.5× faster; differential checks below |

The identical C++ final hash was `4245173410283384140`. The profiler attributed most old movement cost to repeated terrain-plane evaluation during shoreline recovery (over 1.3 billion plane calls in its instrumented 100-tick run). Timing comparison uses uninstrumented optimized builds; profiler overhead is excluded.

During two concurrent longer runs, Python `World.load + World.exchange` medians were 20.92 and 14.08 ms, with 95th percentiles 36.06 and 28.52 ms. These include shared-host contention and exclude HTTP, Roblox and plant transfer; they are not end-to-end latency claims.

## Correctness checks

- 10,000 C++ comparisons against the original geometry implementation: exact recovery position, success/failure, final position and velocity, including invalid starts and shoreline cases.
- 10,000 Luau sweep/floor comparisons against the original implementation, including floor crossings, exterior coordinates and zero padding.
- 30,000 reproducible founder samples across three seeds: valid wet positions, identical seeded sampling and occupied-volume fraction.
- Actual native application plus relay advanced 30 ticks; motion advanced in C++, plant tick reached 30, 96 plants were transferred and run/habitat identities matched. Real packets were accepted by the mapped Luau protocols.
- Mature snapshots from both longer runs also passed Luau row, binary display, radial mapping and plant protocol validation.
- Native habitat/plant/checkpoint checks pass under a 1 MiB stack limit. All 64 mapped Luau sources compile. UI checks, 17,472 radial-frame checks and 12,010 solar-clock phase checks pass.
- Habitat cache invalidation, identity rejection and observer-only input tests pass. Existing relay durability/deduplication/lease/quota tests also passed.

The native application was compiled with g++ here. Rebuild and run the included CMake targets on Windows; this environment cannot verify MSVC execution, Studio rendering, Rojo synchronization or actual client/server frame times.

## Smaller founding population: calculation and evidence

The old cohort was `(2500,150,15)`. With `s=0.4`, the new cohort is `(1000,60,6)`, totaling 1,066. The founder sampler selects a shared compact set of conservative wet cells occupying approximately `0.400163` of its total valid sampling volume. Thus initial density relative to the same sampling model is `s / 0.400163 = 0.999593`; initial species ratios are preserved. This is a discrete safe-cell volume calculation, not a measurement of the lake's exact continuous volume.

All three species share that initial patch. Initial ages are reduced to one quarter of the old randomized age, preventing some founders from starting near their maximum lifespan. Subsequent biology, mortality, feeding and reproduction retain their model rules. There is no forced respawn, immortality or population cap.

Two seeded runs reached an absolute stop tick of 5,000:

| Seed | Last published microbial tick | Cyanobacteria | Bacterivores | Bodo |
|---|---:|---:|---:|---:|
| 42 | 5,000 | 1,453 | 617 | 2 |
| 137 | 4,987 | 1,334 | 291 | 16 |

The second publisher is asynchronous; the process completed tick 5,000 but its last microbial packet precedes it. Bodo survived and reproduced in both runs, but seed 42 declined substantially. This profile remains an experiment, not a validated stable equilibrium. Long-horizon, multi-seed trophic calibration remains necessary before claiming persistent planetary ecology. Population can grow above its starting count.

## Installation and acceptance

Follow START_HERE.md. Use `runtime/planet-native-v1`, copying only the matching habitat survey. The new movement authority intentionally changes checkpoint ABI; keep old hybrid checkpoints intact in their old runtime. No replacement `.rbxl` is required.

Measure Studio client frame, server heartbeat interval, exchange HTTP, state application and simulation ticks/sec separately. The target is 60 Hz rendering / 16.7 ms frames, with a 30 Hz biological clock and 6 Hz HTTP exchanges. Interpolation adds presentation buffering; HTTP observations are not guaranteed 16.7 ms old. Confirm stable Live state and record any actual exchange error before changing reconnect policy.

This establishes a regional foundation. Planetary expansion still needs region scheduling, subscriptions, migration and persistence; the present single-world relay's population and packet budgets remain finite. Global atmospheric scattering, fluid dynamics and calibrated predator persistence are not implemented by this performance release.
