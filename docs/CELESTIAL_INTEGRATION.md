# Celestial integration — planet-sky-3-celestial

This focused update extends the working baked Opaque sky. It changes five client presentation modules; no C++ transport, checkpoint format, biology, plant lifecycle, player controller, water geometry, or server script changes are included.

## Presentation

- Six actual client MeshParts: primary moon, banded gas planet Aureole, blue planet Pelagic, smaller moon Cinder, and two irregular asteroid fragments. These are visual proxies, anchored with collision, touch, query, and shadow casting disabled. They are not physical orbital simulation or visitable terrain.
- The sun is a local Neon sphere. Moon and planet vertex colors are shaded against the canonical solar direction. Atmosphere attenuation dims bodies during daylight; horizon and water blending hide them appropriately. Bodies appear according to their positions, not all simultaneously.
- A seeded 800-star catalog and subtle galactic band are sampled into the background once. Stars fade out in daylight and below the local horizon. The background catalog is world-oriented; full sidereal rotation is not implemented. The fictional body orbits use the existing simulation clock and observer position; they do not consume biological RNG or change photosynthetic energy.
- Cubemap resolution increases from 32 to 64 pixels per face. Shared-edge samples and analytic star splats agree across all 12 cube joins. This is a modest procedural background, not a high-resolution photographic sky. GPU filtering seams must still be checked in Studio.

## Work limits and failure behavior

Six fixed-topology meshes are retained after initialization. Mesh creation yields between bodies. Shading changes at most 64 vertex colors per heartbeat with a soft 0.75 ms elapsed-time check; this is a scheduling target, not a guaranteed frame-time ceiling. No per-frame model allocation, lights, raycasts, network messages, or server physics are added. Metrics publish twice per second.

The sky retains serialized asynchronous baking, six reusable EditableImages, front/staging content sets, generation cancellation, and failure backoff. Sampling remains limited to 512 pixels per heartbeat with a soft 1 ms budget. Higher resolution increases generation latency and startup work. Cached background generation yields between faces. Engine baking and GPU costs are not covered by Lua timing measurements.

Mesh allocation failure disposes partial resources and retains the previous moon. Model update failure disposes the six models and restores the fallback moon. Sky baking failure retains the last complete generation. Existing EditableMesh/API permissions are required, as for the current animated water. Do not disable those permissions.

The presentation targets observers on or near the planet. Proxy sizes are capped at Roblox's 2048-stud limit; orbital travel, eclipses, mutual shadowing, N-body dynamics, and physically calibrated radiometry are outside this release. Do not interpret visual orbit parameters as biological inputs.

## Install

Stop Studio Play. Save CI_CelestialIntegration.zip to Downloads. Run from the project root in PowerShell:

```powershell
Expand-Archive -LiteralPath "$env:USERPROFILE\Downloads\CI_CelestialIntegration.zip" -DestinationPath "$env:TEMP\CI_CelestialIntegration" -Force
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:TEMP\CI_CelestialIntegration\Install-Sky.ps1" -ProjectRoot .
```

The installer validates every payload hash, backs up affected paths, copies to the precise project locations, verifies installed hashes, and rolls back if installation fails. It requires the existing planetary sky controller. It is not a replacement project root. Sync Rojo and start a NEW Play session. No native rebuild, new-world creation, or relay restart is needed.

## Check in Studio's CLIENT Command Bar during Play

```lua
local root=workspace:FindFirstChild("CI_PlanetCelestial")
assert(root,"Missing celestial controller")
for _,key in {"SkyVersion","SkyRenderer","SkyState","SkyGeneration","SkyBakeFailures","CelestialModels"} do
 print(key,root:GetAttribute(key))
end
local models=root:FindFirstChild("CelestialModels")
if models then
 print("3D bodies",#models:GetChildren(),"Update ms",models:GetAttribute("UpdateMs"),"Peak ms",models:GetAttribute("MaxUpdateMs"))
end
```

Expected after initialization: SkyVersion planet-sky-3-celestial, SkyState Published, CelestialModels celestial-1, six 3D bodies. Allow initial mesh allocation and the first complete sky bake to finish. Bodies below the horizon will not be visible. Retained geometry can be inspected under the folder.

Compare the same checkpoint, position, graphics setting, and camera before/after: client frame time and MicroProfiler, relay latency/error count, above/below-water transitions, dawn/noon/dusk/night, horizon and cube-edge views at multiple planetary locations. Client UpdateMs excludes engine bake/GPU work; do not use it as total frame time. Preserve the baseline backup until this check passes.

## Verification completed outside Studio

Seven headless test groups passed: research UI, radial habitat coordinates, solar clock, observation/interpolation, species presentation, sky/background, and celestial models. Tests cover all cube joins, deterministic catalog output, apparent body angles and observer parallax, Opaque-only publication, serialized baking, failure backoff/recovery, cancellation, resource destruction, model initialization failure, shading work bound, and underwater hiding. Five runtime modules pass Luau compilation. Test doubles do not reproduce Roblox rendering, asset permissions, or GPU performance. PowerShell installer execution and Studio visual/FPS acceptance remain unverified in this environment.

Run repository tests with a Luau CLI:

```text
python planet/tests/run_checks.py --luau PATH_TO_LUAU
```

Python here is an optional developer test launcher, not runtime transport or simulation.

## Rollback

Use the exact backup directory printed by the installer:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:TEMP\CI_CelestialIntegration\Restore-Sky.ps1" -ProjectRoot . -Backup "runtime/sky-backups/PRINTED-BACKUP-NAME"
```

Stop Play before restoring; sync Rojo and start a new session afterward. Rollback restores affected pre-installation files and removes files that were newly added by this package.

## Technical references

Roblox's official API references informed the implementation:
- https://create.roblox.com/docs/reference/engine/classes/EditableMesh
- https://create.roblox.com/docs/reference/engine/classes/AssetService
- https://create.roblox.com/docs/reference/engine/classes/Sky

The working Opaque-content publication path was also confirmed directly by the user's magenta baked-sky test. This delivery preserves that path.
