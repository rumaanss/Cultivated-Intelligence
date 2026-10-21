## Chemistry Integration Status

The chemistry layer uses the existing 10 x 10 x 6 spatial scale and is
currently bounded and non-destructive:

- carbon, oxygen, ammonium, nitrate, and phosphate fields exist per cell;
- no-flux bounded diffusion runs once per simulation tick;
- cyanobacteria consume small nutrient amounts and produce oxygen;
- dead organisms recycle bounded carbon, ammonium, and phosphate;
- photosynthesis receives a nutrient support multiplier clamped to 0.0-1.25;
- reproduction receives the same bounded nutrient support gate;
- neutral chemistry skips the reproduction random roll, preserving the prior
	deterministic random sequence.

Chemistry does not directly kill organisms, replace the energy model, alter
feeding, or change the neural architecture. Oxygen/sulfide redox chemistry,
chemistry neural sensors, and sexual reproduction remain later stages pending
long-run stability validation.

## Live dashboard

The Raylib metrics panel now has clickable `ORGANISMS` and `CHEMICALS` tabs
below the graph. The Organisms tab shows species count, average energy, age,
health, and tracked food intake. The Chemicals tab shows average dissolved
carbon, oxygen, ammonium, nitrate, and phosphate, plus sampled chemistry
history. Press `]` or `[` to select an organism and `N` to inspect its live
28-input/20-hidden/5-output brain state. Press `M` to open the read-only
Advanced Metrics display. Left-click an organism in the world view, or use `]`
and `[`, to select it before opening the inspector with `N`. In the neural
inspector, click an input, hidden, or output neuron to inspect it; use the
mouse wheel to zoom and middle-drag to pan. Selected hidden neurons show their
activation, stable `H00`-`H19` identity, strongest current input/output and
recurrent influences, plus incoming and outgoing plastic-weight and
eligibility-trace magnitude.

The world panel is a 2D `X/Z` cross-section by default and switches to a 2D
`X/Y` top-down view with `V`. The simulation state is three-dimensional, but
the current renderer does not implement a raylib 3D camera view.

## Running and reproducibility

The default seed is `42`, so the same executable and inputs produce the same
initial population and random sequence. Use a different unsigned seed to run a
new experiment:

```powershell
.\build-validation\Release\cybernet_sim.exe --seed 12345
```

The active seed is written to the terminal and included in every row of
`output/metrics.csv`.

For a finite, no-window throughput run that preserves the ordinary simulation
tick sequence, use benchmark mode. Add `--trace` to record phase timings and a
population-state hash in `output/performance_metrics.csv`:

```powershell
.\build-validation\Release\cybernet_sim.exe --benchmark-ticks 100000 --trace
```

Use `--workers <N>` to run decision and movement calculations through `N` fixed
worker threads. The default is `1`; worker count is a performance setting and
does not alter the simulation's evolutionary rules.

Use `--archive-dir <directory>` to place CSV archives and benchmark reports on
another drive. This changes only where observational output is stored; all live
simulation state remains in RAM.

## Neural interface

Each organism owns an inherited 1,111-value genome: 1,110 values decode into a
28-input, 20-hidden-unit recurrent neural network with lifetime-only synaptic
plasticity, and one value controls speed within the species-specific range.
New organisms inherit a mutated copy of their parent's genome; the program does
not use reinforcement learning, fixed policy weights, forced actions, or
external fitness selection.

The neural portion is 560 input-to-hidden weights, 400 genetic recurrent
weights, 20 hidden biases, 100 hidden-to-output weights, 5 output biases,
20 modulator weights, 1 modulator bias, and 4 plasticity traits. The separate
speed gene makes the organism-level total 1,111.

Founders receive reproducible seed-driven initial ages below their species
lifespan, while newborns begin at age zero. World boundaries reflect and damp
the impacted velocity component, preventing persistent wall adhesion.

Inputs are normalized to `[-1, 1]` and include prey direction/distance,
energy, velocity, depth, age, noise, light, crowding, local food,
reproductive state, boundary direction/proximity, nearby-threat direction,
threat distance/density, and a bias input. The former mate inputs were
repurposed because reproduction is currently asexual. The five outputs are
forward motion, strafe motion, vertical motion, one reserved output, and
feeding intent. A predator can feed only when its evolved feeding output is at
least `0.5`, prey is within capture range, and its feeding cooldown is ready.

Boundary and threat inputs are sensory information only. They do not turn an
organism, impose wall avoidance, train a policy, or affect reproduction. Any
response must be expressed by the evolved neural controller.

## Advanced metrics

Advanced metrics are passive observations sampled with ordinary metrics. They
do not modify live brains, genomes, actions, reproduction, or selection.

- Evolution: generation/speed spread, active founder lineages, and sampled
	genome diversity.
- Behavior: wall contacts and dwell time, inward actions near boundaries,
	prey/threat visibility, feeding precision, and threat retreat rate.
- Learning: sampled plastic-weight magnitude, hidden-state variance, output
	variance, and output saturation.
