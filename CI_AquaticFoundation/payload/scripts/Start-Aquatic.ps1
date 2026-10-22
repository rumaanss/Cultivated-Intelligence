param(
 [string]$Runtime='runtime/aquatic-foundation',
 [uint64]$Seed=42,
 [switch]$NewWorld,
 [int]$Port=8765,
 [uint32]$StopTick=2147483000
)
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
Push-Location $root
try {
 $destination=if ([IO.Path]::IsPathRooted($Runtime)) { [IO.Path]::GetFullPath($Runtime) } else { [IO.Path]::GetFullPath((Join-Path $root $Runtime)) }
 $exe=Join-Path $root 'build/native/Release/ci_aquatic.exe'
 if (!(Test-Path $exe)) { $exe=Join-Path $root 'build/native/ci_aquatic.exe' }
 if (!(Test-Path $exe)) { throw 'Build first with scripts/Build.ps1.' }
 if (Test-Path (Join-Path $destination 'checkpoint.bin')) { throw 'This is a legacy biology runtime. Choose a separate aquatic directory.' }
 $checkpoint=Join-Path $destination 'aquatic.checkpoint.json'
 if ($NewWorld -and (Test-Path $checkpoint)) { throw 'Aquatic world already exists. Omit -NewWorld to resume it, or choose a new runtime.' }
 if (!$NewWorld -and !(Test-Path $checkpoint)) { throw 'Choose -NewWorld explicitly for a new aquatic ecosystem.' }
 New-Item -ItemType Directory -Force $destination | Out-Null
 if (!(Test-Path (Join-Path $destination 'planet_habitat.json'))) { Copy-Item contracts/planet_habitat.json $destination }
 $launch=@('--project-root',$root,'--live-dir',$destination,'--seed',"$Seed",'--port',"$Port",'--ticks',"$StopTick")
 if ($NewWorld) { $launch+='--new-world' }
 Write-Host 'Aquatic scenario: native C++ simulation + transport. Stop the previous native process first. Ctrl+C saves.'
 & $exe @launch
 if ($LASTEXITCODE -ne 0) { throw "Aquatic application exited with code $LASTEXITCODE" }
} finally { Pop-Location }
