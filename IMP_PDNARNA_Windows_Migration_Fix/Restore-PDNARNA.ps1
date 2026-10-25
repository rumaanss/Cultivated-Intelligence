param([Parameter(Mandatory=$true)][string]$Root,[Parameter(Mandatory=$true)][string]$Backup)
$ErrorActionPreference='Stop'
$Root=[IO.Path]::GetFullPath($Root).TrimEnd([IO.Path]::DirectorySeparatorChar)
$Backup=[IO.Path]::GetFullPath($Backup)
if (!$Backup.StartsWith((Join-Path $Root 'archives/pdnarna')+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)) { throw 'Backup must be inside this project archives/pdnarna directory.' }
# Load only function declarations from the paired installer, never its installation body.
$tokens=$null;$parseErrors=$null
$ast=[Management.Automation.Language.Parser]::ParseFile((Join-Path $PSScriptRoot 'Install-PDNARNA.ps1'),[ref]$tokens,[ref]$parseErrors)
if ($parseErrors.Count) { throw 'Installer parser error' }
foreach ($fn in $ast.FindAll({param($a) $a -is [Management.Automation.Language.FunctionDefinitionAst]},$false)) { . ([ScriptBlock]::Create($fn.Extent.Text)) }
$manifest=Get-Content -LiteralPath (Join-Path $Backup 'manifest.json') -Raw | ConvertFrom-Json
$changes=@()
foreach ($item in $manifest.files) {
 $path=SafePath $Root $item.path;$exists=Test-Path -LiteralPath $path -PathType Leaf
 $old=if ($exists) { [IO.File]::ReadAllBytes($path) } else { $null }
 $actual=if ($exists) { Hash $old } else { $null }
 if ($actual -eq $item.original) { continue }
 if ($actual -ne $item.target) { throw "No files changed. Edited since installation: $($item.path)" }
 $data=if ($item.existed) { [IO.File]::ReadAllBytes((SafePath (Join-Path $Backup 'original') $item.path)) } else { $null }
 if ($item.existed -and (Hash $data) -ne $item.original) { throw 'Backup integrity mismatch' }
 $changes+=@{path=$path;old=$old;data=$data;existed=$item.existed}
}
$done=@()
try {
 foreach ($change in $changes) { $done+=,$change;if ($change.existed) { Put $change.path $change.data } else { Remove-Item -LiteralPath $change.path } }
} catch {
 [Array]::Reverse($done);foreach ($change in $done) { Put $change.path $change.old };throw
}
Write-Host "Restored $($changes.Count) source files. Rebuild before starting the original scenario. Runtime checkpoints were preserved."
