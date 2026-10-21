# Planet biology integration

## Implemented

The native `planet_habitat.json` now defines one versioned habitat shared by C++, relay and Roblox. It contains 4,623 sampled columns, 3,596 wet samples and 256 eligible shore cells. Its maximum sampled water depth is 102.58 studs. The microbial simulation bounds are 436 × 212 × 108 local studs, mapped radially onto the existing planet; the rectangular bounds are not a replacement lake surface.

The C++ planet build initializes the existing three microbial species inside a conservative heightfield derived from native samples. It initializes 96 plant founders among the eligible native land cells. Biology, plant growth, resource accounting and clocks remain in C++. C++ now owns microbial movement as well as biology (motionAuthority cpp-v1). Roblox sends an observer heartbeat and consumes authoritative motion; it no longer integrates the whole population every server frame. There are no registered player actors, legacy player controllers, terrain generators or water generators in the new biology mounts.

Plant rendering uses the local radial frame and native terrain raycasts for visual ground placement. Microbial rendering is bounded to 384 nearby organisms; plant rendering is bounded to 64 plants and 2,400 parts. Plant packet transfers are chunked and validated before acceptance. The existing research interface selects both organism kinds and displays timestamped model data. Microbial ages are simulation ticks; plant ages are plant ticks (one plant step per three simulation steps). The plant inspection panel shows its carbon reserve in model units; an energy-capacity percentage remains undefined.

Startup waits for the native habitat export and requires its exact digest. The relay rejects old geometry in the planet runtime directory before granting a simulation lease. The C++ checkpoint ABI includes the habitat digest and cpp-motion-v1. Start this release in runtime/planet-native-v1; preserve prior hybrid checkpoints separately. Plant packets require the generated surface revision and the same run as the microbial stream. Existing checkpoints from the old island are not migrated.

The accepted animated glass, water lighting, movement and camera implementations are retained. The bounded celestial presentation now drives Lighting from the biological clock; biology does not write Terrain or regenerate water. New code lives under `planet/src/biology`, with explicit Rojo mounts. The historical `roblox-legacy` tree remains outside the active project.

## Verification and limits

- Compiled and executed the actual C++ application in planet mode with the relay, advancing 30 world ticks with live microbial state and 96 plants. The last asynchronous microbial snapshot can precede the final tick; the plant world snapshot reached tick 30. The run and habitat identities matched across streams.
- The mapped Roblox manifest, row, binary microbial display and plant protocols accepted the real C++/relay packets. Legacy bounds and plant surface identities were rejected.
- C++ habitat checks cover collision bounds, 20,000 sampled candidate positions, radial-chart coordinate conversion, 96 valid plant founders, deterministic 120-tick plant evolution, checkpoint restoration and manifest identity.
- All mapped Luau sources compile. Existing research UI checks and 17,472 radial frame round trips pass.
- Four preflight endpoint tests and the new relay identity gate test pass.

These checks do not emulate Roblox Studio rendering, engine physics, Rojo synchronization or network deployment. The final native Play check is still required. CMake/MSVC and PGO builds were not run here; the application was compiled with g++ against the supplied raylib headers, with unused graphics code removed by the linker. The Windows build retains its existing raylib dependency.

## Planetary foundation and scientific limits

This is one regional habitat, not global ecology. The contract separates world position, habitat identity, simulation bounds and biology. Additional habitats will require regional scheduling, cross-region migration, resource exchange, per-region stream subscriptions and larger-scale persistence.

The microbial collision floor takes the highest nearby sampled native elevation plus one stud of clearance. This conservatively reduces usable space near slopes and shoreline, but cannot certify unsampled sub-grid terrain detail. No old rock proxies are inserted. Local biology/optics retain their prior models; this does not implement fluid dynamics, global light transport or a calibrated planetary ecosystem. Initial land chemistry values remain model defaults, not measured soil data. The present eligibility mask restricts plant habitat to the surveyed near-lake cells.

## Metric definitions

Server heartbeat Hz and server step ms measure RunService.Heartbeat cadence, not CPU work or client FPS. Relay work ms now prefers the actual combined biology exchange's processing duration; the preflight probe is only a fallback. HTTP round-trip and state-apply measurements are displayed separately. Simulation ticks/s observes publisher tick advancement, resets on run/boot change and is not benchmark throughput. Snapshot age uses the relay host clock and file modification time. An accessible relay does not imply that biology is advancing.

## Source and world ownership

`planet/src/world` contains the accepted world sources plus research inspection/diagnostics. The Bootstrap preflight is composed from `planet/components/PlayerBootstrapBase.lua`, `planet/components/Integration.lua` and the habitat frame module. `tools/build_planet.py` patches only preflight sources into the exact baseline world; it does not embed new biology instances. Sync `planet/default.project.json` to install the biology modules into the current world. No replacement `.rbxl` is needed for this release.

The source ZIP excludes build trees, runtime data, local credentials and PGO output. Merge it over the current source root; preserve those local files. Historical audit documents describe earlier stages and are not the current activation instructions. Use `START_HERE.md`.

## Performance release

See Performance_Implementation_Plan.md and Performance_Validation.md for current changes, measurements and limits. Original microbial designs are restored under distance/part budgets. Initial cohort density is preserved within the conservative founder sampling model by scaling both count and occupied volume to approximately 40%; this is not a long-term stability guarantee.
