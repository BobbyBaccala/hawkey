# Product and technical notes

Current exhibition implementation and limits: MATCH_STATUS.md. Video workflow: MOTION_CAPTURE.md.

## Product
Original premium PC hockey simulation. Primary input: mouse and keyboard; overhead 3D view. Fictional identities, authentic hockey decisions. Practice quality precedes match and management scope.

## Engine decision
Godot 4.6 standard/GDScript was selected because its editor and headless runtime actually execute in this environment. It supports a native desktop project and reproducible simulation tests without a proprietary engine installation. Unity/Unreal are not installed here. This is a capability decision, not a claim that Godot delivers lifelike animation without specialist work.

## Architecture
- project.godot: native project and 120 Hz timing.
- main.tscn: five-on-five exhibition entry point; scripts/match.gd extends the reusable rink/input/puck laboratory.
- scripts/match_state.gd: authoritative match clock, phase, score and penalty eligibility.
- practice.tscn: earlier isolated laboratory entry point.
- scripts/lab.gd: character/puck simulation, practice partner, goalkeeper tracking, cameras, input, HUD and finite event sounds.
- scripts/arena.gd: rounded rink, markings, two goals, glass and seating.
- scripts/goal_net.gd: NHL-style goal (rounded base frame, upper back bar, white base padding), diamond-mesh netting shader with impact ripple, netting collision slabs. The arena calls impact() when the puck's velocity changes sharply in or against a net.
- scripts/arena_lighting.gd: per-zone overhead spot pools and player rim lights (arena meshes sit on visual layer 2, which rim lights skip).
- scripts/goal_celebration.gd: goal presentation, one entry point celebrate(end_sign, team_color, team_name) called by match.gd on a goal: red rotating beacon on a bracket behind each net's end glass (omni glow + sweeping spot, ~4 s), a decaying warm counter-phase pulse of the overhead pools and team-tinted LED ribbons (~3 s), and a jumbotron GOAL then team-name animation (~4 s) while arena_dressing.gd holds score updates (scoreboard_hold) and restores them after. Render review: tools/capture_goal_light.gd.
- scripts/ice_marks.gd: skate-cut map (one texel ~4 cm) scored by every blade on the ice and sampled by the ice shader and by the paint shader on every marking/emblem (arena.gd paint(), set_cut_map()); cleared at each period.
- Rink size is NHL: arena.gd HALF_WIDTH (85 ft sheet), HALF_LENGTH (60 m), CORNER_RADIUS (28 ft); everything that depends on the rink width reads these rather than literals. Overhead rigging is on arena_lighting.gd RIGGING_LAYER, hidden by any camera above RIGGING_CLEARANCE over the sheet (arena_lighting.gd camera_cull_mask()).
- Rink markings use NHL proportions from constants in arena.gd (GOAL_LINE, BLUE_LINE, END_DOT_Z, DOT_X...); gameplay code reads Arena.GOAL_LINE rather than literal distances.
- scripts/skater_visual.gd: CC0 skinned human foundation, original kit and two-bone lateral push/glide posing.
- scripts/crowd.gd: alpha-cutout generated crowd artwork in seating rows.
- assets/: shipped human mesh, generated crowd/ice textures and uniform shader; provenance in docs/ASSETS.md.
- scripts/skating.gd: deterministic velocity update and directional goal-mouth crossing.
- tests/test_simulation.gd: executable regression scenarios.
- data/roster.schema.json: future roster interface, currently unused by laboratory.

Physics owns puck movement. Player motion is an explicit velocity model. Assisted possession is a proximity velocity spring, not a teleport or permanent parent-child attachment. Rendered geometry is separate from skating velocity. Goal detection uses interpolation across the mouth plane. Boards/posts use static collision and puck uses continuous collision detection.

## Practice-lab limitations (0.3; current exhibition status is in MATCH_STATUS.md)
- Skinned human uses a 163-bone foundation and original two-bone poses, not motion capture. No crossover, backward-skating, shooting, checking or fall animation families. Equipment and garment skinning still need specialist polish.
- Photographic crowd cards repeat eight generated people. They are flat representations, not volumetric or individually animated spectators.
- Skater contact uses CharacterBody collision, without mass/angle-based checking or falls.
- Goalkeepers track angle with simple pad colliders. No reaction-delay model, screens, save selection, butterfly, covering or realistic rebound control.
- Rink dimensions and markings are prototype approximations, not a validated league ruleset.
- Moving support partner is a practice aid, not full tactical AI.
- Shots remain flat, with no lift/spin controls.
- Goalkeeper pad-contact counter is diagnostic; repeated contacts are not official save statistics.
- No complete match, opposition skaters, remapping, controller support, persistent settings, saves, fatigue or accessibility menu.
- Synthetic impact sounds are placeholders. No recorded hockey audio or crowd.
- No Steam integration or release claims.
- Linux software render reports unsupported V-Sync; hardware/Windows performance is unmeasured.

