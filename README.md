# Hawkey — 0.3 skinned players, skating and crowd

Native Godot 4.6 PC hockey practice prototype. Uses a CC0 skinned human foundation with original hockey equipment, procedural skating and generated crowd/ice textures. This is still a practice prototype, not EA NHL-level photorealism or a complete match.

## Open this version
Download the ZIP from the **prototype/skating-puck-lab** branch, extract to a new folder, then import that folder's **project.godot** in Godot 4.6. Press F5. Opening an older downloaded folder will continue running the old build.

## Controls
| Input | Action |
| --- | --- |
| WASD | Skate |
| Shift | Increased effort |
| Ctrl | Hockey stop |
| Mouse | Aim |
| Hold/release left mouse | Charge/shoot |
| Right mouse | Pass to partner |
| Space | Switch skater |
| C | Close perspective / full rink |
| Mouse wheel | Zoom |
| R | Reset player and puck |
| Escape | Pause |
| F1 | Diagnostics |
| 1 / 2 | Compare skating ratings |

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
Four executable suites:
```
godot --headless --path . --script tests/test_simulation.gd
godot --headless --path . --script tests/test_lab.gd
godot --headless --path . --script tests/test_controls.gd
godot --headless --path . --script tests/test_animation.gd
```
Tests cover ratings, deceleration, directional goal detection, two nets, rounded boards, perspective camera, high-speed board rebound, goal counting, reset/pause, goalkeeper contact/save, actual W/Ctrl input and stationary puck-control stability.

Rendered screenshots were inspected at 1440×900 using Linux Mesa llvmpipe software rendering. This verifies appearance and framing, not Windows performance, controller behavior or satisfying human gameplay feel. The imported human is a foundation with procedural equipment and posing; motion capture, photorealistic player textures, advanced skating transitions, full team AI, complete rules, GM and career are not implemented.

## Windows export
Install matching Godot 4.6 export templates, then Project > Export > Add > Windows Desktop. Export to a separate empty folder. Windows export/installation has not been validated here and no executable is supplied.

## Further work
See docs/DEVELOPMENT.md for architecture, remaining limitations and the production roadmap.
