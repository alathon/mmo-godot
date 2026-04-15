param(
    [int]$NumBots = 10
)

Set-Location (Split-Path $PSScriptRoot -Parent)

for ($i = 1; $i -le $NumBots; $i++)
{
    Start-Process godot-mono -ArgumentList "--headless --scene res://src/client/Game.tscn -- --bot"
}
