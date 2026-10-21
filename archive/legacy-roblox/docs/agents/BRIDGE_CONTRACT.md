# Body contract v1

## Ownership and scope

C++ remains authoritative for biology, root position, body scale and any future physical joint state. Roblox renders component poses. A native Part, a pigment patch and a mesh triangle are not independent simulation entities. Refer to one stable joint-group ID and let the client reconstruct all attached surfaces.

This package supplies definitions and a codec, not a new command endpoint or live transport. It intentionally does not manufacture physical limb states from decorative models. Do not stream angles back to C++ as measured biology. Roblox input should become validated high-level intent in the existing command channel.

## IDs and units

`body_contract.json`, `AgentBodyContract.lua`, `agent_body_contract.hpp` are generated from the same authored hierarchy. IDs 1–6 are body definitions; they are NOT species IDs 0–2. Component IDs are 1-based and parent 0 denotes the root. Preserve component ordering and bump the schema version for any incompatible hierarchy/axis change. Current IDs are stable for this package, not a dynamically allocated universal anatomy registry.

Coordinates: right handed, Y up, forward -Z, angles in radians. Pivots are in model units. For the native renderer multiply pivots and geometry by authoritative radius / safeRadius. A component supports one scalar axis rotation. Multi-axis physical joints would require a future schema revision. The current pose contains no muscle force, mass, sensors or contact mechanics.

## Binary full pose (little endian)

| Offset | Type | Meaning |
| --- | --- | --- |
| 0 | uint32 | magic 0x31425043, bytes CPB1 |
| 4 | uint16 | schema 1 |
| 6 | uint16 | body design ID |
| 8 | uint32 | agent ID |
| 12 | uint32 | simulation tick |
| 16 | uint16 | component count |
| 18 | uint16 | reserved, must be zero |
| 20 | int16 × count | ordered component angles, -32767..32767 maps to -π..π |

Exact payload length is 20 + 2 × component count. Quantization maximum error is about 0.00275 degrees. -32768, invalid counts/designs/versions, extra or missing bytes and nonzero reserved bytes are rejected. The decoder returns a complete validated pose; C++ leaves its output untouched on failure. Full poses avoid missing-delta dependencies.

| Design | Detailed triangles | Medium triangles | Components | Pose bytes |
| --- | ---: | ---: | ---: | ---: |
| Cyanobacteria | 964 | 300 | 1 | 22 |
| Bacterivore | 700 | 300 | 5 | 30 |
| Bodo saltans | 952 | 524 | 9 | 38 |
| Tideback | 4,684 | 1,256 | 17 | 54 |
| Reedrunner | 3,300 | 1,284 | 18 | 56 |
| Crestgrazer | 4,600 | 1,264 | 16 | 52 |

At 20 full poses/s a Reedrunner uses 1,120 raw payload bytes/s, excluding root snapshots, framing, run ID, JSON/base64, HTTP, encryption and retransmissions. This is arithmetic, not a measured end-to-end bandwidth benchmark. Sending all native piece transforms would duplicate data; these poses send only one angle per component.

## Integration sequence (still required in the real bridge)

1. Negotiate the schema and attach definitions once per connection/run.
2. Scope every pose batch to the existing run ID; the small payload deliberately omits it. Reject stale/duplicate ticks within a run, reset ordering on a new run, and define handling before uint32 tick rollover. Do not infer order solely from arrival time.
3. Validate the agent exists and the body ID matches its assigned definition. Apply authoritative radius/root coordinates from the normal snapshot.
4. Decode and buffer poses. Interpolate neighboring valid ticks on the client; use shortest-angle interpolation at ±π. Bound buffering and drop stale poses after run reset/despawn. The codec itself does not perform ordering or interpolation.
5. Call `AgentModelFactory.poseAngles(rig, rootCFrame, pose.angles)` for the native model. Imported mesh groups need an adapter that preserves their local origins and hierarchy after Studio import.
6. Keep simulation frequency independent from render frequency. Subscribe only to visible/relevant bodies, batch by snapshot tick, and retain coarse markers outside the visual budget.

C++ usage: include `agent_pose_codec.hpp`, populate `ci::body::Pose`, call `encode`, then pass returned bytes through your chosen transport. Luau uses `AgentPoseCodec.encode/decode` with a buffer. Existing JSON transport must explicitly frame or base64 these bytes; never splice arbitrary binary into JSON.

Future simulation component properties should be separate versioned state keyed by `(agentId, componentId)`, sent only on change. The pose codec is intentionally narrow so a color/mesh revision does not require a new physics protocol.
