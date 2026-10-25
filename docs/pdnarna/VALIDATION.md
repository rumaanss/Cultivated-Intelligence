# Validation — pdnarna-4 behavior update

Validated on 2026-10-23 against the previously delivered pdnarna-3 integration.
This report covers the changed movement model; it does not reuse the old model's
long-run results as evidence.

## Automated checks

- Native Release build: the 34-test suite passed, including biology, original
  terrestrial/aquatic regressions, real HTTP/authentication/retry/resume and runtime
  isolation. Additional behavior and migration assertions were strengthened and
  rerun after that complete suite; their logs are included.
- Native behavior: local light, food and oxygen responses; speed proportional to
  paid motor protein; no active movement without oxygen; no instantaneous speed
  boost from an allele alone; attached immobility; C/N/P and oxygen/photon ledgers;
  exact stochastic continuation of position, route, behavior and lifecycle state.
- Normal long runs: over 95% of living mobile colonies record paid travel;
  attached parents record none. The mutating endpoints contain 687–723 distinct
  living genomes. See `evidence/ecology/behavior-summary.json`.
- Upgrade: an actual checkpoint from the previous released executable preserves
  all original pools, six alleles, lineage and RNG. Added machinery starts at zero.
  The original backup is byte-identical; a differing older backup is preserved.
- Roblox/Luau: all 75 production scripts compile; general UI/sky tests pass. Aquatic
  tests cover persistent ID across patch movement, measured interpolation, duplicate
  packet handling, growth scaling, division size change, daughter identity, allele
  colors, explicit death cleanup, culling, stale/shutdown cleanup and part limits.
  A real C++ observation packet is also replayed through the Luau consumer.
- Native HTTP: fresh and mature worlds pass interest selection, bounded packets,
  authentication, retries and save/resume. Mature selected response: 24 patches,
  34,147 bytes in the recorded run; this is one measurement, not the maximum budget.
- Python and PowerShell installers: preflight, atomic conflict refusal, LF/CRLF,
  install, repeat install, edited-file protection and full/repeated rollback pass.
- Scoped Rojo project builds. The supplied place changes exactly four Source
  properties in two chunks; the other 1,484 chunks remain byte-identical to the
  original uploaded place. See the verification JSON.

## Ecology acceptance

Six 100,000-tick runs, seeds 1 / 42 / 9876 with mutation probability 0 / .02.
Each process restarts every 5,000 ticks and checks invariants every 500 ticks.
The independent assessor recomputes element totals from raw saved material pools
and derives turnover from ancestry. All 120 segments must be present.

The unchanged gate requires at least 50 colonies per guild, no population-cap hit,
conservation and births/deaths, plus mutation events in mutating runs. In the late
80,000–100,000 window, each guild's maximum/minimum biomass must be <=1.5 and its
birth/death ratio must be 0.5–2. There is no reseeding or rescue.

Guild order is suspended producer / attached producer / decomposer.

| Case | Final colonies | Late biomass max/min | Late births/deaths | Result |
| --- | --- | --- | --- | --- |
| 1-fixed | 17,359 / 153 / 6,059 | 1.018 / 1.092 / 1.015 | 1.025 / 0.714 / 1.134 | PASS |
| 1-mutating | 17,538 / 135 / 5,448 | 1.027 / 1.090 / 1.020 | 1.017 / 0.842 / 1.081 | PASS |
| 42-fixed | 17,218 / 119 / 5,811 | 1.031 / 1.044 / 1.009 | 0.985 / 1.164 / 1.142 | PASS |
| 42-mutating | 17,125 / 145 / 6,101 | 1.023 / 1.078 / 1.019 | 0.989 / 1.011 / 1.165 | PASS |
| 9876-fixed | 17,187 / 156 / 6,555 | 1.027 / 1.047 / 1.020 | 1.008 / 0.893 / 1.151 | PASS |
| 9876-mutating | 17,043 / 159 / 6,016 | 1.035 / 1.169 / 1.020 | 0.998 / 1.265 / 1.081 | PASS |

These are finite-horizon engineering checks, not proof of perpetual equilibrium
or biological calibration of a named species.

## Timing and platform limits

- 42-fixed: p95 step times 5.806, 6.028, 5.852 ms in sequential repeats from copies of the 100,000-tick checkpoint.
- 42-mutating: p95 step times 6.562, 6.298, 5.958 ms in sequential repeats from copies of the 100,000-tick checkpoint.

Each repeat runs 2,000 ticks. The timer includes the C++ environmental/physiology
step and excludes HTTP, snapshot encoding, persistence, validation and Roblox.
The shared host can affect timings; this is not a Roblox FPS measurement.

Windows/MSVC compilation and actual Roblox Studio visual/FPS behavior were not
executed here. PowerShell installer tests ran with PowerShell on Linux. The
validator's Windows checkpoint replacement uses MoveFileExW but remains untested
on Windows. Local Studio acceptance should check movement visibility, grounding,
selection/notebook behavior, sample counts, birth/death presentation, feed stoppage
and reconnect. Unobserved or culled colonies are not falsely animated as deaths.

Sources, per-file hashes, test logs, all six final checkpoints, CSV traces,
independent assessment and benchmark metadata are included. Trial checkpoints are
evidence and are never installed over your running simulation.
