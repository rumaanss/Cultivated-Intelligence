# Stage 3 validation

Implementation and automated validation are complete for this package. Windows/MSVC and Studio-specific acceptance remain explicitly pending. This is a finite simulation validation, not a claim of permanent ecological equilibrium.

| Check | Result |
|---|---|
| Full native Release regression suite | 39/39 passed; see the recorded full-suite log |
| Stage 3 physiology controls | Compatible feeding, diet exclusion, oxygen limitation, unfed decline, material conservation, allocation order, paid morphology, mature algae reproduction, checkpoint roundtrip and malformed topology rejection passed |
| Blackout control | Four biological days without light: no fixation and declining producer material; fixation resumes during ten-day follow-up; all guilds/forms persist |
| Native HTTP integration | Schema 3, bounded interest, real organism/tissue/food packets, authentication, retry, resume and isolation passed |
| Executable migration | Native-generated pdnarna-4 checkpoint migrated into a separate runtime; source retained; seed inherited; daily report boundary and repeat/overwrite guards passed |
| Original engine | Original physiology and lake implementation files are byte-identical to the delivered baseline; the original launcher gains only a Stage 3 runtime collision guard |
| Roblox logic | Actual native packet replay shows both grazers and four habitats; persistent identity, invalid packet rejection, part budgets, interest/stale/shutdown cleanup passed |
| Luau / Rojo | 96 standalone Luau files and 4 bundled world sources compile; the render-test template is instantiated/executed separately; Rojo build passed |
| Installers | Python and PowerShell preflight, atomic conflict refusal, CRLF compatibility, repeat install, edited-file rollback refusal and full/repeated rollback passed |
| PowerShell launch/report | One-root new seed, saved-seed resume, overwrite refusal and exact CSV stock totals passed under PowerShell on Linux |
| Long ecology | See `evidence/ecology-summary.json` and `evidence/ecology-trajectories.png` for measured gates and trajectories |
| Windows/MSVC execution | Not available in this environment; not claimed as tested |
| Roblox Studio visual interaction and device performance | Not available in this environment; not claimed as tested |

The native trials use seeds 42 and 9876 with mutations enabled, and seed 1 with mutations disabled. Each runs to 120,000 ticks, or 200 biological days, with checkpoint continuation. The first 100-day transition failed the late biomass criterion because bacterial populations dropped during the initial predator boom. That result is retained in the evidence. The same unchanged biology was then followed for a second, independent 100-day interval; all recorded gates passed there. The recorded gates require all guilds/forms to persist, demographic reproduction in the follow-up interval, no 50,000-record cap hit, local C/N/P food residual below 1e-6 mmol, and late mean biomass within a factor of two between the two 50-day windows from ticks 60,000–90,000 and 90,000–120,000. These are finite operational checks, not an empirical calibration to natural species or a perpetual-stability proof.

The package keeps failed exploratory trials separate from accepted-candidate results. Earlier failures exposed excessive record subdivision, algal reproduction blocked by tissue turnover, and a missing daily-report directory. Those defects were corrected and covered by controls; the earlier runs are not counted as passing evidence.

The scene verifier compares the exact delivered behavior-place baseline against the patched place. Only reviewed script Source properties change. Terrain and unrelated chunks are byte-identical. Native mesh files are generated deterministically and the low-detail Roblox geometry is embedded; no mesh asset upload is required.

Before treating the visual integration as fully accepted, open the included place (or sync the updated Rojo project into your working place), connect a Stage 3 runtime, and verify swimming, feeding/lineage inspection, the four growing algal forms, disconnect cleanup and frame rate on your target hardware. Automated Luau mocks cannot establish GPU appearance, picking behavior or Studio FPS. This is the remaining platform-specific check, not a hidden claim that it has already happened.
