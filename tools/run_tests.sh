#!/usr/bin/env bash
# Runs every tests/test_*.gd headless, two at a time (JOBS=n to change), one
# log per suite in build/test-logs/. Exit status is non-zero if any suite failed.
set -u
cd "$(dirname "$0")/.."
mkdir -p build/test-logs
rm -f build/test-logs/*.log build/test-logs/_status
ls tests/test_*.gd | xargs -P "${JOBS:-2}" -I{} sh -c 'n=$(basename {} .gd); timeout 1500 godot --headless --script {} > build/test-logs/$n.log 2>&1; echo "$n $?" >> build/test-logs/_status'
total=$(wc -l < build/test-logs/_status)
bad=$(awk '$2!=0' build/test-logs/_status)
fails=$(grep -l "FAIL" build/test-logs/test_*.log 2>/dev/null)
echo "suites: $total"
[ -n "$bad" ] && echo "non-zero exits:" && echo "$bad"
[ -n "$fails" ] && echo "logs with FAIL lines:" && echo "$fails"
if [ -z "$bad" ] && [ -z "$fails" ]; then echo "all passed"; exit 0; fi
exit 1
