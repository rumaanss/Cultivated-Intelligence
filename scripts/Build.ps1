param([switch]$Research, [int]$Jobs = 4)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
Push-Location $root
try {
    $researchFlag = if ($Research) { 'ON' } else { 'OFF' }
    cmake -S . -B build/native -DCMAKE_BUILD_TYPE=Release "-DCI_BUILD_RESEARCH=$researchFlag"
    if ($LASTEXITCODE -ne 0) { throw 'CMake configuration failed.' }
    cmake --build build/native --config Release --parallel $Jobs
    if ($LASTEXITCODE -ne 0) { throw 'Native build failed.' }
    ctest --test-dir build/native -C Release --output-on-failure
    if ($LASTEXITCODE -ne 0) { throw 'Regression tests failed; do not launch this build.' }
} finally { Pop-Location }
