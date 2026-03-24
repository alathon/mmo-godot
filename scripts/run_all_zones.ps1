$forestJob = Start-Job { & "$using:PSScriptRoot\run_game_server.ps1" forest 7000 }
$otherJob  = Start-Job { & "$using:PSScriptRoot\run_game_server.ps1" other 7001 }

Write-Host "Started forest on port 7000 and other on port 7001"
Write-Host "Press Ctrl+C to stop all"

try {
    Wait-Job $forestJob, $otherJob | Out-Null
} finally {
    Stop-Job $forestJob, $otherJob
    Remove-Job $forestJob, $otherJob
}
