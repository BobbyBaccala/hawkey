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

## Presentation and environment
- [x] Arena lighting pass: per-zone overhead spot/omni lights so the ice has soft pools of light and players get rim light; check gameplay-camera readability.
- [x] Ice detail (slice 1): skate cuts carved behind every skater that build up over the period, fresh sheet at each period start; brighter broadcast-white ice.
- [ ] Ice detail (slice 2): faint reflections of boards/glass in the ice and a glossier just-resurfaced look in the first minutes of a period.
- [x] Rink markings to NHL proportions: goal lines 11 ft from the end boards (goals moved with them), blue lines 25 ft from centre, end-zone spots 20 ft out, hash marks and L marks on end-zone circles, goaltender trapezoid.
- [ ] Rink width: the shell is 60 x 30 m (international width); an NHL sheet is 26 m (85 ft) wide with 28 ft corners. Narrowing touches board collision, AI clamps, cameras and the seating bowl, so do it as its own change with test_boards re-run.
- [ ] Goal nets: proper mesh netting with a back-bar shape, white padding at the base, and net ripple when the puck goes in.
- [ ] Benches and penalty boxes on one side with glass, doors and players seated, removing the bare stands there.
- [ ] Crowd reactions: cards bob/raise on goals and big saves; seat shimmer during play.
- [ ] Goal horn light and arena light flash on goals; jumbotron "GOAL" animation.
- [ ] Replay after goals: 4–6 second replay with an alternate camera and a "REPLAY" wipe.
- [ ] Faceoff presentation: camera cut closer for faceoffs; players set in proper faceoff stance.
- [ ] Intermission and final screens: period stats (shots, hits, faceoffs, PP) styled like the score bug.

## Players and animation
- [ ] Goalie save selection: pick butterfly, blocker, glove, pad-stack or poke by shot location; interruptible recovery.
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
