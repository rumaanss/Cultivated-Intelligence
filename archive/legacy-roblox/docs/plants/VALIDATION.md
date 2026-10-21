# Validation report — Intelligent Plant Life v1

## Passed here

- C++20 plant library and publisher compiled with g++ using `-Wall -Wextra -Wpedantic -Werror`.
- Plant lifecycle tests: eligibility alone does not germinate/grow/reproduce; explicit intent and funding are required; unaffordable requests fail; finite pending jobs restore correctly.
- Controlled neural test: an explicit germination output establishes the seed; equal zero outputs preserve waiting. This verifies neural agency, not evolved intelligence.
- Carbon, water and nutrient accounting checked repeatedly over growth, reproduction, death and decomposition.
- Shared-resource test checks equal allocation for matched roots competing for limited water.
- All three founding genomes exercised; offspring mutation observed in the disclosed viable baseline.
- Checkpoint integrity, neural hidden-state round trip and continuation equivalence verified. Corrupted files rejected.
- Drought/dormancy test verifies that seeds can die rather than live indefinitely.
- AddressSanitizer and UndefinedBehaviorSanitizer run passed with leak detection disabled. LeakSanitizer could not run in this container because its process-inspection mechanism is unavailable; no leak-check claim is made.
- Real HTTP relay tests passed for authentication, full snapshot, unchanged response, topology-preserving deltas, explicit removal, new-run reset, terrain export and invalid surface rejection.
- Existing relay hardening suite passed: durable deduplication/restart, changed retry rejection, fencing, ambiguous JSON rejection, event-gap isolation, load and quota checks. Its 10,000-agent/30-exchange test measured median 37.1 ms and p95 42.6 ms in this environment; this is a regression check, not the plant benchmark.
- Existing ecology and run-options tests passed.
- New reproduction migration test passed: legacy behavior remains available, intent-v2 suppresses eligible births without neural intent, explicit intent still requires resources, CLI selection works.
- The modified main simulation translation unit passed a syntax check against its actual raylib headers. The complete graphical executable was not linked/run here.
- Actual PlantAssetLibrary and PlantRenderer Lua code ran with a math/Instance test double: three models generated, unchanged parts retained, part budgets respected and teardown completed.
- Actual PlantProtocol code checked full-state application, wrong-base rejection, unchanged topology reuse and duplicate-ID rejection.
- All nine supplied plant Lua sources passed Luau syntax compilation. Syntax compilation is not Roblox's full Studio type analysis.
- The three model fixtures were produced by explicit, ledger-accounted C++ growth requests. Preview geometry was emitted by the actual Lua asset code. The preview is not an image-generation guess or a Studio screenshot.

## Backend workloads

Benchmark.json contains four runs including file output/checkpoints and audit logging. Selected results:

| Policy | Founders | Steps | Final plants | Final organs | Mean wall ms/step | Snapshot bytes |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Wait control | 24 | 300 | 24 | 0 | 0.82 | 9,592 |
| Random neural | 24 | 600 | 308 | 1,162 | 3.32 | 230,813 |
| Viable baseline | 24 | 600 | 512 | 4,235 | 12.68 | 583,672 |
| Viable baseline, lower light | 128 | 300 | 512 | 7,742 | 11.62 | 916,895 |

These are single-seed functional/workload examples. Different founder counts and conditions are not a controlled comparison proving neural superiority. A repeated-seed fitness study would be needed for such a claim. The 512-plant result reaches the disclosed engineering population cap; it is not evidence of natural equilibrium. Unchanged topology omission reduces delta size relative to these full snapshots.

## Not verified here

- Roblox Studio import, analyzer diagnostics, exact native rendering appearance and live frame-time/latency on the user's hardware.
- Windows compiler/runtime behavior. CMake build files and commands are supplied; CMake itself was unavailable in this environment, so builds used direct g++ commands.
- A hosted Roblox server communicating through the user's production HTTPS deployment.
- Long-duration ecological stability, useful evolutionary adaptation, biome-scale carrying capacity or botanical accuracy.

## Reproduction commands

```bash
cmake -S tools/plants -B build-plants
cmake --build build-plants --config Release
ctest --test-dir build-plants -C Release --output-on-failure
python tools/plants/benchmark.py build-plants/ci_plant_sim Benchmark.json
```

In the Roblox repository, regenerate/verify native models using a snapshot and a Luau CLI:

```bash
python tools/plants/verify_and_preview.py /path/to/luau /path/to/plant_showcase.json
python tools/plants/render_preview.py
```

The C++ `plant_showcase` target produces the authored source snapshot. Model generation requires Python numpy, matplotlib and Pillow for the preview only; the running C++/Roblox system does not require those packages.
