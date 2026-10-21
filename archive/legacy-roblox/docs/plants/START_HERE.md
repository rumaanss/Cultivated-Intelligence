# Intelligent Plant Life v1

This package implements a separate C++ plant ecology publisher, an authenticated channel in the existing relay, native Roblox plant models/renderer, an inspector, terrain export, checkpointing, inherited traits and neural controllers, and an explicit reproduction-intent mode for the existing organisms.

**Start with the model showroom, then the baseline simulation, then neural experiments.** The baseline and authored model fixture are explicitly scripted controls. They demonstrate the machinery and appearance, not evolved intelligence. Neural is the publisher's default policy; random founders may never establish or may go extinct. There is no hidden rescue or automatic reproduction.

## Package contents

- `PlantLifePackage.rbxmx`: Studio installer, renderer modules, inspector, terrain exporter and static showroom data.
- `PlantModels.rbxmx`: the three editable native model examples, with no running scripts.
- `PlantGrowthPreview.png`: render from the actual Lua geometry descriptors, not a Studio screenshot.
- `source/civ0.77/` and `source/ci_rbxl/`: full replacement/new source files.
- `patches/`: Git patches for the reviewed local revisions, with base commits in `BUILD_INFO.json`.
- `FixIslandWarnings.lua`: the earlier Terrain/optional-instance warning fix.
- `ReferenceIslandPackage.rbxmx` and `ISLAND_SETUP.md`: corrected island package for fresh installs.
- `IMPLEMENTATION_NOTES.md`, `VALIDATION.md`, `Benchmark.json`: behavior, limitations and measurements.

No tokens, transport credentials, live checkpoints or Windows executables are included. Build the C++ executable on your machine. No C++ rebuild is required just to inspect the static showroom.

## A. Inspect the models in Studio

1. Extract the zip. Open your existing CI place and stop Play.
2. In Explorer, select **ServerStorage**, right-click → **Insert from File**, then select `PlantLifePackage.rbxmx`.
3. Make sure `PlantLifePackage` is directly under ServerStorage.
4. Open the Command Bar and run:

```lua
require(game.ServerStorage.PlantLifePackage.Install).Showroom()
```

The three examples appear at Y=220; the camera moves to them. Delete `Workspace.CI_PlantShowroom` to remove the display. These shapes were produced by an explicit authored growth-policy fixture with a disclosed generous initial resource provision. They are not a promise that random neural plants will grow into these exact shapes.

For independent editable models, insert `PlantModels.rbxmx`. Its parts are anchored, noncolliding and do not contain simulation scripts. Keep display models separate from live plant render folders.

## B. Apply source changes

Make a local Git checkpoint of your own work first. From each matching repository root, check the corresponding patch before applying it:

```powershell
git apply --check "C:\path\to\PlantLife_v1\patches\civ0.77.patch"
git apply "C:\path\to\PlantLife_v1\patches\civ0.77.patch"
```

Use `ci_rbxl.patch` from the Roblox repository root. If a check fails, do not force it: compare the full replacement files under `source/` with your newer files. The patch is based on the revisions listed in BUILD_INFO.json, not an assumption about later GitHub edits.

Sync Rojo after applying the Roblox source patch. The new `Plants.server.lua` is a separate bootstrap script; it does not replace ServerBootstrap or LiveStateService. Existing transport credentials remain in `Server.LiveTransportConfig` and are never copied to clients.

**Alternative Studio-only install:** after importing the package, run:

```lua
require(game.ServerStorage.PlantLifePackage.Install).Install()
```

Use either source sync or this installer, not both. The installer refuses existing Plant* modules/scripts rather than overwriting them. Studio-only installation still needs your existing server-only LiveTransportConfig and the C++/relay updates. Later Rojo syncs must include the new source files or they can remove Studio-only changes.

## C. Build the C++ plant publisher

From the `civ0.77` repository root, using CMake and a C++20 toolchain:

```powershell
cmake -S tools/plants -B build-plants
cmake --build build-plants --config Release
ctest --test-dir build-plants -C Release --output-on-failure
```

On Visual Studio generators the executable is `build-plants\Release\ci_plant_sim.exe`. On single-configuration Linux/macOS builds it is `build-plants/ci_plant_sim`. The independent plant target does not fetch or require raylib. The root project also includes the plant targets when `CI_BUILD_PLANTS=ON` (default).

## D. Start the relay and export your actual island

