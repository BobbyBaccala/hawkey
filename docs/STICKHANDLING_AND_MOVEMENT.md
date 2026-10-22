# Moving puck control and skills

Source: `e06ab4c`, 2026-10-22. This is an original procedural implementation,
not a claim of EA animation parity or a complete licensed skill-move catalogue.

## Player-visible changes

The carried puck follows measured blade velocity, including rotation and lateral
handling. Newly received passes still cushion first; established control blends
in over 0.08–0.24 seconds. Corrections are bounded (80 m/s² receiving, rising to
150 m/s² carrying). The puck remains a colliding rigid body: no parenting,
position snapping, invulnerability or guaranteed deke success. Free-puck,
pass and shot launch speeds are unchanged in this pass.

Forehand/backhand reach now crosses the body. Neutral stick input adds restrained
handling while skating. Cut, toe drag and sweep each animate the stick, hands and
torso; the cut also steers through normal skating acceleration. Protection holds
the puck away from the nearest defender and reduces skating speed. Moves have
bounded duration and a 1.65-second cooldown; losing possession cancels them.

| Action | Controller | Keyboard |
|---|---|---|
| Continuous handling | Right stick left/right | Hold `[` / `]` |
| Lateral cut | LB/L1 + right stick left/right | `Z` |
| Toe drag | LB/L1 + right stick down | `X` |
| Sweeping deke | LB/L1 + right stick up | `V` |
| Protect puck | Hold A/Cross | Hold `G` |
| Wrist shot / slap shot | Unmodified right stick up / down then up | Existing shooting controls |

Modified upward input does not accidentally shoot. Existing passing, shooting,
braking and defence-pair `Q` controls are retained. Mapping tests use synthetic
controller events; a physical controller session is still needed.

## AI movement

AI carriers may choose a move with an opponent 1.3–4 m away, outside an immediate
close shooting opportunity and away from boards. Move choice and evasion side
use the skater's slot and opponent location. Close clear shots retain priority.
A move completes before another normal pass/shot decision; normal defence can
still dislodge the puck during it. AI also protects under very close pressure.

Positioning uses speed-sensitive arrival, smoothed steering and extra braking
near stationary targets. Moving-puck pursuit keeps a tighter arrival radius;
bench changes retain their dedicated routes. Facing holds its last heading when
the puck is almost underfoot instead of suddenly choosing the attacked net.
Faceoffs clear transient skill lean, stick and steering state.

## Measured checks

The reproducible carry fixture drives straight skating at 6 m/s, a stationary
180° pivot and lateral handling for 420 actual 120 Hz physics ticks. Only the
initial puck placement is scripted; subsequent movement uses production puck
control and physics. It is a stress fixture, not AI gameplay or a human feel test.

| Same fixture | Before (`38155c4`) | After (`e06ab4c`) |
|---|---:|---:|
| 95th percentile puck–blade distance | 0.7174 m | 0.1425 m |
| Maximum puck–blade distance | 0.7254 m | 0.2042 m |
| Ownership drops | 0 | 0 |

The old result demonstrates why ownership alone was misleading: the puck could
be counted as controlled while visibly trailing far behind the blade.

`test_puck_skills.gd`: 1,108 checks, zero failures. Three moving physical moves
retain possession for 720/720 ticks, maximum blade gap 0.1315 m, maximum arm reach
0.565 m and glove/shaft gap below 0.001 mm. Separate checks verify loss outside
reach, a real opponent poke during a deke, cooldown/input isolation and an AI
carrier selecting a move under pressure. These do not establish full-match balance.

The goalie tracking regression fixture now advances its manually driven update
at the project's actual 120 Hz rate for the intended half-second; its previous
60 Hz argument conflicted with CharacterBody's 120 Hz movement step. Its existing
net-clearance acceptance thresholds are unchanged.

All 22 affected engine suites pass on the source commit. Exact suite summaries,
before/after fixtures, natural AI trace, capture samples and artifact hashes:
[verification JSON](verification/stickhandling-20261022.json).

## Actual engine evidence

[Eight-second training MP4](videos/stickhandling-demo-8s-20261022.mp4) shows cut,
toe drag, sweep and protection while skating. This is explicitly **scripted
training input with production physics**, not AI-vs-AI. No puck reposition after
initial placement. All half-second samples retain control (sampled gaps under
5.2 cm); the stronger stress fixture above is the meaningful worst-case comparison.

- [Cut JPEG](screenshots/stickhandling-cut-20261022.jpg)
- [Toe-drag JPEG](screenshots/stickhandling-toe-drag-20261022.jpg)
- [Sweep JPEG](screenshots/stickhandling-sweep-20261022.jpg)

Captured with Godot 4.6.2 Compatibility/llvmpipe at 960×600, 30 output FPS,
no MSAA/screen AA, 1024px shadows. Full 273-frame offline source render took
1m33s; first second removed, eight seconds retained. This is not a consumer
hardware frame-rate measurement. Encoded H.264 yuv420p, 240 frames; full decode
checked. The isolated training fixture is silent; no audio track is included. Underlying models, skating, arena and puck use the production resources.

Separate normal AI exhibition: Godot 4.6.3, seed 42, 30 seconds at 120 Hz,
no staged events. Both teams acquire the puck ([16,12]), with 16 release events
and ten skill attempts already counted by 25 seconds. Final score 0–0 and no
shots: sustained chance creation remains open; this run does not prove improved
scoring, balance or full-match polish.
