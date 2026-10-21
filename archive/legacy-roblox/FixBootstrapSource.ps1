$ErrorActionPreference = "Stop"
if (!(Test-Path .\src\client)) { throw "Run this from your ci_rbxl repository root." }
Get-ChildItem .\src\client -Recurse -File | Where-Object { $_.Name -match 'Bootstrap.*\.(lua|luau)$' } | ForEach-Object {
 $old = [System.IO.File]::ReadAllText($_.FullName)
 $new = [regex]::Replace($old, 'error\s*\(\s*([a-zA-Z_][a-zA-Z_0-9]*)\s*([,)])', 'error(tostring($1)$2')
 if ($new -ne $old) {
  Copy-Item -LiteralPath $_.FullName -Destination ($_.FullName + '.warningfix-backup.txt') -ErrorAction Stop
  [System.IO.File]::WriteAllText($_.FullName, $new, (New-Object System.Text.UTF8Encoding($false)))
  Write-Host "Fixed bootstrap:" $_.FullName
 }
}
