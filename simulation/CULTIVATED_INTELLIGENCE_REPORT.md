# CULTIVATED INTELLIGENCE VERSION 0.77 REPORT - REVISED

## BY RUMAAN SAAMIR SHARIF

## OCTOBER 2026

Current project copy: `E:\cultivated_intelligence\ci_cplusv1.16`

Technology: C++20, CMake, MSBuild, Visual Studio Build Tools 2026, raylib 5.5

Simulation domain: Evolving 3D aquatic digital organisms (Cyber-Nets)

Current program phase: Validated simulation baseline with expanded research
telemetry, interactive neural inspection, and safe performance measurement.
Long-run ecological analysis and PGO optimization are the next workstreams.

---

## 1. Executive Status

Cultivated Intelligence is a functioning, observable C++ artificial-life
simulation with native visualization, deterministic seed support, chemistry,
CSV telemetry, an interactive neural inspector, and a headless benchmark path.

| Milestone | Status |
|---|---|
| Local build environment restoration | Complete |
| Baseline build and runtime validation | Complete historically; current full rerun pending |
| Z-as-depth world-coordinate standardization | Complete |
| Observational metrics and event counters | Complete |
| Cause-of-death and extinction metrics | Complete |
| Demography, energy-flow, spatial, reproduction, and trait metrics | Complete |
| Native C++ CSV output | Complete |
| Bounded async archival for high-volume CSV files | Complete |
| Native raylib visualization | Complete |
| Interactive brain inspector foundation | Complete |
| Headless benchmark and trace path | Complete |
| PGO instrumentation build | Complete and manually compiled |
| Full post-change automated test execution | Pending CMake Tools configuration |

The project is no longer in an early "can it run?" stage. It is suitable for
controlled performance work, long-run ecological analysis, and isolated
experimental lineages.

---

## 2. Product Mission

Cultivated Intelligence models an evolving aquatic ecosystem populated by
digital organisms with inherited genomes and recurrent neural control.

The simulation is built around evolutionary selection rather than externally
trained intelligence.

| Principle | Design rule |
|---|---|
| Initial population | Randomized inherited founder genomes |
| Brain adaptation | Lifetime-only self-modulated recurrent plasticity |
| Selection pressure | Survival, feeding, reproduction, mutation, aging, starvation, predation, and death |
| Inheritance | Mutated genome only |
| Prohibited inheritance | Plastic weights, traces, hidden state, outputs, or learned lifetime state |
| Prohibited training | No reinforcement learning, labels, reward signal, gradients, or pretrained behavior |
| Performance rule | Do not cap births, growth, mutation, or ecological processing for speed |

The scientific value of the project depends on preserving these constraints.

---

## 3. Current Development Environment

| Item | Current state |
|---|---|
| Active project root | `E:\cultivated_intelligence\ci_cplusv1.16` |
| Language standard | C++20 |
| Build system | CMake + MSBuild |
| Build toolchain | Visual Studio Build Tools 2026 |
| Renderer/framework | raylib 5.5 |
| Main executable | `build\Release\cybernet_sim.exe` or configured equivalent |
| PGO build directory | `build-pgo-vscode` |
| Development workflow | VS Code integrated terminal |
| Native data output | C++ CSV generation |
| External analysis dependency | Not required |

The executable supports seed selection, configurable archival limits, headless
benchmarking, phase tracing, and an optional archive directory on another
storage drive.

---

## 4. Simulation Architecture

The simulation is organized around distinct system responsibilities:

| System | Responsibility |
|---|---|
| Main application | Simulation loop, run modes, input, rendering coordination, UI state |
| Brain/RNN | Genome decoding, recurrent processing, neuromodulation, plasticity |
| Lifecycle | Aging, movement, photosynthesis, feeding completion, death |
| Ecology | Sensing, prey capture, mutation, reproduction, population processing |
| Chemistry | Nutrient fields, diffusion, primary-producer use, recycling |
| Physics | Position, velocity, movement, bounds, spatial constraints |
| Celestial/day cycle | Day/night and ambient-light state |
| Metrics | Snapshots, event counters, research reporting |
| CSV output | Persistent records and bounded background archival |
| Renderer | 2D projections, HUD, graphs, dashboards, organism visualization |
| Brain inspector | Selected-organism neural and plasticity-state visualization |
| Benchmark path | Headless finite-run measurement and optional phase trace |

Known core implementation areas include:

