# Agent model kit — refined body studies + island warning fixes

Start with the previews in `previews/`. They render the actual exported geometry, not screenshots from Roblox. `MotionStudy.gif` shows the procedural joint motion. The three larger creatures are original studies guided by your Mesozoico reference: angular anatomy, tapered tails, pale undersides, dark pigment blocks and restrained amber eyes. They are not extracted game assets.

## What is included

- Three creature bodies: Tideback prowler, Reedrunner scout, Crestgrazer browser.
- Three stylized current-agent designs: Cyanobacteria, Bacterivore and Bodo saltans.
- Detailed and medium-detail glTF meshes, palette textures, static OBJ alternatives.
- Editable native Roblox Part/Wedge fallbacks and optional local live-agent renderer.
- Matching C++/Luau body definitions and a tested binary full-pose codec.
- The earlier island warning fix, plus the corrected island import package.

The detailed glTF meshes have beveled/tapered geometry and integrated pigment. The native fallback is intentionally simpler and will not look identical. The larger bodies remain separate studies: installing this kit does not turn microbes into dinosaurs or add simulated limbs to the C++ biology.

## 1. Fix the earlier island warnings

Stop Play. Open `FixIslandWarnings.lua` in a text editor, copy its entire contents into Studio's Command Bar and run once. It updates the existing module sources. This contains the previously prepared explicit Terrain/parent/clone type narrowing fixes. It does not rebuild your terrain. A corrected `ReferenceIslandPackage.rbxmx` is included for fresh installs; follow the included `ISLAND_SETUP.md` if starting fresh.

## 2. See the editable Roblox models

1. Extract this zip. Open your existing CI place in Studio and stop Play.
2. In Explorer select **ServerStorage**, right-click and choose **Insert from File**. Select `AgentModelPackage.rbxmx`.
3. Confirm the resulting folder is named `AgentModelPackage` directly inside ServerStorage. If it landed in Workspace, drag it into ServerStorage.
4. Open the Command Bar and run:

```lua
require(game.ServerStorage.AgentModelPackage.Install).Showroom()
```

This creates `Workspace.CI_AgentShowroom` at Y=220, separate from your island, and positions your camera. Delete that folder to remove the preview or rebuild it. These models are the native editable fallback, not the richer meshes in the preview sheet.

## 3. Import the richer creature meshes

Use Studio's **3D Importer** to import, for example, `models/Tideback.gltf`. The embedded palette image travels with the file. Keep the named component groups separate when you need articulation; merging the body into one mesh loses independent groups. Inspect orientation, colors and scale in the import preview before accepting. Palette PNGs are also supplied separately if your import workflow requires them.

`__LOD1.gltf` variants preserve the main silhouette with simpler pigment and fewer small features. Each exported glTF uses one material and one 128×128 palette. OBJ/MTL alternatives are static geometry; use glTF for the named hierarchy. No uploaded Roblox mesh asset IDs are supplied. Import/upload and Studio-specific articulation setup remain necessary. The native renderer does not automatically discover or animate imported glTF assets.

## 4. Optional live-agent cosmetics

With the existing CI place open and Play stopped:

```lua
require(game.ServerStorage.AgentModelPackage.Install).EnableLive()
```

Then start Play. The installer adds the shared modules and a separate client controller. Its only edit to LiveController is the species-ID attribute on existing markers. It refuses an unrecognized source layout instead of guessing. Existing shared modules are backed up inside the package.

The live renderer uses the three small native designs and keeps the authoritative radius, position marker and selection target. It selects up to 24 nearby visible agents, capped at 336 native parts, at 4 Hz; cosmetic poses update at 24 Hz. These are conservative defaults, not a benchmarked hardware limit. No per-part network updates, Humanoids, physics assemblies or server-side animation are added. Distant agents keep their existing markers.

To remove this optional renderer, stop Play and run:

```lua
require(game.ServerStorage.AgentModelPackage.Install).DisableLive()
```

It restores backed-up shared modules and removes its controller. It deliberately retains the harmless species metadata attribute to preserve subsequent edits to LiveController. If using Rojo, persist the same files and the species metadata change in your source tree; a later sync otherwise overwrites Studio-only changes.

## 5. Roblox / C++ component contract

See `BRIDGE_CONTRACT.md`. The JSON, generated Lua and C++ header use matching body IDs, component IDs, parents, pivots and axes. Components are joint groups: dozens of decorative pieces can follow one component. This is a tested interchange foundation, not an already connected new live simulation protocol.

No C++ rebuild is required for the showroom or optional existing-agent cosmetics. The supplied C++ headers can be included in a future bridge integration; they are not installed into your current backend by the Studio installer.

## Verification and remaining checks

The build checked all six joint hierarchies and mesh buffers, winding, normals, palette coordinates and animated bounds. The real Luau factory ran under a lightweight Roblox API mock through 80 poses per body and teardown. The C++/Luau codec passed byte-for-byte interoperability and malformed-payload tests. Source compilation checks syntax, not all Studio type inference.

Studio is not available in this environment. Import appearance, asset-upload permissions, Studio warnings, live performance and animation quality in-game still need a Studio check. The motion loop is a procedural study, not a finished foot-contact locomotion system.

## Rebuild assets

From `ci_rbxl/`, with Python + numpy/matplotlib/Pillow installed:

```bash
python tools/agents/build_designs.py
python tools/agents/refine_meshes.py
python tools/agents/export_models.py
python tools/agents/build_body_contract.py
python tools/agents/finish_assets.py
python tools/agents/package_kit.py
```

Tests require a Luau CLI path; codec tests also require g++:

```bash
python tests/agent_models.py /path/to/luau
python tests/agent_pose_codec.py /path/to/luau
```

Roblox references: https://create.roblox.com/docs/studio/importer and https://create.roblox.com/docs/performance-optimization/improve
