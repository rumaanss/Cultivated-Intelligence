# Stage 3 live relay and cilia fix

Based on 495e894939282f9cccc164f89601c7c99561df57.

## Findings and changes

Start-Stage3.ps1 launches ci_stage3 directly. Neither Python nor the historical
Python relay runs in this path. The repository includes archived projects,
installation payload duplicates, tests and asset-generation tools. Its language
percentage is not a runtime cost measurement. Keep biology and live transport
in C++; do not rewrite offline tools as a speculative latency fix.

The native HTTP request previously parsed a new whole-lake JSON snapshot and
copied the whole JSON tree before filtering it to observer patches. New
snapshots arrive about once per second, explaining why work spikes on only
some requests. Publication now parses into an immutable shared JSON object;
requests pin that object and copy metadata plus selected rows only. Parsing
still costs CPU on publication; it is not included in HTTP relay work anymore.
There is no biology, timestep, sampling budget or checkpoint format change.

Cilia previously started on an idealized ellipse independently of the authored
asymmetric/recessed body mesh. Their roots now come from ray intersections with
the actual low-detail body triangles, computed once when the module loads.
Each root is embedded slightly into the body; body and cilia share scaling and
rotation. Oscillation moves the tip, never the attachment. This fixes both
Stage 3 grazer types. Numeric annotations also address the three Studio math
warnings reported previously.

## Measurements and checks

Release GCC build, Linux, fresh seed 42, actual loopback HTTP requests.
These are small comparative samples, not Windows or Roblox performance promises.

- Initial 24-patch request: baseline 18.14 ms, patched 0.42 ms native relay work.
- Repeated four-region requests (15 each): baseline new-publication spikes
  17.89–20.10 ms; patched changed-view/snapshot requests 1.54–1.99 ms.
- Requests without a changed snapshot remained around 1 ms.
- The existing relay timing excludes final response encoding/network/Studio
  scheduling. Video frame at 65 seconds shows native relay work 2.2 ms and HTTP
  round-trip p95 83.6 ms. They are different measurements.
- All 39 native tests passed, including native transport, Stage 3 migration,
  controls and disturbance. FullPond initially had an empty local executable;
  relinking that target and rerunning passed. No FullPond source change.
- Actual native packet renderer replay passed both grazers/four algae forms,
  identities, part budgets, offspring visibility and stale cleanup. Luau compile
  passed. Actual Studio visuals/FPS remain to be verified.

## Algae investigation: no speculative relocation

A fresh seed-43 run for 6000 ticks (ten biological days), unchanged biology,
was grouped by water depth at each founder's chemistry cell. Material validation
passed. Carbon is mmol C including all organism compartments.

| Depth (studs) | Algal founders | Original founders surviving | Living algae at end | Initial C | Final C |
|---|---:|---:|---:|---:|---:|
| Less than 20 | 64 | 55 | 76 | 3134.79 | 12989.1 |
| 20 to less than 50 | 64 | 54 | 82 | 3913.17 | 17188.9 |
| 50 or deeper | 668 | 560 | 700 | 42444.9 | 73015.1 |

This does not reproduce a rapid deep-water die-off and does not diagnose the
user's saved population. Visible disappearance can also be interest filtering
or bounded display selection: at most two algae per form are shown locally.
The recording alone cannot distinguish those from deaths. The model uses its
own native light field; visual darkness is not a light measurement.

Founder placement, physiology and mortality are unchanged. Before relocating
algae, inspect the affected stage3.checkpoint.json and food-day reports, compare
individual ancestry death records against visibility, and correlate local
fixation, respiration and biomass. Shore/wall colonization should be governed
by native substrate/light availability and accounted founder material, never
Roblox-only spawning or free biomass. This issue remains open for that saved run.

## Apply from the existing project root

Save Stage3_Live_Fix.patch in the project root. Commit or stash local edits first.
Apply with `git apply --check .\Stage3_Live_Fix.patch` followed by
`git apply .\Stage3_Live_Fix.patch` only if the check succeeds. Rebuild with:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\Build.ps1
```

Sync the modified planet source into Studio using your existing Rojo connection
(`rojo serve planet/default.project.json`), then restart Play. Rebuilding C++
alone does not update a saved .rbxl. This fix does not replace your place file.
Resume the existing world without -NewWorld:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\Start-Stage3.ps1 -Runtime runtime/stage3-43
```

Use the actual runtime directory you previously created if it differs.
