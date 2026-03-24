#!/bin/sh
cd "$(dirname "$0")/.." || exit 1
godot --headless --scene res://src/orchestrator/Orchestrator.tscn
