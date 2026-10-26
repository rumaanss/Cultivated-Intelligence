# Targeted inspection fix

Apply after IMP_PS3VINSPECTION-1. Exactly three project files change.

The Stage3Inspection test reached remove_all while its replay Inspection objects still owned open std::ifstream handles. The replay readers now leave scope and close before directory removal. Assertions and deletion failures remain enabled; nothing is skipped or suppressed. No simulation runtime code or checkpoint format changes.

The two Roblox diagnostic scripts contained three deprecated version() calls. They now use the optional string Workspace attribute CI_StudioVersion, or explicitly report "not recorded". If recording a calibration report, copy the Studio version from its About dialog into that attribute. This is manually supplied metadata, not an automatic engine-version reading. No privileged replacement API or warning suppression is used.

## Install from the main project root

Extract with the IMP_PS3VINSPECTION_Fix folder intact, then run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\IMP_PS3VINSPECTION_Fix\Install-Inspection.ps1 -Root .
if ($LASTEXITCODE -eq 0) {
    cmake --build build/native --config Release --target test_inspection
    if ($LASTEXITCODE -eq 0) {
        ctest --test-dir build/native -C Release -R "^Stage3Inspection$" --output-on-failure
    }
}
```

Sync the changes through Rojo, then check Studio Script Analysis again. Your existing 40 passed tests need not all be rerun for a cleanup-only test change. The one failed test must now pass on Windows. Existing saved worlds remain unchanged.

The installer performs a complete hash preflight, preserves a source backup in archives/inspection, and refuses conflicts. Repeat installation is safe. To undo, invoke this folder's Restore-Inspection.ps1 with -Root . and -Backup <the printed backup path>.

## Verification

The corrected test was rebuilt and passed on Linux. Both changed Luau files compiled and all three deprecated call sites were removed. This environment cannot run Windows/MSVC or Studio, so the actual Windows deletion and Studio warning disappearance must be confirmed locally. Installer preflight/install/repeat/rollback and conflict behavior were tested on PowerShell Core on Linux.
