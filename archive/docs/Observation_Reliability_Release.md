> Superseded by `Lake_Complete_Release.md`. Use the combined updater and omit `--ticks` when resuming an existing run.

# Observation reliability — first implementation increment

Scope: initial connection diagnostics and low-risk duplicate-work reduction from the lake implementation plan. This is not completion of the spatial streaming, sky, model LOD or ecological tuning phases. The intermittent reconnect exception has not yet been reproduced in Studio.

## Changes

- Research diagnostics retain the previous error after recovery, its timestamp, count and the latest 32 state/error events. Events carry run, boot, batch, sequence, tick and failure phase. This bounded history lasts for the Studio server session; export it before Stop.
- HTTP and state-application metrics expose rolling p50/p95/p99 over up to 120 successful samples. Existing research interface rows show p95 beside the latest value. Failed exchanges remain in error history, not the successful-latency sample window.
- Native bridge status includes boot identity and publication UTC milliseconds. Relay ignores a status explicitly belonging to another boot.
- Relay omits motion only when the client has acknowledged the same snapshot sequence. Lost replies still resend; new snapshots still transmit motion. Each new request batch still writes an observer heartbeat.
- Client interpolation uses the server's snapshot-arrival timestamp instead of treating each repeated fetch as new movement.
- Partial client updates rotate through the visible membership instead of always updating its first 64 organisms.

No biological parameters, terrain, water presentation or saved-world formats changed. Existing C++ stale-input/ownership checks remain intact. Duplicate input batches intentionally do not renew the C++ heartbeat.

## Validation

Passed locally:

- New Python observer-stream regression: identical retries, lost response resend, acknowledged duplicate suppression, new snapshot movement, heartbeat publication, wrong-boot status rejection and boot resync.
- Existing relay hardening: durable event deduplication, restart/fencing, malformed JSON rejection, event gaps, request limits and 10,000-agent exercise.
- Native C++ LiveBridge suite, including new stale-input recovery and status metadata assertions; compiled with g++ C++20. Windows execution remains to be checked.
- Luau UI, radial frame (17,472 round trips), solar math (12,010 phases), bounded percentile window and duplicate-snapshot interpolation tests.
- Changed Luau source compilation.
- Supplied mature snapshot/plant packets accepted by actual mapped Roblox protocols.
- git diff --check.

Actual 3,724-agent frozen-snapshot replay: initial response 1,133,145 bytes; acknowledged duplicate approximately 507 bytes; duplicate exchange median approximately 1.92ms in this container. This comparison is initial full response versus duplicate heartbeat, not a general live speedup benchmark. It excludes HTTP, Studio, rendering and advancing biology. New snapshots still require whole-population processing; upstream regional streaming remains the next performance stage.

## Update from the project root in PowerShell

Stop Studio Play, simulator and relay cleanly first. Keep the existing runtime directory/checkpoint. If Git reports local changes, preserve them before switching; do not reset them.

GitHub's connected integration rejected writes with HTTP 403, so this increment is supplied as `ci_observation_reliability.patch`. Save it in the project root. It is based on commit bd3f3cd8adf93f07f446d113feb19189d9c63cf9.

```powershell
git switch -c fix/lake-observation-reliability
git apply --check .\ci_observation_reliability.patch
if ($LASTEXITCODE -eq 0) { git apply .\ci_observation_reliability.patch }
```

If the check reports conflicts, stop and preserve local edits; do not use a forced reset. Once the patch applies successfully:

```powershell
cmake --build simulation/build-planet --config Release --target cybernet_sim
```

Start the existing relay, Rojo and simulation as before, in separate terminals:

```powershell
py simulation/tools/live_bridge/relay.py --directory runtime/planet-native-v1 --roblox-root planet
```

```powershell
rojo serve planet/default.project.json --port 47126
```

```powershell
py tools/run_planet.py --runtime runtime/planet-native-v1
```

Use the same saved planet and Rojo connection. The simulator can wait until Play supplies observer input. Do not start a second relay for the same runtime. No place rebuild or habitat re-export is required by these changes.

## Studio acceptance still required

Use the same graphics settings and camera route. Verify water, organism containment and population continuity. Observe HTTP/state-apply p95 and whether any reconnect occurs. Before Stop, run this in the Studio command bar to export the bounded diagnostics into Output:

```lua
local t = game:GetService("ReplicatedStorage"):FindFirstChild("CI_ResearchTelemetry")
if t then
 print("CI_OBSERVATION_DIAGNOSTICS", game:GetService("HttpService"):JSONEncode(t:GetAttributes()))
end
```

The output contains research telemetry, not transport configuration. A failure now retains its phase/reason after recovery. A live 60-minute soak and actual MicroProfiler capture remain gates before claiming reconnect resolution or 60 FPS.

Rollback: stop all three processes and revert the applied patch with `git apply -R ci_observation_reliability.patch`; rebuild the simulator and resync Rojo. Keep the same runtime. These changes do not migrate checkpoint data.
