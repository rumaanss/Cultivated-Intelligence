param([string]$Runtime = 'runtime/planet-native-v1', [int]$Port = 8765)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$directory = if ([IO.Path]::IsPathRooted($Runtime)) { $Runtime } else { Join-Path $root $Runtime }
$token = (Get-Content (Join-Path $directory 'native.token') -Raw).Trim()
Invoke-RestMethod -Uri "http://localhost:$Port/health" -Method Post -ContentType 'application/json' -Headers @{'X-CI-Token'=$token} -Body '{"schema":1}' | ConvertTo-Json -Depth 6
