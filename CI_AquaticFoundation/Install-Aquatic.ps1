param([string]$ProjectRoot=(Get-Location).Path)
$ErrorActionPreference='Stop'
$root=(Resolve-Path -LiteralPath $ProjectRoot).Path
if (!(Test-Path (Join-Path $root 'planet/default.project.json')) -or !(Test-Path (Join-Path $root 'contracts/identity.json'))) { throw 'Run from the native project root. No files changed.' }
$manifest=Get-Content -Raw -LiteralPath (Join-Path $PSScriptRoot 'manifest.json') | ConvertFrom-Json
function TextHash([string]$Path) {
 $text=[IO.File]::ReadAllText($Path).Replace(([string][char]13+[char]10),[string][char]10)
 $sha=[Security.Cryptography.SHA256]::Create()
 try { return ([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($text)))).Replace('-','').ToLowerInvariant() }
 finally { $sha.Dispose() }
}
# Complete preflight before changing project files. CRLF checkouts are accepted.
foreach ($entry in $manifest.files) {
 if ($entry.path -match '(^/|\\|(^|/)\.\.(/|$))') { throw 'Invalid package path.' }
 $source=Join-Path $PSScriptRoot ('payload/'+$entry.path)
 $target=Join-Path $root $entry.path
 if ((Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash -ne $entry.sha256) { throw "Package integrity failed: $($entry.path). No files changed." }
 if (Test-Path -LiteralPath $target) {
  $hash=TextHash $target
  if ($hash -ne $entry.sha256 -and (!$entry.before -or $hash -ne $entry.before)) {
   throw "Local file differs from the audited version: $($entry.path). No files changed. Keep your work and provide this file for a merge; do not force overwrite."
  }
 } elseif ($entry.before) { throw "Required baseline file is missing: $($entry.path). No files changed." }
}
$backup=Join-Path $root ('runtime/aquatic-backups/'+(Get-Date -Format 'yyyyMMdd-HHmmss')+'-'+[guid]::NewGuid().ToString('N').Substring(0,8))
New-Item -ItemType Directory -Force $backup | Out-Null
$records=@()
foreach ($entry in $manifest.files) {
 $target=Join-Path $root $entry.path
 $present=Test-Path -LiteralPath $target
 $records+=[pscustomobject]@{path=$entry.path;existed=$present}
 if ($present) {
  $saved=Join-Path $backup $entry.path
  New-Item -ItemType Directory -Force (Split-Path $saved -Parent) | Out-Null
  Copy-Item -LiteralPath $target -Destination $saved -Force
 }
}
[pscustomobject]@{root=$root;files=$records} | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $backup 'backup.json')
try {
 foreach ($entry in $manifest.files) {
  $source=Join-Path $PSScriptRoot ('payload/'+$entry.path)
  $target=Join-Path $root $entry.path
  New-Item -ItemType Directory -Force (Split-Path $target -Parent) | Out-Null
  Copy-Item -LiteralPath $source -Destination $target -Force
  if ((Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash -ne $entry.sha256) { throw "Installed hash mismatch: $($entry.path)" }
  Write-Host "VERIFIED $($entry.path)"
 }
} catch {
 foreach ($entry in $records) {
  $target=Join-Path $root $entry.path
  if ($entry.existed) { Copy-Item -LiteralPath (Join-Path $backup $entry.path) -Destination $target -Force }
  elseif (Test-Path -LiteralPath $target) { Remove-Item -LiteralPath $target }
 }
 throw
}
Write-Host "Installed aquatic-foundation-1. Backup: $backup"
Write-Host 'Next: rebuild with scripts/Build.ps1, start scripts/Start-Aquatic.ps1 in a NEW runtime, sync Rojo, Play.'
