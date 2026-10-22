# Unified biological research records

All currently simulated biological categories use the existing research interface.
No neural weights, activations or brain graphs are sent to Roblox.

| Record | Summary | Trends / Notes / notebook |
|---|---|---|
| Legacy individual microbe | Existing energy, health, age | Existing energy/capacity history; recorded generation and age |
| Legacy plant | Existing carbon reserves, health, age | Existing assimilation, respiration, maintenance, structure, water/nutrients |
| Suspended producer population | Biomass concentration, oxygen, available PAR | Biomass trend; sampled net change; C/N/P, water nutrients and patch identity |
| Attached cyanobacterial mat | Biomass per substrate area, oxygen, PAR | Same population measurements with area units |
| Aerobic decomposer population | Biomass concentration, oxygen, local PAR | Same chemistry; PAR is environmental exposure, not photosynthesis |

Population records represent the **patch guild**, not one visible cell. Two mat
rigs share one record to avoid double-counting biomass. IDs are namespaced strings
(aq-patch-guild), so they cannot collide with individual organism IDs or trigger
individual neural inspection requests.

Biomass is mmol C/m³ for suspended/decomposer populations and mmol C/m² for mats.
Organic N and P use the corresponding volume/area basis and the current fixed
106:16:1 quota. DIC, ammonium-N, nitrate-N, phosphate-P and oxygen are mmol/m³.
PAR is µmol photons/m²/s. Sediment is mmol C/m².

Net change is derived from consecutive C++ biomass snapshots divided by elapsed
biological time and expressed per biological day. It includes growth, respiration,
death and transport; it is **not gross photosynthesis or reproduction rate**.
It remains unavailable until two valid samples exist. Trends use timestamped
biomass with a labeled adaptive vertical scale. Repeated snapshots do not add
new trend samples; stale values are explicitly marked.

Environment reads the finite C++ atmospheric carbon pool in mmol C, and displays
C/N/P conservation residuals. It does not call this atmospheric ppm.

Selecting a model or population list entry shows Summary, Trends and Notes in the
existing inspector. Record observation preserves the biological type, timestamp,
source, run/tick, patch, units and supported measurements in the existing notebook.
The separate chemistry overlay has been removed. No new UI hotkey is required.

Current model display budget: six nearby patches; at most 192 parts. Cyanobacteria
reuse the original faceted geometry and pigment blocks at a smaller scale.
Attached representatives are grounded; suspended representatives have small local
cosmetic vertical drift. Decomposer appendage motion uses the old rig and weakens
with low oxygen. Neither movement is a resolved current or neural decision.
Dead representations are removed without removing their C++ material.

For a future species, provide a stable identity, biological type, timestamp and
supported measurements. Do not populate absent measurements with zeros or treat
population summaries as individual animals. All future neural inspection remains
in the C++ research application.
