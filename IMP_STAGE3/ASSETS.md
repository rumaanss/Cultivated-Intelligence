# Model kit

`assets/stage3/` contains the actual authored geometry, not concept-image placeholders.

- `BacterialGrazer.gltf`: compact copper/moss body, recessed pocket, short cilia.
- `MicroalgalGrazer.gltf`: elongated teal body, plum underside, recessed feeding belt and short cilia.
- `Ribbon`, `Fan`, `Filament`, `Sheet`, `Holdfast`: reusable growth modules.
- `<Form>Habitat1/2.gltf`: two illustrative assembled proportions for each habitat form.
- Matching OBJ files provide geometry-only interchange; use glTF for vertex colors.
- `actual-mesh-preview.png` renders the exported meshes. It is not a Roblox screenshot.
- `mesh-manifest.json` records vertex/triangle counts and the lower-detail native fallback.

Regenerate with `python tools/stage3_models.py` (developer dependencies: NumPy and Matplotlib). Roblox's required path is already self-contained in the source and patched place. glTF import is optional artwork editing, not an installation prerequisite. Live algae are assembled from the saved C++ tissue graph, rather than randomly choosing a decorative cluster. The illustrative assemblies show how the modules fit together, not a promised fixed growth shape.

The default local renderer limits Stage 3 to 2,800 parts, up to three samples per grazer guild and up to two algae per morphotype. It renders at most eight paid sections per alga and exposes the full native section count in inspection. Static algae are not rebuilt by the movement animation loop.
