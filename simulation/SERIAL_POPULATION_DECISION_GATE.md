# Serial Population Phase Decision Gate And Implementation Draft

## Objective

Optimize the serial population-processing phase only when the improvement
preserves the exact evolutionary contract: the same parent order, RNG sequence,
births, deaths, genomes, IDs, chemistry recycling, telemetry, and lineage
events for a paired same-seed run.

The target is not to make population processing parallel at any cost. The
target is to remove avoidable allocation, duplicated work, and data movement
from the existing serial algorithm before considering a more complex execution
architecture.

---

## Current Evidence

An eight-worker, 250,000-tick ordinary Release trace reported:

| Phase | Time | Share |
|---|---:|---:|
| Decision | 881.01s | ~55% |
| Population processing | 517.65s | ~32% |
| Interaction | 132.93s | ~8% |
| Environment, movement, metrics | 77.28s | ~5% |

Population processing is now the largest intentionally serial component. It
contains reproduction eligibility checks, birth chance rolls, genome mutation,
brain decoding, mutation-stat calculation, death event construction, chemistry
recycling, population compaction, and newborn insertion.

---

## Non-Negotiable Constraints

The optimized population path must not:

- Cap births, population size, mutation rate, or ecological work.
- Change the order in which eligible parents are evaluated.
- Change the number, order, or recipient of RNG draws.
- Change child ID assignment, parent/root-ancestor identity, or insertion
  order.
- Change mutation probability, mutation magnitude, clamping, speed-gene
  handling, or brain initialization.
- Change death-event order, biomass recycling order, or lineage event order.
- Drop or reorder telemetry records.
- Introduce a distinct reproduction or mutation model for optimized runs.

The scalar reference path remains available during every stage.

---

## Measurement Contract

Every comparison keeps these settings identical:

| Setting | Requirement |
|---|---|
| Seed | Same value per paired run |
| Worker count | Same fixed count |
| Tick count | Same finite workload |
| Archive settings | Same frame interval and caps |
| Build mode | Same ordinary Release or same optimized PGO build |
| Hardware state | Comparable power mode and background load |
| Output directory | Separate directory per run |

Use at least five repeated runs and compare median ticks/second. Use an
early-ecology workload and a late/reproduction-heavy workload.

---

## Decision Gates

### Gate 0 - Matched Baseline

Required before changing population code:

- Benchmark the same tick count and seed at the selected worker count.
- Record population-phase milliseconds per tick, peak population, archive
  output, and state hash.
- Run the current full-state equivalence test successfully.

**Pass condition:** a matched scalar-worker baseline exists.

**Fail condition:** do not optimize from unmatched run lengths or different
population histories.

### Gate 1 - Population Subphase Trace

Add trace-only timing inside `Ecology::processPopulation` for:

| Subphase | Purpose |
|---|---|
| Eligibility and support checks | Identify scanning/branching cost |
| Birth chance and RNG rolls | Identify reproduction-roll cost |
| Child copy, mutation, and brain decode | Identify genome/lifetime cost |
| Mutation-stat collection | Identify duplicated genome work |
| Death event and chemistry recycling | Identify removal-side cost |
| Compaction and insertion | Identify vector data movement/allocation cost |

Also record additions/event-vector reallocations and population-capacity growth.

**Pass condition:** one or more dominant subphases are measured, not guessed.

### Gate 2 - Low-Risk Serial Cleanup

Apply only optimizations that preserve current loop order and RNG order:

- Reuse population-event storage as well as the existing newborn buffer.
- Reserve growth capacity from observed demand without imposing a population
  limit.
- Produce mutation count and total mutation distance inside the existing gene
  mutation loop, eliminating the current second full genome scan.
- Avoid temporary objects and redundant profile lookups where profiling proves
  they matter.
- Preserve existing stable remove/insert behavior and newborn insertion order.

**Continue condition:** full-state equivalence passes and population processing
improves by at least `25%` in a matched workload.

**Stop condition:** no material gain or any divergence. Retain the reference
implementation.

