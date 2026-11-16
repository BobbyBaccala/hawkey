# Claude project memory — Hawkey

Read this first each session; update it before finishing (`/update-memory`).
Keep it short: current state, decisions, gotchas, next steps. History lives in
the run log at the bottom of `docs/BACKLOG.md`.

_Last updated: 2026-11-16 (cloud session, branch prototype/skating-puck-lab)._

## Owner and working style
- Owner: Ethan. Wants visible progress on the player and goalie models every
  session, judged against EA NHL and real reference photos (he sent Carey
  Price photos: stance, butterfly, splits, glove saves).
- Watch usage: prefer one agent; parallel sub-agents only when clearly worth it.
  Batch renders/tests, keep logs on disk.
- Show before/after images from fixed cameras; say plainly what is still wrong.

## Current state (2026-11-16)
Skaters
- Kit v9 (`assets/kit/skater-kit-v9.glb`, `tools/blender/kit_v9.py`): rounder
  shoulders, sweater side panels, breezer side stripe (kit_gear.gdshader
  pants_stripe via UV2.x).
- Scanned head (`assets/gear/head-v1.glb`) on skaters, goalies and referees;
  6 skin tones + hair colours from the jersey number (`assets/skater_face.gdshader`,
  FACE_TONES/HAIR_COLORS); hair/liner/ear masks baked into vertex colour; smooth
  neck guard.
- Blender skate, helmet, glove meshes; CPU body checks with stagger and glass rattle.

Goalies (details in the run log; consts named in skater_visual.gd)
- Pads v2 GLB (boot channel, toe pocket), constant-size drawn pad pinned at the
  knee, rigid in every pose (owner 2026-11-12), toe window closed
  (Gear.pad_toe_cover()); butterfly knees +-0.34 (BFLY_KNEE_X) so the pads
  meet as one wall; kneeling feet turn toe-back behind the pad. Collision
  proxies (pads, pad_box, get_goalie_gear) are separate and include rig.transform.
- Save kinds (SAVE_KINDS, spring weights SAVE_SNAP 24 / SAVE_RECOVER 10):
  glove, blocker, pad_left/right, splits_left/right, stack_left/right
  (choose_save), plus body (arms clamp in), rvh_left/right (reverse VH post
  seal, PlayMoves.choose_post), poke (POKE_*), cover (COVER_*). Torso leans and
  turns into saves; goalie_look() turns the head to save_target.
- match.gd goalie_read(): poke check (PlayMoves.goalie_pokes, 40% knocks the
  puck off) and post seal when no shot is coming; pose_goalies_stopped() keeps
  goalies animating through whistles (cover over the puck, catch held up with
  the puck in the glove, others back to stance) - they used to freeze mid-save.
- Gear: gloves oriented from the arm (place_goalie_glove/align_pair), blocker
  fist on the drawn shaft; white pads with thin accent graphics; glove backs,
  catcher pocket/web, pad rear straps; kit pants with accent stripe; sleeve
  yoke; mask paint + dangler; two-tone stick shader over the de-branded bake.

