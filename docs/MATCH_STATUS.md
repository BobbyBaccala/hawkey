# 0.6 exhibition simulation status

## Implemented
- Ten on-ice skater actors and two goalkeepers; 18 fictional roster entries per team.
- Human-controlled Toronto skater, switching, aim/charge/shoot, aimed assisted passing.
- AI puck pursuit with one primary pursuer per team, support lanes, defensive positioning, carrying, passing under pressure and shooting.
- Fixed 120 Hz physics with a physical CCD puck, boards/posts and controlled stick assistance.
- Three 20-minute game-clock periods; default 4× clock rate. Pause, whistles and intermissions stop clock/penalty time.
- Goals trigger stoppage, centre faceoff setup and restart; teams and goalkeepers change ends by period.
- Forward lines 1–4 and three defence pairs, fatigue and bench recovery.
- On-the-fly line requests skate to a bench-side handoff point before the same actor takes an incoming roster identity; no extra on-ice bodies. Stoppage line changes swap immediately.
- Action-driven tripping, interference and charging minors. Two-minute game-time timers, strength reduction to minimum three, queued additional minors, expiry restoration and advantaged power-play goal release.
- Manual legal poke/body-check separation with short stun response.
- Goalkeepers use angle/depth targets, 0.14-second target updates, capped movement, shot prediction, butterfly/recovery blend, expanded low collider and angled physical rebounds.
- Original goalie mask cage, leg pads, catcher/blocker; two visually represented officials.
- A straight camera with zero lateral offset/roll, perspective follow/wide views, score/period/clock, penalties and line/stamina HUD.
- Previous practice lab remains at practice.tscn for isolated tests.

## Verification
Ten scripts (including synthetic controller input, free puck flight and goalie equipment): test_simulation, test_lab, test_controls, test_animation, test_match_state, test_match, test_match_loop.
State tests cover stopped clocks, period advancement/end, minor expiry, queued minors and power-play goal release.
Scene tests cover 5v5 counts, unique roster IDs, pause, strength reduction/restoration, bench changes, camera alignment and goalie end switching.
A 2,400-tick / 20-second headless match-loop test retained valid player counts and rink bounds, advanced game clock, scored a goal and restarted.
Linux software-render PNG inspected. No Windows/hardware performance validation or external playtest is claimed.

## Explicit gaps
This is an early exhibition prototype, not an NHL-accurate rules implementation or EA NHL-quality production.
- Offside, icing, delayed calls, coincidental penalties, majors/misconducts, authentic faceoff mechanics and full special-team systems are absent.
- A tied regulation match ends as a draw; overtime/shootouts are absent.
- AI is basic positioning/decision logic, without validated hockey tactics or difficulty calibration.
- Goalkeeper reaction uses a simple shared interval and ballistic height prediction, with basic pad/glove colliders and catch/cover logic. Screen recognition, realistic save selection, motion-captured saves and butterfly/post integrations remain absent.
- Puck now has gravity, free vertical motion, loft and air rebounds. Dedicated puck colliders avoid the movement capsules. Coefficients still need reference calibration; flexible sticks and aerodynamic lift are absent. Contact has no falling/ragdoll or checking animation.
- Bench handoff reuses the actor at the boards; no hopping-over-boards animation or visible reserve-player population.
- Rink dimensions remain prototype approximations.
- Rendered skinned players remain a CC0 human derivative with procedural garments/equipment; production skin/fabric textures, garment deformation and animation transitions need substantial work.
- Crowd members are repeated flat cutout cards.
- Video pose extraction was tested and rejected the available low-resolution clip. No retargeted video-derived animation is claimed; see MOTION_CAPTURE.md.

See SPORTS_GAME_RESEARCH.md for source-backed implementation choices and remaining production gates.

0.6 replaces the shared goalie pad wall with pose-aligned individual gear. GOALIE_GEAR.md records behavior and limits.
