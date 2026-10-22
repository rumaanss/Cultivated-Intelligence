# Aquatic foundation acceptance record

Tested 2026-10-21 in the supplied Linux workspace. Native code was built with
g++ C++20, optimization enabled, and the existing native core library. Luau checks
use the existing Luau runtime/compiler. Windows MSVC, PowerShell execution and
Roblox GPU presentation were not available here; the supplied Build.ps1 builds
and runs native acceptance tests on the user's machine.

## Passed

- All three founder seeds (1, 42, 9876) reached 100,000 ticks.
- Nonnegative finite chemistry; C/N/P ledger conservation; reaction-accounted O₂.
- Photon demand bounded by supplied light.
- Darkness stops photosynthesis; illuminated growth exceeds dark controls.
- Missing dissolved phosphate prevents first-step production.
- Anoxia prevents aerobic DOC consumption.
- Maintenance, mortality, detritus settling, decomposition and nutrient recycling.
- Exact checkpoint continuation versus uninterrupted simulation.
- Corrupt checkpoints and wrong seeds rejected.
- Actual native HTTP authentication, bounded interests, acknowledged-data
  suppression, exact retry responses, empty-interest cleanup and checkpoint resume.
- Fresh-world requests cannot replace existing checkpoints.
- Aquatic executable rejects legacy biology checkpoint directories.
- Existing native biology HTTP regression, including persistence/restart, passed
  with the modified transport.
- Luau packet validation rejects invalid identity, duplicate IDs and NaN.
- Client test doubles: 6 patch / 192 part cap, reuse, terrain grounding queries,
  zero-biomass rig destruction, interest exit, stale-data and shutdown cleanup.

## Recorded local measurements

The three 100,000-tick ecological runs together took **17.509 seconds** in the
optimized kernel test (approximately 0.0584 ms/tick). This excludes Roblox rendering
and networking. It includes periodic ledger validation; it is not a planetary or
worst-case frame-time benchmark.

Final biomass (mmol C), rounded:

| Seed | Suspended producers | Attached mats | Decomposers |
|---|---:|---:|---:|
| 1 | 1,733,880 | 12,559.6 | 111,429 |
| 42 | 1,733,890 | 12,439.4 | 111,411 |
| 9876 | 1,733,880 | 12,575.9 | 111,424 |

These show guild persistence in this limited, closed foundational scenario.
They do not establish a robust full food web, species diversity or evolutionary
adaptation. Deep/shaded mat biomass declines; no mechanism rescues it artificially.

One measured 24-patch native response was **5,390 bytes**, with **0.606 ms** reported
native work. That is an observed sample, not a latency percentile or a Roblox FPS
guarantee. Full internal lake summaries are about 46 KB and remain in C++ memory;
only selected patch rows are transmitted.

## Reproduce

Build and run all configured native tests:

    powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\Build.ps1

Run just the new native acceptance tests after building:

    ctest --test-dir build/native -C Release -R "AquaticFoundation|NativeAquaticIntegration" --output-on-failure

The optional native HTTP acceptance uses Python only as a developer test client.
The live application has no Python dependency. If Python is absent CMake skips
that HTTP test, but still builds/runs the C++ biochemical acceptance test.

Optional Luau checks, if Luau is already installed:

    py planet/tests/run_aquatic_checks.py --luau path/to/luau.exe

## Studio acceptance

1. Keep the existing lake place and permissions. Stop the previous native process.
2. Launch a new aquatic runtime; connect Rojo and sync before Play.
3. Confirm the native terminal reports non-neural aquatic cells and an advancing tick.
4. Select a population in the existing research interface. Verify live chemistry, nonnegative concentrations and small C/N/P residuals.
5. Inspect mats on the bed and restored microbial model illustrations underwater.
6. Leave the lake: local cohort models should be removed; the native tick continues.
7. Stop native simulation: the client removes stale cohorts within about 5 seconds.
8. Restart the same runtime without -NewWorld: tick and material state resume.
9. Compare frame/relay timings at the same camera position. Water, sky and controller
   source files are outside this update.


## Research/model integration follow-up

The original Cyanobacteria body is now reused at a 0.16-stud display bounding
radius. The Bacterivore body is adapted for the non-neural decomposer representation
at 0.42 studs including its appendage. This is artistic reuse, not a taxonomic claim.
Bodo and other consumer designs are retained without spawning nonexistent guilds.

Passed actual body-library tests: 18 cyanobacteria rigs and 6 decomposer rigs within
192 parts, 18 correctly registered population records, repeated-update reuse,
zero-biomass rig destruction, range exit, stale cleanup and tag cleanup.

Passed research interface tests: biomass/O₂/PAR instead of fabricated individual
energy/health/age, raw biomass trends, stale sample rejection, notebook export.
Existing plant, UI, frame, sky, presentation and performance-probe checks passed.
Native HTTP/resume acceptance passed after exposing the existing atmospheric
reservoir values. The biochemical equations/checkpoint schema were unchanged;
the earlier 300,000-tick kernel result was not rerun for a presentation-only change.

Actual Windows/Studio visual and GPU validation remains outstanding.
