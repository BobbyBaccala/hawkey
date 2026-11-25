#!/usr/bin/env bash
# Run several full CPU games in parallel and summarise them.
#   tools/sim_batch.sh <label> <seed>... [-- --tune=goalie_read_time=0.17 ...]
# Results go to build/sims/<label>/g<seed>.json (+ .log); each game rewrites
# its JSON at every period end, so a container restart keeps the finished
# periods. Re-running the same label skips seeds whose game already finished.
# ~35-60 min for 4 games on 4 cores; prints sim_report.py at the end.
set -uo pipefail
cd "$(dirname "$0")/.."
label="$1"; shift
seeds=(); while [ $# -gt 0 ] && [ "$1" != "--" ]; do seeds+=("$1"); shift; done
[ "${1:-}" = "--" ] && shift
dir="build/sims/$label"; mkdir -p "$dir"
for s in "${seeds[@]}"; do
  if [ -f "$dir/g$s.json" ] && ! grep -q '"partial":true' "$dir/g$s.json"; then echo "seed $s done already"; continue; fi
  timeout 7200 godot --headless --script tools/sim_game.gd -- --seed="$s" --out="$dir/g$s.json" "$@" > "$dir/g$s.log" 2>&1 &
done
wait
python3 tools/sim_report.py "$dir"/g*.json
