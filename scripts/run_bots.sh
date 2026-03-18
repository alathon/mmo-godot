#!/bin/sh

# Run a bunch of bots in headless mode.
# Defaults to 10, but you can specify as input to script.

NUM_BOTS=${1:-10}

for i in $(seq 1 $NUM_BOTS); do
    /Applications/godot.app/Contents/MacOS/godot --headless --scene res://src/client/Bot/BotGame.tscn &
done
