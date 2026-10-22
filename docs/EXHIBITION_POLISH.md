# Exhibition-match polish

2026-10-22. AAA remains a target; this build is an alpha. The owner authorized
Codex to cover the presentation work while Claude usage is unavailable.
Work stays on codex/game-modes / draft PR #2; no release or PR merge is implied.

Source: `d77009e`. Exact checks and capture provenance: [verification record](verification/exhibition-polish-20261022.json).

## First solo pass

Implemented and tested in this pass:

- Selectively integrated Claude's 936bbd0 material shading, screen-size stick
  coverage and player reflection pass using a clean three-way application.
  Current goalie equipment geometry, net exclusion and slower puck releases
  are retained. Reflection intensity/bounce/exposure were reduced and blur
  increased after inspecting the first render; the imported settings looked too
  bright in the close camera. The pass renders tagged on-ice models at 0.4×
  resolution, excludes bench figures and carries across painted markings.
- Added an explicit world-velocity animation interface. Forward stride, backward
  C-cuts and lateral edge steps blend from actual travel relative to the body;
  camera direction does not select them. Backward pushes stay low instead of
  using forward toe-off; lateral steps gather without crossing the feet.
  Reversing lateral travel blends the leading side rather than snapping it.
- Reconciled Claude's 3785bfd facing behavior into the existing tactical planner:
  carriers face the attacked net, other skaters watch the puck while moving.
  Both human and AI match control use the rule. A live defensive-coverage
  scenario verifies backward footwork is exercised by actual tactical movement.
- Turning goalies unweight their skates in small alternating steps with a
  controlled toe swivel. Standing turn steps fade out in butterfly and do not
  rotate detached pad sections. Existing full-circle puck tracking is retained.

This is procedural locomotion and a modest presentation improvement. It does
not add motion-captured crossovers, a complete foot-plant system, reverse-VH,
a final goalie locomotion controller or human-validated skating feel.

## Preview provenance

The JPEGs are actual Godot viewport images from the working 4.6.2 Compatibility
renderer on llvmpipe. They are controlled inspection views, not a new live match
recording or a performance benchmark. Broadcast shows the opening faceoff;
three footwork figures use production visuals at the same sampled stride phase.
Reflection off/on uses the same camera, lighting and geometry, toggling just
reflection strength in this build. It is not a fabricated older-build comparison.

[Broadcast](screenshots/exhibition-polish-broadcast-20261022.jpg) ·
[Forward / backward / lateral](screenshots/exhibition-polish-directional-footwork-20261022.jpg) ·
[Reflection off](screenshots/exhibition-polish-reflection-off-20261022.jpg) ·
[Reflection on](screenshots/exhibition-polish-reflection-on-20261022.jpg)

Reproduce with `tools/capture_exhibition_polish.gd` and a working display:

```sh
DISPLAY=:10 LP_NUM_THREADS=4 build/renderer-diagnostic/godot-4.6.2 \
  --path . --rendering-method gl_compatibility --audio-driver Dummy \
  --script tools/capture_exhibition_polish.gd
```

## Validation

The first 21 affected suites passed. Eleven targeted reruns after the final
facing/transition/reflection changes, plus the new defensive integration suite,
leave 22 current suites with zero failures. The directional suite has 968 checks.
Headless tests used Godot 4.6.3. An initial integration fixture incorrectly expected
backtracking during a neutral-zone forecheck; it was replaced with defensive-zone
coverage and rerun, checking C-cuts only while actually moving backward. No full
exhibition human acceptance or target-hardware FPS result is claimed.

## Next quality gates

| Priority | Gate | Current state | Acceptance evidence needed |
|---|---|---|---|
| 1 | Directional movement and transitions | Partial; first pass implemented/tested | Continuous gameplay review of defending, stops, pivots and diagonal transitions; skates/gear remain coherent |
| 2 | Puck-contact actions | Partial; release, receiving and held-pass preparation implemented/tested | Anticipation/contact/recovery timing, receiving absorption, pressured passes and one-timers; no invisible or detached contacts |
| 3 | Goalie locomotion and posts | Partial; tracking/net clearance/pivot steps tested | Shuffle-to-butterfly-to-recovery, post attachment and reverse-VH without equipment clipping; playable shot scenarios |
| 4 | Sustained tactical play | Partial; selectable planner and facing integrated | Full exhibition at each strength, sensible shot/pass decisions, role constraints and no repeated deadlocks |
| 5 | Broadcast presentation and sound | Partial; shaders/reflection layer integrated | Camera motion/puck visibility, restrained highlights, readable UI, audio context and crowd consistency across a full match |
| 6 | Polished exhibition acceptance | In progress | One complete uninterrupted match through result/rematch, human feel review, regression pass and measured performance on target hardware |

Puck-contact/receiving source 870246d now implements the next slice; see
PUCK_CONTACT_POLISH.md for the actual receiving checks and gameplay evidence.
The next checkpoint is sustained chance creation, shot-contact anticipation
and goalie post/recovery transitions. These are checkpoints for active work,
not an unattended background job or a promise of a completion date.

Claude's latest remote remains 2ff37ab. This pass selectively reconciles the
photo/facing slices; newer replay, crowd reaction, stick/bench and role-planner
work still needs separate integration. Neither remote branch history is rewritten.

Moving control/skills source `e06ab4c` adds blade-velocity following, physical cut,
toe drag, sweep and protection, cross-body handling, AI move selection, smoothed
arrival/braking and near-puck facing stability. See STICKHANDLING_AND_MOVEMENT.md
for measured carry error, controls and source-pinned evidence. These gates remain
partial: natural chance creation, sustained tactical decisions, transition art
review and physical controller/full-match acceptance still need work.

Owner-reviewed grip follow-up source `c5a8f71` replaces ambiguous palm roll with
explicit top/bottom thumb direction; wider/deeper dekes add stronger body weight
transfer while respecting hand contact and reach. See HOCKEY_GRIP_AND_DEKES.md
for actual close-ups, a moving physical demo and reference-access limitations.
Anatomy/transition realism remains partial and subject to human review.

Supplied-photo follow-up `abf97b9` refines top-hand height/forward reach, bent
elbow, capped wrist cock and drag pullback; gameplay blade follows the shared
pose. Reference-inspired inspection and moving physics evidence are in
PHOTO_STANCE_REFINEMENT.md. This is still partial procedural anatomy, with
per-player handedness and full animation/human acceptance outstanding.
