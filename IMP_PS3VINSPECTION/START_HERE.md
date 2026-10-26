# IMP_PS3VINSPECTION — integrated source package

Release: IMP_PS3VINSPECTION-1. Baseline: GitHub `ac10418` (2026-10-25), including the relay/cilia fix. The optional previously delivered algae-grounding patch is accepted and retained.

This package implements native lineage inspection, independent display/connection states, an explicit Roblox scene-light input, recorded replay, geometry comparison tools, and diagnostic geometric sensing. It is a source integration candidate: actual Roblox Studio geometry/lighting/pixel capability and Windows/MSVC acceptance still need the included local checks. No claim of pinpoint terrain equality or rendered-image vision is made.

## Install in your existing project root

Stop the native executable before rebuilding. Preserve your existing runtime directory. Extract this archive to `IMP_PS3VINSPECTION` under your main project directory, then run these commands from that main directory:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\IMP_PS3VINSPECTION\Install-Inspection.ps1 -Root . -Check
if ($LASTEXITCODE -eq 0) {
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\IMP_PS3VINSPECTION\Install-Inspection.ps1 -Root .
    if ($LASTEXITCODE -eq 0) {
        powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\Build.ps1
    }
}
```

The installer verifies every changed file before writing. It accepts the reviewed baseline or the earlier grounding patch, refuses conflicting local edits, skips repeat installations, and records an exact source backup. It does not change runtime checkpoints, terrain, or `.rbxl` files. Do not force a conflict; it identifies a version that needs merging.

Sync `planet/default.project.json` through Rojo into your existing Roblox place, reviewing the proposed script changes. This is the maintained place-update route. Keep the actual terrain and existing place; a Rojo build of this source alone is not a replacement for the terrain-containing place. Start native first and sync the generated server-only transport configuration before Play. Never publish that credential.

## Resume the existing ecology

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\Start-Stage3.ps1 -Runtime runtime/stage3-43
```

Use your actual existing runtime name. Pre-package runtimes default to **native-reference** mode. Their photon inputs remain the original native model. The new inspector works in this mode; Roblox scene shadows do not drive biology in it.

Select a cohort normally to open the lineage panel, or press **L** to open it and enter a native cohort ID. Parent and child buttons explicitly change selection. Dead individuals remain queryable. A removed rig never establishes death. The panel reports biological status, display reason, connection freshness, family, material state, light, native position and any cosmetic grounding offset. Native coordinates are X=east, Y=north, Z=altitude in studs; cohort equivalents are not individual cell diameter.

## Separate scene-light experiment

Do not convert the running long-run experiment. Use a new runtime:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\Start-Stage3.ps1 -Runtime runtime/inspection-test-43 -Seed 43 -NewWorld -SensorMode scene
```

Native waits for the Roblox server's complete scene batch. Sync Rojo, enable Studio HTTP requests, and Play in the existing terrain place. The server samples all 199 habitat columns independent of player location. No scene batch means no biological advancement. Later resume this runtime without `-NewWorld` or `-Seed`; its sensor mode is retained.

The current physical approximation is explicit: surface direct-light occlusion, a 15% unoccluded diffuse component, then existing native water/canopy attenuation. Ten biological ticks use one scene batch. These are provisional engineering parameters, not a declaration of the world's future governing sciences. See MODEL.md before using scene mode for an ecological comparison.

## Studio acceptance

Use a test session, with this package synced. In the **server** Command Bar:

```lua
local modules = game.ServerScriptService.CI_Biology
local calibration = require(modules.InspectionCalibration)
local report = calibration.Geometry(require(modules.InspectionGeometryFixture))
print(report.passed)
calibration.Sensors({200, 100, 110})
```

This prints `CI_GEOMETRY_REPORT` and `CI_SENSOR_CALIBRATION` JSON. Geometry failures are evidence to investigate, not instructions to loosen tolerances. The sensor check temporarily creates and removes its own registered blocker above the water.

To affect native sunlight with another object, tag its server-owned BasePart `CI_SensorySurface`, set `CanQuery=true`, and set numeric `CI_OpticalTransmission` between 0 (opaque) and 1 (fully transmitting). Terrain is always included and water is handled by native attenuation. Visual Transparency does not imply a measured optical transmission. Register every additional biologically relevant optical solid. Increment Workspace's `CI_TerrainRevision` after terrain edits and regenerate/revalidate the shared geometry before accepting the new world.

For the optional screenshot capability experiment, set the boolean Workspace attribute `CI_RunPixelCapabilityProbe=true` **before Play**. The client prints `CI_PIXEL_CAPABILITY`, then stops. It does not save/upload an image, move the camera, or feed screenshot pixels to organisms. A successful screenshot read is still not evidence of an independent organism camera.

Complete the acceptance checklist in VALIDATION.md, including camera independence, sun direction, four players, stale connection, selected lineage death and local MSVC build.

## Replay and rollback

Scene input is saved as `runtime/<experiment>/scene-observations-<boot>.jsonl`. Each native process gets a separate recording, preventing overlapping restart histories. Replay needs the corresponding original seed/start checkpoint and this same code/configuration; a light log alone is not a complete world recording.

For a recording that starts at tick zero:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\Start-Stage3.ps1 -Runtime runtime/inspection-replay-43 -Seed 43 -NewWorld -SensorMode replay -SensorReplay .\runtime\inspection-test-43\scene-observations-<actual-boot>.jsonl -StopTick <recorded-end-tick>
```

Replace both angle-bracket placeholders with actual values. Replay does not require Roblox observations. A missing, exhausted or incompatible recording stops advancement with an error. For a recording that begins later, use a separate runtime containing the matching start checkpoint and habitat, then launch without creation options with `-SensorMode replay`. Preserve the original runtime untouched.

To restore source, use the backup path printed during installation:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\IMP_PS3VINSPECTION\Restore-Inspection.ps1 -Root . -Backup .\archives\inspection\<actual-backup-directory>
```

Rebuild and resync Rojo afterwards. Rollback refuses to overwrite files edited after installation. Source rollback does not undo biological history. Continue original long-run checkpoints with their original compatible source; keep scene experiment checkpoints and logs separately.
