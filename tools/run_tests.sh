#!/usr/bin/env bash
# Runs tests/test_*.gd headless, two at a time (JOBS=n to change), one log per
# suite in build/test-logs/. Exit status is non-zero if any suite failed.
#   tools/run_tests.sh                 every suite (~20-30 min on 2 CPUs)
#   tools/run_tests.sh goalie clipping only suites whose names contain a word
set -u
cd "$(dirname "$0")/.."
mkdir -p build/test-logs
rm -f build/test-logs/*.log build/test-logs/_status
if [ $# -gt 0 ]; then
  pat=$(printf '%s|' "$@"); pat=${pat%|}
  list=$(ls tests/test_*.gd | grep -E "$pat")
else
  list=$(ls tests/test_*.gd)
fi
# Longest suites first (durations remembered in build/test-durations.txt from
# earlier runs): with JOBS parallel slots a long suite started last would
# otherwise run alone at the end.
dur=build/test-durations.txt
if [ -f "$dur" ]; then
  list=$(for f in $list; do n=$(basename "$f" .gd); t=$(awk -v n="$n" '$1==n{print $2}' "$dur"); echo "${t:-9999} $f"; done | sort -rn | cut -d' ' -f2)
fi
start=$(date +%s)
echo "$list" | xargs -P "${JOBS:-2}" -I{} sh -c 'n=$(basename {} .gd); t0=$(date +%s); timeout 1500 godot --headless --script {} > build/test-logs/$n.log 2>&1; rc=$?; echo "$n $rc $(( $(date +%s) - t0 ))" >> build/test-logs/_status'
# Remember durations (newest wins) and show the slowest suites.
{ [ -f "$dur" ] && cat "$dur"; awk '{print $1, $3}' build/test-logs/_status; } | awk '{d[$1]=$2} END{for(k in d) print k, d[k]}' | sort > "$dur.tmp" && mv "$dur.tmp" "$dur"
echo "wall time: $(( $(date +%s) - start )) s; slowest suites (s):"
sort -k3 -rn build/test-logs/_status | head -6 | awk '{printf "  %-34s %s\n", $1, $3}'
total=$(wc -l < build/test-logs/_status)
bad=$(awk '$2!=0' build/test-logs/_status)
fails=$(grep -l "FAIL" build/test-logs/test_*.log 2>/dev/null)
echo "suites: $total"
[ -n "$bad" ] && echo "non-zero exits:" && echo "$bad"
[ -n "$fails" ] && echo "logs with FAIL lines:" && echo "$fails"
if [ -z "$bad" ] && [ -z "$fails" ]; then echo "all passed"; exit 0; fi
exit 1
