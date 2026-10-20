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
- [ ] Ice detail: subtle skate-scratch decal/shader that builds up over the period, faint reflections of boards, resurfaced look at period start.
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
