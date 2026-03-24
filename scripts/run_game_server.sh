#!/bin/sh
cd "$(dirname "$0")/.." || exit 1
if [ -z "$1" ] || [ -z "$2" ]; then
    echo "Usage: $0 <zone_id> <port> [extra args...]"
    echo "Example: $0 forest 7000"
    exit 1
fi
ZONE="$1"
PORT="$2"
shift 2
godot --headless --scene "res://src/game-server/zones/ServerZone.tscn" -- --zone "$ZONE" --port "$PORT" "$@"
