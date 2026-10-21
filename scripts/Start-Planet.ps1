param(
    [string]$Runtime = 'runtime/planet-native-v1',
    [string]$ImportRuntime = '',
    [switch]$NewWorld,
    [switch]$Autonomous,
    [switch]$Unpaced,
    [switch]$Research,
    [int]$Port = 8765,
    [int]$Workers = 4,
    [uint64]$Seed = 42,
    [uint32]$StopTick = 4294967295
)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
Push-Location $root
try {
    if ([IO.Path]::IsPathRooted($Runtime)) { $destination = [IO.Path]::GetFullPath($Runtime) }
    else { $destination = [IO.Path]::GetFullPath((Join-Path $root $Runtime)) }
    $exeName = if ($Research) { 'ci_research.exe' } else { 'ci_headless.exe' }
    $exe = Join-Path $root "build/native/Release/$exeName"
    if (!(Test-Path $exe)) { $exe = Join-Path $root "build/native/$exeName" }
    if (!(Test-Path $exe)) { throw 'Build first: .\scripts\Build.ps1 (add -Research for the graphical interface).' }
    if ($ImportRuntime) {
        $source = (Resolve-Path $ImportRuntime).Path
        if ($source -eq $destination) { throw 'Import into a separate new directory to preserve your original runtime.' }
        if (Test-Path (Join-Path $destination 'checkpoint.bin')) { throw 'Destination already has a checkpoint. Omit -ImportRuntime to resume it.' }
        foreach ($name in @('checkpoint.bin','planet_habitat.json')) {
            if (!(Test-Path (Join-Path $source $name))) { throw "Import source is missing $name. Stop the old simulation cleanly before importing." }
        }
        $sourceLock = $null
        try {
            $lockPath = Join-Path $source 'publisher.lock'
            if (Test-Path $lockPath) {
                $sourceLock = [IO.File]::Open($lockPath, [IO.FileMode]::Open, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
            }
            # Copy only durable biology; never transient transport ownership.
            New-Item -ItemType Directory -Force $destination | Out-Null
            Copy-Item (Join-Path $source 'planet_habitat.json') $destination
            $pending = Join-Path $destination 'checkpoint.importing'
            Copy-Item (Join-Path $source 'checkpoint.bin') $pending
            if ((Get-FileHash (Join-Path $source 'checkpoint.bin')).Hash -ne (Get-FileHash $pending).Hash) { throw 'Checkpoint copy verification failed.' }
            if (Test-Path (Join-Path $source 'reproduction.schema')) { Copy-Item (Join-Path $source 'reproduction.schema') $destination }
            Move-Item $pending (Join-Path $destination 'checkpoint.bin')
        } finally { if ($null -ne $sourceLock) { $sourceLock.Dispose() } }
        Write-Host 'Checkpoint copied and verified. Original runtime retained.'
    }
    if (!(Test-Path (Join-Path $destination 'checkpoint.bin')) -and !$NewWorld) {
        throw 'No checkpoint found. Use -ImportRuntime <old runtime path> to preserve biology, or explicitly choose -NewWorld for founders.'
    }
    New-Item -ItemType Directory -Force $destination | Out-Null
    if (!(Test-Path (Join-Path $destination 'planet_habitat.json'))) {
        Copy-Item contracts/planet_habitat.json $destination
    }
    $launch = @('--project-root',$root,'--live-dir',$destination,'--island-surface',(Join-Path $root 'contracts/planet_surface.txt'),'--geometry','lake','--optics','v2','--archive-dir',(Join-Path $destination 'metrics'),'--port',"$Port",'--workers',"$Workers")
    $policyPath = Join-Path $destination 'reproduction.schema'
    if (Test-Path $policyPath) {
        $policy = (Get-Content $policyPath -Raw).Trim()
        if ($policy -notin @('legacy-v1','intent-v2')) { throw 'Unsupported saved reproduction policy.' }
        $launch += @('--reproduction',$policy)
    }
    $launch += @('--seed',"$Seed")
    if (!$Research) { $launch += @('--headless','--benchmark-ticks',"$StopTick") }
    if ($Autonomous) { $launch += '--autonomous' }
    if ($Unpaced) { $launch += '--unpaced' }
    Write-Host 'One C++ process runs simulation and transport. Do not start relay.py.'
    & $exe @launch
    if ($LASTEXITCODE -ne 0) { throw "Application exited with code $LASTEXITCODE" }
} finally { Pop-Location }
