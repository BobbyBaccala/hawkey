# Controller and simulation research — 0.5

Reviewed 19 October 2026. These are primary developer publications and engine documentation, not proof that Hawkey has reproduced their results.

## What the sources actually support

1. **Ubisoft La Forge, Introducing Learned Motion Matching (2020)**
   https://www.ubisoft.com/en-us/studio/laforge/news/6xXL85Q3bF2vEj76xmnmIu/introducing-learned-motion-matching
   Motion matching searches recorded poses using foot position/velocity, hip velocity and future trajectory/facing. Short transition blends, foot locking and IK polish the result. It only plays supplied motion; it does not invent absent combinations. Learned motion matching compresses an established motion system. It is not a way to recover production hockey animation from a low-resolution broadcast.
   **Hawkey implication:** acquire or record skating-specific motion first: push, glide, inside/outside edges, crossover, backward skating, pivot, stop, stickhandling, release and recovery. Annotate skate contacts and stick grips. Keep trajectory and facing separate from pose selection. Current code still uses procedural IK, not motion matching or a trained network.

2. **Ubisoft La Forge, DReCon (2019)**
   https://www.ubisoft.com/en-us/studio/laforge/news/VjEIwquaIyEZZSw5RZI0V/drecon-datadriven-responsive-control-of-physicsbased-characters
   Research combines data-driven animation with responsive physics-based character control. A plausible learned physical controller requires training data and training work.
   **Hawkey implication:** preserve responsive skating physics and use animation constraints to follow it; do not claim adding a shader or ragdoll reproduces this research. No DReCon controller is implemented here.

3. **EA, NHL 26 Gameplay Deep Dive (13 August 2025)**
   https://www.ea.com/games/nhl/nhl-26/news/nhl-26-gameplay-iceq2-deep-dive
   EA describes more than 80 new save animations, pose matching, recovery-interruptible consecutive saves and positioning tied to size/style. EA also describes NHL EDGE tracking data driving attributes/tendencies. These are EA's own product claims.
   **Hawkey implication:** goalies need save selection based on puck trajectory/height, physical equipment coverage and interruptible recovery, then a real save library. Version 0.5 adds basic height-dependent pad/glove positioning and physical rebounds/catches; it has neither EA's animation library nor tracking dataset.

4. **Godot 4.6, Controllers, gamepads, and joysticks**
   https://docs.godotengine.org/en/4.6/tutorials/inputs/controllers_gamepads_joysticks.html
   Godot already provides standard controller axes/buttons and deadzone handling; the engine uses SDL 3 on desktop for controller support.
   **Hawkey implication:** a separate controller plugin is unnecessary. A small native adapter implements radial deadzones, analog speed, trigger hysteresis, button edges and disconnect pause. Xbox-style and PlayStation-style labels are shown. Actual hardware compatibility and feel remain untested.

5. **Godot 4.6, RigidBody3D**
   https://docs.godotengine.org/en/4.6/classes/class_rigidbody3d.html
   The engine supports continuous collision detection and direct force integration. Frequent arbitrary transform changes can conflict with simulation.
   **Hawkey implication:** use a free rigid puck with gravity and CCD, launch velocity rather than a scripted flight path, separate movement capsules from puck colliders, and apply grounded drag in `_integrate_forces`. The puck is not height-locked. Resets/faceoffs intentionally reposition it. Stick possession still uses bounded velocity assistance rather than a fully physical flexible stick/blade model.

6. **Godot 4.6, CylinderShape3D**
   https://docs.godotengine.org/en/4.6/classes/class_cylindershape3d.html
   The engine documentation warns of known cylinder collision bugs. Hawkey therefore uses a 32-sided convex disk collider for the puck, with a 1 mm margin and solver penetration tolerance suitable for its small thickness. The rendered puck is still cylindrical.

## Implemented now

- Native controller-first match input: LS skating/shot direction, RS stickhandling, RT charge/release, LT elevation, RB pass, Y saucer, A switch, B check, X poke, D-pad line/pair requests, L3 effort, R3 stop, Start pause.
- Analog travel scales skating speed. Radial deadzone 0.18; RT press/release thresholds 0.18/0.08 suppress chatter.
- Stick blade, shaft, grip and two-hand IK use the same smoothed right-stick target as assisted puck control.
- Free vertical motion, gravity, spin/tumbling, elevated shots and saucer passes. AI calculates a low ballistic arc toward the upper net.
- Puck sees floor/boards/glass/net and dedicated flat skates, torso, pads, catcher/blocker colliders. It ignores the rounded movement capsules that caused artificial launches.
- Low-speed airborne pucks do not automatically attach to possession assistance. Goalkeepers select low/high coverage from an estimated intercept height, with basic cover/catch whistles and defensive-zone faceoff setup.

## What still prevents the requested visual standard

The player is still a generic CC0 human with procedural hockey kit and procedural poses. Better hand alignment does not replace production character art. Required work includes a hockey-specific clothed mesh with deformation-ready shoulders/hips, skin/fabric/normal/roughness textures, coherent gloves/skates, several LODs and validated animation retargeting. No AI-generated concept picture is passed off as gameplay. No proprietary EA source, models or motion have been imported.

The earlier 426×240 public skating-video extraction accepted 0 of 383 frames at its critical-joint quality threshold. That rejected experiment is documented in MOTION_CAPTURE.md. Footage cannot simply be overlaid onto a model to recover reliable 3D motion. Clean full-body high-frame-rate footage with calibrated views or licensed skating mocap is the next data dependency.

## Acceptance gates for subsequent production work

- Capture a skater close-up and full-rink play from the actual engine, at the same light/camera settings, before calling the models improved.
- Record a physical-controller session: drift, diagonal travel, partial triggers, device removal/reconnect, aim retention, stick reach, shot release latency. Synthetic tests are necessary but insufficient.
- Validate hockey motion with a knowledgeable skater: planted blades stay on the ice, edge changes/crossovers are distinct from running, hands stay on shaft, shots blend into recovery without snapping.
- Calibrate puck sliding, shot travel, rebounds and pad reactions against measured reference clips. Current coefficients are tunable prototype values, not empirically fitted hockey physics. No aerodynamic lift, realistic rolling resistance or flexible stick simulation is claimed.
- Validate goalie reach/reaction, rebounds, consecutive saves and covers across a grid of shot locations/heights. Current prediction ignores screens and deflections until the next update.
- Keep full 5v5, lines, clock and minors, but label the rules incomplete: offside, icing and delayed penalties still need implementation.
