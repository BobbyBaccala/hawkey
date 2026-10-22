# Strong-side stick carrying and roster handedness

2026-10-22, production source `6b7d849`. The owner correctly rejected the previous
centered forward carry. Wrist/contact checks alone did not establish the desired
hockey silhouette. This pass changes the default stick/hand placement itself.

## Player-visible correction

A right shot carries the blade beside the player's right hip, with the left hand
at the knob and the right hand lower along the lateral diagonal shaft. A left
shot mirrors that relationship with the actual opposite arms. In a straight-on
view, the player's right is the viewer's left.

The neutral blade pocket is 0.92 m to the shooting side and 0.78 m ahead in rig
space, replacing 0.36 m sideways / 1.18 m ahead. The top grip moves toward the
shooting side; the lower hand follows the same shaft. Shoulders open toward that
side. Deliberate backhands may cross the body and reach forward to clear the
padded hip; ordinary neutral stickhandling stays beside the shooting side.

This uses the existing original model and hand meshes. The body/jersey is not
mirrored with negative scale. Upper/lower arm assignment, thumb-side roll,
receiving reach, shot torso twist, stop offset, carried and seated stick targets
follow handedness. Existing puck collision, receiving/assist, release speeds,
move timing and controls are preserved. Wrist cock remains bounded at 0.45 rad
(25.8°), preserving the existing cuff/forearm alignment acceptance threshold. There is no visual-only puck attachment.

## AI integration

Loose-puck recoverers now angle their body so the side-held blade, rather than
the torso forward axis, reaches the puck. The old straight-at-puck heading had
no stable solution with the wider lateral offset: a normal AI integration run
exposed orbiting without possession. The corrected heading uses the handed blade
angle and normal skating/contact, without widening pickup reach or assigning
ownership. A dedicated real AI recovery regression covers both shot hands.
Other tactical positioning and carrier net facing are preserved.

The initial full-forehand pose also exposed sleeve/torso intersections. Keeping
the top hand nearer its hip and following a smooth forehand/backhand wrist path
resolves these while preserving the strong-side silhouette and original sleeve
clearance thresholds.

## Actual data integration

The validated player database already contains `shoots: L/R`. Match construction
now passes it to each on-ice visual, and `change_identity` updates it when lines
change. GM match rosters use the same path. Older fixture profiles without this
field retain an explicit right-shot fallback; the original current world already
requires valid L/R values. Goalie gear stays on its existing separate path.
Generic decorative bench figures still have their existing default handedness;
this pass does not claim complete roster identity rendering for every bench seat.

`SkaterVisual.set_shoots("L"/"R")`, `shot_side()` and `top_hand_index()` expose
the handed pose. `stick_home(input, right_shot=true)` keeps its old default-call
interface; production animation/receiving passes the actual handedness. Horizontal
stick input keeps the same physical direction for either shot. Blade velocity
history resets on a handed identity switch to avoid deriving velocity from that
pose discontinuity.

## Verification and evidence

`test_strong_side.gd` checks initial roster wiring, both line-change identities,
neutral side/hand diagonal, swapped arm assignment, mirrored trajectories,
positive-scale geometry, glove/shaft contact and thumb/reach constraints.
Independent physical trials drive cut/drag/sweep for each handedness with only
one initial puck placement per trial. They do not prove natural AI balance.

The clipping fixture now covers both handednesses. The first pass exposed a
backhand glove/hip overlap; reaching forward during the deliberate cross-body
backhand resolves it without restoring a centered neutral pose or loosening
clipping thresholds. The neutral assertion in the earlier grip test was replaced
with the owner's strong-side acceptance criterion; its contact, wrist, arm and
stick-length criteria remain intact.

Actual frontal and close-up captures are staged engine inspection poses, with
the puck placed for each pose. Separate moving videos use scripted training inputs
and production rigid-body puck physics. They are not unstaged AI gameplay.
Final executed artifacts and source-pinned summaries follow.


| Shot | Frontal pose | Hand alignment | Moving physics demo |
|---|---|---|---|
| Right | [JPEG](screenshots/strong-side-right-20261022.jpg) | [JPEG](screenshots/strong-side-right-grip-20261022.jpg) | [8 s MP4](videos/strong-side-right-8s-20261022.mp4) |
| Left | [JPEG](screenshots/strong-side-left-20261022.jpg) | [JPEG](screenshots/strong-side-left-grip-20261022.jpg) | [8 s MP4](videos/strong-side-left-8s-20261022.mp4) |

All **27 affected regression suites pass** on `6b7d849`. The strong-side suite
passes **10,119 checks**, including **1,440/1,440 physical moving ticks held**,
maximum blade gap **0.1853 m**, maximum hand/shaft error below **0.001 mm** and
actual AI recovery at ticks **130 / 129** for R/L. The existing grip suite passes
3,167 checks; stride, both-handed mesh clipping, full stick length, receiving,
input, tactics, benches/line changes, Play Now and OT/shootout gates pass.

Separate normal AI run: 30 seconds, seed 42, Godot 4.6.3 at 120 Hz, unchanged
normal rules and no forced events. Acquisitions [9,12], ten release events,
final shots [2,0], score [1,0]. This demonstrates exercised possession, passing,
shooting and scoring in this short run; it does not establish balanced full-match
AI or statistical improvement in scoring.

Stills: actual Godot 4.6.2 Compatibility viewports, 1200×800. Each moving demo:
960×600, 30 output FPS, 240 frames, 8.000 seconds, H.264 yuv420p, silent/no audio
track, full decode clean. All half-second samples retain control; maximum sampled
gap R 0.1552 m / L 0.0969 m. These are independent scripted-input trials, each
with one initial placement and actual rigid-body simulation, not AI exhibitions.
Both source renders use llvmpipe and a reduced capture-only AA/shadow profile;
273 source frames take 2m57s / 2m55s offline with one-second warmup removed.
Output FPS is not a real-time hardware measurement.

[Exact summaries, AI trace, capture samples and hashes](verification/strong-side-20261022.json).
Human pose/feel review, full-match tuning, physical controller review and complete
bench-seat identity/handedness wiring remain open. This is a functional on-ice
handedness/carry slice, not a claim of finished commercial animation.

## Subsequent owner grip correction

The owner accepted neither test passage nor shaft contact as proof that the top
hand could hold the stick. SHAFT_ALIGNED_GRIP.md replaces the oblique fist/channel
orientation with exact shaft alignment and an independent flexible forearm cuff.
The side-carry and on-ice roster-handedness behavior from this checkpoint remains.

The later [palm/blade correction](PALM_AND_BLADE_CONTACT.md) preserves shooting-side
carry and true arm assignment. get_blade_world now means the outside-face puck
center, while blade_position remains the visual blade center. Consumers drawing
blade geometry must use its actual mesh transform rather than the puck pocket.