### Gate 3 - Deterministic Reproduction Preparation

Only after Gate 2, evaluate a two-stage reproduction design:

1. Serially inspect eligible parents in the current order and pre-generate
   exactly the RNG values that current reproduction would consume.
2. Build read-only reproduction plans indexed by current organism slot.
3. Commit parent energy/cooldown updates, IDs, child construction, mutation,
   event generation, recycling, and insertion in the original serial order.

This stage is allowed only if it preserves the exact serial RNG stream and
observable event order. It is not permission to reorder parents or births.

**Continue condition:** full-state equivalence passes and the measured planner
removes a demonstrated bottleneck.

### Gate 4 - Parallel Mutation Prototype

Parallel mutation is optional and comes only after Gates 0-3 pass.

Required properties:

- Parent eligibility, child IDs, and every mutation random value are assigned
  serially in the existing order.
- Each worker mutates only one isolated child copy and its assigned metadata.
- Child completion results are committed in parent order.
- Brain decoding and mutation calculations retain per-gene arithmetic order.
- No worker mutates the live parent population, RNG, chemistry, or metrics.

**Continue condition:** at least `2x` improvement in the isolated child
construction/mutation subphase and exact full-state equivalence.

**Stop condition:** excessive random-value staging, memory pressure, changed
floating-point results, or any state mismatch.

### Gate 5 - Acceptance Threshold

Accept a production population-phase optimization only if all requirements hold:

| Requirement | Threshold |
|---|---|
| Population-phase throughput | At least `2x` faster in representative late ecology |
| Overall throughput | At least `1.25x` median end-to-end gain |
| Equivalence | Full-state comparison passes |
| Telemetry | No records lost, changed, or reordered |
| Memory | Measured and within an explicitly approved budget |
| Stability | Full tests and long-run multi-seed validation pass |

If an optimization improves only microbenchmarks but not end-to-end throughput,
it does not justify permanent complexity.

---

## Required Equivalence Coverage

Every accepted stage compares the scalar reference with the candidate path for:

- Organism count, order, IDs, parent IDs, root ancestors, generations, and
  birth data.
- Position, velocity, energy, health, age, food intake, cooldowns, and state.
- Full genomes, speed traits, brain inputs, hidden state, outputs, plastic
  weights, eligibility traces, and last plastic updates.
- RNG engine state and every chemistry cell, scratch cell, producer count, and
  chemistry total.
- Population IDs, death/birth events, recycling order, and configured output
  records.

Minimum workloads:

| Workload | Requirement |
|---|---|
| Focused equivalence | 1,000 ticks for representative seeds |
| Integration equivalence | 10,000 ticks for representative seeds |
| Stress equivalence | High-population, reproduction-heavy scenario |
| Output equivalence | World-frame and lineage ordering under archive load |

---

## Rough Implementation Order

1. Run matched long headless traces at the selected worker count.
2. Add trace-only population subphase timings and allocation counters.
3. Identify the dominant population subphase from real data.
4. Add reusable event storage and capacity instrumentation.
5. Merge mutation-stat calculation into the existing mutation loop.
6. Run focused and integration equivalence tests after each cleanup slice.
7. Measure Gate 2 performance against the matched baseline.
8. Design a serial reproduction-plan prototype only if eligibility/RNG planning
   remains expensive after cleanup.
9. Design an isolated child-construction prototype only if mutation/decode is
   the measured dominant cost.
10. Pre-generate random values serially and preserve parent-order commit before
    any worker touches child construction.
11. Run full-state and output-order equivalence tests.
12. Accept, revise, or discard the prototype according to Gate 5.

---

## Current Position

The project has safely parallelized decision and movement work while keeping
the ecological timeline serial. Population processing is the next measured
serial target because it now consumes roughly one-third of an eight-worker
late-run trace.

This gate does not authorize a population cap, changed birth order, changed
mutation stream, or changed ecological resolution. It authorizes measurement
and carefully staged removal of redundant serial work only.