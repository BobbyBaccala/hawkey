# Claude project memory — Hawkey

Read this first each session; update it before finishing (`/update-memory`).
Keep it short: current state, decisions, gotchas, next steps. History lives in
the run log at the bottom of `docs/BACKLOG.md`.

_Last updated: 2026-11-12 (cloud session, branch claude/goalie-butterfly-pads-i8na2t,
based on prototype/skating-puck-lab; not yet merged back)._

## Owner and working style
- Owner: Ethan. Wants visible progress on the player and goalie models every
  session, judged against EA NHL and real reference photos (he sent Carey
  Price photos: stance, butterfly, splits, glove saves).
- Watch usage: prefer one agent; parallel sub-agents only when clearly worth it.
  Batch renders/tests, keep logs on disk.
- Show before/after images from fixed cameras; say plainly what is still wrong.

## Current state (2026-11-12)
Skaters
- Kit v9 (`assets/kit/skater-kit-v9.glb`, `tools/blender/kit_v9.py`): rounder
  shoulders, sweater side panels, breezer side stripe (kit_gear.gdshader
  pants_stripe via UV2.x).
- Scanned head (`assets/gear/head-v1.glb`) on skaters, goalies and referees;
  6 skin tones + hair colours from the jersey number (`assets/skater_face.gdshader`,
  FACE_TONES/HAIR_COLORS); hair/liner/ear masks baked into vertex colour; smooth
  neck guard.
- Blender skate, helmet, glove meshes; CPU body checks with stagger and glass rattle.

Goalies
- Pads: `assets/gear/goalie-pads-v2.glb` (v1 kept) — moulded boot channel up the
  back, toe pocket under a thin toe bridge, toe opening. Drawn pad is a constant
  size (PAD_VIS_SCALE 1.016 x 1.25 x 1.35 = 91 cm, 11 in) pinned at the knee and
  centred on the ankle across the pad; collision proxies (`pads`, `pad_box`,
  `get_goalie_gear`) are separate and unchanged.
- Thigh rise hangs from the unscaled pad node and only rotates/translates.
  Butterfly wall (`separate_thigh_rises()`, WALL_* consts): dropping, each rise
  turns from the thigh to stand face-on over its knee stack, seated 3 cm over
  the lower pad top, inner edge 3 mm off centre - one wall across the
  five-hole. A kicking leg keeps its rise on the extended pad.
- Save body language (SAVE_LEAN_*, PAD_SAVE_*): torso tips/turns toward a
  glove or blocker reach (catcher pocket square to the shooter); pad
  extensions lean, bend and turn the chest over the lead pad. Torso/catcher
  save proxies follow this pose (shared source), so save coverage moved too.
- Knee cradle, calf wrap and straps (`Gear.pad_rear`, `PadRear` nodes).
- Skate stays on the ankle; in the butterfly the foot keeps ~105 deg to the
  shin with the toe in the pad's boot channel.
- Catcher: two lobes with a T notch, tan leather pocket, laced web, finger
  binding and stall breaks. Blocker: fingers/thumb round the stick, palm,
  wrist strap.
- Stick: owner's downloaded CCM Premier model, logos blanked before baking
  (`tools/blender/goalie_stick_v1.py` -> `assets/gear/goalie-stick-v1.glb`),
  1.45 m; the box shaft/paddle/blade stay hidden as save proxies.
- Sweater: accent yoke + chest diamond crest, ends at the hips over wider
  accent-coloured pants.

Gameplay (for context): offside and icing (`scripts/rules_offside_icing.gd`),
CPU body checks, PLAY NOW seats, smarter CPU (Codex/earlier sessions).

Tests: 46 suites; last full run 46/46 at 6a216e9 (2026-11-12).

## Open defects / next steps (goalie first)
1. Splits as a separate desperation save pose (backlog "Goalie saves slice 2").
2. Butterfly polish: 6 mm shaded seam between the two rises; knee-stack ends
   of the lower pads are ~14 cm apart under the rises; rise top still moves
   9.0 cm/frame mid-drop (inherent to the 6/s drop; knee 5.9).
3. Full glove lean shows a jagged sleeve/yoke seam on the far shoulder.
4. Merge this branch back into prototype/skating-puck-lab (owner's call).
5. Catcher back plain; blocker board back flat black.
6. Goalie stick bake lost its red graphic (white/black only).
7. Skaters: boxy shoulders still, single face mesh (add variants), number font
   is block (backlog "Blender kit, pass 2").
8. Parked unfinished work in old cloud worktrees (jersey numbers/athletic font,
   shooting animations) did not reach GitHub — redo from the backlog items.

## Decisions
- 2026-11-07: downloaded models/brands allowed with logos, names and signatures
  removed; credits in assets/CREDITS.md.
- 2026-11-12: EA NHL screenshots/video are allowed as visual reference;
  files ripped from EA games (or any commercial game) are still not used.
- 2026-11-07: PLAY NOW is the only mode.
- 2026-11-12: cloud sessions use the personal "hawkey" environment; its setup
  script installs Godot 4.6.2 to /usr/local/bin/godot and runs the import.
  Cloud runs push to their designated claude/* branch, not the work branch.
- Goalie visuals may differ from the save collision proxies; keep the
  proxies' behaviour identical unless gameplay is the task (compare
  `get_goalie_gear()` at sampled poses before/after).

## Gotchas
- Cloud container: if `godot` is missing, the session is not on the "hawkey"
  environment; `main` is only a README - the project is on
  prototype/skating-puck-lab.
- Full suite in the cloud: `JOBS=3 tools/run_tests.sh` took ~20 min (4 cores).
- Save poses are gameplay: changing torso/catcher pose changes get_goalie_gear();
  run test_goalie_saves and test_play_now_ai after any save-pose edit.
- `test_clipping.gd`: inside test = ray parity candidate + winding number
  (pads are overlapping closed shells; boolean meshes have slivers). Judge the
  skate against the pad mesh in pad space. Don't add region exceptions.
- After adding/replacing a GLB or PNG, run `godot --headless --import` before
  tests, or preload fails ("no resource loaders").
- GDScript: untyped `:=` from Variant fails to parse; give explicit types.
  A script error in a headless test can hang — run tests with a timeout.
- Codex's Windows files may be CRLF; normalise before diffing.
- Never `pkill -f` a pattern that matches your own command; kill by PID.
- Mixamo clips are absent in clean checkouts; mocap tests skip.
- Blender bridge outputs are written to `<bridge>/out/<job>.*`; the Godot side
  needs the GLB copied into `assets/` (GLB embeds textures as
  `<name>_<image>.png` on import — commit those too).
