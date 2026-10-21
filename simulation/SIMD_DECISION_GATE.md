# SIMD Decision Gate And Implementation Draft

## Objective

Develop a SIMD-oriented brain execution path only if it delivers at least a
`4x` median end-to-end simulation throughput gain over the accepted scalar
worker baseline, without changing organism individuality, evolutionary rules,
randomness, ecological resolution order, or telemetry integrity.

This is an execution-architecture experiment, not a new brain lineage. The
reference organism remains the current `28 inputs / 20 hidden / 5 outputs /
1,110 neural genes + 1 speed gene` baseline.

---

## Non-Negotiable Constraints

The SIMD path must not:

- Cap population, births, mutation, or ecological work.
- Change the random-number sequence received by any organism.
- Change serial feeding, predation, chemistry, aging, death, reproduction,
  mutation, population insertion/removal, or lineage ordering.
- Drop, reorder, or alter telemetry records.
- Remove an organism's independent genome, brain lifetime state, identity,
  lineage, or inspector visibility.
- Introduce a separate behavior model for SIMD organisms.

The scalar path remains available as the reference implementation.

---

## Measurement Contract

Every comparison must keep these settings identical:

| Setting | Requirement |
|---|---|
| Seed | Same value per paired run |
| Worker count | Same fixed count |
| Tick count | Same finite workload |
| Archive settings | Same frame interval and caps |
| Build mode | Same ordinary Release or same optimized PGO build |
| Hardware state | Comparable power mode and background load |
| Output directory | Separate directory per run |

The primary measurement is median ticks/second across at least five repeated
runs. Use both an early-ecology workload and a late/high-population workload.

---

## Decision Gates

### Gate 0 - Establish The Scalar Reference

Required before SIMD work:

- Complete the worker-count benchmark matrix for `1`, `2`, `4`, and `8`
  workers using ordinary Release.
- Select the best stable worker count for the current machine.
- Record median ticks/second, phase timings, peak population, peak memory, and
  population-state hash.
- Run the full existing test suite from a configured build directory.

**Pass condition:** a documented scalar-worker baseline exists.

**Fail condition:** do not begin SIMD layout work while worker count, test
health, or baseline workload is uncertain.

### Gate 1 - Confirm The Opportunity

Required evidence:

- In optimized scalar-worker Release, decision work remains at least `70%` of
  representative tick time.
- The workload is compute- or memory-bound in the brain path rather than in
  output, chemistry, population processing, or rendering.
- Ordinary compiler optimization and PGO have already been measured.

**Pass condition:** brain decision work remains the dominant research-cost
path after current safe optimizations.

**Fail condition:** optimize the measured non-brain bottleneck instead.

### Gate 2 - Isolated SIMD Kernel Prototype

Build a private prototype that batches only brain decisions in fixed blocks.
Do not replace canonical organism storage yet.

Required prototype properties:

- Scalar fallback remains available.
- Fixed worker chunks remain unchanged.
- Inputs are gathered in current organism-vector order.
- Each SIMD lane maps to one explicit organism slot.
- Results are scattered back to that same slot before movement.
- No shared ecology mutation occurs inside the prototype.

Measure scalar versus prototype with the same workload.

**Continue condition:** at least `2x` decision-phase improvement and at least
`1.5x` end-to-end improvement, with no full-state mismatch.

**Stop condition:** lower gain, excessive gather/scatter cost, or any state
divergence. Keep the scalar-worker architecture and do not proceed to layout
replacement.

### Gate 3 - Equivalence Before Canonical Layout Change

The SIMD prototype must match the scalar reference for all of the following:

- Organism count, order, IDs, parent IDs, root ancestors, generations, and
  birth data.
- Position, velocity, energy, health, age, food intake, cooldowns, and state.
- Full genomes and speed traits.
- Inputs, hidden state, outputs, plastic weights, eligibility traces, and last
  plastic updates for every brain.
- RNG engine state.
- Every chemistry cell, scratch cell, producer count, and chemistry total.
- Population IDs, lineage events, and configured output records.

Test at minimum:

| Workload | Requirement |
|---|---|
| Focused equivalence | 1,000 ticks for serial, 1, 2, 4, 8, and 16 workers |
| Integration equivalence | 10,000 ticks for representative seeds |
| Stress equivalence | High-population and reproduction-heavy scenario |

Compile SIMD code with conservative floating-point semantics. If vectorization
changes arithmetic ordering or uses fused operations that cause a mismatch, it
does not pass this gate.

### Gate 4 - Canonical SIMD Layout Proposal

Only after Gates 0-3 pass may the prototype become a canonical layout project.

The proposed layout must preserve stable identity:

```text
organism ID <-> stable brain slot <-> SIMD lane in a temporary batch
```

Recommended ownership:

| Data | Ownership |
|---|---|
| ID, lineage, position, energy, age, species, genome | Canonical organism record |
| Decoded brain weights, hidden state, plastic weights, traces | Brain storage indexed by stable slot |
| SIMD batch | Temporary execution view of stable slots |
| Inspector selection | Resolves organism ID to stable brain slot |

Birth allocates a new slot. Death retires a slot only after serial ecological
resolution. Slot reuse requires a generation/version counter so stale inspector
or worker references cannot alias a new organism.

### Gate 5 - Acceptance Threshold

The production SIMD implementation is accepted only when all requirements hold:

| Requirement | Threshold |
|---|---|
| End-to-end throughput | At least `4x` median scalar-worker baseline |
| Equivalence | Full-state comparisons pass |
| Telemetry | No records lost or reordered |
| Memory | Measured and within an explicitly approved budget |
| Inspector | Same selected-organism brain data remains available |
| Stability | Full test suite and long-run multi-seed validation pass |

If the result is below `4x`, retain the prototype only if it is simple,
maintainable, and materially improves research throughput. Otherwise revert
cleanly to the scalar-worker implementation.

---

## Rough Implementation Order

1. Finish ordinary Release and optimized PGO scalar-worker benchmarks.
2. Archive baseline performance CSV files and state hashes.
3. Add compiler vectorization reports to determine whether current inner loops
   already receive useful automatic SIMD.
4. Create a scalar batched-brain harness outside the live simulation loop.
5. Add an equivalent SIMD batched-brain harness for fixed batches of `8`
   organisms on AVX2-capable hardware.
6. Compare kernel outputs exactly, lane by lane, before using either harness in
   a simulation tick.
7. Integrate the batch prototype behind an explicit execution option while
   retaining scalar-worker execution as default.
8. Run Gate 3 full-state equivalence workloads.
9. Measure end-to-end throughput and memory use.
10. Decide whether the prototype meets Gate 5 before designing persistent SoA
    brain storage.
11. If accepted, migrate decoded/runtime brain arrays to stable-slot storage in
    small validated slices: weights, hidden state, plastic state, then
    inspector binding.
12. Re-run full state equivalence after every storage slice.

---

## Current Position

The project has passed deterministic fixed-chunk decision and movement
equivalence for `1`, `2`, `4`, `8`, and `16` workers over 1,000 ticks. That is
the baseline for this SIMD decision gate, not permission to flatten storage
immediately.

The next decision is driven by measured scalar-worker and optimized-PGO phase
timing. SIMD proceeds only if decision work remains dominant and the isolated
prototype clears Gate 2 without compromising equivalence.