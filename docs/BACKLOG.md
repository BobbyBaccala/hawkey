# Hawkey improvement backlog

Worked through by an automated session every 2 hours. Each run takes the
**first unchecked item**, finishes it (or a clearly useful slice of it), ticks
it, and adds a line to the run log at the bottom. Goal: look and feel closer to
EA's NHL games, within what code and free/licensed assets allow.

Rules for every run:
- Never import EA (or other commercial game) code, art, audio or files, or
  anything from recompiled/decompiled games. Real brands and NHL/club logos
  stay out; invented names only.
- Never commit files from `assets/mixamo/` (Adobe forbids redistributing them).
- All test suites in `tests/` must pass before pushing; add a test when a change
  adds behaviour. Render screenshots and look at them before calling it done.
- Keep a change reversible and focused; if an item is too big, split it here.
- If an item needs the owner (filming, scanning, buying assets), skip it and
  note why in the log.
- Another agent (Codex/ChatGPT) works on game modes hourly at about :45,
  on its own branches (e.g. `codex/game-modes`). Always fetch before starting
  and before pushing; rebase rather than overwrite, and keep changes to shared
  files (match.gd, lab.gd) small and well-described.

## Presentation and environment
- [x] Arena lighting pass: per-zone overhead spot/omni lights so the ice has soft pools of light and players get rim light; check gameplay-camera readability.
- [x] Ice detail (slice 1): skate cuts carved behind every skater that build up over the period, fresh sheet at each period start; brighter broadcast-white ice.
- [x] Ice detail (slice 2): faint reflections of boards/glass in the ice and a glossier just-resurfaced look in the first minutes of a period.
- [x] Ice detail: skate cuts and wear also over painted lines, dots and the centre logo (they are separate meshes above the ice today).
- [x] Rink markings to NHL proportions: goal lines 11 ft from the end boards (goals moved with them), blue lines 25 ft from centre, end-zone spots 20 ft out, hash marks and L marks on end-zone circles, goaltender trapezoid.
- [x] Rink width: the shell is 60 x 30 m (international width); an NHL sheet is 26 m (85 ft) wide with 28 ft corners. Narrowing touches board collision, AI clamps, cameras and the seating bowl, so do it as its own change with test_boards re-run.
- [x] Goal nets: proper mesh netting with a back-bar shape, white padding at the base, and net ripple when the puck goes in.
- [ ] Benches and penalty boxes on one side with glass, doors and players seated, removing the bare stands there.
- [ ] Crowd reactions: cards bob/raise on goals and big saves; seat shimmer during play.
- [ ] Goal horn light and arena light flash on goals; jumbotron "GOAL" animation.
- [ ] Replay after goals: 4–6 second replay with an alternate camera and a "REPLAY" wipe.
- [ ] Faceoff presentation: camera cut closer for faceoffs; players set in proper faceoff stance.
- [ ] Intermission and final screens: period stats (shots, hits, faceoffs, PP) styled like the score bug.

## Players and animation
- [x] Skating stride and arm clearance (owner feedback): one leg at a time - glide on a plant foot under the hip, push out to the side and back on the inside edge, low recovery back under the body; weight shifts over the glide leg; staggered (not side-by-side) coasting stance. Right-handed grip fixed (right hand is the bottom hand, so no arm reaches across the chest); elbows solved around the torso and gloves kept outside the jersey.
- [ ] One hand off the stick: when skating hard without the puck, the top hand lets go and that arm swings with the stride.
- [ ] Handedness per player (left/right shot) from the roster, mirroring the grip, blade side and shot animations.
- [x] Goalie save selection (slice 1): butterfly, glove, blocker, body block and left/right pad extensions picked from the shot's predicted crossing point; per-save blend weights so a new read interrupts the recovery; gear colliders move with the save.
- [x] Goalie pad and glove models (pass 1): painted anti-aliased graphics textures (pads, blocker, catcher cheater) instead of per-triangle colours; pad outer roll, stitched breaks and face stitching; blocker finger sidewall; catcher with deep pocket under the T, thick finger roll, kit-tipped thumb, laced T-trap web and a flat cheater cuff.
- [ ] Goalie gear pass 2 (owner offered reference photos of real gear - ask for them): match silhouettes to the photos, add knee-landing blocks and inner-knee wedges, catcher back/wrist strap, blocker palm detail.
- [ ] Goalie saves (slice 2): pad stack (stacked pads, sliding on the side) for desperation saves, poke check on close carriers, and a post-save freeze/rebound-control beat.
- [ ] Shooting animations: wrist-shot and slapshot wind-up/follow-through driven by charge; stick flex look.
- [ ] Crossovers and tight turns: leg crossover cycle when turning at speed; lean into turns.
- [ ] Hockey stops: snow spray particles and a skid pose when braking hard.
- [ ] Body checks: hit reaction lean/stumble, glass rattle when near boards.
- [ ] Jersey detail: numbers on sleeves and back via proper decals, team stripe on socks matching jersey, nameplate polish.

## Gameplay feel
- [ ] Passing feel: pass speed by distance, receiver stick reach, saucer passes clearing sticks.
- [ ] AI positioning: forwards support, defence gap control, back-checking.
- [ ] Offside and icing rules with linesman whistle and banner.
- [ ] Shot variety: one-timers, backhands, deflections off sticks and bodies.

## Audio
- [ ] Original synthesized arena audio: skate carves, puck on stick, boards thud, crowd bed that swells on chances, goal horn.