```
src/main.cpp
src/brain/rnn_brain.cpp
src/brain/brain_inspector.hpp
src/simulation/async_record_writer.cpp
src/simulation/lifecycle.cpp
src/simulation/metrics.cpp
src/world/chemistry.cpp
src/world/ecology.cpp
src/world/physics.cpp
```

---

## 5. World Model and Coordinate Standard

The simulation uses one explicit coordinate convention throughout the world,
ecology, physics, sensing, chemistry, metrics, and visualization systems.

| Axis | Meaning | Bounds | Ecological role |
|---|---|---:|---|
| X | Horizontal | 0-100 | Horizontal world position |
| Y | Horizontal | 0-100 | Horizontal world position |
| Z | Vertical depth | 0-60 | Depth, light exposure, photosynthesis |
| Z = 0 | Deep water | - | Lowest light exposure |
| Z = 60 | Surface | - | Highest light exposure |

Only Z affects depth-derived behavior, light exposure, and photosynthesis.

| View | Representation |
|---|---|
| Default world view | 2D X/Z cross-section |
| Top-down view | 2D X/Y horizontal plane |
| Simulation state | Full XYZ world geometry |
| 3D camera renderer | Not currently implemented |

---

## 6. Ecosystem Baseline

The established ecosystem includes the aquatic food web:

```
Cyanobacteria -> bacterivores -> Bodo saltans
```

| Process | Status |
|---|---|
| Cyanobacterial photosynthesis | Working |
| Feeding and capture | Working |
| Predator-prey relationships | Working |
| Reproduction | Working |
| Mutation | Working |
| Starvation | Working |
| Aging | Working |
| Predation death | Working |
| Biomass recycling | Working |
| Cause-of-death reporting | Working |
| Species-extinction event reporting | Working |

The chemistry layer is currently bounded and non-destructive:

| Chemistry feature | Current state |
|---|---|
| Spatial grid | 10 x 10 x 6 |
| Fields | Dissolved carbon, oxygen, ammonium, nitrate, phosphate |
| Diffusion | No-flux bounded diffusion once per tick |
| Primary production | Cyanobacteria consume nutrients and produce oxygen |
| Recycling | Dead organisms add bounded carbon, ammonium, and phosphate |
| Photosynthesis | Nutrient multiplier clamped to 0.0-1.25 |
| Reproduction | Same bounded nutrient-support gate |
| Neutral chemistry | Skips reproduction random roll to preserve prior random sequence |

Chemistry does not directly kill organisms, replace the energy model, alter
feeding mechanics, or change the neural architecture.

---

## 7. Neural Architecture and Evolutionary Constraints

Current validated brain lineage:

| Layer | Count | Purpose |
|---|---:|---|
| Inputs | 28 | Environmental and internal organism sensing |
| Hidden neurons | 20 | Recurrent decision processing |
| Outputs | 5 | Behavioral control |
| Neural genome | 1,110 genes | Inherited neural and plasticity specification |
| Organism genome | 1,111 genes | Neural genome plus one speed gene |

Genome layout:

| Gene range | Meaning |
|---|---|
| 0-559 | Input -> hidden weights |
| 560-959 | Genetic recurrent hidden -> hidden weights |
| 960-979 | Hidden biases |
| 980-1079 | Hidden -> output weights |
| 1080-1084 | Output biases |
| 1085-1104 | Neuromodulator weights |
| 1105 | Neuromodulator bias |
| 1106-1109 | Plasticity rate, trace decay, forgetting, plasticity scale |
| 1110 | Separate organism speed gene |

Recurrent-plasticity model:

| Component | Count | Inherited? |
|---|---:|---|
| Genetic recurrent synapses | 400 | Yes |
| Lifetime-only plastic recurrent synapses | 400 | No |
| Eligibility traces | 400 | No |
| Hidden state | 20 | No |
| Output state | 5 | No |

The reference architecture is `28 inputs / 20 hidden / 5 outputs / 1,110
neural genes / 1 speed gene`. Expanded architectures must be separate,
versioned experiments.

---

## 8. Brain Inspector - Current State

The neural inspector is a live selected-organism research tool. It reads a
copied inspection snapshot and does not alter brain state, randomness,
inheritance, or actions.

