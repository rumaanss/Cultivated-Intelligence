# Planet integration: preliminary audit and implementation plan

Status: source audit in progress, 20 October 2026. Parts 5–9 pending. This is not a completed full-project audit or an implemented integration.

## Baseline and scope

The user confirms planet0bc4_glass.rbxl is the current world. Preserve its terrain, accepted research GUI, R6 movement and radial camera. Integrate microbes into its existing lake and initially seed plants on suitable nearby land. Preserve water appearance while adapting the earlier presentation package. Do not run legacy island/basin/water generation. Design habitats as individually addressable regions for future planetary expansion.

No world or production source has been changed during this preliminary audit. Original archives remain intact. Source-only working copies have been extracted separately for inspection.

## Received inventory

| Archive | Files | Main contents | Treatment |
|---|---:|---|---|
| CI_Ecosystem_Update(2).zip | 2,055 | Combined source and 1,801 build-ecosystem files | Compare source, exclude builds from canonical source |
| ci_rbxl(1).zip | 201 | Roblox source, assets, docs, tools and distribution | Candidate Roblox source, reconcile against embedded world |
| c++cipart1.zip | 231 | C++ headers/source, relay tools, runtime directories | Extract source; separate runtime state and credentials |
| c++cipart2.zip | 16 | Build configuration, README and miscellaneous files | Reconcile configuration; classify loose files |
| c++cipart3.zip | 931 | Primarily generated builds and dependencies | Preserve archive; do not treat binaries as source |
| c++cipart4.zip | 758 | Experiment output, primarily CSV | Keep outside source repository |

Parts 3 and 4 alone expand to approximately 1.32 GB. Keeping generated outputs separate will remove much of the apparent project complexity. Nine token files occur in part 1; their contents were not printed or copied into the extracted source tree. Deployment credentials belong in local ignored configuration, never a distributable project package.

Source comparison: 69 shared files between the C++ source and ecosystem C++ copy are byte-identical. Of 96 shared Roblox files, 94 match; .gitignore and src/server/LiveTransportConfig.lua differ. This comparison establishes overlap only, not which package is authoritative for every unique file. Transport values must be reconciled without exposing secrets.

## Verified findings

1. **Legacy startup creates another environment.** Roblox src/client/Controllers/CartesianBasinController.client.lua constructs water, seabed, particles, backdrop, lighting and celestial presentation. It calls Water.new with SurfaceY=0. Keeping this controller active in the planet would create an unwanted flat environment.
2. **Coordinate conversion is incompatible with the planet.** src/shared/SimulationSpace.lua maps simulation x/y to Roblox X/Z about the origin, maps z to global Y, and computes depth using global Y. Positions, headings, velocity, depth, picking and player interaction require a common planet-aware adapter, not just a visual translation.
3. **Rojo currently installs auto-starting legacy controllers.** default.project.json maps src/client into StarterPlayerScripts/Client alongside existing content. ResearchCameraController and other LocalScripts can run alongside the accepted planet player. ignoreUnknownInstances does not disable those new scripts or resolve ownership conflicts.
4. **Biology and transport are enabled in legacy configuration.** LiveConfig.Enabled and PlantConfig.Enabled are true. Connection and spawning need explicit staged readiness gates before this configuration is used with the planet.
5. **Plant initialization is tied to the old island contract.** C++ main.cpp initializes IslandWorld from --island-surface, requires live mode, lake geometry and optics v2, and validates checkpoint clock relationships. Existing checkpoints cannot simply be assumed compatible with the new habitat.
6. **Useful telemetry already exists.** relay.py returns relayTimingMs; LiveStateService measures HTTP round-trip time and sends timing, payload sizes and pending event count. LiveController displays these in its own label. Reuse the data path in the accepted research interface, remove competing UI ownership, and add missing authoritative performance measurements.
7. **Benchmark throughput is not live server speed.** C++ performance_metrics.csv includes elapsed time and ticks/second for performance reporting. GUI live metrics must explicitly identify their sampling window and source instead of treating benchmark values as current telemetry.
8. **Water presentation still requires a focused comparison.** The current glass adaptation does not contain the complete earlier custom sky/moon-glint presentation. Duplicate presentation folders seen in screenshots require lifecycle investigation; their cause is not established by screenshots alone.

## Proposed canonical layout

