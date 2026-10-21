# Native architecture and boundaries

One C++ process hosts the simulation loop, existing deterministic worker pool, asynchronous checkpoint publisher, and a bounded local HTTP server. Roblox is an observer of native organism motion and biology. It does not create native biological events. The original planetary protocol already enforced that boundary; the new server retains it.

The tick thread queues a latest snapshot and receives the latest observer heartbeat. The publisher creates immutable in-memory JSON snapshots. HTTP workers parse each new snapshot once, select at most 384 organisms per region (four regions maximum), and send acknowledgment-based membership, biology and motion deltas. Checkpoints still use the existing atomic, durable file path. No `snapshot.json`, `input.txt`, `plants.json`, SQLite ledger, or Python process is involved in live exchange.

A response cache is committed only with its exact run/session/batch and request payload. Retries must match; changed-payload retries and older batches are rejected. A new process has a new boot identity. Ownership epochs start above the restored checkpoint epoch. A different observer cannot take ownership until the existing eight-second lease expires. Observer input cannot alter native organisms.

HTTP binds to `127.0.0.1`, uses a server-only token, four workers, a bounded queue, two-second socket timeouts, a three-MiB request limit, duplicate-key/depth checks and separate authenticated budgets of 420 exchanges/minute and 180 auxiliary requests/minute. Compression and TLS support are not compiled into the local transport. Published Roblox servers require a separately designed authenticated remote deployment; the local token is not a public hosting scheme.

Plant snapshots use an eight-revision delta history. Larger transfers are frozen into 256-KiB pages; at most three transfers are retained. Plant death changes presentation to grounded litter; native decomposition and carbon bookkeeping remain authoritative. Unsupported dead organs disappear from the live canopy.

The 30-tick/second cap is wall-clock pacing, not a change to biological equations. Unpaced benchmarking and unattended advancement are explicit options. The shared application preserves recording, seed selection, worker count, reproduction policy and research panels. The PowerShell launcher exposes common options; advanced original options remain on the executable.

## Why C++, and what this does not prove

The concrete transport failure was intermittent access to exchange files and inconsistent retry identity. In-memory native transport removes that exchange-file failure mechanism. C++ alone does not guarantee low latency: population size, sensing/neural cost, chemistry, serialization, checkpoint work, Roblox application work and rendering still require measurement.

The new profiler separates tick computation from wall-clock waiting and exposes phase means and recent p95s. No claim is made that Python was the dominant CPU bottleneck in the user's evolved run. The provided native benchmark starts from founders because the current private checkpoint was not supplied here.

## Source lineage and preservation

The new root was based on planetary commit `bd3f3cd8adf93f07f446d113feb19189d9c63cf9` plus the local reliability/presentation fixes from this conversation through commit `7e98154`. GitHub did not expose a later planetary commit when checked for this delivery.

The old repositories were also inspected: `civ0.77` at `49051c159360022710b6d8b2447cb6f248537d12`, and `ci_rbxl` at `d0a0c70ba89087896901b3346bfe0b88797cbe0c`. The existing research interface is preserved in the shared C++ application and `simulation/src/brain/brain_inspector.hpp`. Old compiled binaries, PGO results and build caches were not imported as source dependencies.

The checkpoint serialization ABI was not changed by this migration. The lake contract is `db04d3c77c22a8c8c770e48b90a16cb445f0b2003d2c86a96d02f5eb21ca85f5`. Terrain, the working glass-water presentation, solar biology, microbial models and player controller remain in the active planet source.

## Planetary scaling

The service serves one runtime today. Bounded observer regions and explicit habitat identities provide foundations for later spatial partitioning; this is not a claim that a planet of organisms is already scalable. Future work should partition simulation regions, preserve cross-region material/organism conservation, and measure each partition before increasing total population. Biology rendering limits are observation limits, never population deletion rules.
