# CI Aquatic Foundation — focused integration

18 source/test/documentation files: **4 existing files replaced, 14 files added**.
No full project root, world file, water controller, sky replacement or neural
research UI deletion. Runtime biology remains C++; Python appears only in optional
developer tests.

## Install

Save CI_AquaticFoundation.zip into your existing project root.
Stop Play and the native simulation (Ctrl+C), then run these commands **in
PowerShell from the project root**, not the Roblox command bar:

    Expand-Archive .\CI_AquaticFoundation.zip -DestinationPath .\CI_AquaticFoundation -Force
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\CI_AquaticFoundation\Install-Aquatic.ps1

The installer verifies package hashes, accepts LF/CRLF source files, checks the
four existing files against the audited baseline, and backs up every affected
file before installing. It refuses to overwrite different local edits. If it
reports a mismatch, send the named file for a merge; do not force overwrite.

After installation succeeds:

    powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\Build.ps1

Wait for the build and tests to pass. Then:

    powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\Start-Aquatic.ps1 -Runtime runtime/aquatic-foundation -NewWorld -Seed 42

Leave this terminal running. In a second PowerShell terminal at the same root:

    rojo serve planet/default.project.json --port 47126

Connect/sync Rojo in the existing planet place, then Play. Keep the already-working
HTTP and water/sky permissions. **Do not start relay.py or Start-Planet at the same
time.** Press **F8** for the aquatic chemistry card.

## Resume, seeds and previous ecology

Ctrl+C saves. Resume by omitting -NewWorld:

    powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\Start-Aquatic.ps1 -Runtime runtime/aquatic-foundation -Seed 42

A different seed uses another runtime, e.g. -Runtime runtime/aquatic-123 -NewWorld
-Seed 123. The old land/microbial runtime is not converted or deleted. To return
to it, stop aquatic and use your normal Start-Planet.ps1 command for that runtime.

This scenario intentionally replaces legacy neural microbes/land plants in the
active observation session with **non-neural suspended producers, cyanobacterial
mats and decomposer populations**. Their material state stays in C++; Roblox
models are magnified, bounded illustrations. Existing land code/models remain
available for later development.

## Details and verification

Read docs/AQUATIC_FOUNDATION.md and docs/AQUATIC_VALIDATION.md after installation.
Three seeds passed 100,000 ticks each with conservation checks and guild
persistence; native exchange/resume and Luau lifecycle tests passed.
Roblox visual quality/FPS and Windows execution still require local verification.

The chemistry is a reduced C/N/P/O₂ foundation with sediment and photon budgets,
not full molecular abiogenesis or a validated planetary ecosystem. New neural
animals, Charophyta morphology and land changes are outside these two stages.

## Rollback

The installer prints its backup folder. Stop Play and C++, then run:

    powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\CI_AquaticFoundation\Restore-Aquatic.ps1 -Backup runtime/aquatic-backups/YOUR-BACKUP-FOLDER

Rebuild, launch the previous runtime with Start-Planet.ps1, and sync Rojo.
Aquatic checkpoint data remains available in its separate runtime.
