# What this integration implements

## World and authority

`IslandWorld` covers X [-576,896] and Z [-512,448] in global Roblox studs. The pond stays a local 100×100×60 aquatic habitat. Local pond coordinates map to global coordinates as (x-50,z-60,y-50). Keeping the old pond dimensions in its collision and protocol code is intentional: they are a habitat boundary, not the extent of the island world.

Both populations run in `cybernet_sim` on one clock. Plants advance every three world ticks; their snapshots publish every 15 ticks. At the existing live pacing this is approximately 10 plant updates and two plant publications per second. Plant rendering remains capped at 64 plants / 2,400 parts. Microbial detail stays capped at 24 agents / 336 parts. Off-camera plants still simulate.

## Shared environment, distinct organisms

- One celestial cycle and `OpticalField` supply biological light. Air does not receive underwater Fresnel/absorption losses. Pond water retains the v2 depth attenuation and rock occlusion. A shared coarse canopy field shades biological queries for both populations.
- Plants assimilate carbon from a common atmospheric reservoir and return respiratory/decomposition carbon. Gas exchange at the pond surface connects that atmosphere to microbial dissolved-carbon and oxygen cells. The conversion is normalized research-model accounting, not SI biochemical calibration.
- Plant roots use finite local soil nutrients/water. Conservative downhill transfers move water and dissolved mineral through adjacent island cells; transfers that reach the pond enter its chemistry field and are debited from the land ledger. Plant and microbial habitats are not one uniformly mixed bucket.
- Plant and microbial neural architectures remain different. Plants retain their inherited recurrent weights, organ structure, resource checks, mutations and explicit action requests. Eligibility never automatically commits growth or reproduction.
- The initial 96 plants use three small established starting phenotypes. Their initial root/stem/leaves are paid for from founder carbon and nutrients. This makes the starting population inspectable without claiming its first bodies were grown by neural evolution.
- The old terrestrial-only independent publisher remains available for tests, but live island mode owns its publisher lock and writes plant snapshots through the existing asynchronous C++ bridge.

## Physics and remaining limits

This is an integrated research simulation, not a completed general-purpose planetary physics engine. Shared world state does not mean identical physiology or motion equations: microbes retain their pond movement/collision behavior, while rooted plants retain structural support, soil-depth and growth-space constraints. The live bridge still uses the existing Roblox-authoritative movement path validated by C++; this patch does not rewrite that ownership model.

The island uses a 32-stud sampled heightfield, not every decorative object or voxel. Plant growth does not yet collide with every decorative rock/model. Plant canopy shading uses vertical columns, not directional volumetric leaf tracing; distant land terrain does not yet cast biological horizon shadows. Detailed wind loading, heat, atmospheric circulation, full nutrient-species stoichiometry, aquatic plant adaptations, grazing, and roots deforming terrain are not implemented by this patch. Soil and water retain different chemistry representations and simplified reaction rates. The system shares actual environmental calculations/exchanges, but is not a single fully calibrated chemistry/force solver.

The existing C++ debug view remains focused on the pond; Roblox is the island-wide visual view. The stored plant snapshot and microbial snapshot may be published at different rates, with `worldTick` supplied for alignment. Durable replay uses the single combined checkpoint rather than combining independent save files.

Random neural controllers may choose waiting, unproductive actions, or die. There is no hidden baseline policy that forces successful growth. Exact population size and success should be evaluated rather than presented as learned intelligence.

## Recovery

The Studio migration archives only the generated `CI_ReferenceIsland.Woodland` folder and saves edited sources as StringValues. To restore the static trees, stop Play and move the archived Woodland folder back under `Workspace.CI_ReferenceIsland`. Set TreeBudget back to 145 only if you intend to regenerate decoration later. Keep old run directories and checkpoints; this patch does not delete them.
