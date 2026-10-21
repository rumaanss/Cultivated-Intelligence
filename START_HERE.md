# Lifecycle/sky review candidate

Read [validation and upgrade notes](docs/LIFECYCLE_SKY_RELEASE.md) first. Preserve your working runtime: checkpoint migration is forward-only. Studio visual acceptance and sustained neural-tree reproduction remain open gates.

# Start the native integration

This root replaces the active Python relay with an embedded C++ service. Keep your existing Roblox place: this package does not regenerate the island, terrain or water.

## 1. Stop and preserve the old run

Stop Studio Play. Stop the old simulation with Ctrl+C and let it finish saving. Stop the Python relay and old Rojo server. Keep the entire old project as a backup.

Extract `CultivatedIntelligenceNative` into a separate directory. Open PowerShell in that new root. Use your already installed CMake, Visual Studio C++ build tools and Rojo.

## 2. Build and test

```powershell
.\scripts\Build.ps1
```

The default build needs no Python or Raylib. If Python is already present, CTest also runs the developer HTTP integration test. It is not used by the running application. CMake's normal compiler detection checks can report unsupported compiler flags without indicating a build failure; the build and test exit codes decide success.

## 3. Import your current ecosystem once

Use the old runtime path you have been running:

```powershell
.\scripts\Start-Planet.ps1 -ImportRuntime 'E:\cultivated_intelligence\CI_Planet_Integration_Source\CultivatedIntelligence\runtime\planet-native-v1'
```

This copies and checks the durable checkpoint, keeps the old copy, and checks the habitat against the compiled lake contract. It does not copy transient relay ownership or reset the population. If your old project has moved, substitute its actual runtime path. A checkpoint from the earlier hybrid-motion ABI will be rejected, not converted silently.

Wait for `[CI Native] Loopback HTTP port 8765`. The process writes the server-only Roblox connection configuration. **Do not run `relay.py` or the old `run_planet.py`.**

For subsequent starts:

```powershell
.\scripts\Start-Planet.ps1
```

If you deliberately want fresh founders instead of your saved organisms, use a separate runtime:

```powershell
.\scripts\Start-Planet.ps1 -Runtime runtime/fresh-lake -NewWorld
```

## 4. Connect the existing place

In a second PowerShell terminal, from this new root:

```powershell
rojo serve planet/default.project.json --port 47126
```

Connect the Studio Rojo plugin to port 47126, sync, then Play your existing planet. HTTP requests and EditableMesh must remain enabled as in your working place. The native service binds only to your local computer; this configuration is for Studio, not a published multiplayer server.

Default behavior pauses biology when no observer heartbeat has arrived for three seconds. The process remains available and resumes when Studio reconnects. It retains the original ownership timeout of eight seconds when changing Roblox server sessions.

For an unattended **headless** run that continues without Studio:

```powershell
.\scripts\Start-Planet.ps1 -Autonomous
```

Do not run a second process against the same runtime. Ctrl+C saves a final checkpoint. `-StopTick` is an **absolute** checkpoint tick, not an additional tick count. `-Workers 4` is the launcher default; adjust it for your CPU. `-Unpaced` removes the 30-tick/second cap for benchmarking; it does not change biological time per tick.

## 5. Observe performance

```powershell
.\scripts\Diagnostics.ps1
```

This reports native tick mean/p95, phase costs, HTTP p95, state age and simulation rate without printing the authentication token. `runtime/planet-native-v1/metrics/segment-*/performance_metrics.csv` is written on clean headless exit. The Roblox research interface retains its HTTP, apply, client/server frame and simulation-rate fields.

A 60 FPS rendering target is separate from the simulation's 30 ticks/second and the HTTP exchange's 6 requests/second. See `docs/VALIDATION.md` for measured results and remaining platform checks.

## Research interface later

```powershell
.\scripts\Build.ps1 -Research
.\scripts\Start-Planet.ps1 -Research
```

This builds the preserved Raylib/OpenGL UI with its neural inspector, synapse panels, lineage, population, chemistry and advanced metrics. Its dependency is downloaded only for this optional build. Run it **instead of** the headless executable against a runtime, never beside it. Add `-Autonomous` if you want it to advance without Studio.

## Troubleshooting

- **Port in use:** stop the old relay/native instance. Do not delete lock files to force access.
- **Another publisher owns the directory:** another simulation is still running; stop it cleanly.
- **Habitat mismatch:** use the matching native-v1 survey/checkpoint. Do not rewrite the digest to bypass validation.
- **Aftman cannot find Rojo:** run from this root, which includes `aftman.toml`. Your existing Rojo installation is sufficient when already configured.
- **Missing checkpoint:** provide `-ImportRuntime`, or explicitly select `-NewWorld` in a different runtime.
- **Script execution blocked:** use your normal allowed PowerShell invocation/policy; this package does not alter your machine's execution policy.

The package contains source, not a prebuilt Windows executable or your private runtime. The original place and evolved checkpoint remain on your computer.
