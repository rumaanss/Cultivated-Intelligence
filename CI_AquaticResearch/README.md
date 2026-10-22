# Aquatic models + unified research interface

Install over CI_AquaticFoundation. This is a focused update: 9 replacements and
2 new files, including tests/docs. It reuses your existing AgentDesignData and
AgentModelFactory without replacing either. Water, sky, relay logic and biological
equations are unchanged. No new world or checkpoint migration.

Stop Play and C++ with Ctrl+C. Save the ZIP into your project root; run PowerShell:

    Expand-Archive .\\CI_AquaticResearch.zip -DestinationPath .\\CI_AquaticResearch -Force
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\\CI_AquaticResearch\\Install-AquaticResearch.ps1

The installer checks the audited file versions and makes a backup. If it reports
a different file, send the named file for a merge instead of forcing replacement.

After successful installation, build:

    powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\\scripts\\Build.ps1

Then resume your SAME aquatic runtime and seed, without -NewWorld:

    powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\\scripts\\Start-Aquatic.ps1 -Runtime runtime/aquatic-foundation -Seed 42

Sync Rojo, then start a new Play session. The original cyanobacteria design is
smaller and used for suspended and attached populations; the earlier flagellated
body is adapted for decomposers. Consumer designs remain available for later guilds.

Use the existing Organisms list or cursor selection. Population Summary shows
biomass, oxygen and light; Trends shows biomass history; Notes shows chemistry and
sampled net change. Record observation captures measurements in the notebook.
The separate F8 panel is removed. Existing plants and individual microbes retain
their own supported research fields. Neural internals remain in C++.

The C++ rebuild exposes the already-existing atmospheric pools to Environment.
The biochemical model and its checkpoint state are preserved.

Tests passed: actual old body designs, 192-part cap, research tags, death/range/
stale/shutdown cleanup, population metrics/trends/notebook, existing UI and sky
checks, native exchange and resume. Windows/Studio GPU appearance still requires
verification on your computer. Motion is presentation-only, not new hydrodynamics.

Details: docs/AQUATIC_RESEARCH_METRICS.md and docs/AQUATIC_VALIDATION.md.

Rollback: stop Play/C++; run Restore-AquaticResearch.ps1 -Backup <printed backup>
from this extracted folder, then rebuild and sync Rojo.
