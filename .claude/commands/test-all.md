---
description: Run every Hawkey test suite and summarise failures
---
Run the full test suite: `tools/run_tests.sh` on Linux/macOS or
`powershell -File tools/run_tests.ps1` on Windows (logs go to
`build/test-logs/`). It takes about 6-7 minutes (2026-11-25); run it in the background and wait for the notification.
When it finishes, report: suites run, non-zero exits, and every FAIL line with
its suite. Do not claim a pass for a revision you did not run it on.
