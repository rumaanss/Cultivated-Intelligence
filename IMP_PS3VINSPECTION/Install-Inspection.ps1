param([Parameter(Mandatory=$true)][string]$Root,[switch]$Check)
$ErrorActionPreference='Stop'
$Root=[IO.Path]::GetFullPath($Root).TrimEnd([IO.Path]::DirectorySeparatorChar)
function SafePath([string]$base,[string]$relative) {
 if ([IO.Path]::IsPathRooted($relative) -or $relative.Split('/').Contains('..')) { throw "Unsafe package path: $relative" }
 $p=[IO.Path]::GetFullPath((Join-Path $base $relative))
 if (!$p.StartsWith($base+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)) { throw 'Path escapes root' }
 $scan=$p
 while ($scan -and $scan.Length -ge $base.Length) {
  if ((Test-Path -LiteralPath $scan) -and ((Get-Item -LiteralPath $scan -Force).Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw "Refusing linked path: $scan" }
  $scan=Split-Path $scan -Parent
 }
 return $p
}
function Hash([byte[]]$bytes) {
 try { $text=(New-Object Text.UTF8Encoding($false,$true)).GetString($bytes).Replace("`r`n","`n");$bytes=[Text.Encoding]::UTF8.GetBytes($text) } catch [Text.DecoderFallbackException] { }
 $sha=[Security.Cryptography.SHA256]::Create()
 try { return ([BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-','').ToLowerInvariant() } finally { $sha.Dispose() }
}
function Put([string]$path,[byte[]]$bytes) {
 [IO.Directory]::CreateDirectory((Split-Path $path -Parent)) | Out-Null
 $temporary=$path+'.inspection-'+[Guid]::NewGuid().ToString('N')
 try { [IO.File]::WriteAllBytes($temporary,$bytes);Move-Item -LiteralPath $temporary -Destination $path -Force } finally { if (Test-Path -LiteralPath $temporary) { Remove-Item -LiteralPath $temporary } }
}
foreach ($name in @('CMakeLists.txt','contracts/identity.json','planet/default.project.json')) { if (!(Test-Path (Join-Path $Root $name) -PathType Leaf)) { throw 'Root must be your Cultivated-Intelligence repository folder.' } }
$manifest=Get-Content -LiteralPath (Join-Path $PSScriptRoot 'manifest.json') -Raw | ConvertFrom-Json
$changes=@()
foreach ($item in $manifest.files) {
 $path=SafePath $Root $item.path
 $data=[IO.File]::ReadAllBytes((SafePath (Join-Path $PSScriptRoot 'payload') $item.path))
 if ((Hash $data) -ne $item.target) { throw "Corrupt payload: $($item.path)" }
 $exists=Test-Path -LiteralPath $path -PathType Leaf
 $old=if ($exists) { [IO.File]::ReadAllBytes($path) } else { $null }
 $actual=if ($exists) { Hash $old } else { $null }
 if ($actual -eq $item.target) { continue }
 if (!(@($item.accepted) -contains $actual)) { throw "No files changed. Local edits conflict with baseline: $($item.path)" }
 $changes+=@{item=$item;path=$path;data=$data;old=$old;actual=$actual;existed=$exists}
}
if ($changes.Count -eq 0) { Write-Host 'Already up to date.';exit 0 }
if ($Check) { Write-Host "Preflight passed: $($changes.Count) files. No files changed.";exit 0 }
$backup=Join-Path $Root ('archives/inspection/'+(Get-Date -Format 'yyyyMMddTHHmmss')+'-'+[Guid]::NewGuid().ToString('N').Substring(0,8))
[IO.Directory]::CreateDirectory($backup) | Out-Null
$record=@()
foreach ($change in $changes) {
 if ($change.existed) { Put (SafePath (Join-Path $backup 'original') $change.item.path) $change.old }
 $record+=@{path=$change.item.path;existed=$change.existed;original=$change.actual;target=$change.item.target}
}
$json=@{release=$manifest.release;files=$record} | ConvertTo-Json -Depth 8
Put (Join-Path $backup 'manifest.json') ([Text.Encoding]::UTF8.GetBytes($json))
$done=@()
try {
 foreach ($change in $changes) { $done+=,$change;Put $change.path $change.data }
} catch {
 [Array]::Reverse($done)
 foreach ($change in $done) { if ($change.existed) { Put $change.path $change.old } elseif (Test-Path -LiteralPath $change.path) { Remove-Item -LiteralPath $change.path } }
 throw
}
Write-Host "Installed $($changes.Count) files. Backup: $backup"
Write-Host 'Read START_HERE.md in this package, then build. Existing runtime and place files were not modified.'
