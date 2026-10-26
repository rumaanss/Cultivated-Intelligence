# IMP_PS3VINSPECTION contracts and boundaries

## Ownership

C++ remains authoritative for identities, ancestry, DNA/RNA/protein, motion, metabolism, reproduction and material accounting. Roblox supplies observations of its registered scene. Inspection is administrative access; neither lineage IDs nor biological labels are supplied to organism controllers as sensory recognition.

The future diversity of sensory methods, founding sensory traits, governing physics/biology, genetic trade-offs and food redesign remain deferred. IMP_PS3GF is not implemented here. The sensor envelope supports named modalities; only scalar photoreception and an administrative geometric diagnostic exist in this release. Existing paid native sensing/motility remain the behavioral machinery.

## Inspection

`POST /inspection` uses the existing server-only token, schema 1, run, id, optional cursor and limit (1–64). It returns one individual and a bounded page of direct children. Run plus ID is durable; boot identifies a native process. Death comes only from native ancestry. The full lineage is recovered by paginated parent/child queries rather than broadcasting it or depending on the 256-entry presentation-event ring.

Birth and death event keys are stable `<id>:birth` and `<id>:death`; a founder is labelled initialized. These compact lifecycle facts already persist in Stage 3 ancestry. Historical records do not invent missing death causes, last poses, trait expression or sensor measurements. The current native model retains parents after offspring creation, so creating a child does not imply parent death.

The native index publishes at approximately one-second intervals. Replies expose the biological snapshot tick and its age independently of the service's current clock. A fresh HTTP connection can still carry a stale biological snapshot. Data viewed after disconnection remains historical confirmation, not proof of current state.

Roblox distinguishes rendered, missing terrain, budget omitted, awaiting render, omitted native sample and outside delivered interest. These are separate from alive/dead/unknown and fresh/stale/disconnected/run-changed. The former rig is not the identity store. Parent/child navigation is explicit; no automatic replacement selection occurs on death. The inspector can query any valid native ID even when no rig exists.

## Light and sensor protocol

`POST /sensing` is separate from observer exchange. Both endpoints share the existing authentication and JSON framing validation but use a separate bounded extension lock/rate budget, avoiding the observer exchange lock. Maximum request body is 128 KiB; maximum registered optical surfaces is 128; transparent traversal is bounded to eight surfaces. Incomplete coverage and invalid material declarations refuse a sample.

Every scene batch identifies schema, run, boot, native request ID, frozen tick, habitat digest, optics revision, server host, scene revision and one visibility value per habitat column. Wrong identity, wrong tick, changed retries, invalid values and incomplete coverage are rejected. Exact accepted retries are acknowledged without applying input twice. The first valid server owns a pending stream; expiry clears the lease for recovery. Results apply on the simulation thread, before a biological step. HTTP workers never mutate the live colony vectors.

A request expires after five wall-clock seconds and must be resampled. In **scene** mode, the native world waits at a safe step boundary until a complete batch is accepted. Ten biological ticks share that sample, including at most approximately six degrees of solar angular change; this cadence is an approximation. Pause stops biological time and allocation, not the transport. In **native-reference** mode, no Roblox input is required and original native sunlight is retained. There is no silent mode fallback. **Replay** applies recorded transmission at its original biological tick intervals.

The scene sensor samples native-defined column positions at z=108.02 studs, just above the reference water surface. Direct rays follow the native reference-lake sun direction, up to 12,000 studs. The source is server Workspace Terrain plus explicitly registered `CI_SensorySurface` BaseParts. Player avatars, debug geometry, client-only cohort models and display LOD are excluded. An object's declared optical transmission applies once; Roblox visual transparency is not a physical calibration. Terrain blocks direct light. Water is ignored by these rays because native code accounts for it.

Accepted surface transmission is `0.15 + 0.85 * directVisibility`. Incident native photon flux becomes `1000 * max(0,sin(2*pi*tick/600)) * transmission`, in the model's existing PAR-like units (micromoles photons / square metre / second). Native water, suspended biomass, DOC/POC and canopy losses then apply once. The incident photon ledger is reduced by the external occlusion loss. Photosynthesis, its material/oxygen changes and recorded photoreceptor input use the accepted native light field. Motility decisions continue to use the previous complete cell field, retaining the existing update order.

