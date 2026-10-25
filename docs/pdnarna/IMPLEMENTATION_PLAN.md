# PDNA/RNA behavior and Roblox parity update

Authorized scope: inherited, non-neural actions with visible movement, growth,
reproduction, lineage and genome diversity in the existing Roblox world.

1. Add paid sensing/motor expression and local light/food/oxygen responses in C++.
2. Save exact positions, routes, behavior, movement costs and RNG; upgrade model-3
   checkpoints without changing existing material or lineage, with original backup.
3. Keep representative colony IDs stable across patches; send real positions,
   inherited alleles and bounded actual lifecycle events through native transport.
4. Render bounded individual models, positional interpolation, material-linked body
   size, parent/child identity, allele color encoding and explicit death cleanup.
5. Extend the existing research inspector and notebook rather than adding another UI.
6. Verify native biology/HTTP/migration, Luau behavior and native packet replay,
   source installers/rollback, Rojo build and source-only place patch preservation.
7. Rerun the existing ecology gates because locomotion changes resource access.

Actual Roblox Studio appearance and Windows/MSVC execution require the user's
local environment; mocked renderer checks cannot certify those platform outcomes.

## Finite-horizon ecology gate

For each of seeds 1, 42 and 9876 with mutation disabled/enabled, require 100,000 ticks,
process restarts every 5,000 ticks, C/N/P and O2/photon ledgers, no population-cap hit,
at least 50 surviving colonies per guild, and births/deaths (plus mutation events
in mutating cases). Across all recorded samples from ticks 80,000–100,000, each guild's maximum/minimum biomass must remain within
a factor of 1.5 and its birth/death ratio within 0.5–2. These engineering bounds were
set before the model-3 trials and retained for this behavior update. They do not prove indefinite equilibrium.
