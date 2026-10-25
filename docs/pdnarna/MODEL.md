# IMP_PDNARNA model and boundaries

This reconstruction replaces guild-only reproduction in the optional aquatic scenario
with explicit reproductive colonies. It is a reduced, resource-accounted research
model; its rates are scenario parameters, not fitted measurements of named species.
The existing terrestrial plant/neural ecosystem remains a separate executable/runtime.

## State and material

The C++ environment retains DIC, NH4, NO3, PO4, O2, DOC, POC, sediment, bound P and
finite atmospheric C/O2. Each colony owns structural carbon, separate C/N/P reserves,
DNA carbon, eight RNA-carbon amounts and eight protein-carbon amounts. Every amount is
mmol of the named element. Structure and legacy organic matter use N/C=16/106 and
P/C=1/106. DNA/RNA use N/C=.4, P/C=.1; protein uses N/C=.25, P/C=0. These are explicit
composition approximations. Dead colonies retain their exact C/N/P in a separate
detritus pool rather than being forced into the legacy organic quota.

The eight functional gene groups are photosynthesis, nutrient transport, catabolism,
repair, storage, replication, sensing and motility. A genome stores one, two or four chromosome copies,
each with eight regulatory alleles. Expression is the mean across homologous copies.
It sets RNA/protein synthesis targets; metabolic capacity depends on the protein
actually present. An allele does not directly multiply instantaneous photosynthesis.
Paid housekeeping/repair protein reduces maintenance inefficiency through its
relative amount (bounded 0.25–4). This is a reduced kinetic rule, not a distinct
molecular damage model. DNA is a material pool and replication state,
not an explicit nucleotide sequence. Diploid/tetraploid configurations apply to these
aquatic colonies, not to a replacement of the existing terrestrial plant genetics.

RNA/protein synthesis shares scarce material proportionally across gene-group
demands, avoiding gene-index priority. It takes C/N/P from reserves, plus .12 C respiration per C assembled.
Respiration needs O2 and returns carbon to DIC. RNA and protein turnover return exact
composition to reserves. Structural growth uses the same paid synthesis rule. Carbon
fixation and nitrate assimilation share a local absorbed-photon budget. O2 is verified
against reaction production/consumption, not a complete oxygen-atom inventory. The
model does not explicitly store ATP, molecular free energy or amino-acid sequences.

## Lifecycle and inheritance

Founders are allocated from existing guild material. Creation/migration adds no mass.
Growth preserves a carbon reserve determined by paid storage protein. The same
capacity sets N/P reserve targets using structural quotas; excess above 125% of
those targets returns to local inorganic pools. Carbon above its night-reserve
target can fund growth; carbon storage is separately bounded at twice structure. This replaces the exploratory
implementation's independent, oversized N/P reserve limits. Each colony
has a fixed birth-structure target and baseline DNA proportional to that target and
ploidy. It must reach twice the structure and DNA before division. Existing structure,
reserves, DNA, RNA and proteins divide equally; neither daughter is subsidized.

Bookkeeping uses persistent-parent budding: the parent retains ID, birth time and
lifetime flux totals; the new daughter gets a new ID, parent ID, generation+1 and
zero lifetime assimilation/respiration counters. Mutation occurs at division, changes
one inherited regulatory allele (clipping at its bounds can produce a neutral
event), and creates an immutable genome record with parent
genome ID. Unchanged descendants share a genome record. All births and deaths retain
ancestry. No population rescue or reseeding occurs after initialization.

Mortality returns all material to detritus; structural starvation also causes death.
The colony cap prevents unbounded allocation; it defers births without deleting
material. Hitting that cap fails ecological validation. Maximum checkpoint size is
256 MiB and the restore budget is two million ancestry/genome records. Very long
runs will eventually need an archival policy; there is no silent lineage truncation.

## Spatial and ecological assumptions

The regional lake has 16-stud columns and two layers, .28 metres/stud. Wet fraction
uses nine survey samples; center depth consistently determines water volume, layer
placement and optical thickness. Migration preserves all original amounts when the
geometry is aligned, so concentrations can change from the old averaged-depth grid.

Mobile colonies have continuous habitat positions and saved local destinations.
Each decision compares only the current cell and wet neighbors. Producers prefer
higher light availability; decomposers prefer available DOC/detritus weighted by
oxygen. Low oxygen can instead trigger an oxygen response. Otherwise colonies
explore locally. These rules approximate non-neural signalling; they are scenario
rules, not a fitted model of cyanobacterial phototaxis or buoyancy.

