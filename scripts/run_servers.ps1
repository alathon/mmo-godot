$root = Split-Path $PSScriptRoot -Parent

$procs = @(
    Start-Process cmd -ArgumentList "/k", "title Orchestrator && cd /d `"$root`" && godot-mono --headless --scene res://src/orchestrator/Orchestrator.tscn" -PassThru
    Start-Process cmd -ArgumentList "/k", "title Zone: forest (7000) && cd /d `"$root`" && godot-mono --headless --scene `"res://src/game-server/zones/ServerZone.tscn`" -- --zone forest --port 7000" -PassThru
    Start-Process cmd -ArgumentList "/k", "title Zone: other (7001) && cd /d `"$root`" && godot-mono --headless --scene `"res://src/game-server/zones/ServerZone.tscn`" -- --zone other --port 7001" -PassThru
)

Write-Host "Started orchestrator, forest (7000), other (7001) in separate windows."
Write-Host "Press Ctrl+C here (or close the windows) to stop all."

try {
    $procs | Wait-Process
} finally {
    $procs | Where-Object { -not $_.HasExited } | ForEach-Object { taskkill /PID $_.Id /T /F 2>$null }
}
