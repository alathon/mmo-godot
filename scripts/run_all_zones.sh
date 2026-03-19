#!/bin/sh
SCRIPT_DIR="$(dirname "$0")"

cleanup() {
    kill 0
    wait
}
trap cleanup INT TERM

"$SCRIPT_DIR/run_game_server.sh" forest 7000 &
"$SCRIPT_DIR/run_game_server.sh" other 7001 &

echo "Started forest on port 7000 and other on port 7001"
echo "Press Ctrl+C to stop all"
wait
