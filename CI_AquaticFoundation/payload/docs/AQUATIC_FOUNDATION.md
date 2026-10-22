# Aquatic foundation 1

A separate, persistent **non-neural aquatic scenario**, sharing the surveyed lake,
player controller, water, sky and native transport. It does not convert or erase
the previous plant/microbial world. The old executable and Raylib target remain.

## Start and observe

Stop Play and the previous native process. Install and rebuild as described in the
package README. Then run from the project root:

    powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\Start-Aquatic.ps1 -Runtime runtime/aquatic-foundation -NewWorld -Seed 42

Keep the terminal open. Sync planet/default.project.json with Rojo, then Play the
existing planet. Keep HTTP requests and existing water/sky permissions enabled.
No Python relay and no new place file.

Press **F8** for chemistry. Click a nearby microbial cohort to inspect its patch.
The old individual-organism count is zero in this scenario: these are biochemical
biomass populations, not individually simulated animals.

**Ctrl+C** saves and stops. Resume with the same command **without -NewWorld**.
Use the same seed when resuming. Another seed needs another runtime directory.
The simulation continues while Studio is stopped or nobody observes. It saves
every 30 seconds and on clean termination. A forced kill may lose the last 30
seconds. -NewWorld refuses to overwrite an existing aquatic checkpoint.

## Implemented system

| Component | Behavior |
|---|---|
| Spatial foundation | Wet patches from the verified lake survey; two water layers per column |
| Light | Existing 600-tick solar phase; Beer–Lambert attenuation by water, producers, DOC and suspended detritus |
| Photon budget | Surface PAR enters in µmol/m²/s; fixation cannot exceed each producer guild's absorbed supply |
| Water chemistry | Dissolved inorganic C, ammonium-N, nitrate-N, phosphate-P, O₂ |
| Organic material | DOC, suspended detritus, suspended producers, attached mats, bacteria, sediment organic matter |
| Sediment | Settling, slow solubilization, reversible phosphate binding; faster P release under low O₂ |
| Transport | Conservative exchange across wet neighbors and layers; downward settling |
| Atmosphere | Finite well-mixed C/O₂ reservoirs exchange with surface water |
| Producers | Non-neural suspended cyanobacterial guild and attached cyanobacterial mat guild |
| Decomposers | Non-neural aerobic bacterial biomass; DOC uptake, growth, mineralization and oxygen demand |
| Lifecycle | Growth, maintenance, mortality, additional oxygen-stress mortality; dead biomass becomes detritus |
| Persistence | Versioned checksummed atomic checkpoint; habitat/seed validation; exact numerical continuation |
| Observation | Bounded native interest packets, local models, chemistry inspection and stale-data cleanup |

16-stud patches use nine terrain samples for wet fraction/depth. Narrow features
below that resolution are approximated. Geometry and water meshes are not rebuilt.
Visual mat lobes are independently grounded against existing Terrain; unsupported
or dry lobes are omitted.

## Units, time and conservation

The explicit study scale is **0.28 metres/stud**. Stored C/N/P pools are **mmol
amounts**. Water concentrations are mmol/m³; mats and sediment are mmol C/m².
Oxygen is mmol O₂.

Each tick represents **144 biological seconds**. 600 ticks = one biological day.
The paced process runs at 20 ticks per real second: one biological day per 30 real
seconds. This is an intentional scenario acceleration, not real elapsed time.
The existing celestial phase is retained.

All organic pools use the provisional common quota **C:N:P = 106:16:1**:

- C total = atmospheric C + inorganic dissolved C + all organic C.
- N total = NH4-N + NO3-N + organic C × 16/106.
- P total = PO4-P + bound sediment P + organic C × 1/106.

Photosynthesis moves inorganic resources into biomass. Death moves biomass into
particulate detritus. Settling moves that into sediment; solubilization produces
DOC. Bacterial respiration returns C/N/P to inorganic pools. Hiding a Roblox
model never changes stored material.

O₂ is checked against a cumulative **reaction ledger**, not claimed to be a
conserved total element. Carbon fixation and nitrate assimilation produce O₂;
respiration and nitrification consume it. Oxygen atoms in water, carbonate and
every organic molecule are not inventoried.

