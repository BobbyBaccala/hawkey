# Hawkey — 0.2 arena and skating rebuild

Native Godot 4.6 PC hockey practice prototype. Procedural 3D models and animation remain placeholders; this is not production-quality character art or a complete match.

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
Three executable suites:
```
godot --headless --path . --script tests/test_simulation.gd
godot --headless --path . --script tests/test_lab.gd
godot --headless --path . --script tests/test_controls.gd
```
Tests cover ratings, deceleration, directional goal detection, two nets, rounded boards, perspective camera, high-speed board rebound, goal counting, reset/pause, goalkeeper contact/save, actual W/Ctrl input and stationary puck-control stability.

Rendered screenshots were inspected at 1440×900 using Linux Mesa llvmpipe software rendering. This verifies appearance and framing, not Windows performance, controller behavior or satisfying human gameplay feel. Production models, motion capture, full team AI, complete rules, GM and career are not implemented.

## Windows export
Install matching Godot 4.6 export templates, then Project > Export > Add > Windows Desktop. Export to a separate empty folder. Windows export/installation has not been validated here and no executable is supplied.

## Further work
See docs/DEVELOPMENT.md for architecture, remaining limitations and the production roadmap.
