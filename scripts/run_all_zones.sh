#!/bin/sh
SCRIPT_DIR="$(dirname "$0")"

"$SCRIPT_DIR/run_game_server.sh" ServerForest 7000 &
"$SCRIPT_DIR/run_game_server.sh" ServerOther 7001 &

echo "Started ServerForest on port 7000 and ServerOther on port 7001"
echo "Press Ctrl+C to stop all"
wait
