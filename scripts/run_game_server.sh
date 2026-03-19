#!/bin/sh
if [ -z "$1" ] || [ -z "$2" ]; then
    echo "Usage: $0 <zone_id> <port> [extra args...]"
    echo "Example: $0 forest 7000"
    exit 1
fi
ZONE="$1"
PORT="$2"
shift 2
/Applications/godot.app/Contents/MacOS/godot --headless --scene "res://src/game-server/zones/ServerZone.tscn" -- --zone "$ZONE" --port "$PORT" "$@"
