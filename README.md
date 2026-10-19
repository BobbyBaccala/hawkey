# Hawkey — 0.4 five-on-five exhibition

Native Godot 4.6 PC hockey exhibition prototype. Uses a CC0 skinned human foundation with original hockey equipment, procedural skating and generated crowd/ice textures. This is an early exhibition prototype, not EA NHL-level photorealism or a complete regulation ruleset.

## Open this version
Download the ZIP from the **prototype/skating-puck-lab** branch, extract to a new folder, then import that folder's **project.godot** in Godot 4.6. Press F5. Opening an older downloaded folder will continue running the old build.

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
Seven executable suites:
```
godot --headless --path . --script tests/test_simulation.gd
godot --headless --path . --script tests/test_lab.gd
godot --headless --path . --script tests/test_controls.gd
godot --headless --path . --script tests/test_animation.gd
godot --headless --path . --script tests/test_match_state.gd
godot --headless --path . --script tests/test_match.gd
godot --headless --path . --script tests/test_match_loop.gd
```
Tests cover ratings, deceleration, directional goal detection, two nets, rounded boards, perspective camera, high-speed board rebound, goal counting, reset/pause, goalkeeper contact/save, actual W/Ctrl input and stationary puck-control stability.

Rendered screenshots were inspected at 1440×900 using Linux Mesa llvmpipe software rendering. This verifies appearance and framing, not Windows performance, controller behavior or satisfying human gameplay feel. The imported human is a foundation with procedural equipment and posing; motion capture, photorealistic player textures, advanced skating transitions, sophisticated tactics, complete rules, GM and career are not implemented.

## Windows export
Install matching Godot 4.6 export templates, then Project > Export > Add > Windows Desktop. Export to a separate empty folder. Windows export/installation has not been validated here and no executable is supplied.

## Further work
See docs/DEVELOPMENT.md for architecture, remaining limitations and the production roadmap.
