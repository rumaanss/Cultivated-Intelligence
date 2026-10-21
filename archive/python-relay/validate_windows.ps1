# Run from the C++ project root. No permission changes or security bypasses.
$ErrorActionPreference="Stop"
cmake -S . -B build-optics
if ($LASTEXITCODE -ne 0) { throw "Configure failed" }
cmake --build build-optics --config Release --parallel 4
if ($LASTEXITCODE -ne 0) { throw "Build failed" }
ctest --test-dir build-optics -C Release --output-on-failure
if ($LASTEXITCODE -ne 0) { throw "Tests failed" }
Write-Host "Native tests complete. Now follow the Studio multiplayer acceptance checklist in README."
