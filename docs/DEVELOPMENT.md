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
- scripts/control_slots.gd: PLAY NOW seat model (the game's only mode). Every position on both teams is a seat held by a CPU until a human claims it (join/claim/release/move; team or one-position control; to_dict/from_dict for a future network lobby). match.gd setup_seats()/apply_play_now() read the title-screen options (broadcast_hud.gd play_options) and human_controls() decides which skater the local player drives; --spectate makes all twelve CPU.
- scripts/skater_ai.gd: CPU hockey decisions as pure functions (shot_quality, pass_safety/lead_point, carrier_decision shoot/pass/carry/dump/protect, carry_target, pursue_target, gap_target, mark_target, open_spot, intercept_point, assign_coverage, shot_aim, SKILL per difficulty). match.gd update_team_ai() gathers positions once a tick (refresh_ai_reads) and acts on them (ai_shoot, ai_pass with a pass_receiver who meets the puck, ai_defend pokes/hits).
- tools/export_player_gltf.gd: exports the in-game home/away skater and goalie as static glTF (CPU-skinned, hidden body regions dropped, colours in vertex colours; materials HK_VC/HK_FACE/HK_VISOR) for Unreal: tools/blender/game_export_fbx.py (bridge) -> FBX, tools/unreal/import_game_players_ue.py (bridge, *_ue job) -> /Game/Hawkey/GameExport in HawkeyReference_v3.
- scripts/game_stats.gd: per-period team stats (goals, shots, hits, faceoffs won, power-play goals/opportunities, penalty minutes). match.gd update_match_hud() calls sync(match_state, team_shots, faceoff_wins) every tick, which books what changed to the current period (minors tagged `stats_booked` in match_state.penalties; a goal scored with more skaters out than the other side is a PP goal); hits come from add_hit() in defensive_action().
- scripts/stats_screen.gd: intermission / final stats card in the score-bug style, built by broadcast_hud.gd (show_stats() / hide_stats(), with a full-screen dim behind it). match.gd shows it at END OF PERIOD (match_state INTERMISSION_SECONDS = 8 s) and at FINAL instead of the old banners. Render review: main.tscn -- --capture --stats-screen=intermission|final [--stats-demo].
- practice.tscn: earlier isolated laboratory entry point.
- scripts/lab.gd: character/puck simulation, practice partner, goalkeeper tracking, cameras, input, HUD and finite event sounds.
- scripts/arena.gd: rounded rink, markings, two goals, glass and seating.
- scripts/goal_net.gd: NHL-style goal (rounded base frame, upper back bar, white base padding), diamond-mesh netting shader with impact ripple, netting collision slabs. The arena calls impact() when the puck's velocity changes sharply in or against a net.
- scripts/arena_benches.gd: player benches (west, behind match.gd BENCH_X) and penalty boxes with the officials' booth (east); seated players are skinned skaters (skater_visual.gd seated mode, pose_seated(); set_team_colors() re-dresses them; re-posed only on change, POSE_BUDGET per frame), set_penalty_count() fed by match.gd; figures are rigged and animated by update_figures() (follow the puck, celebrate(team) on goals, set_bench_numbers() from the roster); stand_up()/go_out() let match.gd's line change get a seated player up to go out (once up he walks to the boards and waits there, has_riser(team, true)) and seat the player coming off (has_riser(); if nobody is up when the tired player lands, match.gd hop 3 waits while stand_up(..., hurry) gets one up); in_zone() tells arena_dressing.gd which seating rows to leave out and glass_openings() tells arena.gd where the bench fronts have no glass. Render review: tools/capture_benches.gd.
- scripts/board_hop.gd: line-change board hop path/pose (sample()); skater_visual.gd start_hop() moves the visual over the west boards while match.gd holds the body at its bench_spot() and swaps the player on the bench. The top hand plants on the board cap during the gather (sample().plant/.hand, skater_visual.gd plant_weight()/hand_plant), and the stick is lifted blade-up clear of the boards (sample().carry, skater_visual.gd stick_carry/carry_knob()). Render review: tools/capture_hop.gd.
- assets/gear/head-v1.glb: scanned (MetaHuman-derived) skater head, ~8.5k tris, skinned to the base rig; skater_visual.gd MESH_HEAD / head_parts() / build_mesh_head() add it under the helmet, uniform.gdshader hide_head hides the base head surface above 1.545 m (goalies and referees keep the base head). Test: tests/test_head_mesh.gd.
- scripts/arena_lighting.gd: per-zone overhead spot pools and player rim lights (arena meshes sit on visual layer 2, which rim lights skip).
- scripts/goal_celebration.gd: goal presentation, one entry point celebrate(end_sign, team_color, team_name) called by match.gd on a goal: red rotating beacon on a bracket behind each net's end glass (omni glow + sweeping spot, ~4 s), a decaying warm counter-phase pulse of the overhead pools and team-tinted LED ribbons (~3 s), and a jumbotron GOAL then team-name animation (~4 s) while arena_dressing.gd holds score updates (scoreboard_hold) and restores them after. Render review: tools/capture_goal_light.gd.
- scripts/goal_replay.gd: instant replay after goals. match.gd calls capture(delta) every live tick (ring buffer, 8 s at 30 fps: every tracked visual's transform, every Node3D under it and every bone pose, plus the puck) and goal(end_sign) on a goal; 2 s later a slanted REPLAY wipe covers the cut and the clip [goal-3.2 s, goal+0.6 s] plays (slow motion for the last second before the goal; 5.4 s on screen) from a reverse-angle camera above the scored-on net's end boards while the match is frozen (step(delta)); a second wipe hands back the live picture exactly as it was. Each goal picks an angle (pick_angle(): shooter cam for long shots, ice level for close range, overhead for cross-slot plays, else reverse; never twice running), named on the REPLAY tag; an on-screen prompt shows Enter/Space/A skips. Big saves are replayed too, but only at a whistle: match.gd calls big_save(end, strength) from the goalie contact (crowd save_reaction() >= SAVE_MIN) and whistle() when PLAY turns to STOPPAGE; a save within SAVE_WINDOW (4 s) of the whistle replays [save-2.6 s, save+1.0 s] tagged GREAT SAVE. In slow motion a crisp camera-facing puck trail (trail_points(), last 0.4 s of clip time, cut at teleports) follows the puck. Render review: main.tscn -- --capture --replay / --replay-wipe / --replay-save [--replay-angle=reverse|ice|overhead|follow].
- Faceoffs (match.gd setup_faceoff() / place_linesman() / start_drop() / step_drop()): players line up in skater_visual.gd's faceoff stance and the camera cuts close on the dot; an official stands just off the dot (side picked per camera so he never blocks the centres) holding the puck out over it (skater_visual.gd drop_hand, DROP_HAND/DROP_LEAN). On the drop the puck falls kinematically from his hand while everyone waits, the centres' blades poise (draw_time / draw_blade_offset()), and on landing pick_faceoff_winner() decides from the roster "faceoff" rating and stamina (seeded faceoff_rng): the winner's blade sweeps back (DRAW_WIN) and the puck comes off it toward his forehand side and own end (DRAW_BACK_SPEED/ANGLE), the loser jabs across (DRAW_LOSE). faceoff_wins counts them per team. User timing: the first shoot/pass press while the puck falls (register_draw_press(), graded by draw_timing_quality(): best right at the landing; pressing just before the drop = JUMPED) shifts the odds toward or away from the user's centre (DRAW_TIMING_BONUS / DRAW_JUMP_PENALTY), and broadcast_hud.gd show_faceoff_cue() shows FACEOFF WON / LOST with the timing grade. Violations: just before the drop pick_violator() may throw a centre out (VIOLATION_CHANCE, or VIOLATION_JUMP_CHANCE when the user jumped); start_violation()/step_violation() hold the faceoff phase while the linesman waves (skater_visual.gd wave_out) and the centre and his best-rated winger swap spots, then the winger takes the draw; a team's second violation on the same faceoff (draw_violations) is a delay-of-game minor (delay_of_game()). After the drop the linesman backs out of the circle skating backward with C-cuts (skater_visual.gd back_skate, back_cut_foot(); review: tools/capture_backskate.gd). A draw-timing hint (broadcast_hud.gd show_draw_hint()) shows at the first FACEOFF_HINT_COUNT lineups. Render review: main.tscn -- --capture --faceoff / --faceoff-end / --faceoff-drop / --faceoff-draw [--faceoff-timing] / --faceoff-violation[=<s>] / --faceoff-delay / --faceoff-backing[=<s>].
- scripts/ice_marks.gd: skate-cut map (one texel ~4 cm) scored by every blade on the ice and sampled by the ice shader and by the paint shader on every marking/emblem (arena.gd paint(), set_cut_map()); cleared at each period.
- Rink size is NHL: arena.gd HALF_WIDTH (85 ft sheet), HALF_LENGTH (60 m), CORNER_RADIUS (28 ft); everything that depends on the rink width reads these rather than literals. Overhead rigging is on arena_lighting.gd RIGGING_LAYER, hidden by any camera above RIGGING_CLEARANCE over the sheet (arena_lighting.gd camera_cull_mask()).
- Rink markings use NHL proportions from constants in arena.gd (GOAL_LINE, BLUE_LINE, END_DOT_Z, DOT_X...); gameplay code reads Arena.GOAL_LINE rather than literal distances.
- scripts/skater_visual.gd: CC0 skinned human foundation, original kit and two-bone lateral push/glide posing.
- Goalie butterfly wall (skater_visual.gd separate_thigh_rises(), WALL_* constants): thigh rises stand face-on over the knee stacks and meet at the five-hole as the goalie drops; save body language (SAVE_LEAN_*, PAD_SAVE_*) leans/turns the torso toward glove, blocker and pad saves. Splits desperation save (SPLITS_* constants, save kinds splits_left/right, chosen by choose_save() past |x| > SPLITS_X): hips drop to the ice, both legs straight out along it; tests/test_goalie_saves.gd and test_clipping cover it; tools/capture_saves.gd --row=2 and capture_goalie.gd --only=splits render it. Test: tests/test_goalie_butterfly_wall.gd.
- scripts/crowd.gd: alpha-cutout generated crowd artwork in seating rows (practice lab). The match bowl's crowd cards (arena_dressing.gd build_crowd()) use assets/crowd.gdshader: per-fan in-play fidget and shimmer, and crowd_react(amount, end_sign, hold) stands them up on goals (goal_celebration.gd) and hard saves (match.gd save_reaction()). Render review: tools/capture_crowd.gd.
- assets/: shipped human mesh, generated crowd/ice textures and uniform shader; provenance in docs/ASSETS.md.
- scripts/skating.gd: deterministic velocity update and directional goal-mouth crossing.
- tests/test_simulation.gd: executable regression scenarios.
- data/roster.schema.json: future roster interface, currently unused by laboratory.
- assets/gear/skate-v1.glb: skaters' skates from Blender (HKY CC-BY 4.0 skate, see assets/CREDITS.md): boot_L/R rigid on the skate node, cuff_L/R on the shin-following cuff node; skater_visual.gd MESH_SKATE / skate_part(), procedural Gear.skate() for goalies and rollback. Built by the night-shift Blender job night_skate_v2_0250 (Hawkey art/night/skates/).
- assets/gear/helmet-v2.glb: skaters' helmets from Blender (Novichkov CC-BY 4.0 helmet, markings removed, see assets/CREDITS.md): helmet_shell (Kit.helmet_shell team colour), helmet_fittings, helmet_visor under the helmet node, placed by HELMET_MESH_OFFSET/SCALE; skater_visual.gd MESH_HELMET / helmet_part(), procedural Gear.skater_helmet() for rollback (goalies wear masks). Built by tools/blender/helmet_v2_debrand.py -> helmet_v2_smooth.py -> helmet_v2_normals.py through the bridge.
- assets/gear/glove-v1.glb: skaters' gloves from Blender (our own design, tools/blender/glove_v1.py): closed fist round the shaft at GLOVE_HOLE, glove_L (thumb +X) / glove_R, 2.4k tris each; vertex colours are masks recoloured per team by skater_visual.gd glove_part() (cached per hand+kit); MESH_GLOVE flag, procedural Gear.skater_glove() for rollback.
- tools/capture_showcase.gd: character showcase capture, the yardstick for player-model work (owner's EA customisation-screen reference, Hawkey art/NIGHT_SHIFT_PLAYER_MODELS.md 0b): one skater and one goalie in the team kit on a dark teal studio floor (warm key with shadows, dim fill, two cool rim spots, light fog, glossy floor + reflection probe), turned front / three-quarter / back plus a pair shot. Run under xvfb with gl_compatibility, `--out=<prefix>`, `--only=skater|goalie`.

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
