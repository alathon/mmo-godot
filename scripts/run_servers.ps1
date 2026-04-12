param(
    [string]$Address = "127.0.0.1",
    [int]$ForestPublicPort = 0,
    [int]$OtherPublicPort = 0
)

$root = Split-Path $PSScriptRoot -Parent

$forestArgs = "--zone forest --port 9002 --address $Address"
$otherArgs = "--zone other --port 9003 --address $Address"
if ($ForestPublicPort -gt 0) { $forestArgs += " --public-port $ForestPublicPort" }
if ($OtherPublicPort -gt 0) { $otherArgs += " --public-port $OtherPublicPort" }

$procs = @(
    Start-Process cmd -ArgumentList "/k", "title Orchestrator && cd /d `"$root`" && godot-mono --headless --scene res://src/orchestrator/Orchestrator.tscn" -PassThru
    Start-Process cmd -ArgumentList "/k", "title Zone: forest (9002) && cd /d `"$root`" && godot-mono --headless --scene `"res://src/game-server/zones/ServerZone.tscn`" -- $forestArgs" -PassThru
    Start-Process cmd -ArgumentList "/k", "title Zone: other (9003) && cd /d `"$root`" && godot-mono --headless --scene `"res://src/game-server/zones/ServerZone.tscn`" -- $otherArgs" -PassThru
)

Write-Host "Started orchestrator, forest (9002), other (9003) with address=$Address in separate windows."
Write-Host "Press Ctrl+C here (or close the windows) to stop all."

try {
    $procs | Wait-Process
} finally {
    $procs | Where-Object { -not $_.HasExited } | ForEach-Object { taskkill /PID $_.Id /T /F 2>$null }
}
