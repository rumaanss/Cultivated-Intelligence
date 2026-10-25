param(
 [string]$Runtime='runtime/pdnarna',
 [uint64]$Seed=42,
 [switch]$NewWorld,
 [string]$MigrateAquatic='',
 [switch]$FixedGenome,
 [string]$Config='',
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
 foreach ($name in @('checkpoint.bin','aquatic.checkpoint.json','stage3.checkpoint.json')) { if (Test-Path (Join-Path $destination $name)) { throw 'Choose a separate physiology runtime. Original ecosystems are retained.' } }
 $checkpoint=Join-Path $destination 'physiology.checkpoint.json'
 if ((Test-Path $checkpoint) -and ($NewWorld -or $MigrateAquatic -or $FixedGenome -or $Config)) { throw 'Resume without creation/configuration options. The saved genome mode and configuration are retained.' }
 if (!(Test-Path $checkpoint) -and !$NewWorld -and !$MigrateAquatic) { throw 'Choose -NewWorld or -MigrateAquatic explicitly.' }
 if ($NewWorld -and $MigrateAquatic) { throw 'Choose founders or migration, not both.' }
 if ($MigrateAquatic -and !(Test-Path $MigrateAquatic -PathType Leaf)) { throw 'Pass the original aquatic.checkpoint.json file to -MigrateAquatic.' }
 New-Item -ItemType Directory -Force $destination | Out-Null
 if (!(Test-Path (Join-Path $destination 'planet_habitat.json'))) { Copy-Item contracts/planet_habitat.json $destination }
 $launch=@('--project-root',$root,'--live-dir',$destination,'--physiology','--seed',"$Seed",'--port',"$Port",'--ticks',"$StopTick")
 if ($NewWorld) { $launch+='--new-world' }
 if ($MigrateAquatic) { $launch+=@('--migrate-aquatic',(Resolve-Path $MigrateAquatic).Path) }
 if ($FixedGenome) { $launch+='--fixed-genome' }
 if ($Config) { $launch+=@('--physiology-config',(Resolve-Path $Config).Path) }
 Write-Host 'PDNARNA: native C++ reproduction and chemistry, 20 ticks/s. Ctrl+C saves. Stop other native processes first.'
 & $exe @launch
 if ($LASTEXITCODE -ne 0) { throw "Physiology application exited with code $LASTEXITCODE" }
} finally { Pop-Location }