Photoreceptor output records the field used by the last completed biological step and is checkpointed. It is a modeled scalar field, not measured screenshot brightness. Surface-column sampling does not resolve every organism's individual sub-cell shadow, underwater overhang or local emission. Diffuse light is currently an unoccluded approximation. Refraction, caustics, scattering, spectral pigment science and local point lights are not simulated by this new input. These limits are explicit calibration gates for future physical-science work.

The 16-ray diagnostic starts at the selected native cohort pose and samples a 64-stud tangent ring against the registered physical scene. Depths return to bounded native diagnostic storage with pose/tick provenance. It is **not** a new optical eye, predator controller, rendered image or species-recognition system. It currently excludes biological bodies; no physical cell-size rule or complete sensor proxy population has been invented. Defining biological sensory geometry and modality traits belongs to the deferred science/phenotype work. Player-visible magnified bodies cannot substitute for biological dimensions.

## Daylight presentation

`WorldLighting` owns live brightness/ambient illumination. Water presentation retains camera-dependent scattering, grading and exposure. The world light follows the shared reference-lake solar phase rather than the player's depth. Native ticks remain the sole clock, with the existing bounded interpolation. C++ never reads player exposure or graphics settings.

Roblox's reachable directional-light path and a single global sun differ from a full spherical physical sky. Existing engine-angle diagnostics remain visible in the lineage inspector. A decorative sun is not proof of engine-light alignment. Accept direction error only after the supplied dawn/noon/dusk/night test; target 5 degrees in the reference lake. No zero-error or planet-wide equivalence is claimed.

## Geometry

The original native/Roblox contract and terrain are unchanged. `ci_geometry_probe` exports exact native heightfield intersections for occupied-column radial probes, short oblique rays, route-clearance rays and shoreline/grid-edge probes. Roblox compares actual terrain query hits, position, normals and coordinate round trips. Short chart rays project to Roblox chords, so the report includes chart/curvature approximation rather than hiding it.

Provisional engineering thresholds are fixed before Studio measurement: 0.25 studs position error, 10 degrees normal error, 0.01 studs transform round-trip error, and zero hit/miss disagreement. They are **not** a replacement for the user's pinpoint physical requirement and may be too coarse for future biological body sizes. Failing these thresholds blocks geometry acceptance. Passing finite probes does not establish every curve, cave or overhang. The hash identifies the source survey, not all current Roblox collision surfaces. Visual holdfast grounding offsets remain separately reported.

## Persistence and compatibility

The Stage 3 checkpoint adds optional `sceneTransmission` and `photoreceptors` fields; old checkpoints still restore, with unavailable receptor history explicitly labelled not recorded yet. After the first step the field is authoritative. Native and scene mode are retained in `inspection-mode.json`. A scene-lit checkpoint copied without its mode file is refused if it would silently default to native-reference.

A recording is append-only per boot and includes run, seed, habitat, optics revision, apply/valid ticks, transmission and scene provenance. Replay requires the corresponding starting biological state. Existing binary RNG serialization and migration behavior are unchanged. Scene input can change ecological outcomes intentionally; it must not be retroactively mixed into an existing native-reference ecological trial.

## Primary API references checked

- https://create.roblox.com/docs/workspace/raycasting
- https://create.roblox.com/docs/reference/engine/classes/Lighting
- https://create.roblox.com/docs/reference/engine/classes/CaptureService
- https://create.roblox.com/docs/reference/engine/classes/AssetService
- https://create.roblox.com/docs/reference/engine/classes/EditableImage
- https://create.roblox.com/docs/reference/engine/classes/ViewportFrame

The pixel capability probe uses CaptureScreenshot, then attempts CreateEditableImageAsync(Content.fromUri(contentId)) and ReadPixelsBuffer. Its result records the installed Studio version, success/error and elapsed time. It does not assume temporary capture content is accepted. Even success only establishes readback of that main-view capture, not independent offscreen organism views or usable whole-population throughput.
