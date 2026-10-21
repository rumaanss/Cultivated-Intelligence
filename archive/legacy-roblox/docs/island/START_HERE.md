# Unified island ecosystem — installation

Built against C++ commit `49051c1` and Roblox commit `d0a0c70`. This is a source replacement package, not Windows executables. No GitHub changes were pushed.

## 1. Install source replacements

Stop Studio Play, the organism executable, the old plant executable, and the relay. Disconnect Rojo temporarily.

- Copy the CONTENTS of `cpp/` into `E:\cultivated_intelligence\ci_c++_v0.77`.
- Copy the CONTENTS of `roblox/` into `E:\cultivated_intelligence\ci_rbxl`.
- Preserve subfolders and replace matching files. Do not copy the Roblox folder into the C++ repository.

From the Roblox repository run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\island\FixBootstrapSource.ps1
```

This narrowly fixes the legacy bootstrap's `player.Name` formatting argument if that older script exists on disk. The current repository bootstrap needs no change. Other startup behavior is retained.

Start your usual Rojo server, reconnect Studio and sync the new source files. With Play stopped, open the ZIP's `ApplyIslandIntegration.lua` in a text editor, copy ALL of it into Studio's Command Bar, and run it once. Save the place.

The Studio patch updates live scripts AND stored import-package copies. It fixes the terrain typing and the older bootstrap formatting warning, and moves `Workspace.CI_ReferenceIsland.Woodland` into a timestamped ServerStorage backup. Original sources are stored as StringValues, so backups do not create more script-analysis warnings. Rocks, terrain, water, lighting and camera configuration are not regenerated. Do NOT run the island generator again.

## 2. Build the unified C++ executable

From the C++ repository:

```powershell
cmake -S . -B build-island -DCYBERNET_PGO_MODE=OFF
cmake --build build-island --config Release --parallel 4
ctest --test-dir build-island -C Release --output-on-failure
```

This uses a new build folder to avoid old build caches. CMake may download raylib on its first configuration. The standalone plant test executable still exists for isolated tests; do not run it for the live island.

## 3. Create a NEW live world and export the island

Use `live\island001`, or another unused name. Old checkpoints have a different schema and cannot be mixed with the unified world. Keep old directories intact.

Start the relay in its own terminal, from the C++ repository:

```powershell
py tools\live_bridge\relay.py --directory live\island001 --roblox-root ..\ci_rbxl
```

Keep the relay running. Sync Rojo again so the generated server-only transport configuration reaches Studio. HTTP requests must be enabled as in your previous setup.

With your existing island loaded and Play STOPPED, run:

```lua
require(game.ReplicatedStorage.Shared.PlantSurfaceExport).Upload()
```

Wait for the successful export message. It creates `live\island001\plant_surface.txt` in the relay directory. This is your actual terrain sampled into 32-stud cells, over the entire 1,472 × 960-stud island rectangle. Soil resource quantities are explicit model defaults, not measurements of Roblox materials.

## 4. Run ONE ecosystem process

In the C++ simulation terminal:

```powershell
.\build-island\Release\cybernet_sim.exe --optics v2 --geometry lake --island-surface live\island001\plant_surface.txt --seed 250 --live-dir live\island001 --benchmark-ticks 25000 --archive-dir output\island001 --workers 8
```

Then press Play in Studio. Live simulation ticks wait for the existing Roblox authority handshake. A paused or disconnected live bridge pauses plants too, preventing their clocks from drifting.

Your live processes are now:

1. `cybernet_sim.exe` — microbes AND plants.
2. Python relay.
3. Rojo.

**Do not start `ci_plant_sim.exe`.** A shared publisher lock prevents both programs from writing plant state simultaneously.

You should see the C++ startup message `[Island] 1472 x 960 studs; 96 land plants...` (fewer only if the export contains fewer valid land cells). The first 12 start on the valid land closest to the pond; the rest are distributed across the island. They begin as small established plants with four funded organs, not full-sized trees. All subsequent growth and reproduction remain neural decisions. A randomly initialized controller is not guaranteed to thrive.

Use the research camera to look toward the shoreline. **P** opens the nearest-plant inspector. Bacteria detail is limited to 24 nearby, visible agents; distant agents retain ball proxies intentionally. Detailed bodies need actual species metadata, now supplied on creation and updates.

## 5. Resume and check status

Restart the same relay and use the same simulation command to resume the new unified checkpoint automatically. `--benchmark-ticks` is the total target world tick, not an additional duration. Increase it, for example to `50000`, if a run has already reached `25000`. Do not use the old plant `--resume` command.

One checksum-protected `checkpoint.bin` stores microbial brains, plant genomes/memory/jobs/soil, chemistry, RNG and the shared clock. Its terrain is retained on resume; re-exporting does not silently move an existing population. Checkpoints are same-build files. Keep a new live directory when moving between incompatible builds.

If plants are absent, check server Output and Workspace attributes `CI_PlantStatus`, `CI_PlantTick`, and `CI_IslandWorldTick`. On the client, `Workspace.CI_LivingPlants` contains rendered plant models and `Workspace.CI_AgentDetails` has `DetailedAgents` / `NativeParts` attributes. If the startup message is absent, check that the executable is from `build-island` and the command includes `--island-surface`.

## Git staging

Run this in PowerShell after reviewing your changes:

```powershell
git -C "E:\cultivated_intelligence\ci_c++_v0.77" add -A; git -C "E:\cultivated_intelligence\ci_rbxl" add -A
```

This stages both repositories; it does not commit or push. Your C++ repository already tracks many build artifacts: inspect `git status` and avoid committing transport credentials or new live-state directories.
