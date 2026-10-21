# Delivery validation and practical limits

**Final result: 27/27 native tests passed, all 79 Luau files compiled, and all five Luau behavioral suites passed.**

## Executed here

- Linux GCC 13.3 Release build of the complete headless application, without a Raylib dependency.
- Existing 25 native regression targets covering neural computation, simulation, deterministic workers, chemistry, optics, native movement, lake geometry, plant biology, checkpoint recovery and conservation.
- Native HTTP end-to-end test with a real simulation: authentication, malformed/duplicate JSON rejection, bounded observer membership, selection pinning, exact retry replies, changed-payload rejection, conflicting owners, boot resync, observer-only input, plant packet assembly, checkpoint persistence and restart progression. The test advances to tick 240, then resumes and exits at tick 480.
- Unattended headless runs advance without Studio, resume exactly, and produce matching tested organism state with one and four decision workers.
- Release regression assertions are explicitly enabled, including old tests that otherwise compiled their assertions out.
- All 79 active planet/test Luau files compile. Five behavioral suites pass: research UI, radial frame round trips, solar clock inversion, observation metrics/interpolation, and original species silhouettes.
- The preserved graphical application translation unit passes C++ syntax compilation against its pinned Raylib headers.

The final test log is included in `docs/validation/`. Tests are source/build validation, not a substitute for playing the actual Roblox place.

## Performance evidence

The local founding-cohort test (1,000 cyanobacteria, 60 bacterivores, six Bodo saltans, 96 plants, one decision worker) sustained approximately 30 ticks/second at the configured pacing cap. In a representative completed test run, mean tick computation was 8.2–8.7 ms and recent tick p95 was 11.5–11.9 ms. Local HTTP round-trip median was 15.0–16.3 ms, with p95 19.3–20.2 ms, while deliberately asking for full plant reset data on every exchange. Results vary with host load; the included logs record the final run separately.

These measurements do **not** establish 60 FPS in Roblox, a 16-ms end-to-end observation delay, or the performance of the user's much older evolved population. The old private checkpoint was not available here. The native publisher and HTTP service report zero live exchange-file reads/writes; durable checkpoints still perform file I/O.

The prior logs demonstrate exchange-file access and response-identity failures. They do not demonstrate that Python computation itself was the dominant bottleneck. This delivery removes Python and exchange-file polling from the runtime, then provides profiling to identify the remaining cost on the actual machine.

## Platform/visual checks still required

This environment cannot execute MSVC/Windows, the Roblox engine, or the graphical Raylib window. The supplied PowerShell commands, Windows socket/locking path, actual Rojo synchronization, GPU/frame timing, water appearance and sky seam must be checked in the user's existing Studio place. No "error-free" guarantee is claimed.

The accepted water, physical sun/moon, solar clock and microbial models were preserved. This migration does **not** claim to have solved the reported sky seam. A further visual change without the actual place/view would be speculative and could regress the water/lighting. The existing solar math checks pass, but they do not test engine atmosphere rendering.

Dead plants now render grounded litter and dead organs no longer remain suspended in the canopy. This is a presentation change; their native carbon continues to decompose. Its Luau syntax is validated; ground placement still depends on the existing radial terrain sampling in Studio.

No plant lifespan, maintenance rate, carbon source, or predator population was changed as part of the language migration. Earlier examples of large plants dying included substantial stored carbon and advanced age; changing maintenance blindly would confound the biological research. The existing actual assimilation, maintenance, water, nutrients and age-stress diagnostics remain available for measurement.

## Preserved state and rollback

The current native-v1 checkpoint format and seed are retained. Import copies rather than consumes the old runtime, verifies the copied checkpoint, and refuses to overwrite an existing destination checkpoint. The old simulation must be stopped. Native startup rejects a mismatched habitat.

To roll back, stop the new process and Rojo, reopen the old source/old runtime, and run the previous setup. Do not copy new runtime state back over the preserved original just to roll back. Original terrain/place data was never bundled or rewritten by this package.