Restart the updated relay using your usual live directory and transport setup. For a local Studio setup, from the C++ repository:

```powershell
python tools/live_bridge/relay.py --directory live/state --roblox-root "C:\path\to\ci_rbxl"
```

This reuses the relay's server-only token configuration. Sync the generated LiveTransportConfig with Rojo. Keep HTTP requests enabled in Studio's game settings. Do not expose the local development server publicly; hosted Roblox servers need the existing HTTPS deployment path.

With the island already generated and Play stopped, run in Studio's Command Bar:

```lua
require(game.ReplicatedStorage.Shared.PlantSurfaceExport).Upload()
```

The exporter raycasts **existing Terrain only**, samples the island into 32-stud cells, excludes water/steep ground/the protected pond, and uploads `live/state/plant_surface.txt`. It does not regenerate or edit your island. Soil depth, initial water and nutrient values are initial model assumptions, not measurements extracted from terrain material.

Plants use **Roblox studs with Y up**. This separate habitat does not inherit the microbial simulation's Z-depth coordinate convention. The exported world manifest is persisted inside the plant checkpoint.

## E. Run living plants

For a new, inspectable baseline run on your island:

```powershell
.\build-plants\Release\ci_plant_sim.exe --directory live/state --surface live/state/plant_surface.txt --policy baseline --founders 12 --seed 731 --ticks 0 --interval-ms 100
```

Start Play in Studio. Plant bodies are rendered locally; **P** toggles the nearest-plant inspector, and **R** toggles visible roots while the inspector is open. You may need to move the research camera out from the pond toward the island to see plants. The demo can use all three species.

`--interval-ms 100` controls wall-clock pacing; the ecology timestep is a normalized model step, not a calibrated real-world hour. Growth jobs take four ecology steps. The publisher samples output/checkpoints about every ten steps. The renderer interpolates visual dimensions; it does not change authoritative growth.

Stop the publisher with Ctrl+C. Resume the same ecosystem with:

```powershell
.\build-plants\Release\ci_plant_sim.exe --directory live/state --resume --ticks 0 --interval-ms 100
```

Resume restores saved genomes, traits, hidden neural state, graph, reserves, pending growth, soil, clock and RNG. CLI founder/environment settings do not overwrite a resumed world. A crash or Ctrl+C can lose the steps since the most recent published checkpoint (up to approximately ten steps); checkpoint and snapshot are published in that order. The current implementation does not claim exactly-once audit logging across crashes.

For a new neural experiment, use a **new plant directory**, point the relay at that directory, export the terrain there, and run the same command with `--policy neural`. Do not delete your existing saved ecosystem to switch policies. `--policy wait` is the explicit no-growth/no-reproduction control. To compare policies, use matched seeds, terrain and environment settings. Successful scripted growth is not evidence of a learned strategy.

## F. Existing organisms: reproduction intent

Rebuild the normal `cybernet_sim` executable after applying the C++ replacements. Add this flag to your normal launch command for a **new** run:

```text
--reproduction intent-v2
```

In this explicit mode, neural output 3 must exceed 0.5 before the existing biological reproduction checks can produce offspring. The output used to be reserved. Genome array sizes and checkpoint ABI are unchanged; its interpretation is now versioned by the selected reproduction policy.

`--reproduction legacy-v1` preserves old behavior and remains the compatibility default. The program writes `reproduction.schema` beside live checkpoints and refuses to silently reopen a legacy population with new intent semantics. Use a new live directory to start intent-v2. The policy is also recorded in the research archive. Existing microbial visuals are not changed by this plant package.

## G. Earlier island warnings

With Play stopped, paste all of `FixIslandWarnings.lua` into the Command Bar and run once. This includes the previously prepared Terrain/optional-instance type-narrowing fixes. It updates module sources without rebuilding terrain.

## Disable the plant presentation

Set `ReplicatedStorage.Shared.PlantConfig.Enabled=false` in source and restart Play. Stop the separate C++ publisher if you also want to pause plant ecology. Camera distance, render detail and disabling the client renderer do not pause a running C++ plant world.

## What still needs Studio verification

The native geometry and renderer were exercised with a math/Instance test double, and all supplied Lua scripts passed Luau syntax compilation. Roblox Studio was not available here. Actual import behavior, Studio analyzer diagnostics, visual quality under your lighting and client frame-time measurements are therefore unverified. Windows CMake commands are supplied but the executable was compiled/tested with Linux g++ in this environment.