| Capability | Status |
|---|---|
| Persistent selected-organism state | Complete |
| Organism selection by `[` and `]` | Complete |
| Organism selection by world-view left click | Complete |
| Visible selected-organism marker | Complete |
| Live 28/20/5 architecture display | Complete |
| Neuron selection | Complete |
| Mouse-wheel zoom and middle-drag pan | Complete |
| Live input, hidden, and output states | Complete |
| Plastic weights and eligibility traces | Complete |
| Last plastic updates and modulator state | Complete |
| Dynamic hidden-neuron evidence detail | Complete |

| Visual treatment | Meaning |
|---|---|
| Blue | Positive activation or weight |
| Red | Negative activation or weight |
| Connection thickness | Absolute displayed weight magnitude |
| Yellow ring | Selected neuron |
| White world ring | Selected organism |

Selected hidden neurons are identified structurally as `H00` through `H19` in
their detail panel. They report activity mode, strongest current input/output
influence, recurrent links, and incoming/outgoing plasticity and trace values.
They do not receive fixed semantic labels.

---

## 9. Metrics, Telemetry, and CSV Reporting

The simulation includes observational metrics and event reporting without
altering organism behavior, random-number usage, tick ordering, or brain
behavior.

| Category | Reported information |
|---|---|
| Population | Total and per-species counts, energy, age, speed, health |
| Environment | Tick, daylight, ambient light, chemistry summary |
| Demography | Eligible organisms, births, deaths, net change, recent births |
| Mortality | Starvation, age, predation deaths by species |
| Extinction | Tick and sequence of observed species disappearance |
| Energy flow | Photosynthesis, prey capture, predator gain, movement, death energy |
| Spatial ecology | Occupancy, entropy, mean depth, depth deviation |
| Reproduction | Parent concentration, parent age, mutation count and distance |
| Trait selection | Living, parent, newborn, and death speed comparisons |
| Learning | Plastic weights, traces, updates, modulation, activation state |
| Cognitive probes | Passive cloned-brain boundary, prey, and threat comparisons |

Persistent output:

| Output | Purpose |
|---|---|
| `metrics.csv` | Population, environment, seed, births, deaths |
| `world_frames.csv` | Configurable organism world snapshots |
| `run_metadata.csv` | Seed, sampling, world, and brain configuration |
| `evolution_metrics.csv` | Generation, speed, lineage, genome diversity |
| `behavior_metrics.csv` | Boundary, prey, threat, feeding behavior |
| `learning_metrics.csv` | Plasticity, traces, updates, modulation, activation state |
| `benchmark_metrics.csv` | Passive cognitive probe results |
| `demography_metrics.csv` | Population and reproductive readiness |
| `energy_flow_metrics.csv` | Ecological energy transfers |
| `mortality_metrics.csv` | Cause-specific mortality |
| `spatial_metrics.csv` | Occupancy and depth distribution |
| `reproduction_metrics.csv` | Reproductive concentration and mutation distance |
| `trait_selection_metrics.csv` | Descriptive inherited-speed comparisons |
| `extinction_events.csv` | Species extinction events |
| `lineage.csv` | Birth/death lineage events with cause, speed, and mutation data |
| `performance_metrics.csv` | Headless benchmark throughput, phase timings, state hash |

World-frame and lineage records use independent bounded background writer
queues. Records retain per-file order. If a queue reaches capacity, simulation
waits instead of discarding scientific output.

---

## 10. Native Visualization and Analysis

Visualization and graphing are implemented natively in C++ using raylib.
Python is not required for simulation visualization, graphing, or core
analysis.

| Mode | Purpose |
|---|---|
| 2D X/Z world view | Depth-aware ecosystem inspection |
| 2D X/Y top-down view | Horizontal distribution and movement analysis |
| Native graph panel | Population and chemistry-history analysis |
| Organism/Chemicals dashboards | Per-species and chemistry summaries |
| Brain inspector | Organism-level neural and plasticity-state analysis |
| Advanced metrics overlay | Passive research metrics and probe summaries |

The renderer supports multiple simulation ticks per rendered frame. Headless
benchmark mode removes rendering only; it executes the ordinary tick sequence.

---

## 11. Validation Status