Sensing and motility are inherited regulatory gene groups. Each mobile colony
must synthesize their RNA and protein from existing reserves. Their RNA targets
are .0004 × structure × expressed allele; protein targets are .00325 × structure
× allele. The original six groups retain their original synthesis targets and
activity normalization. Attached colonies do not synthesize motor/sensing groups.
Sensing activity costs .001/day × structure × activity in respired carbon.
Motor activity sets maximum speed .06 studs/tick at reference protein abundance,
clamped at fourfold. At 20 ticks/s that reference speed is 1.2 studs per real second.
Movement costs .003/day × structure at reference speed, scaled by actual attempted
step. Both costs need stored carbon and environmental oxygen. Failed attempts can
still consume work. No motor protein or no payable energy means no active thrust.
The RNG, protein allocation, local conditions and inheritance determine behavior;
there is no neural network, pathfinding to distant food or global optimum search.

A route persists until arrival or a terrain obstruction. Decisions have an
80-tick minimum interval. Actual speed changes with available motor protein and
energy. Background volume/degree-weighted mixing proposals remain possible while
idle, with .8/day nominal proposal rate and .025 studs/tick passive travel. Travel
time changes the realized cell-transition rate; this is not the old instantaneous
jump process. Material belongs to the departure chemistry cell until arrival.
Routes are checked against terrain; dry/blocked routes stop and replan. There is
no hydrodynamic solver. Attached parents stay fixed; some daughters disperse to
neighboring bottom cells at division. The birth location records that dispersal;
no continuous attached-parent locomotion is invented.

Photosynthesis, DOC consumption, shared extracellular detritus hydrolysis, inorganic
uptake, maintenance, growth and division all act on local resources. Inorganic
nutrients are budgeted against simultaneous per-cell uptake demand, avoiding
first-processed colonies taking the entire remaining supply. Unused shares stay
in water until the next tick. DNA synthesis precedes structural growth so scarce
phosphorus can support ongoing genome replication. A cell has one
hydrolysis allowance per tick, divided by decomposer structure; splitting colonies
cannot multiply the available detritus supply. POC settles and sediment releases
DOC. Phosphate binding and nitrification remain conservative reactions.

Default rates per biological day: producer fixation capacity 1.8 suspended / 1.6
attached; light half-saturation 25; decomposer uptake 1.4; respiratory fraction .65;
maintenance .035; structural growth .7; RNA turnover .25; protein turnover .08;
baseline mortality .015. Mutation probability .02 per birth. Time remains 144
biological seconds/tick, 600 ticks/day, paced at 20 ticks/real second. These values
are provisional; ecological survival is a finite-run check, not biological calibration.

## Persistence and presentation

Checksummed schema-2 / pdnarna-4 checkpoints retain pools, RNG, configuration,
genomes, lineage, positions, destinations, decision times and travel/energy counters.
Existing pdnarna-3 checkpoints upgrade on resume. All six existing alleles and
all material pools are preserved; the two new regulatory alleles start at 1 and
their RNA/protein start at zero. Extending functional regulation does not change
the reduced model's fixed DNA quota. The executable saves the original checkpoint
before writing the upgraded state, never overwriting a differing older backup.
The earlier aquatic-foundation migration remains explicit and uses a separate
runtime; the terrestrial runtime remains independent.

The native snapshot retains sampled IDs as they move. Each patch admits at most
two samples per guild; recently born daughters of sampled parents have priority
for the second slot. This is a deliberately persistent observational sample,
not a random sample or a complete census. The service sends at most 24 patches
per observer / 96 combined patches / 576 colony rows. Each client renders at most
six patches, 24 colonies and 192 body parts. Stable IDs retain the same inspectable
Roblox model across patch changes. Leaving the interest area or sample causes
culling; only a received death event causes a death animation. Events retain up to
256 entries and ten real seconds at nominal rate, so distant/missed events do not
produce invented animations.

Roblox interpolates between received C++ positions over the observed tick interval
(20 ticks/s, interpolation capped at two seconds). It does not extrapolate beyond
the newest position. Body radius follows the cube root of structure/birth target;
division halves the parent's material and adds a real child with inherited genome
and recorded parentage. Color encodes the eight actual regulatory alleles, including
mutations. This is an inspection aid, not a claim that these genes encode pigment.
Movement, sensing/motor protein activity, their alleles, travel distance, carbon
cost and lifecycle status are exposed in the existing research notebook. Bodies
are magnified, stylized colony markers, not literal microbial dimensions. Chemistry
and individual pools have separate units. A stale feed clears after five seconds.

This work does not implement planet-wide water accounting, new neural consumers,
Charophyta morphology, pH/carbonate speciation, temperature-dependent kinetics,
anaerobic metabolism or a global hydrodynamic solver. CPU kernel timings do not
measure Roblox rendering or prove an FPS target.
