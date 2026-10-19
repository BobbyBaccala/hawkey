# 0.6 stance, sticks and goalie gear

## Changes

The old goalie had one broad collision box below the torso. Pads and gloves were posed separately, so a save could occur where no equipment was visible. Version 0.6 removes that wall. Each pad, catcher, blocker, goalie blade, paddle, chest and mask now has an individual puck-facing body. `SkaterVisual.get_goalie_gear()` supplies both shape dimensions and the actor-local transforms derived from the rendered parts. `sync_goalie_contacts()` applies those in the simulation tick. The movement body remains separate and the puck ignores its collision layer.

The pads have broad flat faces, tapered/beveled shells, bindings and knee rolls. They follow the shin direction in the ready stance and rotate outward during the butterfly, with lower-edge clearance enforced against the ice. Their collision approximation is still a box around each pad, so clipped corners can contact slightly outside the bevel. There is no full-width invisible pad barrier.

Equipment uses different rebound coefficients: pad 0.20, chest 0.08, blocker 0.48, catcher 0.02, blade 0.40, paddle 0.35, mask 0.30. The engine combines these with puck material behavior. These values are prototype tuning, not measurements of actual gear. Contact normals and equipment motion resolve outgoing direction/height; no scripted flat rebound replaces them.

A moderate-speed front entry into the catcher pocket can whistle play dead. Rear entries and edge contacts do not automatically become catches. Slow loose pucks in close can still trigger the separate basic cover logic. Shot-height-driven hand reach is rate-limited rather than snapping upward instantly.

Players and goalies start with lower hips, bent knees and forward torso inclination. Goalies keep their hands forward, with the blocker on the stick hand and the catcher on the opposite side. Open source hand and foot surfaces are hidden under closed equipment gloves and original skates. Skate blade bottoms now rest at the ice plane instead of floating roughly 5 cm above it. Continuous curved cloth sleeves follow the same shoulder/elbow/wrist IK targets as the skeleton; they are procedural surfaces, not a new motion-capture animation or cloth simulation.

Sticks use thin curved blade meshes with rounded-up toes and narrow rectangular shafts. Skater blades are 0.28 m long and 9 mm thick, goalies 0.36 m and 13 mm; these are chosen game-model dimensions, not a claim of certified regulation measurements. The heel joins the shaft and the blade stays on the ice. Goalies now have a distinct paddle. Field-player stickhandling still uses bounded puck assistance; only the goalie blade/paddle have dedicated physical stick collision in this revision.

Presentation uses a steeper centred perspective camera, a smaller scoreboard, softer shadows and lower-contrast neutral ice texture. The supplied EA NHL screenshot was a visual reference only; no EA artwork, models, code or motion were imported.

## Verification

Ten executable headless suites pass on Godot 4.6 Linux. The added goalie suite checks active stance height, grounded skate geometry, pad rotation and ice clearance, shared visual/collision transforms, independent equipment materials, real puck contact against both pads and the blocker, an unobstructed shot outside the pad silhouette, front-pocket catch stoppage and rejection of rear glove catches. Animation tests also check knee flexion, blade thinness and stick lie through stickhandling extremes.

`tools/capture_equipment.gd` renders a controlled four-pose review; `--goalie-closeup` renders the ready/butterfly close-up. These are explicitly pose-review fixtures, not live gameplay. `--capture` on the main scene renders a live 5v5 match. PNGs are in docs/screenshots and contain actual engine geometry/lighting.

## Remaining limitations

The generic base body, procedural garments/equipment, simple facial materials and procedural motion still fall short of the requested EA NHL production standard. The sleeves are a lightweight curved envelope around IK targets, without cloth dynamics or captured folds. Gloves do not simulate finger articulation. The goalie equipment is kinematic rather than a physically articulated body, and pad foam/net deformation is absent. Rebound calibration, full save selection/recovery animations, screen recognition, post integration, skate-edge locomotion, goalie styles and human playtesting remain outstanding. Physical controller hardware and Windows performance are untested.
