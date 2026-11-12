# Hawkey — Claude Code project guide

Hawkey is an original PC hockey simulation in **Godot 4.6** (GDScript) that
aims to look and feel like EA's NHL games. The owner (Ethan) directs the work;
Claude owns graphics, models, equipment, lighting and animation; Codex
(ChatGPT) owns modes, data, saves, rules/input and simulation on its own
branches.

**Start every session by reading `docs/CLAUDE_MEMORY.md`** — it is the
project memory: current state, open defects, decisions, gotchas and the next
steps. Update it (and the run log at the bottom of `docs/BACKLOG.md`) before
you finish. The `/update-memory` command does this.

## Branches and git
- Work branch: `prototype/skating-puck-lab` (track `origin/prototype/skating-puck-lab`).
- Fetch before starting and before pushing; rebase, never force-push.
- Never merge `codex/game-modes` (or any Codex branch) into this branch.
- Keep edits to the shared files `scripts/match.gd` and `scripts/lab.gd` small
  and described in the commit.
- Ask the owner before pushing unless he has already said to push this session.

## Rules (mandatory; full text at the top of docs/BACKLOG.md)
- Downloaded models and real-world gear are allowed, but brand names, club/NHL
  logos, player names and signatures are digitally removed; every third-party
  model keeps its credit and licence note in `assets/CREDITS.md`.
- Never use EA or other commercial-game code/art/audio, or anything from
  decompiled games.
- Never commit `assets/mixamo/`.
- PLAY NOW is the only game mode; every position is a seat a CPU holds until a
  human takes it (`scripts/control_slots.gd`).
- Every test in `tests/` must pass before pushing. Add a test for new
  behaviour. Render and LOOK at the result before calling visual work done.
- Never relax a test tolerance to make it pass; fix the geometry or explain an
  independently justified change in the commit.

## Running things
Godot 4.6.2 is the reference version (`godot` on PATH; on Windows see
`tools/setup_windows.ps1`).

- Import once after pulling or adding assets: `godot --headless --import`
- One test: `godot --headless --script tests/test_clipping.gd`
- All tests: `tools/run_tests.sh` (Linux/macOS) or
  `powershell -File tools/run_tests.ps1` (Windows). ~20–30 min; logs in
  `build/test-logs/`. Every suite must exit 0 with 0 failures.
- Match render: `godot --rendering-method gl_compatibility --resolution 1728x1080 main.tscn -- --capture`
  (writes `hawkey-match-preview.png` in the temp folder; options `--camera=0..3`,
  `--spectate`, `--capture-time=<s>`, `--faceoff*`, `--replay*`, `--stats-screen=...`).
  On headless Linux prefix `xvfb-run -a -s "-screen 0 1728x1080x24"`.
- Close-up renders (`--script tools/<name>.gd`):
  `capture_skater_close.gd` (skater kit), `capture_goalie.gd [--only=<shot>]`
  (goalie shots: legs-*, rear-*, mitt, blocker*, catch...),
  `capture_goalie_seq.gd [--clay]` (fixed-pose drop/recovery sheet),
  `capture_goalie_drop.gd [--clay]` (continuous drop/recovery from the live
  update, prints largest per-frame steps), `capture_gloves.gd` (catcher and
  blocker alone), `capture_head.gd`, `capture_saves.gd`.
- Save the best render as `docs/screenshots/<name>-auto-<YYYYMMDD>.png`, then
  run the import again so its `.import` file exists, and commit both.

## Blender
Blender 5.2 is on the owner's PC
(`C:\Program Files\Blender Foundation\Blender 5.2\blender.exe`). Scripts in
`tools/blender/` take a bridge root after `--` with `input/` and `out/`
folders (the old bridge lives at
`Documents\hawkey-prototype-skating-puck-lab-(1)\blender_bridge`). In Claude
Code on the PC you can run them directly:

    & "C:\Program Files\Blender Foundation\Blender 5.2\blender.exe" -b --factory-startup --python-exit-code 1 --python tools/blender/goalie_pads_v2.py -- <bridge root>

Copy the result from `<bridge root>/out/` into `assets/` and re-import.
Source models the owner downloaded are in `Documents\Hawkey\art\incoming\`.

## Coordination with Codex
Read `AGENTS.md` and `docs/AGENT_HANDOFFS.md`. Incoming requests are in
`docs/agent_handoffs/codex-to-claude/` on the current `origin/codex/game-modes`
head (fetch it; this branch may not have the newest). Reply under
`docs/agent_handoffs/claude-to-codex/` on this branch (new file
`CL-<YYYYMMDD>-<NNN>.md` plus a row in the index table). Never write Codex's
acknowledgement for it.

## Where things are
- Architecture list: `docs/DEVELOPMENT.md` (update it when adding a script/system).
- Backlog + run log: `docs/BACKLOG.md`.
- Player/goalie visuals: `scripts/skater_visual.gd`, procedural gear
  `scripts/gear_builder.gd`, materials `scripts/kit_materials.gd`, shaders in
  `assets/*.gdshader`, models in `assets/gear/` and `assets/kit/`.
- Custom commands: `.claude/commands/` (`/next-run`, `/test-all`,
  `/goalie-review`, `/update-memory`).
