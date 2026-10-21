# Validation

## Passed

- 18 CTest tests: neural brains, chemistry, physics, ecology, lifecycle, CLI parsing, metrics, asynchronous recording, selection, spawning, deterministic simulation, spatial grid, island integration, live bridge, optics, live checkpoints, plant biology, and reproduction intent.
- Island integration: exact island bounds, land-only initial plants, distinct neural policy, shared clock, air/water optics, shared canopy, plant–atmosphere carbon accounting, conservative soil-to-pond mineral transfer, explicit wait autonomy, combined checkpoint corruption rejection, deterministic restore/replay, and exclusive plant publishing. The live-checkpoint test also writes plant payloads to disk, restores them through LiveBridge, and verifies asynchronous plants.json publication.
- Six agent designs: actual Luau rig creation and teardown, 80 poses per design, collision-radius envelopes, mesh/joint data, and species metadata integration.
- Actual Luau plant geometry and renderer against the real C++ initial island snapshot: stable part identity, part budget, teardown, protocol delta bases, and duplicate-ID rejection.
- Actual local HTTP relay tests: authentication, full plant state, delta/removal, unchanged response, run reset, terrain ingestion, and invalid terrain rejection.
- `src/main.cpp` syntax compilation with the real raylib 5.5 header.
- All Roblox source files and the generated Studio migration script passed Luau syntax compilation.
- Source diffs passed whitespace/error checks; delivery contains source/documentation only, without credentials, runtime checkpoints or compiled executables.

## Review corrections

- Avoided exposing Windows headers to raylib through the publisher-lock header.
- Removed duplicate plant-only canopy rebuilding when the island supplies shared optics.
- Reused runoff buffers and published plant state at two updates per second rather than every biological step.
- Corrected microbial resource support after usable carbon exhaustion and limited recorded uptake to available reactants.
- Replaced a stale hardcoded lake-contact test with the current geometry's contact height while retaining penetration/quarantine assertions.
- Added one combined checksum-protected checkpoint for microbes, plants, chemistry and clock; old checkpoint formats are explicitly rejected.

## Not verified here

Roblox Studio and Windows/MSVC execution were unavailable. Luau syntax compilation is not Studio type analysis. The patch addresses the exact warning sources shown, but a zero-warning Studio count must be checked after source sync and migration. The complete graphical raylib application was not linked/run here because the Linux environment lacks X11 development dependencies; backend targets and the application translation unit were checked separately. Installation includes the Windows build/test commands.

This validates an integrated research-model foundation. It does not establish biological realism, evolutionary success, calibrated planetary chemistry, or a particular frame rate on the user's hardware. See ARCHITECTURE_AND_LIMITS.md for the exact implemented and unimplemented environmental behavior.