Photon use is bounded by absorbed supply, including a conservative allowance for
carbon fixation and nitrate assimilation. This does not simulate molecular ATP,
complete thermodynamic free energy or every intracellular pathway.

## Provisional parameters

These are scenario assumptions, not calibrated species measurements.

| Process | Base value |
|---|---:|
| Noon surface PAR | 1000 µmol/m²/s |
| Light half-saturation | 80 µmol/m²/s |
| Suspended producer / mat maximum growth | 0.8 / 0.35 per day |
| Producer maintenance | 0.04/day |
| Bacterial uptake / maintenance | 1.2 / 0.08 per day |
| Bacterial growth yield | 0.30 |
| Baseline mortality | 0.02/day |
| Suspended / sediment solubilization | 0.08 / 0.03 per day |
| Settling | 0.5/day |
| Vertical / horizontal mixing | 0.8 / 0.2 per day |
| Nitrification | 0.04/day, oxygen limited |

Fractional transfers use 1-exp(-rate×dt), bounded by available material. Growth
requires light, local space, DIC, N and P. Initial stocks are recorded in the ledger;
there is no ongoing nutrient subsidy or automatic population rescue. Seeds vary
founder biomass, not neural weights.

## Performance and planetary extension

C++ owns the lake. No RNN controllers or per-cell-organism update loops exist in
this scenario. Chemical state uses fixed arrays and precomputed spatial neighbors.
An observational summary is published into memory once per real second.

The existing native exchange sends at most **24 patches per observer**, up to four
research observers: **96 rows maximum**. Snapshot/interest tokens suppress unchanged
data. Each Roblox observer receives nearby rows at most once per second. A client
shows at most **12 patches / 192 simple parts**, with shadows/collisions disabled.
Camera interest is checked twice per second; models are reused. No EditableMesh,
generated images or new external assets are required.

Mats, curved filaments and rods are **magnified cohort illustrations**, not literal
cell sizes or individual census counts. Opacity reflects biomass. Below the
display threshold they become invisible and non-selectable; interest exit, stale
state and shutdown destroy models.

This is a regional foundation. A planet still requires region partitioning,
boundary exchange, scheduling/load budgets and multi-region benchmarks. These
tests do not prove planetary throughput or guarantee Roblox 60 FPS.

## Scope limits

The two foundational stages are delivered here, not the entire future trophic web.
No new grazers, neural animals, Charophyta morphology, tree changes or evolutionary
controller experiments are included. These chemical guilds have fixed provisional
traits; legacy land biology remains in its separate runtime.

This reduced C/N/P/O₂ model does not yet solve dynamic pH, carbonate speciation,
temperature, salinity, sulfur/iron pathways, anaerobic metabolism, sediment
porewater diffusion or hydrodynamic currents. Atmospheric exchange uses a reduced
carbonate target and finite reservoirs. It is **not an abiogenesis simulation**;
nutrient presence alone does not demonstrate spontaneous life.

## Scientific design basis

Compartment separation, remineralization and elemental checks follow established
ecosystem-model practice. This is a smaller custom model, not a calibrated copy:

- Baird et al. (2020), CSIRO Environmental Modelling Suite optical/biogeochemical
  models. https://doi.org/10.5194/gmd-13-4503-2020
  Reference for pelagic/benthic/sediment pools and C/N/P versus O₂ accounting.
- US Army Corps of Engineers, Nutrient Simulation Module I.
  https://www.hec.usace.army.mil/confluence/wqetm/water-quality-transformation-libaries/nutrient-simulation-module-i
  Reference for floating/attached producer compartments and nutrient transformations.
- Coastal generalized ecosystem model, CGEM 1.0 (2024).
  https://doi.org/10.1016/j.ecolmodel.2024.110831
  Reference for coupling optics, nutrients and benthic processes.

See AQUATIC_VALIDATION.md for measured tests. Test doubles cannot establish Roblox
GPU performance or appearance. In Studio, verify the F8 card updates, mats follow
terrain, leaving the lake removes cohorts, and existing water/sky presentation
remains intact. Compare frame/relay timings on the same camera and hardware before
raising presentation density.
