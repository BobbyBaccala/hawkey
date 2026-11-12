---
description: Do one finished improvement run on Hawkey (pick work, build, test, render, log)
---
Do one substantial, finished improvement to Hawkey (or two small ones). $ARGUMENTS

1. Read `docs/CLAUDE_MEMORY.md`, the rules at the top of `docs/BACKLOG.md`, and
   any new requests in `docs/agent_handoffs/codex-to-claude/` on
   `origin/codex/game-modes` (fetch first).
2. `git fetch origin` and make sure you are on `prototype/skating-puck-lab`,
   up to date (rebase; never force-push, never merge Codex branches).
3. Pick work: if the owner gave a focus above, do that; otherwise take the
   first item under "Open defects / next steps" in the memory file, else the
   first unchecked backlog item not marked in progress. Split large items.
4. Render the current state first with the relevant capture tool and LOOK at it.
   Then implement. Keep `scripts/match.gd` / `scripts/lab.gd` edits small.
5. Render again from the same cameras and compare; iterate (at most three
   correction cycles). Save the best before/after sheet to
   `docs/screenshots/<name>-auto-<YYYYMMDD>.png` and re-import.
6. Run the relevant tests, then the full suite once on the final revision
   (`/test-all`). Add a test for new behaviour. Never relax tolerances.
7. Tick/split the backlog item, add one run-log line, update
   `docs/DEVELOPMENT.md` if you added a script/system, and run `/update-memory`.
8. Commit with a clear message. Ask before pushing unless already told to push.
9. Finish with 2-4 sentences for the owner: what changed, what to look for in
   game, the screenshot path, and anything still wrong.
