# Claude project memory — Hawkey

Read this first each session; update it before finishing (`/update-memory`).
Keep it to ~100 lines: current state, open problems, decisions, gotchas.
History and per-run numbers live in the run log at the bottom of
`docs/BACKLOG.md` (trimmed 2026-11-26 from 300 lines; nothing was lost - the
run log has every entry).

_Last updated: 2026-11-26 (cloud session, branch prototype/skating-puck-lab)._

## Owner and working style
- Owner: Ethan. Wants visible progress on player and goalie models every
  run, judged against EA NHL and real photos (Carey Price reference set).
- Show before/after sheets from fixed cameras (`tools/sheet.py --diff`); say
  plainly what is still wrong. Prefer one agent; parallel only when worth it.

## Current state (details: run log + docs/DEVELOPMENT.md)
- Skater kit v12 (`tools/blender/kit_v12.py`): v11 with the hem eased closer
  over the breezers (HEM_EASE 3.0/2.2 cm; v11's 4.4/3.2 cm made a bell).
  v11: rounded yoke, side panels, padded breezers tapering to the knee (keep opening < 0.88 x thigh: owner
  rejected a "drum" look). Socks from the knee with shin-guard cap + thigh
  sock (Gear.sock/sock_thigh). Glove v2 (`glove_v2.py`): continuous finger
  rolls, thumb beside the shaft, dark cuff liner. Scanned head with 6 skin
  tones x 6 face shapes. Block-number jersey digits.
- Goalie: rigid pads v2 (owner: pads never bend, skate never shows through),
  13 save kinds with spring timing (SAVE_KINDS), save boxes separate from
  visuals (get_goalie_gear incl. rig.transform), rebound control, freezes,
  covers, squeezes, reverse VH, poke, pad-stack dive.
- Animation: keyframed stick strokes (stroke_anim.gd: shots, passes, dekes,
  tip, block, receive), turn lean + crossovers, stickhandling.
- CPU AI: TeamTactics structure (breakouts, 1-2-2, OZ/DZ spots), faceoff
  lineups (end-zone wingers stacked on the middle hash, NZ D staggered;
  tests/test_faceoff_alignment.gd).
- Stats (owner target: 25-30 SOG/team, .870-.930 sv%, a few 1+ P/GP):
  GOALIE_READ 0.18 s since 2026-11-26: 12 games (seeds 31-34, 61-68) =
  2.92 goals/team, .903 sv%, 30.2 SOG; its three 4-game batches read 3.88,
  1.75 and 3.12, so never tune on 4 games. 0.16 s gave 2.50 / .905 / 26.4.

## Open problems / next steps
1. Stats on target with 0.18 s; SOG at the top edge (30.2) - watch it.
2. Skaters: knee cap knobby in a deep bend; teal thigh sock visible inside
   the far breezer opening; breezer stripe edge wobbles; jersey hem flares
   stiffly; cuff close-up camera hides the top hand.
3. Strokes: no dive motion into splits; blade face doesn't roll open/closed;
   skill-stick gestures untested on a real pad (owner).
4. AI: teammates < 2 m apart in ~18% of frames; OZ forwards could go lower.
5. skating.gd:22 slerp logs "axis must be normalized" in sim games (harmless;
   Codex's file - tell them).
6. Godot 4.7.1 (HDR, area lights, breaking changes): try on a branch later.

## Decisions
- 2026-11-07: downloaded models allowed with logos/names/signatures removed;
  credits in assets/CREDITS.md. PLAY NOW is the only mode.
- 2026-11-12: EA NHL screenshots/video are visual reference only; never
  files from any commercial game. Claude may push fully tested work to
  prototype/skating-puck-lab.
- 2026-11-12 (owner): goalie pads don't bend in the butterfly; the skate must
  never show through the pad; pad colliders may move with the pads.
- Goalie visuals may differ from save proxies; keep proxies identical unless
  gameplay is the task (compare get_goalie_gear() at sampled poses).
- 2026-11-26 (owner approved all four from the process review):
  Blender 5.2.5 LTS (official tarball, checksum-verified) and Godot 4.6.3 in
  the cloud environment; stat batches in separate helper cloud sessions;
  this file trimmed.

## Process
- Tools: `tools/sheet.py` (labelled sheets, --crop, --diff),
  `capture_skater_close.gd --only=`, `tools/sim_batch.sh` +
  `sim_game.gd --tune=<match var>=<v>` (never edit constants mid-batch;
  JSON saved each period), `run_tests.sh` (timings, longest first; full
  suite ~6-7 min).
- Long stat batches: start them in helper cloud sessions (create_session on
  this repo/branch, prompt = run sim_batch.sh and reply with the report; no
  commits), read results with list_events. Container restarts between turns
  kill local background jobs.
- Before a model change, grep tests/ for that area: tests encode owner
  decisions.
- Blender: `/opt/blender/blender-5.2.5-linux-x64/blender -b --factory-startup
  --python-exit-code 1 --python tools/blender/<script>.py -- <bridge>` under
  `xvfb-run -a`; <bridge>/input/ needs assets/player-base-v1.glb. Same output
  as Blender 4.0 (vertex counts/clearance), ~7 s for the kit.

## Gotchas
- Forward+ renders (lavapipe, see CLAUDE.md) are the judge; gl_compatibility
  makes navy/undersides near-black. Capture tools that cut cameras show
  coloured glows for a frame or two (temporal history) - not in the game.
- White blobs in Forward+ = NaN bloomed by glow: every shader pow() base >= 0
  (square with x*x), clamp vertex colours; test_gameplay_photo enforces it.
- Physics is 120 Hz: probes counting frames as 1/60 s halve every rate.
- `godot --headless --quit` does NOT parse match.gd; after editing it, load
  scripts with load() + can_instantiate() (a parse error hangs probes).
- GDScript: untyped `:=` from Variant fails to parse. Run headless tests with
  a timeout. After adding a GLB/PNG run `godot --headless --import`.
- Never test old behaviour via `git stash` when the test uses new constants
  (hangs). Never `pkill -f` a pattern matching your own command.
- Strokes: blade targets keep STICK_L from the FINAL top hand.
- Save poses are gameplay: run test_goalie_saves and test_play_now_ai after
  any save-pose edit. Whole-body poses (stack): pose upright, roll the rig.
- test_clipping: fix the pose, never add region exceptions.
- Jersey body UV2.x is the angle round the body (wraps down one flank):
  garment_surface(..., wrap_u2) duplicates wrap vertices (sparkle crack fix).
- Gear shader is cull_disabled: open tubes show their pale inside - close
  them with dark liners rather than relying on culling.
- Parallel worktree agents may start on `main` (README only): branch from
  the prototype head. Match renders share /tmp/hawkey-match-preview.png.
- Cloud: no `godot` means the session isn't on the "hawkey" environment.
- Codex's Windows files may be CRLF. Mixamo clips are absent (mocap tests skip).
