# Run from the C++ project root while Studio is in Play.
param([string]$Directory="live\state",[int]$Samples=10)
$ErrorActionPreference="Stop"
for ($i=0;$i -lt $Samples;$i++) {
    $snapshot = Get-Content -LiteralPath (Join-Path $Directory "snapshot.json") -Raw | ConvertFrom-Json
    $status = Get-Content -LiteralPath (Join-Path $Directory "bridge_status.json") -Raw | ConvertFrom-Json
    $inputFile = Get-Item -LiteralPath (Join-Path $Directory "input.txt")
    [pscustomobject]@{
        Time = Get-Date -Format "HH:mm:ss"
        Build = $snapshot.bridgeBuild
        Tick = $snapshot.tick
        Sequence = $snapshot.sequence
        Applied = $snapshot.ack
        Durable = $snapshot.durableAck
        InputAgeMs = [math]::Round(((Get-Date)-$inputFile.LastWriteTime).TotalMilliseconds)
        Recovering = @($snapshot.corrections).Count
        Reason = $status.status
    } | ConvertTo-Json -Compress
    Start-Sleep -Seconds 1
}