## Milestone backlog
1. Current: rebuilt 3D practice arena — rendered inspection and physics/input tests complete; human feel review pending.
2. Next: production skater/goalkeeper models and animation rig, opposing skater, physical checking, goalkeeper response/saves, controller input and practice drills.
3. Full match: five-on-five AI, switching, faceoffs, clocks, stoppages, offside, icing, penalties, line changes, fatigue and results.
4. Presentation: licensed/original animation, blending and IK, detailed rink, uniforms, responsive menus, original spatial hockey sound.
5. GM/career: validated rosters, season simulation, contracts, draft, progression and robust versioned saves.
6. Release: measured Windows builds, device/hardware testing, Steam requirements, rights inventory, external playtesting.

## League coverage matrix
| Tier | Current | Planned rules/data work |
| --- | --- | --- |
| Top North American professional | Not implemented | Configurable rules, schedules, contracts |
| Primary/secondary feeder | Planned | Assignments, eligibility, roster limits |
| Major junior/development | Planned | Age and eligibility validation |
| University/college | Planned | Eligibility and progression |
| European pathways | Planned | League-specific rules and calendars |

No background leagues are simulated yet. No researched real league rules or player databases are embedded.

## Asset/licence register
Human foundation is an adapted Innerscene/MakeHuman CC0 rig. Rink, garment/equipment geometry, netting and HUD are original code-generated assets. Crowd and ice are original generated raster artwork. See docs/ASSETS.md for source and exact prompts. No real player identities, league logos, recordings or motion capture are included. Godot is MIT licensed; include the engine licence and notices in distributed builds. Production needs original or properly licensed skater/goalkeeper models, animation sets, uniforms, ice materials and audio.

## Save/data plan
Schema version is explicit. Future saves need validation, write-to-temporary plus atomic rename, backup and migration tests before GM/career availability. No save implementation is claimed.

## Test plan
Current deterministic tests: acceleration/rating separation, deceleration, directional crossing and misses.
Verified scene integration: two nets, rounded boards, perspective camera, fast board rebound, front shot scoring once, reset/pause, goalkeeper collision/save. Actual W input accelerates, Ctrl brakes and a stationary assisted puck remains bounded. Rendered close/full rink screenshots inspected under Godot 4.6 / Linux Mesa llvmpipe at 1440×900.
Next integration cases: fast shot vs posts; back-net collision; pass/receive under movement; goal exactly once per entry; pause during charge; reset during collision; multiple rendering rates.
Manual checklist: mouse aim alignment, effort turns, charge responsiveness, zoom readability, all input recovery after pause, 10-minute puck trapping attempts.

## Owner action
Open project.godot in Godot 4.6 and play the laboratory. Report skating/aim/puck-control feel before expanding modes. No purchase or Steam account action is needed yet.

## Changelog
0.4: Added a separate five-on-five exhibition scene, three-period match state, timed contextual minors and strength changes, roster lines/bench handoff/fatigue, role-based AI, physical goalkeeper improvements, officials and a level camera. Evaluated video pose tracking; low-quality reference was rejected rather than integrated.
0.3: Added a clothed derivative of a CC0 skinned human, original equipment/garment meshes, knee/arm IK posing, lateral skating and glide blending, generated spectator cards and ice texture. Added animation checks and asset provenance.
0.2: Rebuilt rink and both nets, perspective follow/wide cameras, procedural skater animation, collision movement and stops, stable stick spring, practice support, physical goalkeeper tracking, HUD and finite audio. Added rendered inspection and input/goalkeeper integration tests.

0.1: Created native practice laboratory, deterministic skating/goal tests and development documentation.

## Version 0.5 controller / flight revision

See SPORTS_GAME_RESEARCH.md for primary references and production requirements. The match now has native controller input and a free 3D puck with a convex disk collider. It ignores movement capsules and hits separate equipment/body colliders. Prior flat-puck limitations are superseded; production models/mocap and measured physics calibration are still outstanding. The two new suites test synthetic controller input and isolated airborne/ground puck behavior.
