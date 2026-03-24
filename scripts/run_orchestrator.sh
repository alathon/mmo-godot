#!/bin/sh
cd "$(dirname "$0")/.." || exit 1
/Applications/godot.app/Contents/MacOS/godot --headless --scene res://src/orchestrator/Orchestrator.tscn
