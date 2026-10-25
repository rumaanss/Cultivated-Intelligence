# Stage 3 model and representation

This is a functional ecosystem model, not a calibrated reconstruction of named species. Organisms have inherited regulatory gene groups and materially paid RNA/protein. They do not have neural networks. Stage 2's physiology engine remains independently versioned; Stage 3 runs as `ci_stage3`, model `stage3-1`, schema 3.

## Food web

| Guild | Resource | Contribution / destination |
|---|---|---|
| Suspended microbial producers | Light, dissolved inorganic carbon, N and P | Edible cells for microalgal grazers |
| Attached microbial producers | Bottom light, dissolved inorganic carbon, N and P | Edible films; algal structure shelters part of the film |
| Bacterial decomposers | DOC and hydrolysable detritus | Recycling and living food for bacterial grazers |
| Bacterial grazers | Living bacterial cohorts | Consumer biomass, respiration, egestion and litter |
| Microalgal grazers | Suspended producers and accessible attached films | Consumer biomass, respiration, egestion and litter |
| Algal habitat | Light, dissolved inorganic carbon, N and P | Canopy shade, sheltered surfaces and tissue litter |

Grazers cannot eat other grazers or macroalgal fronds in this stage. Future deposit/filter feeders need explicit additional feeding interfaces and acceptance tests. Macroscopic algae are not made into unlimited food by their appearance.

All stocks and transfers use mmol C/N/P. RNA and DNA have N:C=.4 and P:C=.1; proteins N:C=.25; structural tissue uses 106:16:1. Phosphorus and nitrogen reserves depend on paid storage protein. Carbon, oxygen and photons have explicit ledgers. Chemistry, gas exchange, transport and substrate geometry retain the inherited lake model.

## Behavior and life history

Sensing, motility, capture and digestion require expressed protein. Movement uses local food/light/oxygen cues plus exploration; material pays for active travel. The cell grid approximates encounters. No visible target-seeking AI or collision attack is substituted for native feeding.

A colony record is a biomass cohort, not one anatomically resolved cell. Grazing removes the same fraction of structure, DNA, RNA, protein and reserves. It also reduces the cohort's represented fraction and division target. New tissue and replicated DNA must refill a depleted cohort before it can create further cohort records. This avoids the numerical proliferation of progressively smaller records. Founder biomass is not a permanent protected reserve. Starved/dead cohorts return their material to detritus.

Births create parent-linked identities and inherited genomes. Each division has the configured mutation probability (default .02); one gene copy changes by a bounded multiplier .9–1.1. Alleles remain within .25–4. Fixed-genome runs use mutation probability zero. Directional environmental pressure comes from differential survival/reproduction, not mutations selected to solve current problems.

Capture capacity is .9 per biological day times structure and the lesser of expressed capture/digestion activity. A quadratic encounter response uses a half-saturation concentration of 5 mmol prey C per cubic metre; oxygen gates feeding. Per-tick removal is limited by a .45/day prey turnover rate. These are explicit coarse calibration parameters, not measured species constants. Attached-film accessibility is reduced by `1/(1+4*canopy)`. Simultaneous demand totals determine proportional consumer shares; no iteration-order priority for prey or phosphate. Seventy percent of ingested C/N/P enters reserves, thirty percent enters detritus; carbon respiration also requires oxygen. Consumer maintenance is .08/day before repair efficiency; other guilds retain .035/day.

## Living algae

Four founder morphotypes are genetically distinct categories: Ribbon, Fan, Filament and Sheet. The category itself is inherited unchanged in this version. Width, branching, extension and attachment are quantitative regulatory traits that can mutate; expression requires RNA and protein.

A living alga stores up to 24 persistent tissue sections with an ID, parent, birth tick, carbon, length, width and branching angle. Newly synthesized structural carbon funds extension and forks. Mature tissue retains its proportions; newly formed tissue reflects the current expressed machinery. Local canopy narrows new branch angles. Width/length scale with tissue and form, bounded to 3/6 display studs per section. These are coarse presentation dimensions, not measured cell dimensions or an exact volume mesh. All segment carbon sums to native structural carbon.

Algae enter a paid DNA replication phase at 1.6 times their division target; shedding occurs before growth, so continuous turnover cannot indefinitely block maturity. Living tissue sheds at .015/day, rising with age to .035/day, and is returned to local detritus. Starvation can also consume structure. A surviving graph can grow again when resources return. Vegetative division partitions material, retains the parent's reduced graph and starts the daughter's juvenile graph; offspring inherit the blueprint rather than acquired damage. Establishment requires attachment protein and local canopy below .85. Dispersing offspring establish in a neighboring bottom cell under the inherited attached-colony dispersal rule. This is a substrate/coverage approximation, not a flow-resolved spore simulation.

Canopy intercepts photons before attached films. Algal shelter reduces film grazing and algal litter supplies decomposition. Suspended producers can shade the whole bottom layer. There is no forced coexistence, free nutrient subsidy or population rescue. Trial failure means revising the model, not calling survival ecological stability.

## Food production and reachability

`stage3-food-current.json` and `food-days/<endTick>.json` contain opening/closing live C/N/P and ten signed flow categories per patch, layer and guild. The accounting identity is:

`closing = opening + fixation + inorganicUptake + ingested + netExchange - release - respiration - mortality - grazed - egested`

Structural growth is an internal transfer and is reported separately; adding it again to the identity would double count biomass. Mortality includes algal tissue shedding. Biological production after metabolic costs is `fixation + ingested - respiration - release - egested`; for producers this is net primary carbon production. Its decline from grazing and mortality, plus exchange, gives the change in standing live carbon. Standing carbon includes initial biomass and reserves and must not be described as new production.

The spatial access table gives patch coordinates, layer, area, volume, six standing stocks, accessible bacterial/microbial-algal carbon and canopy. Accessibility is a same-cell estimate with film shelter, before encounter/handling/oxygen limitations. Actual consumed carbon is recorded separately. It is not a promise that future consumers can reach every gram. A biological day is 600 ticks; all rates divide by the recorded observation interval, including partial first/last days.

## Roblox and model assets

C++ supplies identity, lineage, position, movement costs, tissue, genomes, intake, death and food budgets. Roblox interpolates received positions and builds the saved algal graph. Short cilia illustrate recent paid movement/intake; their oscillation is cosmetic. Microbes are magnified samples. Colors are lineage visualization, not evidence of naturally simulated pigmentation.

The compact bacterial grazer has a copper/moss body, short peripheral cilia and a recessed feeding groove. The microalgal grazer retains the elongated teal/plum ciliate form. No trailing sperm-like flagellum is used. Four algae forms use curved ribbon, scalloped fan, filament and sheet modules. The glTF/OBJ kit includes reusable modules and illustrative assembled variants. Illustrative assemblies are not substitutes for live native shapes.

The default Roblox renderer uses local WedgeParts and embedded mesh data: no missing asset IDs, no internet asset lookup, no EditableMesh permission requirement. It samples at most three individuals per grazer guild and two algae per morphotype, subject to a 2,800-part Stage 3 budget. It shows up to eight saved sections per alga and exposes visible/total sections in inspection. Other colonies continue to live in C++. This is bounded visualization, not a full census. Switching interest, stale feeds and shutdown destroy obsolete rigs; absence from the sample is not reported as biological death.

The patched place bundles new modules into existing script sources, preserving all unrelated binary chunks including terrain. Rojo uses the individual source modules. Actual Studio rendering, interaction and device FPS require a Studio validation session; Luau mocks verify protocol and lifecycle logic but cannot establish visual performance.
