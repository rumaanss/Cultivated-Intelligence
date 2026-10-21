# Sky performance isolation

This is the first measurement step before the continuous atmosphere and asset-quality changes. It adds no automatic diagnostic workload. The probe only runs when explicitly called. It freezes sky generation and model updates independently, retaining their current visuals, and restores the previous settings on completion or cancellation.

The eight phases are normal, sky frozen, models frozen, both frozen, then the reverse order. Each phase settles for 3 seconds and measures for 15 seconds: about 144 seconds total. Keep the camera fixed, graphics settings fixed, and the window focused. Do not inspect different organisms or change tabs during the run. This is a screening experiment: biology and the solar cycle continue, so it is not a replay of an identical workload. The reversed order reduces time drift but does not eliminate it. Confirm large differences with a repeated run before choosing an architecture.

Install from the project root after stopping Play and stopping the native simulation with Ctrl+C:

```powershell
Expand-Archive -LiteralPath "$env:USERPROFILE\Downloads\CI_SkyPerformanceIsolation.zip" -DestinationPath "$env:TEMP\CI_SkyPerformanceIsolation" -Force
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:TEMP\CI_SkyPerformanceIsolation\Install-Profile.ps1" -ProjectRoot .
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\Build.ps1
```

Resume your existing simulation with its usual Start-Planet command, same runtime directory and seed, without -NewWorld. Sync Rojo, start a new Play session, and wait for biology and celestial models to initialize. Then run in Studio's CLIENT Command Bar:

```lua
require(game.ReplicatedStorage.CI_Biology.SkyPerformanceProbe).Run()
```

The output prints progress and a final line beginning CI_SKY_PROFILE. Copy that final line to a text file and send it back. The result is also retained for the current Play session:

```lua
print(workspace.CI_PlanetCelestial:GetAttribute("PerformanceProbeResult"))
```

Cancel at any time:

```lua
workspace.CI_PlanetCelestial:SetAttribute("PerformanceProbeCancel", true)
```

## What it measures

Client frame times are sampled on Heartbeat. Replicated exchange telemetry is sampled at most ten times per second and deduplicated by ExchangeTimestamp; it is a sample of completed exchanges, not an exhaustive server trace. Reports include sample counts, means, medians, p95 and maxima, connection freshness, ticks, error counts, camera movement, and sky generation counts. No new HTTP calls are made by the probe.

C++ adds four steady-clock elapsed stages to normal exchange responses: snapshot retrieval/parsing/indexing; observer selection; agent/session/delta assembly; plant packet preparation. These include scheduler waits inside each interval. They are NOT CPU-time measurements. The original Relay work definition is preserved: final response serialization, network transmission, and waiting before entering the exchange function are excluded. Reset/resync replies have no stage data; missing measurements remain missing. Cached retries preserve the original response and its timings.

If freezing sky generation lowers both frame and native elapsed times repeatedly, shared-machine contention becomes more plausible. If the plant stage dominates regardless of sky mode, inspect plant snapshot/delta processing. If only client frames improve, preserve the native transport and focus on client rendering. An empty stage sample count means the new native executable is not running or no normal exchange was sampled; do not interpret it as zero cost.

## Scope and verification

The package contains the two client isolation controls, the explicit probe, the existing coordinate type correction, native timing instrumentation, telemetry forwarding, and tests. It does not yet change atmospheric rendering or body assets. Installer backs up changed files and checks hashes. Windows installer execution and actual Studio performance cannot be verified here.

Headless probe tests verify all eight phases, deduplication, restoration and cancellation cleanup. Existing sky/model tests verify the baked rendering and resource behavior. Native integration tests verify timings, retry identity, views, plants and checkpoint restart. These validate diagnostic operation; they are not evidence of a performance improvement on the user's machine.
