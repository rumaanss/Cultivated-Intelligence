# Implementation boundaries and mapping

## Ten-point plan coverage

| Plan item | Implemented files / behavior |
| --- | --- |
| 1. Permission versus intent | PlantWorld::request: wait always available; stage/site/space/support/resource validation; no automatic fallback on failed commit |
| 2. Biological, neural and inherited layers | PlantGenome, PlantState, recurrent controller/site scorer, resource ledger and separate physiological updates |
| 3. Three plant types | Shrub, canopy tree and dryland founder traits, branch/foliage permissions, inherited mutation bounds and distinct palettes |
| 4. One controller, many sites | 24 inputs / 16 recurrent units / 14 outputs, 12 shared candidate-scoring weights, rotating sample of up to 16 sites |
| 5. Growing 3D architecture | Stable-ID organs, attachment endpoints, finite growth jobs, native modular geometry, local growth interpolation and foliage wind |
| 6. Reproduction and inheritance | Costed pods, explicit release, provisioned seeds, explicit germination, independent hidden state, mutated traits/weights and lineage metadata |
| 7. C++ / Roblox ownership | Separate C++ publisher, existing authenticated relay, snapshots/deltas, server validation, client renderer with 64-plant/2,400-part default cap |
| 8. Inspection and reproducibility | Inspector, decision/birth/death audit, checksummed textual checkpoints and tested continuation replay |
| 9. Existing organisms | Explicit intent-v2 reproductive output interpretation, legacy mode, CLI flag, saved-policy guard and archive metadata |
| 10. End-to-end delivery | Headless tests, independent build target, real HTTP channel tests, Lua renderer tests, three model examples, Studio installer, terrain export and setup guide |

## Deliberate v1 approximations

- This is an artificial-life experiment, not a botanically calibrated digital twin or evidence of consciousness.
- The plant habitat has its own fixed ecology clock and soil resources. It shares the island geometry and relay with the microbial system, but does not yet exchange soil nutrients with the pond chemistry or allow animals to eat plants. Those interactions were not implemented implicitly.
- Photosynthesis uses functional foliage mass/leaf-area traits, grid light and available reserves. Soil nutrients are one pooled quantity. Carbon is the single spendable construction/respiration budget; there is no independently spendable duplicate energy account.
- Light uses a column per surface cell and 64 two-stud vertical layers, refreshed each ecology step. This is a coarse canopy approximation, not ray-traced photosynthesis. A 32-stud exported cell can overestimate shading between nearby but nonoverlapping crowns.
- The client aligns the visual root collar to actual Terrain between coarse surface samples, with one cached raycast per plant. This cosmetic height correction is not written back as biological motion; the C++ soil model remains on its exported height grid. Re-export for a new run after major terrain edits.
- Roots absorb from reached cells using staged proportional sharing. There is no hydraulic network solver. Support checks and local immediate-child load damage are simple mass-based approximations, not full wood mechanics.
- Each plant can fund one finite four-step job at a time. It reevaluates after completion. Waiting does not cancel an already committed job; there is no exposed cancel-job action in v1. Death or loss of a job site releases unspent reservations. Water paid at commitment is a recorded expenditure, not refunded.
- Genome mutation occurs at seed release, when the new individual is instantiated. A stored seed pod does not yet have an individually stored embryo genome. This is a documented simplification relative to mutation at initial seed provisioning.
- Seeds are asexual. Lifetime neural learning/plasticity, pollinators, flowers, fungal networks and cross-template evolutionary body plans are not included.
- Population and organ ceilings are engineering limits (512 plants, 128 retained organs per plant). Rejected requests report system budget reasons. Fully decayed childless organs are reclaimed; IDs are never reused. These ceilings are not biological carrying capacity.
- Live deltas update changed plant metadata and omit unchanged organ graphs. Changed graphs are replaced as a unit, rather than packing separate per-organ changes. This favors correctness and straightforward resynchronization. Snapshot bytes are measured; fine-grained organ patches are a future bandwidth optimization, not claimed here.
- Native near/mid/far art is supplied. No uploaded MeshPart IDs or skinned assets are required. Native rendering is intentionally bounded; it is not a promise that the whole planet can display all leaves simultaneously.
- The three static model fixtures use scripted actions and generous, explicitly ledger-accounted starting reserves to display mature structure. Random controllers are not expected to reproduce those shapes automatically.

## Controller mapping

Outputs 0–10: wait, shoot, branch, thicken, root, foliage, repair, shed, seed, release, germinate. Output 11 controls investment; 12–13 bound direction offsets around inherited angles. Highest-scoring permitted action wins; ties preserve wait. Impossible actions may be masked before selection, but wait is never removed. Final commit revalidates costs and contested space.

Inputs are bounded resource/health/age/light/soil/mass/organ-count/stage observations, bias, mean leaf exposure and action-availability indicators. The initial implementation does not include resource-trend memory as explicit input channels; recurrent state can retain history. No global map or other plants' genomes are exposed to controllers.

## Protocol and persistence

- `POST /plants`: authenticated, read-only biology; request includes schema/run/revision. Response is full reset or base-revision delta with changed records and explicit removed IDs. Missed history causes a reset.
- `POST /plant-surface`: authenticated explicit Studio export; validates dimensions, finite values and fixed format before atomic write. Only new runs load that file. It cannot modify a running plant population.
- Existing `POST /exchange` continues to serve microbes. The relay's existing token remains server-only.
- Server-to-client packets are bounded and chunked. The client periodically requests a full state, verifies revision bases and rejects malformed topology before applying changes.
- `plants.checkpoint` has an integrity checksum, complete state and structural/resource validation. Checksum protects corruption; it is not a signature for untrusted imported files.
- `plant_events.jsonl` rotates at about 8 MiB, retaining one previous file. This is a bounded recent audit, not an unlimited historical lineage database. Resume can replay audit events from the last committed checkpoint; use `(run,tick,event)` context when analyzing crash boundaries.

## Performance policy

Plant ecology runs regardless of visibility. Client geometry selection and wind are cosmetic. The renderer defaults to 64 rendered plants, 2,400 native parts, 100/240/650-stud detail thresholds and 20 Hz cosmetic poses. These are initial budgets, not verified Roblox hardware capacities. Actual measured C++ workloads are in Benchmark.json; they include local checkpoint/JSON/audit I/O and are not a Roblox frame-rate forecast.

The microbe reproduction migration intentionally changes no Organism layout or genome size. Existing saved runs without a policy marker are treated as legacy and cannot silently enter intent-v2. Explicit old-mode playback and direct legacy ecology regression tests remain available.
