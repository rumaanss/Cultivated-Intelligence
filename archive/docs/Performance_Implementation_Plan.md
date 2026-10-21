# Lake performance and presentation implementation

1. Establish evidence: inspect the supplied recording, confirm the habitat hash, measure relay snapshot loading and Luau collision costs. Separate client frame time, server frame time, HTTP latency and simulation tick throughput.
2. Remove repeated immutable-habitat validation from each exchange, while invalidating the cache on file changes. Preserve authentication, run identity, event durability and checkpoint checks.
3. Move planetary microbial movement to C++ under an explicit versioned authority. Cache immutable shoreline recovery candidates without changing positions or tie-breaking. Profile the same mature checkpoint and compare final state hashes. Add conservative collision broad-phase rejection and allocation-free height evaluation. Differential-test against the exact original geometry. Remove unused combat-history work. Coalesce research list refreshes and bound visual update rates.
4. Restore the existing microbial designs with near-view and part budgets. Display plant carbon reserves honestly; do not invent a maximum energy percentage.
5. Reduce initial microbial population through an explicit, reproducible profile and evaluate its encounter density and predator mortality. A formula for initial ratios is not proof of ecosystem stability. Preserve existing checkpoints and make reseeding explicit.
6. Adapt celestial presentation to the planetary radial frame and the existing biological clock. Preserve the accepted water renderer and avoid duplicate Lighting controllers.
7. Validate correctness, record before/after measurements, and deliver source plus a Studio field-check procedure. Target 60 Hz / 16.7 ms frame time; HTTP exchange latency is a separate metric. Local headless timings cannot certify Roblox frame rate.

## Initial evidence

The uploaded habitat is identical to the compiled contract. The recording shows 7.2 server heartbeats/sec and 138.9 ms average server intervals in one sampled view. The native C++/Python path repeatedly validates roughly one million plant/shore distance comparisons per snapshot. The old relay snapshot-load median is 175.14 ms on this host. The initial cache fix reduces warm snapshot loading to 12.01 ms on the same stored population (about 14.6x faster); this is not an end-to-end latency or Studio FPS claim.

## Completion and next acceptance gate

Source implementation and headless checks are complete; measurements are in Performance_Validation.md. Install into a separate native-motion runtime, then validate the actual Roblox client/server frames and HTTP stability in Studio. A regional 30 Hz simulation, bounded client rendering and independent relay cadence establish separation of responsibilities; planetary scale still requires region subscriptions, scheduling, migration and per-region persistence. Increasing organism limits globally is not the scaling strategy.