## Run log
- 2026-10-20 — Backlog created after v0.10 (cameras, arena, broadcast UI).
- 2026-10-20 — Arena lighting pass: 8 shadowless overhead spot pools (scripts/arena_lighting.gd) replace the near-zero omnis; ambient/sun lowered so pools read; two low side rim lights masked off the arena layer (light players only). New tests/test_lighting.gd. Screenshot: docs/screenshots/arena-lighting-auto-20261020-1456.png
- 2026-10-20 — Owner feedback pass: rink markings to NHL proportions (goal lines 11 ft from boards with goals moved, blue lines 25 ft, end spots 20 ft out, hash + L marks, trapezoid; gameplay reads Arena.GOAL_LINE), brighter broadcast-white ice, skate cuts carved behind every skater and cleared each period (scripts/ice_marks.gd), --capture-time=<s> capture option. Boards/glass and scoreboard left as they are; test_boards passes. New tests/test_ice.gd. Screenshot: docs/screenshots/rink-markings-ice-auto-20261020-1548.png
- 2026-10-20 — Ice detail slice 2: ice shader adds a faint mirrored band of the dashers and a soft blue-grey smear of glass/stands near the boards (fades where the ice is cut up); ice_marks.gd tracks time since flood and drives a `fresh` gloss (glossier, slightly darker, more specular) that dries over 90 s after each period's resurface. A parallel duplicate of slice 1 from this run was dropped in favour of ice_marks.gd. tests/test_ice.gd extended. Screenshot: docs/screenshots/ice-reflection-auto-20261020-1600.png
- 2026-10-20 — Skate cuts rebuilt (merged on top of slice 2: reflections and flood gloss kept) after owner said they looked rough: anti-aliased sub-texel strokes (no beads or stair steps) at 2.8 cm/texel, mipmapped so distant cuts read as soft wear, plus a separate wear-haze channel for high-traffic areas; ice base exposure lowered so it no longer clips to pure white and cuts and light pools stay visible. New tools/capture_ice.gd (fast-forwards live play, renders close + wide). Screenshots: docs/screenshots/skate-cuts-close-auto-20261020-1606.png, docs/screenshots/skate-cuts-wide-auto-20261020-1606.png
- 2026-10-20 — Owner feedback: procedural hockey stride (stride_foot(): 62% stance with glide then lateral/back push, toe-out and inside-edge roll; recovery low and back under the hip; hip sway over the glide leg; shoulder counter-turn) and arm/torso clearance (right hand is bottom hand; IK elbow searched around the arm axis to keep sleeves out of the jersey; gloves pushed to the jersey surface; shoulders open toward the blade). New tests/test_stride.gd and tools/capture_stride.gd. Screenshots: docs/screenshots/stride-review-auto-20261020-1627.png, docs/screenshots/stride-ingame-auto-20261020-1627.png
- 2026-10-20 — Owner feedback: smoother stride (all foot/hip curves eased, soft-max blends, no pops; tested by second-difference limits) with the boot following the shin - rolls onto its inside edge with the leg, toe flicks at toe-off with the heel peeling up, toe-up before landing; goalie save selection with glove, blocker and pad-extension poses plus rigid goalie stick. New tests/test_goalie_saves.gd, tools/capture_saves.gd; test_clipping covers the save poses. Screenshots: docs/screenshots/goalie-saves-auto-20261020-1640.png, docs/screenshots/stride-ankle-auto-20261020-1640.png
- 2026-10-20 — Skate cuts over the paint: every painted marking (red/blue/goal lines, circles, hash and L marks, spots, trapezoid, crease) now uses a shared paint shader (arena.gd paint()) that samples the skate-cut map by world position, so scratches and wear haze frost straight across the paint; the centre emblem and HAWKEY text get a transparent wear layer (EmblemWear). Flood gloss reaches the paint too. lab.gd now calls arena.set_cut_map(). tests/test_ice.gd extended. Screenshot: docs/screenshots/paint-wear-auto-20261020-1646.png
- 2026-10-20 — Owner feedback: goalie pads and gloves rebuilt (gear_builder.gd Graphic painter + UVs; textures cached per colourway). Pad knee spacing widened slightly so the new outer rolls don't touch. New tests/test_gear_graphics.gd. Screenshots: docs/screenshots/goalie-gear-auto-20261020-1658.png, docs/screenshots/gear-gallery-auto-20261020-1658.png
- 2026-10-20 — Rink narrowed to NHL width: 85 ft (25.9 m) with 28 ft corner radii, from arena.gd constants HALF_WIDTH / CORNER_RADIUS / CORNER_START that boards, ice, shaders, cut map (ice_marks.gd), puck ice plane, AI/official/bench clamps, broadcast camera, seating bowl, crowd cards and light pools now read. Full-rink camera was black (looking at the ceiling from above): ceiling is now a back-culled downward plane and trusses/lamps/jumbotron sit on a RIGGING_LAYER that only that camera hides. test_boards (new corner start points), test_ice and test_lighting extended. Screenshots: docs/screenshots/rink-width-full-auto-20261020-1755.png, docs/screenshots/rink-width-ice-auto-20261020-1755.png
- 2026-10-20 — Goal nets rebuilt (new scripts/goal_net.gd, arena.goal() uses it): NHL-style frame with a rounded base frame 40 in deep and an upper back bar 22 in behind the crossbar, netting hung between them (top shelf, side panels, sloping back) as one mesh with an anti-aliased diamond-mesh shader that fades to a soft veil at distance, white foam padding inside the base frame, and collision slabs that follow the netting (posts/crossbar unchanged). The arena watches the puck (lab.gd sets arena.puck) and a sharp velocity change in or against a net starts a vertex-shader ripple (bulge + ring wave, decays over ~1 s). New tests/test_goal_net.gd and tools/capture_net.gd. Screenshots: docs/screenshots/goal-net-side-auto-20261020-1904.png, docs/screenshots/goal-net-ripple-auto-20261020-1904.png