- Cognitive probes: copies of sampled brains receive fixed boundary, prey, and
	threat inputs. Their alignment scores are logged for comparison only; probes
	never train or alter live organisms.

## Output files

Each run recreates these CSV files under `output/`:

- `metrics.csv`: sampled population, environmental, birth/death, and seed data
	every 100 simulation ticks.
- `world_frames.csv`: living-organism positions and state at the same sampling
	interval by default. Use `--frame-interval` and `--max-world-frames` to
	control its cadence and cap its number of sampled frames; defaults are 100
	ticks and 1,000 frames.
- `run_metadata.csv`: seed, sampling settings, world dimensions, and brain
	architecture for reproducible analysis.
- `evolution_metrics.csv`: lineage, generation, speed, and genome-diversity
	summaries per species.
- `behavior_metrics.csv`: wall, prey, threat, and feeding summaries per
	species.
- `learning_metrics.csv`: plastic weights, eligibility traces, per-tick plastic
	updates, modulation, and activation-state summaries per species.
- `benchmark_metrics.csv`: passive cloned-brain boundary, prey, and threat
	probe scores per species.
- `demography_metrics.csv`: per-species living and biologically eligible
  population, interval births/deaths, net change, and recent-birth timing.
- `energy_flow_metrics.csv`: realized photosynthesis, prey capture, predator
	gain, movement energy draw, energy at death, and realized assimilation by
	species.
- `mortality_metrics.csv`: interval starvation, age, and predation deaths by
	species.
- `spatial_metrics.csv`: per-species occupancy of the 10 x 10 x 6 spatial
	grid, dispersion entropy, and depth distribution.
- `reproduction_metrics.csv`: per-species parent concentration, age at birth,
	and realized parent-to-child mutation distance.
- `trait_selection_metrics.csv`: descriptive speed comparisons for living,
  reproducing, newborn, and dying organisms.
- `extinction_events.csv`: the tick at which an observed species reaches zero
	living organisms.
- `lineage.csv`: birth and death events with parent and root-ancestor IDs;
	deaths include their recorded cause.
- `performance_metrics.csv`: benchmark tick throughput, peak population,
  population-state hash, and optional per-phase timings from `--trace`.

Lineage output is capped at 500,000 events by default for long runs. Use
`--max-lineage-events` to set another positive limit; aggregate birth/death
metrics remain complete even after the lineage event file reaches its cap.

The world-frame output is CSV, not JSON.

## Builds and tests

Use a normal build directory for development and tests:

```powershell
cmake -S . -B build-validation
cmake --build build-validation --config Release
ctest --test-dir build-validation -C Release --output-on-failure
```

The test suite includes deterministic 1,000-tick and 10,000-tick integration
runs that check valid bounded organism state and guard against all organisms
accumulating on world boundaries.

Raylib is already available at `build-pgo-vscode/_deps/raylib-src`. To reuse
that checkout instead of allowing CMake to fetch another copy for a new build
directory, append this option to the configure command:

```powershell
-DFETCHCONTENT_SOURCE_DIR_RAYLIB="$PWD\build-pgo-vscode\_deps\raylib-src"
```

For MSVC profile-guided optimization, use a separate fresh build directory.
The PGO mode applies only to `cybernet_sim`; test targets remain ordinary
executables.

```powershell
Remove-Item .\build-pgo-vscode\Release\*.pgc -ErrorAction SilentlyContinue
cmake -S . -B build-pgo-vscode -DCYBERNET_PGO_MODE=INSTRUMENT
cmake --build build-pgo-vscode --config Release --target cybernet_sim
```

For the instrumented executable, add the MSVC PGO runtime directory to the
current Developer PowerShell session before running it:

```powershell
$pgoBin = "$env:VCToolsInstallDir\bin\Hostx64\x64"
$env:Path = "$pgoBin;$env:Path"
.\build-pgo-vscode\Release\cybernet_sim.exe --seed 42
Get-ChildItem .\build-pgo-vscode\Release\*.pgc
```

After representative workloads have produced `.pgc` files, do not delete them.
Reconfigure and rebuild the same directory to consume those profiles:

```powershell
cmake -S . -B build-pgo-vscode -DCYBERNET_PGO_MODE=OPTIMIZE
cmake --build build-pgo-vscode --config Release --target cybernet_sim
.\build-pgo-vscode\Release\cybernet_sim.exe --seed 42
```

When source code changes, collect a fresh PGO profile set before rebuilding the
optimized executable.

## Immediate priorities

1. Reconfigure the CMake Tools project and rerun the complete test suite,
	recording the duration of the 10,000-tick integration test as a baseline.
2. Use representative multi-seed, late-population workloads to collect fresh
	PGO profiles, then compare only optimized-release throughput and stability.
3. Establish ecological baselines from the existing CSV outputs before any
	brain redesign. Any expanded-input experiment must use a separately
	versioned genome layout; the current reference is 28 inputs, 20 hidden
	units, 5 outputs, 1,110 neural genes, and one speed gene.
