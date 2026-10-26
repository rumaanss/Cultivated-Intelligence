# Algae terrain attachment correction

Apply after Stage3_Live_Fix.patch. This is a Roblox presentation change only.

Stage 3 algae used native heightfield positions directly, unlike the existing
attached microbial mat renderer, which checks Roblox Terrain. A difference
between the analytic native surface and the rendered voxel surface can leave
an attached alga visibly suspended, especially on slopes. The authored holdfast
mesh was also absent from live algae models.

The correction raycasts only Terrain, ignores water, and adjusts the displayed
base along the local planetary vertical. It embeds the base slightly and draws
the existing holdfast mesh. Growth remains upward in the planetary frame.
Native position, lineage, tissue graph, biomass and chemistry remain unchanged.
The holdfast represents existing structural tissue; it adds no simulated mass.

If there is no submerged terrain hit within 12 studs above/below native placement,
the renderer hides that alga's geometry and retries at the next snapshot. Its
identity and native lifetime are retained. No distant terrain snap is attempted.
The correction exposes CI_AttachmentStatus and CI_GroundOffsetStuds attributes.

One terrain ray per visible alga on a snapshot revision; no per-frame algae
raycasts. Holdfast triangles are included in the unchanged 2800-part budget.

Validation: Luau compile and actual native packet replay pass; both grazers,
four habitat forms, stable identities, offspring, part budget, stale cleanup,
missing-terrain hiding and same-model terrain recovery pass. A renderer test
also verifies animation adds no terrain queries. These are CPU test doubles,
not a substitute for visual inspection in Studio.

Save Stage3_Algae_Grounding.patch in the existing project root:

```powershell
git apply --check .\Stage3_Algae_Grounding.patch
if ($LASTEXITCODE -eq 0) { git apply .\Stage3_Algae_Grounding.patch }
```

Sync the changed Stage3Models module through the existing Rojo connection.
No C++ rebuild or native simulation restart is required. Restart Studio Play if
needed for the cached ModuleScript to reload. Keep the native long run running.
This source patch does not modify a saved .rbxl by itself.
