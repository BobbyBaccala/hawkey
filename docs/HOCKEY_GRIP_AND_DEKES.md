# Grip correction and stronger skill moves

2026-10-22; production source `c5a8f71`. Follow-up to the owner's review of the
previous stickhandling video. This changes the current right-shot procedural rig;
full per-player mirrored handedness is a separate remaining feature.

The old glove roll used distance from the torso to choose the back of the hand.
That could reverse the thumb direction while still passing hand/shaft contact
checks. Attached hands now have explicit opposed grip directions: the left/top
mesh's thumb points down the shaft toward the blade; the mirrored lower hand's
thumb points toward the knob. Cuffs still follow the forearms, and the shaft
stays inside both closed fists. Free/planted hand behavior retains its existing
roll rule. The hand changes preserve the existing glove mesh and all goalie gear.

New regression checks verify orientation, not just contact, during idle, full
forehand/backhand, deep drag, all three dekes on both sides and pass/wrist/slap
follow-through. Across 1,580 sampled poses: 3,164 checks pass; minimum thumb
alignment dot 0.7073, cuff/forearm dot 0.9120, maximum arm reach 0.5650 m and
shaft/contact error below 0.001 mm. Mathematical alignment is not human art
approval; actual close-ups are linked below.

## More visible moves

| Parameter | Previous source `e06ab4c` | This source |
|---|---:|---:|
| Full forehand-to-backhand commanded span | 1.11 m | 1.66 m |
| Full inward drag from neutral | 0.26 m | 0.48 m |
| Outward sweep's commanded depth | 0.065 m | 0.312 m |
| Cut torso lean at peak | 0.105 rad | 0.230 rad |
| Cut skating lateral intent at peak | 0.28 | 0.42 |

Timed action envelopes now use the wider travel, deeper pull/push, stronger hip
weight transfer and shoulder lean. Smoothed blade motion does not instantly reach
the full commanded range. Reach remains limited by the existing arm solver;
measured shaft length in the grip fixture stays at or below 1.3101 m.
Moves retain their durations, cooldown, controller mappings and real-puck control.
No teleport, forced defender miss or cosmetic-only puck is introduced.

## Reference access

The owner asked for a fresh lookup of real hockey grips. Direct HTTPS attempts
on 2026-10-22 to the following coaching/equipment references were rejected with
403 by this environment's proxy. No photographs or article content were retrieved,
so these are **attempted references**, not citations supporting verified research:

- https://howtohockey.com/how-to-hold-a-hockey-stick/
- https://howtohockey.com/how-to-stickhandle/
- https://www.icehockeysystems.com/skill-development-videos/stickhandling-basics
- https://www.purehockey.com/c/how-to-hold-a-hockey-stick
- https://www.hockeycanada.ca/en-ca/hockey-programs/coaching/essentials/downloads
- https://www.usahockey.com

The correction uses explicit grip anatomy and production-pose inspection, with
fresh coaching-photo comparison still open. No reference photographs were copied
into game assets or used to claim permission for a product design.

## Engine evidence

The close-ups are staged production poses in the actual engine, clearly labeled;
the puck is placed for inspection in these stills. The video separately uses
scripted player inputs with the production skating and rigid-body puck: one
initial placement, no puck re-positioning during play. Neither is an AI exhibition.
Final files and regression provenance follow.

- [Corrected grip close-up](screenshots/hockey-grip-close-20261022.jpg)
- [Grip from opposite side](screenshots/hockey-grip-opposite-20261022.jpg)
- [Cut pose](screenshots/hockey-deke-cut-20261022.jpg)
- [Toe-drag pose](screenshots/hockey-deke-drag-20261022.jpg)
- [Sweep pose](screenshots/hockey-deke-sweep-20261022.jpg)
- [Eight-second moving demonstration](videos/grip-dekes-8s-20261022.mp4)

Godot 4.6.2 Compatibility/llvmpipe actual viewport captures. Stills 1200×800;
video 960×600 / 30 FPS, H.264 yuv420p, 240 frames, 8.000 s, silent (no audio track), full
decode clean. Video source render of 273 frames took 1m22s offline; one-second warmup
removed. Output frame rate is not a real-time hardware benchmark. All half-second
video samples retain control, maximum sampled blade gap 0.1189 m.

The stronger three-move 120 Hz physics fixture retains 720/720 ticks, maximum blade
gap 0.2202 m; no teleports, real defender poke still works. The prior 420-tick
skating/pivot/handling fixture still measures p95 gap 0.1425 m and max 0.2043 m, no
drops. Its unchanged worst case is the pivot, so the wider handling did not
increase that fixture's aggregate result. Separate moving skills provide the
more relevant limit for the amplified moves. These are controlled fixtures;
no new unstaged AI chance-creation or full-match balance result is claimed here.

All **26 affected engine suites pass** on source `c5a8f71`, including geometry,
clipping, board hop, moving skills, receiving, input, skating, releases, tactics,
benches, Play Now and overtime/shootout. Exact summaries and artifact hashes:
[verification JSON](verification/hockey-grip-20261022.json).
