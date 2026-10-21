# Reference Island — Studio generator

This version builds the island around the existing pond. It follows the supplied island map's western peninsula, northern landmass, eastern inlet and southern shoreline. The existing 100×100 simulation stays at the center of the pond. The larger island is scenery, not new C++ habitat.

## Quick install: no C++ rebuild

1. Save a copy of your current place. Stop Play.
2. Import `ReferenceIslandPackage.rbxmx` into Studio (Explorer → Insert from File), then place its `ReferenceIslandPackage` folder inside **ServerStorage**.
3. Open the Command Bar and run:

```lua
require(game.ServerStorage.ReferenceIslandPackage.Install).Run()
```

The installer copies six modules to `ReplicatedStorage.Shared`, backs up replaced modules inside the package, and generates the island. Watch Output for `[Island] COMPLETE`. The editor camera moves to an island overview. Generation yields between chunks so Studio can remain responsive; runtime depends on your machine.

4. Select **Workspace → Terrain**. Enable **Decoration** in Properties for native animated grass. This property cannot be set by the generator script.
5. Save the place, then press Play. Your current water and organisms are created by the existing project. The old rectangular backdrop is suppressed when the island is ready.

If Rojo is connected, also copy the six replacement/new files under `ci_rbxl/src/shared/` from the ZIP into your local source tree, then sync. Otherwise a later Rojo sync can overwrite the imported modules. Do not replace your entire `src` folder.

## Source / Rojo installation

Copy these files into `src/shared`:

- IslandConfig.lua — new, authored outline and scenery budgets.
- IslandField.lua — new, deterministic height/material field.
- IslandVegetation.lua — new, bounded woodland, rocks and shrubs.
- ReferenceIslandGenerator.lua — new, Studio generation/removal.
- BasinBackdrop.lua — full replacement; recognizes the generated island.
- ResearchCameraConfig.lua — full replacement; expands free-camera overview bounds.

Sync Rojo. With Play stopped, run:

```lua
require(game.ReplicatedStorage.Shared.ReferenceIslandGenerator).Generate()
```

No changes to the C++ repository, live relay, simulation coordinates, lighting, sky or organism models are needed for this package. It works with the existing submerged terrain as well as the previous lakebed update.

## What is generated

- A traced, irregular island outline; small seeded coast variation preserves the design.
- A high northern ridge, western headland, eastern cove and southern meadows.
- A rounded pond margin around the protected original simulation footprint.
- Native smooth Terrain with sand beaches, grass, ground transitions and rocky slopes.
- Native water around the island and around the pond perimeter; the central pond renderer remains unchanged. A visible difference between native exterior water and the current custom pond water is possible. Water/reflection matching is not part of this pass.
- Up to 145 procedural broadleaf trees, 180 two-rock groups and 240 shrubs. These are simple stylized procedural assets, not No Man's Sky-quality imported foliage. Native grass supplies the fine ground cover when Decoration is enabled.

The scene occupies 1472×960 studs, with the island roughly 1250×740 studs. The heightfield uses 4-stud voxels and 345 chunks. It writes approximately 5.1 million voxel entries, including air, once in Studio. The default decoration ceiling is 1660 parts plus four water join strips. No scenery scripts run per frame.

## Viewing

In Edit mode, use the editor camera to inspect the island. To return to the overview:

```lua
workspace.CurrentCamera.CFrame = CFrame.lookAt(Vector3.new(750,900,1050), Vector3.new(120,0,-80))
```

The existing research free camera supports WASD, Q/Space up, E/Ctrl down, Shift boost, right-drag rotation, mouse-wheel speed, and R reset. Its new bounds allow an island overview. Your live combat mode disables that research camera; use Edit mode to inspect the complete island in that case. Players and organisms remain constrained to the C++ pond; surrounding land is not a playable simulation expansion.

## Remove or regenerate

Stop Play. Run:

```lua
require(game.ReplicatedStorage.Shared.ReferenceIslandGenerator).Remove()
```

Removal uses recorded generated columns rather than the latest configuration. It clears only cells still matching the generated material and occupancy, preserves protected pond cells, and preserves differing later terrain edits. It also removes the generated scenery parts. Edits identical to a generated cell cannot be distinguished. It is not a general undo for hand-sculpted terrain.

Change IslandConfig, then generate again. Studio caches required modules during an editing session: after source/config edits, save and reopen the place before generating so the edited modules are loaded. Remove the island before deleting its marker folder, which contains the data needed for cleanup.

If you installed through the import package and want the original modules restored after removal:

```lua
require(game.ServerStorage.ReferenceIslandPackage.Install).RestoreModules()
```

If generation fails halfway through, use `.Remove()` before retrying. If it refuses existing exterior Terrain, that is deliberate: it checks the complete region before the first write. Preserve or relocate that existing terrain, or work in a clean copy. The generator never calls Terrain:Clear().

## Verification and limits

- All delivered Lua modules compile with the Luau compiler.
- The real field and generator run under a Roblox API test double: shoreline landmarks, height bounds, protected pond, material distribution, scenery budgets, existing-terrain refusal, repeated-build refusal, quantized voxel removal, later-edit preservation, changed-configuration removal and partial-build recovery pass.
- The supplied preview is calculated from the field itself. It is not a Roblox render and excludes vegetation and native voxel smoothing.
- Roblox Studio is not available in the development environment. Import behavior, final visuals, native water seams, device frame time and live scene integration still need a Studio run. The mock tests are not a substitute for that.

Roblox documentation used:
https://create.roblox.com/docs/reference/engine/classes/Terrain
https://create.roblox.com/docs/parts/terrain
https://create.roblox.com/docs/performance-optimization/design

This package is a standalone replacement for the island scenery work, not a request to reinstall or rebuild the earlier C++ terrain ZIP.
