# Stage 3: microbial trophic web and algal habitat

Stage 3 implementation package. Automated native, renderer, installation and extended ecology results are in VALIDATION.md. Windows/MSVC execution and an actual Studio visual/performance review are still platform-specific acceptance checks.

Use your existing CultivatedIntelligenceNative project root. The integration ZIP is an updater, not a second project. The ZIP already contains an `IMP_STAGE3` folder. Put the ZIP in your project root, then extract it from that root with:

```powershell
Expand-Archive -LiteralPath .\IMP_STAGE3.zip -DestinationPath .
```

This produces `.\IMP_STAGE3\Install-Stage3.ps1`. Close native simulation processes before installing.

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\IMP_STAGE3\Install-Stage3.ps1 -Root . -Check
if ($LASTEXITCODE -eq 0) {
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\IMP_STAGE3\Install-Stage3.ps1 -Root .
    if ($LASTEXITCODE -eq 0) {
        powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\Build.ps1
    }
}
```

If preflight reports a conflict, it has changed no files. Keep your local edits; do not force the updater. The package targets the delivered pdnarna-4 behavior update with the Windows migration test correction.

Create a separate Stage 3 world from the SAME project root:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\Start-Stage3.ps1 -Runtime runtime/stage3-43 -Seed 43 -NewWorld
```

Resume it (the seed and configuration are read from its checkpoint):

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\Start-Stage3.ps1 -Runtime runtime/stage3-43
```

Alternatively migrate a pdnarna-4 world into a NEW Stage 3 runtime:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\Start-Stage3.ps1 -Runtime runtime/stage3-from-43 -MigratePDNARNA .\runtime\pdnarna-43\physiology.checkpoint.json
```

Migration keeps the original runtime intact. New guild founders receive material divided from the existing populations; they do not appear for free. A runtime directory holds one world. A different seed needs a different runtime directory. Runtime folders are data inside the project, not separate installations.

Open the included `CI_Stage3_Planet.rbxl` in Roblox Studio and use the existing project's connection workflow. HTTP requests must be enabled as in Stage 2. The place contains all required new rendering code and needs no mesh asset IDs or EditableMesh permissions. When using Rojo, sync the updated `planet/default.project.json` after the native application starts. The native application writes the connection configuration to this project. Do not run two native publishers against the same Roblox source directory.

Food production and accessibility:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\Report-Stage3.ps1 -Runtime runtime/stage3-43
```

The command prints guild totals and exports both local net prey production and reachable standing food. It writes `food-summary.csv` and `food-summary.access.csv` under that runtime. To inspect a completed interval use `-DayEndTick 600`, `1200`, etc. One biological day is 600 ticks (30 wall-clock seconds at 20 ticks/s). Migration's first interval may be shorter; reports record its actual length. Current reports update at day boundaries and shutdown. The C/N/P JSON ledgers remain available under `food-days/`.

Original Stage 2 worlds still use `Start-PDNARNA.ps1`. Restoring the source overlay does not convert a Stage 3 checkpoint back into Stage 2. Use the preserved original world when rolling back. The installer prints the backup path; pass that exact path to `Restore-Stage3.ps1 -Root . -Backup <path>`, then rebuild.

The optional Python installer provides equivalent `--root . --check`, `--root .`, and `--rollback <printed backup>` operations. Python is not required for normal simulation or food-report use.
