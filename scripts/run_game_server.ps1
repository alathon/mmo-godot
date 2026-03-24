param(
    [Parameter(Mandatory=$true)][string]$Zone,
    [Parameter(Mandatory=$true)][string]$Port,
    [Parameter(ValueFromRemainingArguments=$true)][string[]]$ExtraArgs
)

Set-Location (Split-Path $PSScriptRoot -Parent)
godot-mono --headless --scene "res://src/game-server/zones/ServerZone.tscn" -- --zone $Zone --port $Port @ExtraArgs
