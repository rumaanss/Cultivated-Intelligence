param(
    [string]$ProjectRoot = (Get-Location).Path,
    [Parameter(Mandatory=$true)][string]$Backup
)
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path -LiteralPath $ProjectRoot).Path
$backupPath = if ([IO.Path]::IsPathRooted($Backup)) { $Backup } else { Join-Path $root $Backup }
$backupPath = (Resolve-Path -LiteralPath $backupPath).Path
$record = Get-Content -Raw -LiteralPath (Join-Path $backupPath 'backup.json') | ConvertFrom-Json
if ($record.root -ne $root) { throw 'Backup belongs to a different project root.' }
foreach ($entry in $record.files) {
    if ($entry.existed -and !(Test-Path -LiteralPath (Join-Path $backupPath $entry.path))) {
        throw "Backup is incomplete: $($entry.path). No files changed."
    }
}
foreach ($entry in $record.files) {
    $target = Join-Path $root $entry.path
    if ($entry.existed) {
        Copy-Item -LiteralPath (Join-Path $backupPath $entry.path) -Destination $target -Force
    } elseif (Test-Path -LiteralPath $target) {
        Remove-Item -LiteralPath $target
    }
}
Write-Host 'Restored pre-installation files. Rebuild, launch the previous runtime with Start-Planet.ps1, and sync Rojo.'
