# 0.8 clipping pass and proportions

- New `tests/test_clipping.gd` samples the surface of every gear piece and checks whether it lies more than 8 mm inside another piece's closed mesh. It covers seven goalie poses (ready, a save reach, and each quarter of the butterfly drop) and thirteen skater poses (stickhandling extremes and a full stride cycle). Contact is allowed only where it is designed: hands holding the stick inside the gloves, socks tucked into skates and under pants, and the stick's own joints. `--report` lists offending pairs. The pass started at 62 overlaps and now has 0.
- Pads now rest on the skate with the toe cap and blade showing below them, as real pads do. The boot channel stands off the laces, and the calf wing and straps stay above the boot.
- Thigh rises lean out toward the hips when standing. In the butterfly they fold along the thighs and compress where they meet, rather than crossing.
- Mid-drop, the skates turn out early and the knees flare slightly, so the pads never pass through the skates or each other.
- The stick and blocker sit in front of the pads, and the skater's bottom hand rides the shaft clear of the pants.
- Skaters stand with hips about 0.80 m high and more forward lean, instead of a deep squat. The goalie sweater is about 0.62 m across the chest protector instead of a barrel.

# 0.7 sculpted equipment and active stances

## Research basis
Shapes and sizes follow published goaltender equipment limits rather than guesses:
- Leg pads: 28 cm (11 in) maximum face width, about 97 cm (38 in) maximum length, 27 cm maximum depth from face to inner knee; box-style pads with a flat face and square inner edge keep the face upright in the butterfly (IIHF measurement standards; Wikipedia, Ice hockey goaltending equipment).
- Blocker board: 20.5 x 38.5 cm, with a raised thumb-protection sidewall; the top of the board curves toward the shooter.
- Catcher: about 114 cm perimeter, 46 cm from the heel to the top of the T-trap, deep pocket with a 60-90 degree break.
- Goalie stick: blade about 8.9 cm (3.5 in) tall, paddle 64-71 cm long.
- Ready stance: feet slightly wider than the shoulders, knees bent, hands in front of the body, stick flat on the ice in front of the skates with the hand at the top of the paddle. Butterfly: knees together, pads flared to seal the ice, gloves low and in front (Hockey Alberta goaltender guide).

## What changed
- New `scripts/gear_builder.gd` models all equipment as lofted, smoothly shaded meshes with painted team graphics: box-style leg pads (flat pillowed face, outer roll, knee and boot breaks, toe bridge over the skate, knee stack, calf wing, straps), a blocker with a curled board, thumb wall, palm and cuff, a catcher with a deep pocket, finger and thumb rolls, T-trap lacing and cuff, a fibreglass goalie mask with a protruding chin and cat-eye cage, skates with holders and steel, rounded player gloves, padded hockey pants and striped socks.
- Pads ride the shin: +Y follows ankle-to-knee, the face looks at the shooter, and the thigh rise is a separate piece hinged at the break above the knee. In the butterfly it folds back along the thigh, so the two pads meet at the knees instead of overlapping.
- Pad collision now covers the visible pad: the whole pad when standing and the shin-to-knee section once the thigh rise folds.
- Goalie stance sits back: hips behind the heels, shins at roughly 25 degrees, knees in so the pads meet edge to edge, chest forward, elbows in. Catcher open at the hip, blocker at the top of the paddle, stick blade flat about half a metre in front of the skates, shaft running past the hand.
- Goalie sweater and sleeves are bulkier over the chest protector and arm floaters; skaters gain shoulder pads.
- The base body's shorts and socks are hidden where the new pants and sock shells cover them.
- `tools/export_gear.gd` writes every piece to `assets/gear/*.glb` for refinement in Blender (File > Import > glTF 2.0; colours are vertex colours).
- `tools/capture_gear.gd` renders the equipment on its own; `tools/capture_equipment.gd --skater-closeup` renders a skater close-up.

## Still missing
All equipment is generic and unbranded. It is procedural geometry rather than hand-sculpted, textured production art, so it lacks fabric texture, stitching relief and wear. Animation is still procedural posing, not motion capture. Glove fingers do not articulate, and pads do not deform on impact.

---

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
