# Natural basin terrain pass

Based on ci_rbxl f4d1e95 and civ0.77 e5a2c7b (the newly committed live project).

## Install

Apply this Roblox change together with the `terrain/natural-basin` change in civ0.77. Sync the Roblox source with your usual Rojo workflow. Rebuild the C++ executable using your existing build configuration and restart the simulation/relay with its existing live directory and `--geometry lake --optics v2`. Restart Studio Play so the new manifest and geometry load together. Do not replace old recording manifests with the new geometry: old recordings retain their original terrain.

Full Roblox replacement files: src/shared/LakebedPresentation.lua, src/shared/GeometryPresentation.lua, src/server/Services/LiveStateService.lua. New module: src/shared/TerrainVisualConfig.lua.

## Result

The 100x100 basin has eight asymmetric planar regions, a deep central pocket, steep rocky banks, diagonal ridges, and twelve supported boulders with navigation gaps. Sand, silt and rock patches follow source slope, depth and deterministic spatial noise. No texture assets, EditableMesh permissions, or terrain frame loop are needed. Lighting, water settings and organisms are unchanged.

The existing shared geometry contract requires the entire floor to stay below the surface. This is an underwater terrain pass, not the dry hills, beaches or islands from the concept image. The square domain boundary remains. True irregular shorelines need a subsequent shared terrain contract change.

The client generates 452 static wedge parts; the invisible server authority uses 40. The client tessellation is coplanar with the C++ surface, not a displacement effect. TerrainVisualConfig controls palette and patch style. CellSize must divide 100 evenly (default 12.5).

## Validation

Luau compilation passed for all changed modules. tests/terrain_geometry.py executes the lakebed module with engine stubs, checking facet and tessellation coverage, plane agreement, materials and part budgets. The C++ lake test passed, including 10,000 randomized movement/ray checks. Generated C++ header validation passed.

Roblox Studio is unavailable here: actual appearance, frame time and live relay reconnection still need an in-Studio check. In Studio, inspect both above-water and underwater views and compare client/server part counts. The extra static geometry is bounded but its device-specific rendering cost has not been measured.