| Directory | Ownership and contents |
|---|---|
| apps/roblox/ | Rojo project, planet client/server modules, assets and Studio tools |
| apps/simulation/ | C++ source, headers and CMake configuration |
| services/relay/ | Python relay, deployment templates and relay tests |
| contracts/ | Versioned habitat, geometry, units, telemetry and transport schemas |
| tools/ | Exporters, generators, packaging and validation commands |
| tests/ | Cross-component fixtures and integration tests; component tests may stay with their component |
| docs/ | Setup, architecture, audit, migration and troubleshooting |
| worlds/ | Baseline manifest and world references; large rbxl files stored as release assets or appropriate large-file storage |
| archive/ | Historical source packages outside active build/sync paths |
| build/ | Ignored generated build trees and dependency downloads |
| runtime/ | Ignored live sessions, locks, checkpoints and local credentials |
| results/ | Ignored experiment output and recordings, retained separately when valuable |
| dist/ | Generated release packages, never a second editable source of truth |

The structure above is a target, not a completed migration. Reconcile all incoming parts first; moving files now could break CMake paths, relay launch scripts and Rojo mappings. Then migrate with a source provenance manifest, update references, and verify packaging and builds. Preserve originals until verification succeeds.

## Ordered implementation plan and gates

1. **Complete inventory and authority mapping.** Receive parts 5–9; inventory paths, sizes and hashes; identify unique files and differing copies. Compare Roblox source with active scripts embedded in the baseline world. Classify tests actually available versus intentionally omitted. Gate: every active module has an identified source and owner; no silent overwrites.
2. **Make the baseline reproducible.** Record baseline world hash, active script inventory, terrain serialization checks, GUI and camera expectations. Capture existing water settings and runtime instance counts. Gate: a repeatable baseline package and rollback exist.
3. **Separate startup responsibilities.** Establish one owner each for planet movement/camera, water presentation, organism rendering, plant rendering and diagnostics. Exclude legacy basin, island generation, camera and extra UI scripts from the planet Rojo project. Gate: connect/sync/restart creates no old terrain or duplicate presentation roots.
4. **Define the habitat contract.** Include habitat ID, schema version, planet center/radius, lake frame, local coordinates, declared units, water surface/depth and validated floor/shore mask. Establish forward/inverse position and direction conversion. Resolve terrain UnitsPerStud versus player MetresPerStud before assigning physical meaning. Gate: round-trip positions and valid submerged/land locations agree across C++, relay and Roblox.
5. **Reconcile geometry and presentation.** Use the actual existing lake mask and floor data as the habitat authority. Adapt old water lighting/sky/reflection effects to radial depth and local surface normals, with one lifecycle-managed presentation owner. Keep ambient luminous decoration distinct from simulated organisms. Gate: lake coverage and shore/depth queries pass; appearance, enter/exit transitions and duplicate-free restart pass in Studio.
6. **Connect transport with biology gated off.** Negotiate compatible habitat/schema IDs; reject stale or mismatched geometry/checkpoints clearly. Confirm reconnect, sequence handling and server-side validation. Keep connection readiness separate from permission to initialize biology. Gate: transport runs without generating environment or changing accepted player controls.
7. **Integrate diagnostics into the existing GUI.** Show C++ tick and measured ticks/s, relay work ms, HTTP round-trip ms, exchange rate, snapshot age, payload size/pending events, and measured Roblox server step timing. Label unavailable and stale values explicitly; do not substitute zero for missing measurements. Distinguish client FPS from server performance. Gate: values trace to real measurements and visibly change on stall/reconnect.
8. **Enable microbes in the verified habitat.** Initialize only within valid wet cells above the floor and below the surface; check collision and ecology queries against the same geometry contract. Keep old checkpoints isolated unless an explicit validated migration exists. Gate: deterministic fixed-seed placement, no organisms outside the lake, stable reconnect and restart.
9. **Enable nearby plants.** Export suitable land around the lake with local normals, slope, wetness and exclusion rules. Apply seeded near-lake placement initially; preserve simulation ownership and publisher locking. Gate: no plants underwater, embedded in terrain or scattered over the old island coordinates.
10. **Consolidate and deliver.** Move verified sources into the canonical layout, update build/sync/install paths, package source and revised world with setup and rollback instructions. Run available targeted checks plus required Studio checks. Record unverified items plainly. Gate: fresh setup succeeds and the accepted terrain/GUI/camera remain intact.

## Planet-scale foundations

Use a habitat registry and shared contracts rather than a second planet-wide hard-coded coordinate system. Region-local simulation can be introduced with explicit transforms and stable IDs. Design bounded updates, spatial subscriptions and independent presentation lifecycles now; defer full-planet scheduling and cross-region transport until measured needs justify them. Do not allocate detailed simulation or render every organism across the whole planet merely to support one lake.

## Validation limits and remaining inputs

This preliminary pass is static source inspection and archive comparison. No C++ build, live relay run or native Roblox Studio visual/physics validation has been completed for this integration. Remaining C++ parts are the immediate required input. Native Studio validation will be needed before claiming the final water appearance, camera and runtime integration are verified. Tests omitted by the user will be listed as unavailable rather than reported as passed.