| Validation area | Current evidence |
|---|---|
| Source diagnostics for current edits | Clean |
| Brain regression coverage | Present; full current rerun pending |
| Fixed-seed reproducibility coverage | Present in simulation tests |
| 1,000/10,000 tick integration coverage | Present in simulation tests |
| CSV schema coverage | Present in metrics tests |
| Async writer ordering coverage | Added as `AsyncRecordWriterTests` |
| Fixed worker decision/movement equivalence | Passed for 1, 2, 4, 8, and 16 workers over 1,000 ticks |
| Manual instrumented PGO build | Compiled successfully |
| Headless trace runtime | 100 ticks completed successfully |
| Async archive output runtime | Performance, world-frame, and lineage files created |
| CMake Tools test discovery | Not configured in current VS Code session |

The manual headless trace used:

```powershell
.\build-pgo-vscode\Release\cybernet_sim.exe --benchmark-ticks 100 --trace --archive-dir output-validation
```

The instrumented executable is expected to be slow and must not be used for
release throughput conclusions.

---

## 12. PGO Status and Performance Strategy

Profile-Guided Optimization is controlled by `CYBERNET_PGO_MODE`.

| Phase | Purpose |
|---|---|
| `OFF` | Ordinary build |
| `INSTRUMENT` | Collect MSVC PGO profile data |
| Representative runs | Exercise real simulation paths |
| `OPTIMIZE` | Consume collected profile data |
| Final benchmark | Measure optimized executable only |

Safe performance work completed:

- Headless finite benchmark mode: `--benchmark-ticks <N>`.
- Optional phase trace: `--trace`.
- Population-state hash in benchmark output.
- Reused ecology newborn buffer and move insertion.
- Bounded, lossless background archival for world-frame and lineage records.
- `--archive-dir <directory>` for cold telemetry storage.
- Fixed-chunk decision and movement execution through `--workers <N>`.

Performance work must not cap births, reduce population growth, skip ecology,
change mutation, alter random ordering, or modify selection pressure.

---

## 13. Strategic Next Phase

Priority 1 - Complete validation and measure performance

- Configure CMake Tools or use a configured build directory to run the full
  suite, including async writer, metrics, run-options, and integration tests.
- Run headless traces on ordinary Release, instrumented PGO, and optimized PGO
  executables.
- Compare same-seed state hashes before accepting structural optimization.

Priority 2 - Long-duration ecological analysis

- Run long multi-seed simulations.
- Compare persistence, extinction, energy flow, reproduction, spatial
  occupancy, depth use, and trait-selection metrics.
- Compare chemistry-enabled and chemistry-neutral experiments before adding
  stronger chemical effects.

Priority 3 - Research-surface refinement

- Add history charts and selected-synapse inspection to the brain inspector.
- Add exact checkpointing only when full RNG, chemistry, celestial, organism,
  and lifetime-brain state can be serialized and restored faithfully.
- Use phase traces before adding more output threads, SIMD, or parallel phases.

Priority 4 - Separate experimental lineage design

Any expanded-input or expanded-genome architecture must be separately versioned
and must not reinterpret the current baseline.

---

## 14. Governance Rules for Future Changes

| Rule | Reason |
|---|---|
| Preserve the 28/20/5 and 1,111-gene baseline | Maintains scientific comparability |
| Do not cap births or population growth for performance | Preserves selection pressure |
| Keep world dimensions centrally defined | Prevents coordinate drift |
| Keep capture/search logic within Ecology | Maintains subsystem boundaries |
| Keep metrics observational | Prevents telemetry from affecting outcomes |
| Preserve record order and do not drop telemetry silently | Protects research output integrity |
| Store archives on disk, live state in RAM | Preserves simulation performance |
| Validate after each subsystem change | Limits regression scope |
| Use state hashes for structural optimization checks | Protects same-seed comparison |
| Do not use external reward signals | Preserves the evolutionary model |
| Fork new brain designs into new lineages | Preserves experimental control |

---

## 15. Current Management Position

Cultivated Intelligence has progressed into an instrumented artificial-life
research platform with:

- A stable `28/20/5` recurrent-plastic brain lineage.
- A verified 1,110 neural-gene plus one speed-gene organism genome.
- Correct depth-aware spatial modeling.
- Bounded chemistry integration.
- Native 2D visualization, graphs, and organism selection.
- An interactive neural inspector with live plasticity evidence.
- Expanded demographic, mortality, extinction, energy-flow, spatial,
  reproduction, trait, learning, and lineage telemetry.
- A headless benchmark/trace path and archive-directory support.
- A ready path toward PGO and controlled long-run study.

The immediate objective is measurement, repeatability, and optimized execution
without intervening in evolution. The next accepted changes should be driven by
full test results and measured phase timing, not speculative optimization.