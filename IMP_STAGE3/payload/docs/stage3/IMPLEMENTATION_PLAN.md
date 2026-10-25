# Stage 3 — microbial grazing and algal habitat

Status: implementation complete. Automated results and outstanding platform checks are recorded in docs/stage3/VALIDATION.md.
Baseline: delivered pdnarna-4 behavior package, SHA256
13051c7d4f3c49c964301f7d8bae60a1c4b9895eb22baa4d508c0b6181af6470.
Retain planetary terrain, lake geometry, original runtimes and Stage 2 behavior.

## Food web and scope

Sunlight + inorganic C/N/P feed suspended/attached microbial producers and four
macroalgal growth forms (ribbon, fan, filament, sheet). Living bacterial decomposers
feed compact bacterivorous ciliate-like grazers. Suitable suspended/attached producer
cells feed microalgivorous ciliate-like grazers. Macroalgal bodies supply shading,
attachment habitat and detritus, not whole-frond food for microscopic grazers.
All death, egestion and tissue loss return to accounted local pools. No neural
controllers or adaptive hunters in Stage 3. Future consumers use the same explicit
resource, prey-size, accessibility and transfer accounting interface.

## Ordered implementation and acceptance

1. **Versioned core and durable migration.** Preserve pdnarna-4 source behavior;
   add an opt-in Stage 3 engine/runtime with a versioned checkpoint and snapshot.
   Exact continuation includes RNG, genomes, life history, morphology and ledgers.
   Explicit migration copies existing state into a separate runtime and allocates
   new founders from existing material; no source writes or free biomass.
2. **Real consumers.** Two distinct non-neural guilds with paid sensing, locomotion,
   capture/digestion, maintenance, growth and division. Living prey lose the exact
   C/N/P transferred. Demand allocation cannot overdraft or favor iteration order.
   Feeding depends on local accessible prey and capacity; no whole-frond grazing.
3. **Living algal architecture.** Four inherited founder forms, shared bounded
   growth machinery, persistent segments/parents/age/biomass, extension, widening,
   branching, senescence, fragmentation/reproduction and paid regrowth. Accounted
   tissue drives geometry. Local canopy affects light; substrate occupation affects
   establishment. Morphology allele effects require expressed machinery and actual
   resources. Offspring inherit genes, not acquired damage; no directed mutation.
4. **Production/accessibility accounting.** Per biological day and local patch:
   opening/closing live material, growth, respiration, prey removal, assimilation,
   egestion, mortality/tissue loss, transport, resource limitation, and residual.
   Separate standing stock, newly produced tissue, gross carbon fixation and net
   living-biomass change. Accessible food is a defined local estimate, not a claim
   of perfect future reachability. Report consumers' actual intake and reproduction.
5. **Roblox and actual assets.** Generate importable mesh files plus self-contained
   native-part models; no missing external asset IDs. Distinct bacterial/microalgal
   grazers and four modular algae forms with lineage variation. C++ owns location,
   growth, feeding and death; cosmetic appendage motion is labeled presentation.
   Persistent IDs, bounded samples, distance/detail budgets, stale-feed cleanup,
   inspection and local/day food metrics. Patch the delivered world conservatively.
6. **Regression and ecology gates.** Unit tests for transfers, depleted food/O2,
   diet exclusions, allocation order, shading, paid growth, inheritance, damage,
   persistence and malformed input. Executable migration/isolation and HTTP tests.
   Luau compilation and actual packet replay. Multi-seed fixed/mutating long runs
   with save/resume, ledger residuals, every required guild/form persisting and
   reproducing, no population-cap hit or rescue, bounded late biomass and turnover.
   Disturbance and no-food controls distinguish sustained production from founders.
   Record timing and display budgets without claiming unmeasured Studio FPS.
7. **One release.** Source overlay, PowerShell/Python installers with preflight,
   conflict refusal, repeat install and rollback; one-root launch/report scripts;
   models, previews, patched place, model/specification, tested commands, source
   hashes and all validation evidence. Windows/MSVC and actual Studio checks must
   be marked pending unless executed. Never label a failed gate as complete.

## Scientific limits

Functional protist/algal forms, not calibrated species. Gene groups are regulatory
traits, not nucleotide sequence models. Geometry and feeding use explicit coarse
spatial approximations. Microbes are magnified in Roblox without changing physical
feeding ranges. Energy enters through accounted photosynthesis; C/N/P are recycled.
Decorative sway is not a hydrodynamic solver. Finite trials are not perpetual
stability proofs. Habitat complexity must have costs as well as benefits.

## References used for design

- https://www.nature.com/articles/s43705-023-00289-7 — freshwater flagellate bacterivory.
- https://academic.oup.com/femsec/article/79/1/118/668238 — biofilm carbon pathways.
- https://aslopubs.onlinelibrary.wiley.com/doi/10.1002/lno.10040 — plant/periphyton subsidies.
- https://create.roblox.com/docs/studio/importer — glTF and mesh import support.
- https://create.roblox.com/docs/reference/engine/classes/EditableMesh — optional
  dynamic mesh restrictions; required functionality must not depend on that API.
