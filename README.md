# Hawkey — skating and puck laboratory

Early native PC hockey simulation prototype, built with Godot 4.6. This is a practice laboratory with procedural placeholder art, not a finished match or a commercial-quality simulation.

## Run
1. Install Godot 4.6 standard edition.
2. Clone this branch or download its ZIP from GitHub.
3. Import project.godot, then press F6/F5 to play.
4. WASD skate, Shift increases effort, mouse aims, hold/release left mouse shoots.
5. Right mouse passes to the stationary partner who returns nearby loose pucks.
6. R resets the puck, Escape pauses, mouse wheel zooms, F1 toggles debug.
7. Keys 1 and 2 compare 55/85 skating ratings.

## What is implemented
- Elevated 3D rink, physical puck, boards, posts and solid net sides/back.
- Fixed 120 Hz skating with acceleration, momentum, effort and attribute-based speed.
- Assisted stick control using a velocity spring; shots release the physical puck.
- Charged flat shots, assisted partner passes, front-mouth goal counting.
- Practice HUD, pause, zoom, reset, velocity diagnostics and synthetic event sounds.

## Validation
Godot 4.6 Linux headless import and 300-frame scene smoke test passed.
Run deterministic checks:
`godot --headless --path . --script tests/test_simulation.gd`

Tests cover rating effects, coasting deceleration, front entry and back/wide/high rejection.
Scene integration tests also pass for a fast board rebound, one goal per front shot, reset and pause.
Run: `godot --headless --path . --script tests/test_lab.gd`

Rendered visual QA is blocked by the lack of a display server. Interactive feel, Windows installation, controllers and frame-rate targets are **not validated**.

## Windows build
Open Project > Export > Add > Windows Desktop. Install matching Godot 4.6 export templates when prompted, then export to an empty directory outside this repository. No Windows executable is supplied in this milestone. See https://docs.godotengine.org/en/4.6/tutorials/editor/command_line_tutorial.html for CLI export.

See docs/DEVELOPMENT.md for architecture, scope, next milestones and known issues.
