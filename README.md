# Hawkey — 0.7 sculpted equipment revision

Native Godot 4.6 PC hockey exhibition prototype. Uses a CC0 skinned human foundation with original hockey equipment, procedural skating and generated crowd/ice textures. This is an early exhibition prototype, not EA NHL-level photorealism or a complete regulation ruleset.

## Open this version
Download the ZIP from the **prototype/skating-puck-lab** branch, extract to a new folder, then import that folder's **project.godot** in Godot 4.6. Press F5. Opening an older downloaded folder will continue running the old build.

## Controller controls
Godot's native gamepad support is used; no separate plugin is required. Controller hardware has not been tested here.

| Input | Action |
| --- | --- |
| Left stick | Skate and aim shot; direction persists at neutral |
| Right stick | Move stick blade / stickhandle |
| RT / R2 | Hold to charge, release to shoot |
| LT / L2 | Shot elevation, from flat to lifted |
| RB / R1 | Assisted pass toward aimed teammate |
| Y / Triangle | Saucer pass |
| A / Cross | Switch skater |
| B / Circle; X / Square | Body check; poke |
| D-pad up/down; left/right | Forward line; defence pair |
| L3; R3; Start | Effort; stop; pause |
| F2 | Expanded controller help |

## New in 0.7
- Real-proportion goalie gear built as smooth 3D meshes: box-style pads with outer roll, knee/boot breaks and toe bridge; curled blocker board; deep-pocket catcher with T-trap; fibreglass cat-eye mask.
- Thigh rise hinges at the knee break and folds back in the butterfly; pad collision follows the visible pad.
- Goalie ready stance sits back with pads meeting at the knees, hands in front and the stick flat ahead of the skates.
- Skaters gain padded hockey pants, striped socks, shoulder pads, rounded gloves and new skates.
- Gear exports to assets/gear/*.glb for Blender via tools/export_gear.gd.
- Renders: docs/screenshots/goalie-closeup-v07.png, skater-closeup-v07.png, gear-gallery-v07.png, equipment-v07.png, gameplay-v07.png.
- Details and research sources: docs/GOALIE_GEAR.md.

## New in 0.6
- Lower active skater/goalie stances, forward knee flexion and grounded skate blades.
- Curved, thin stick blades; rectangular shafts, goalie paddle, corrected hand/gear assignment and closed gloves.
- Continuous IK-driven cloth sleeves, matte team kits and beveled pad shells.
- Independent pad, catcher, blocker, paddle, blade, torso and mask collision; transforms follow the visible gear.
- Butterfly pads rotate and seal at the ice rather than expanding an invisible wall.
- Different equipment rebound materials; front-pocket catch logic rejects rear glove hits.
- Steeper centred broadcast camera, neutral quieter ice and a smaller scoreboard.
- Actual engine PNGs: docs/screenshots/gameplay-v06.png, equipment-v06.png and goalie-closeup-v06.png.
- Implementation and limits: docs/GOALIE_GEAR.md.

## New in 0.5
- Removed puck height lock: gravity, airborne shots, saucer passes, spin/tumbling and physical rebounds.
- Puck-specific skate/body/pad/glove colliders replace rounded movement capsules for puck contacts.
- Shot-height prediction drives basic goalie pad/glove coverage; catches/covers whistle for a zone faceoff.
- Stick blade, shaft and hand targets follow the right stick; analog movement and disconnect pause.
- Shoulder/armpit gaps repaired by retaining the continuous skinned undershirt.
- Actual renders: docs/screenshots/gameplay-v05.png (live match) and flight-review-v05.png (explicitly labelled scripted shot fixture).
- Research and explicit production gaps: [SPORTS_GAME_RESEARCH.md](docs/SPORTS_GAME_RESEARCH.md).
- Player art remains provisional and below the requested EA NHL standard. No new motion-capture library is shipped.

## Match controls
| Input | Action |
| --- | --- |
| WASD / Shift / Ctrl | Skate / effort / stop |
| Mouse / hold-release LMB | Aim / charge and shoot |
| RMB | Pass toward aimed teammate |
| Space | Switch controlled skater |
| 1–4 | Request forward line |
| Q | Cycle defence pair |
| E / F | Poke / body check (illegal context can cause a minor) |
| L | Toggle automatic fatigue-based forward changes |
| C / wheel | Straight follow/full-rink camera / zoom |
| Escape / F1 | Pause / diagnostics |

## New in 0.4
- Full ten-skater exhibition scene, two goalkeepers and two visual officials.
- Three periods, clock, stoppages, faceoff setups, goals, end switching and match end.
- 18 fictional roster entries per side, manual/on-the-fly line changes and fatigue.
- Three contextual minor types with timers, queued minors, power-play strength and goal-release logic.
- Delayed goalkeeper tracking, prediction, butterfly/recovery poses, mask/gloves and directed rebounds.
- Camera has no lateral offset or roll.
- Actual video pose-extraction experiment rejected low-quality footage; no video-derived animation is shipped.
- Full implemented/absent feature list: docs/MATCH_STATUS.md.
- Actual in-engine screenshot: docs/screenshots/gameplay-v04.png.

## New in 0.3
- Replaced rounded body-part placeholders with a skinned 163-bone human mesh, original jersey, helmet/visor, skates/blades/laces and equipment.
- Bent-knee hockey stance, lateral push/recovery cycles, low skate lift, two-hand stick pose and push-to-glide blending when movement input stops.
- Generated photographic spectator artwork replaces empty block seats. Spectators use flat alpha-cutout cards in the 3D arena.
- Generated worn-ice texture integrated through a subtle surface shader.
- Asset source, CC0 provenance, preparation workflow and exact generation prompts: docs/ASSETS.md.

## Rebuilt in 0.2
- Two red goal frames with visible mesh netting, back/side collision and scoring at both ends.
- Rounded boards, yellow kickplate, glass/stanchions, seating and arena signage.
- Consistent blue/centre lines, goal lines, faceoff circles/dots and blue half-disc creases.
- Perspective camera with smooth follow, zoom and full-rink view.
- Articulated procedural skaters with helmets, jerseys, gloves, skates, sticks and stride animation.
- Both goalkeepers track puck angle and physically block/rebound pucks using simple pad-shaped colliders.
- Skaters collide with boards and other players; momentum turning, coasting and hard stops replace the original movement.
- Bounded damped puck control, flat charged shots, physical board/post rebounds, moving passing support, reception and switching.
- Cleaner practice HUD and finite synthetic impact sounds.

## Validation
Godot 4.6 Linux headless import and scene smoke tests pass.
Ten executable suites:
```
godot --headless --path . --script tests/test_simulation.gd
godot --headless --path . --script tests/test_lab.gd
godot --headless --path . --script tests/test_controls.gd
godot --headless --path . --script tests/test_animation.gd
godot --headless --path . --script tests/test_match_state.gd
godot --headless --path . --script tests/test_match.gd
godot --headless --path . --script tests/test_match_loop.gd
godot --headless --path . --script tests/test_controller.gd
godot --headless --path . --script tests/test_puck_flight.gd
godot --headless --path . --script tests/test_goalie_gear.gd
```
Tests cover ratings, deceleration, directional goal detection, two nets, rounded boards, perspective camera, high-speed board rebound, goal counting, reset/pause, goalkeeper contact/save, actual W/Ctrl input and stationary puck-control stability.

Rendered screenshots were inspected at 1728×1080 using Linux Mesa llvmpipe software rendering. This verifies appearance and framing, not Windows performance, physical controller compatibility or satisfying human gameplay feel. The imported human is a foundation with procedural equipment and posing; motion capture, photorealistic player textures, advanced skating transitions, sophisticated tactics, complete rules, GM and career are not implemented.

## Windows export
Install matching Godot 4.6 export templates, then Project > Export > Add > Windows Desktop. Export to a separate empty folder. Windows export/installation has not been validated here and no executable is supplied.

## Further work
See docs/DEVELOPMENT.md for architecture, remaining limitations and the production roadmap.
