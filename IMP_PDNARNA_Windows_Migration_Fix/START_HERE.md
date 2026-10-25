# Windows migration test correction

Apply this to the already installed pdnarna-4 behavior update that reports
`NativePhysiologyMigration: Trailing RNG data`. Your project root is correct.

Extract this ZIP into `IMP_PDNARNA_Windows_Migration_Fix` inside your existing
CultivatedIntelligenceNative project root. The extracted folder must directly
contain Install-PDNARNA.ps1, manifest.json and payload.

From that same project root, run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\IMP_PDNARNA_Windows_Migration_Fix\Install-PDNARNA.ps1 -Root .
if ($LASTEXITCODE -eq 0) {
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\Build.ps1
}
```

ExecutionPolicy applies only to the child PowerShell process; it does not change
your saved system policy. The installer backs up the old test and refuses
conflicting local edits. Repeating installation is safe. Add `-Check` to the
installer command for a preflight without changing files.

Only tests/native_physiology_migration.py is installed. C++ behavior, DNA/RNA,
movement, reproduction, Roblox scripts, place files, and saved worlds are unchanged.
No new world or reinstall is needed. Keep the build's regression gate enabled.

## Cause and correction

The old model-3 founders fixture was emitted by Linux/libstdc++. Its mt19937_64
stream has 312 words plus a cursor. MSVC uses 312 words without that cursor, so
the loader correctly rejected the extra token. This is a test package portability
bug, not evidence that your saved Windows ecosystem is corrupt.

The fix checks the original fixture SHA256, seed, tick and every RNG word against
the exact unadvanced seed-42 state. It obtains the equivalent native stream format
from a temporary tick-zero world, substitutes only the temporary fixture's RNG
field, and recomputes its checksum. The shipped fixture is never edited. A running
or advanced fixture is rejected instead of reseeded. This is not an active-world
cross-platform checkpoint converter.

Migration still verifies unchanged material pools, genomes, lineage, RNG state,
runtime isolation, exact backup bytes, and preservation of an existing backup.
A new negative test appends extra RNG data with a valid checksum and verifies
rejection without migration or overwriting the checkpoint. The production strict
RNG reader is unchanged.

## Validation

All 34 native tests pass on Linux after the correction (54.20 seconds). Both
312-word and 313-word fixture rewrites are checked. Actual Windows/MSVC execution
must be confirmed by your Build.ps1 run. PowerShell installer validation here uses
PowerShell on Linux. See the included test logs for the checks performed.

To roll back this test-only fix, use the backup directory printed by the installer:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\IMP_PDNARNA_Windows_Migration_Fix\Restore-PDNARNA.ps1 -Root . -Backup '<absolute backup directory>'
```

Rollback restores the original failing test. It does not change any runtime data.