Skaters: stick strokes (owner 2026-11-16: "animations for all that can
happen") - scripts/stroke_anim.gd keyframed splines at constant stick length:
wrist, snap, slap, one_timer, backhand, pass, saucer, tip, poke, deke_fhbh,
deke_toe_drag, deke_fake. SkaterVisual play_stroke/release_stroke/
load_one_timer/get_puck_world (slap & one-timer leave the puck on the ice
during the backswing); the user's held charge parks at the windup
(charge_kind via match human_shot_kind). CPU shots wind up and release at
the stroke's release time (ai_shoot -> shot_pending -> ai_fire_shot); CPU
dekes (ai_deke), deflections/tips (check_deflection); logic in
scripts/play_moves.gd. Sheets: tools/capture_strokes.gd + stroke_sheet.py.

CPU AI (owner 2026-11-16: realistic positioning and flow; measured with
tools/ai_flow_probe.gd + ai_flow_report.py, see DEVELOPMENT.md):
- Carry commitment, pass safety by pressure, speed-aware pass leads,
  release grace (passer 0.42 s / mates 0.08 / opponents 0.25), around_nets().
- TeamTactics.side_for(): own-side wingers/D (faceoffs too); OZ wide strong
  point + weak D in the middle, net front always filled; DZ wingers on the
  half-wall lane; 1-2-2 forecheck. OZ shot floor, point shots, rebound shots.
- Result: ~2.5 attempts/min, even teams, ~3.3 s possessions. Open: teammates
  <2 m apart in ~18% of frames; forwards could work lower in the OZ.
Gameplay (for context): offside and icing (`scripts/rules_offside_icing.gd`),
CPU body checks, PLAY NOW seats, smarter CPU (Codex/earlier sessions).

Tests: 48 suites (new test_strokes); last full run 48/48 (2026-11-16, strokes run).

## Open defects / next steps
1. Scoring rate too high (pre-existing, measured on the old commit too):
   ~8 goals on ~27 attempts per 3 x 4-min CPU games, mostly one-timers from
   12 m beating a set goalie. Investigate save coverage/reaction vs shot aim
   (a "goalie reads the pass" tweak didn't help; reverted).
2. Strokes: CPU rarely picks wrist/backhand (shot_kind pressure split), no
   human skill-stick deke input yet (CPU only), no shot-block slide, no
   dive motion into stack/splits, blade face doesn't roll open/closed.
3. AI: teammates <2 m apart in ~18% of frames; OZ forwards could go lower.
4. Skaters: boxy shoulders, single face mesh, block number font.

## Decisions
- 2026-11-07: downloaded models/brands allowed with logos, names and signatures
  removed; credits in assets/CREDITS.md.
- 2026-11-12: EA NHL screenshots/video are allowed as visual reference;
  files ripped from EA games (or any commercial game) are still not used.
- 2026-11-07: PLAY NOW is the only mode.
- 2026-11-12 (owner): goalie pads do not bend in the butterfly, and the skate
  must never show through the pad. Pad colliders may move with the pads.
- 2026-11-12: cloud sessions use the personal "hawkey" environment; its setup
  script installs Godot 4.6.2 to /usr/local/bin/godot and runs the import.
  Owner 2026-11-12: Claude may merge finished, fully tested work into
  prototype/skating-puck-lab and push it.
- Goalie visuals may differ from the save collision proxies; keep the
  proxies' behaviour identical unless gameplay is the task (compare
  `get_goalie_gear()` at sampled poses before/after).

## Gotchas
- CPU games are chaotic: judge AI changes on 2+ seeds of 4-min games with the
  flow recorder, not one game. test_play_now_ai's CPU game now counts 90 s of
  live play (goal celebrations/replays excluded) - still one fixed seed.
- Strokes: blade targets must keep STICK_L from the FINAL top hand
  (stick_grip() after clear_hand), or the drawn shaft stretches.
- Every shader pow(): base must be >= 0 (clamp N.V; square with x*x, never
  pow(x, 2.0)) - test_gameplay_photo enforces the visor/cloth cases. Before
  the 4a28b7d fix every skater was a glowing ghost in Forward+.
- White blobs in Forward+ = NaN pixels bloomed by glow (gl_compatibility hides
  them). Bisect with glow off; kit_gear clamps vertex colour before pow() and
  guards albedo/normals - keep any new shader maths NaN-safe.
- The game ships Forward+; gl_compatibility renders (no SSIL/SSAO) make navy
  and undersides read near-black. Judge looks in Forward+ via lavapipe (see
  CLAUDE.md, ~80 s/shot); the hawkey env setup script installs the driver.
- Cloud container: if `godot` is missing, the session is not on the "hawkey"
  environment; `main` is only a README - the project is on
  prototype/skating-puck-lab.
- Full suite in the cloud: `JOBS=3 tools/run_tests.sh` took ~20 min (4 cores).
- capture_saves.gd --row=2 picks the save with choose_save() ("auto"), so the
  same row gives a fair before/after when save selection changes.
- Never run a test against `git stash`-ed old code when the test uses new
  constants: the script error makes headless Godot hang until the timeout,
  with your changes still stashed. Check old behaviour with a probe instead.
- Grey-looking gear: compare against a plain StandardMaterial3D on the same
  mesh and bisect the gear shader (build/ test copy) before changing art.
- Whole-body save poses (pad stack): pose upright in rig space and roll the
  rig - the save colliders follow because get_goalie_gear() includes
  rig.transform. Anything measured in the rig frame (lateral) must take the
  roll out again.
- test_clipping --report lists every offending pair; it caught boots in pads
  (straight shins) and hands meeting in the stack - fix the pose, not the test.
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
