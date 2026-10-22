# Puck-contact and receiving polish

2026-10-22, source `870246d`, codex/game-modes / draft PR #2. Alpha scope;
no release, full-match acceptance or AAA-quality claim.

## Implemented

- Shared Match/Practice receiving uses the visible blade, not just a body-radius
  check. Initial pickup requires less than 40cm to the blade, a low puck and less
  than 15.5m/s relative speed. Possession is lost outside bounded stick/body reach.
  A moving receiver can handle a pass that would be too fast relative to a
  stationary player; a high puck or a fast shot is not automatically caught.
- The stick spring cushions velocity over time with an 80m/s² acceleration cap.
  It changes neither puck position nor vertical velocity. The old practice
  receiver's instantaneous 0.35 velocity multiplier is removed.
- Approaching receivers reach their stick toward the puck, then make a 0.32s,
  12cm cushioning motion after control. Hands stay solved on the shaft. Holding
  the pass trigger prepares a low backswing; releasing still passes immediately.
  This does not reintroduce charge-to-power shooting.
- A 0.28s self-repickup lock applies only to the releasing actor. Other players
  can receive/intercept during the old global release delay. Completing a pass
  clears its action delay, while poke/battle cooldowns remain intact to avoid
  every-tick poke/recapture loops. Faceoff/practice resets clear the pickup lock.
- AI recovery targets put the stick ahead of the body and use a smaller stopping
  dead zone near a loose puck. Line-changing players retain their bench routes.
- AI takes an open, sufficiently central shot within 10m before passing purely
  because an off-lane defender is nearby. Close-shot priority excludes behind-net/very acute angles;
  defencemen can also shoot from up to 21m with a clear lane. These decisions
  still use the actual puck, goalie, net physics and existing tactical planner.

## Evidence

The initial 21 affected suites passed. Eight relevant suites were rerun after
final pickup/battle/shot-choice changes; all current checks pass. The receiving
suite has 202 checks, including an actual 10m/s rigid-body pass, no teleport,
bounded velocity change, shot/high-puck rejection, opponent interception,
self-repickup timing, battle cooldown and glove-to-shaft contact. Existing
controller, net targeting, match, tactics, skating, goalie gear/saves, bench,
overtime/shootout, Play Now and rendering checks remain green.

Initial controller fixtures placed a fresh possession at a hard-coded body
location while the prior shot follow-through was still active. They now wait
for the prior action and place the fixture puck at the actual idle blade. The
receiving helper test also initially used a name that shadowed Godot's Control
class; it was renamed before execution. Exact final results and artifact hashes
are in verification/puck-contact-20261022.json.

A separate source-pinned 30-second fixed-step AI run uses normal production rules
without forced goals, passes or puck positions. It records control acquisitions,
release events, clock and shots. These counters are not completed-pass statistics:
loose-puck recoveries and interceptions are included in acquisitions. The run is
an integration check, not proof of balanced/fun hockey or real-time performance.
The final 30-second run recorded acquisitions [19,12] and 15 release events,
with score 0–0 and shots 0–0. Shot/chance frequency remains an observed gap; the
open-shot priority is a targeted correction, not a claim that balance is solved.

## Visuals

Real Godot 4.6.2 Compatibility viewport JPEGs. Close-ups deliberately place the
puck and sample production receive/pass commands with a frozen camera and hidden
HUD. They are controlled inspection scenarios, not continuous gameplay:

[Ready](screenshots/receiving-ready-20261022.jpg) ·
[Reach](screenshots/receiving-reach-20261022.jpg) ·
[Cushion](screenshots/receiving-cushion-20261022.jpg) ·
[Pass preparation](screenshots/receiving-pass-preparation-20261022.jpg) ·
[Follow-through](screenshots/receiving-pass-follow-through-20261022.jpg)

[The ten-second AI-vs-AI MP4](videos/receiving-gameplay-10s-20261022.mp4) is actual uninterrupted production play.
It uses the broadcast camera, seed 42 and normal 4× match clock. One paused second
of renderer warm-up is trimmed. Movie Maker renders fixed 30 FPS on llvmpipe;
playback FPS is not a live hardware benchmark. Models/rules are unchanged by the
capture profile: 960×600, no MSAA/screen AA, 1024px two-split key shadows.

## Reproduce

```sh
# Tests (Godot 4.6.3 headless)
godot --headless --path . --script tests/test_puck_receiving.gd
# Normal AI integration; no forced events
godot --headless --path . --fixed-fps 120 \
  --script tools/check_ai_exhibition.gd -- --seconds=30 --source-sha=870246d
# Native inspection JPEGs, with a working display
DISPLAY=:10 build/renderer-diagnostic/godot-4.6.2 --path . \
  --rendering-method gl_compatibility --audio-driver Dummy \
  --script tools/capture_receiving.gd -- --source-sha=870246d
```

The video reuses tools/record_ai_match.gd with --warmup-frames=30,
--quit-after 333 and --source-sha=870246d. Encode seconds 1–11 to H.264/AAC and
validate duration, decoded frames, audio and live telemetry with:

```sh
python3 tools/verify_ai_video.py \
  --video docs/videos/receiving-gameplay-10s-20261022.mp4 \
  --trace build/receiving-gameplay.json --checks build/receiving-checks.json \
  --seconds 10
```

## Remaining work

Catching/receiving is still an assisted procedural model. Forehand/backhand and
one-timer anticipation/contact, tip-ins, stick deflection volumes, animated puck
protection, target-hardware profiling and human feel/balance review remain open.
Longer AI chance creation and goalie post/recovery behavior are next quality
gates. Newer Claude replay/crowd/bench/role work remains on remote 2ff37ab and is
not claimed integrated by this slice.
