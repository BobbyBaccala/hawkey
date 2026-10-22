# Shaft-aligned fists with independent flex cuffs

2026-10-22, production source `6c9088b`. The owner rejected the sideways top hand
in the preceding side-carry footage and requires the hand to run parallel to the
stick. Contact at one point was insufficient: the old glove roll deliberately
left its closed-fist channel oblique to the shaft to keep a rigid cuff pointed
at the elbow. That compromise is removed.

## Implemented geometry

The closed-fist finger channel (glove local X) now follows the shaft exactly.
The proper physical glove/thumb and actual upper/lower arm assignments still
mirror with roster handedness. Both fists remain seated on the same stick; the
strong-side blade, wrist targets, skating, AI and puck physics are unchanged.

The cuff is a separate smooth gauntlet loft, joined to the fist at its lower
ring and opening around the actual forearm. Its frame bends between the fist and
the forearm, allowing those orientations to differ without angling the fist away
from the stick. Original glove colors, white trim and material are preserved;
no player body, text or kit is negatively scaled. Goalie equipment is unchanged.

`Gear.skater_glove(kit,side,with_cuff=true)` retains the previous default factory
for standalone callers/exports. The animated rig uses the fist-only option and
`Gear.skater_glove_cuff(kit,mouth_frame)` for its flexible gauntlet. Cuff geometry
is cached until its local opening moves 1.5 mm or rotates 0.015 rad, following the
same original procedural-mesh approach as the existing cloth sleeves.
Quaternion interpolation is normalized to avoid numeric basis-conversion errors.

`SkaterVisual.skater_glove_cuffs` contains rendered cuff meshes; `glove_cuff_frames`
stores their commanded forearm openings. Existing cuff tests now inspect the cuff
frame rather than treating the independent fist as if it were still the cuff.
The forearm-alignment acceptance threshold is preserved; the fist/shaft threshold
is strengthened from partial alignment to >0.999. A separate test inspects the
actual generated cuff vertices, including cache error, so the frame is not the
only evidence.

## Verification

`test_shaft_grip.gd`: 3,500 checks, zero failures. Both R/L shots, neutral and
extreme stick positions, cut/toe-drag/sweep and pass/wrist/slap follow-through:

- Actual fist-channel/shaft alignment minimum dot 0.99999976.
- Shaft remains in the channel at three samples across the fist's full width.
- Actual cuff mouth-plane/forearm alignment minimum dot 0.9999491.
- Actual mouth-center offset at most 4.89 mm, including the original 4 mm pad offset.
- Cuff seam remains joined to the fist within 2 mm.

The earlier grip suite now passes its stricter exact-alignment criterion across
3,167 checks; tested forearm cuff alignment is preserved independently. Mesh
clipping, sleeve/stride and board-hop checks also pass in focused execution.
All 28 affected regression suites pass on the source commit, with no logged
engine or script errors. Exact summaries and genuine captures follow.

The close-up stills deliberately stage production poses. The moving close-up
uses scripted training inputs with the production rigid-body puck and only one
initial puck placement. These are not natural AI gameplay or human visual approval.


| Shot | Front close-up | Reverse close-up |
|---|---|---|
| Right | [JPEG](screenshots/shaft-grip-right-front-20261022.jpg) | [JPEG](screenshots/shaft-grip-right-reverse-20261022.jpg) |
| Left | [JPEG](screenshots/shaft-grip-left-front-20261022.jpg) | [JPEG](screenshots/shaft-grip-left-reverse-20261022.jpg) |

[Eight-second moving hand close-up](videos/shaft-grip-close-8s-20261022.mp4).
[Exact verification and artifact hashes](verification/shaft-grip-20261022.json).

Actual 1200×800 Godot 4.6.2 Compatibility stills. Video: 960×600, 30 output FPS,
240 frames, 8.000 seconds, H.264 yuv420p, silent/no audio track, full decode clean.
The tight hand camera does not show the whole puck path; the underlying trace
and physics checks verify control. All half-second video samples retain the puck.
Godot 4.6.3 physical R/L trial retains 1,440/1,440 ticks with maximum blade gap
0.1853 m and real AI pickup for both hands in 130/129 ticks. Those behaviors are
preserved, not claimed as a new AI quality improvement in this visual pass.

The capture-only profile uses llvmpipe, no MSAA/screen AA and reduced shadows;
273 source frames take 1m46s offline with one-second warmup removed. These are
output frames, not a real-time hardware FPS result. Human hand/animation review
remains distinct from passing geometry and functional tests.
