$orchestratorJob = Start-Job { & "$using:PSScriptRoot\run_orchestrator.ps1" }
$forestJob       = Start-Job { & "$using:PSScriptRoot\run_game_server.ps1" forest 7000 }
$otherJob        = Start-Job { & "$using:PSScriptRoot\run_game_server.ps1" other 7001 }

Write-Host "Started orchestrator, forest on port 7000, and other on port 7001"
Write-Host "Press Ctrl+C to stop all"

try {
    Wait-Job $orchestratorJob, $forestJob, $otherJob | Out-Null
} finally {
    Stop-Job $orchestratorJob, $forestJob, $otherJob
    Remove-Job $orchestratorJob, $forestJob, $otherJob
}
