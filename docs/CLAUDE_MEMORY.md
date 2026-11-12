# Claude project memory — Hawkey

Read this first each session; update it before finishing (`/update-memory`).
Keep it short: current state, decisions, gotchas, next steps. History lives in
the run log at the bottom of `docs/BACKLOG.md`.

_Last updated: 2026-11-12 (cloud session, branch prototype/skating-puck-lab;
the butterfly-wall work was merged here by the owner's go-ahead)._

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
- Splits (desperation save, SPLITS_* consts, kinds splits_left/right): picked
  by choose_save() for low shots past |x| > 1.0 m; hips at 0.32 m, both legs
  straight out along the ice, pads face-on, stick hand down. Not a
  knees-down save (butterfly stays 0; match.gd unchanged). Pad colliders
  cover ~1.7 m of the goal mouth.
- Pad stack (STACK_* consts, kinds stack_left/right): choose_save(x, h,
  slide, current) picks it for a low shot wider than 0.62 m when the goalie
  already slides toward it > 1.6 m/s, and keeps it once started (match.gd
  passes visual.lateral + visual.save_kind). Legs-together pose in rig space,
  then the whole rig rolls 1.48 rad, slides 0.95 m to the post, lifts 0.31 m:
  ~64 cm pad wall from the ice. stack_roll is removed from `lateral`.
- Gloves are worn on the arms (place_goalie_glove(), align_pair(), consts
  CATCHER_*/BLOCKER_*): pocket/board face the shooter, catcher upright until
  it reaches (glove save, glove-side stack) then along the forearm, blocker
  fist exactly on the drawn shaft (stick_heel_at() shared with update_stick).
  Calibrated from the ready stance (unchanged).
- Pads: brighter white (#f7f9fb), white-dominant graphics (thin knee/boot
  accent lines, team bands at the break and top of the rise). kit_overhead()
  now darkens only real undersides (normal > ~17 deg down) - it was greying
  every standing pad face (shared with the cloth shader).
- Glove backs: blocker board back off-white, tan palm-leather fist (PALM,
  PALM_DARK), kit strap, rounded cuff (gear_builder.gd add_cuff()); catcher
  cuff is a sleeve lofted from inside the mitt base with the cheater panel on
  its front.
- Save motion: set_save() steps each weight as a critically damped spring
  (SAVE_SNAP 24 in, SAVE_RECOVER 10 out): snap + ease, half-way timing as
  the old linear ramps. tools/capture_save_motion.gd measures it.
- `butterfly` is the match's linear command (read back unchanged); poses and
  pad colliders use butterfly_posed = smoothstep(butterfly) (gentle start
  and landing, quicker middle). Drawn pad cancels the collision pad's
  ice-seal lift along its thickness; ankle strap raised to y -0.25.
- Goalie pants: kit colour with an accent stripe and white piping
  (pants_leg(..., piped)); reference photos said bright team colour.
- Eyes on the puck: goalie_look() turns/tips the head (and mask collider)
  toward save_target, weighted by the save springs, LOOK_* neck limits; on a
  glove-side pad save the catcher goes out over the lead pad.
- Goalie sleeves carry the navy yoke over the cap (kit_cloth sleeve_yoke,
  GOALIE_SLEEVE_YOKE 0.10) - no red spike at the armhole when the arm rises.
- Splits stick lies flat across the five-hole (SPLITS_GRIP_Y, splits_blade():
  blade always across from the blocker hand to the glove side of the hips).
- Catcher back: team-colour backhand panel over the finger half, accent
  piping edge, white stall-break lines.
- Goalie stick: assets/goalie_stick.gdshader paints a two-tone paddle (kit
  upper with accent pinstripe, white lower, kit heel band) over the bake.
- Pad stack "seam" is the ~6 cm V groove between the pads' rounded outer
  rolls (measured at the face), as on real stacks - closing it needs the
  pads to overlap; legs are already edge to edge (bounding boxes touch).
- Pad stack hands: the top hand reaches over the stack on both sides
  (catcher on a glove-side stack, blocker + stick on a blocker-side one).
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

Tests: 47 suites; last full run 47/47 at d0d8ff6 (2026-11-12).

## Open defects / next steps (goalie first)
0. Owner 2026-11-12: gear believability and save animations are the top
   priority. Forward+ review (5992020): pads read white, hot-spots fixed.
   Next: standing pads
   still a little grey (vertical faces get little overhead light).
1. Goalie saves slice 2c: poke check on close carriers, post-save
   freeze/rebound control.
   Polish: stack/splits have no dive motion (the save weight
   blends the pose in ~0.15 s - slowing it would weaken save coverage).
2. Butterfly polish: 6 mm shaded seam between the two rises; knee-stack ends
   of the lower pads are ~14 cm apart under the rises; rise top still moves
   9.0 cm/frame mid-drop (inherent to the 6/s drop; knee 5.9).
3. Skaters: boxy shoulders still, single face mesh (add variants), number font
   is block (backlog "Blender kit, pass 2").

## Decisions
- 2026-11-07: downloaded models/brands allowed with logos, names and signatures
  removed; credits in assets/CREDITS.md.
- 2026-11-12: EA NHL screenshots/video are allowed as visual reference;
  files ripped from EA games (or any commercial game) are still not used.
- 2026-11-07: PLAY NOW is the only mode.
- 2026-11-12: cloud sessions use the personal "hawkey" environment; its setup
  script installs Godot 4.6.2 to /usr/local/bin/godot and runs the import.
  Owner 2026-11-12: Claude may merge finished, fully tested work into
  prototype/skating-puck-lab and push it.
- Goalie visuals may differ from the save collision proxies; keep the
  proxies' behaviour identical unless gameplay is the task (compare
  `get_goalie_gear()` at sampled poses before/after).

## Gotchas
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
