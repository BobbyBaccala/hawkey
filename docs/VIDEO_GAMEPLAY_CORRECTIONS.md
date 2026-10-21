# Corrections from the AI gameplay video

Implemented and tested on 2026-10-21, source `342c197`, development PR #2.
These changes follow the owner's review of the earlier 60-second recording.
That recording remains an honest capture of its older source; it has not been
replaced with these inspection images.

- Goalkeepers track the puck from their net centre through a complete circle,
  including directly behind the goal, at both ends. Angular speed is 9 rad/s;
  there is no rear-angle clamp. Practice now has the same full-angle tracking.
- A closed collision volume on layer 32 excludes goalkeepers from the net cavity.
  The puck mask excludes this layer, keeping the goal mouth open for shots.
  Existing frame/net collisions remain. A conservative minimum 1.18m AI depth
  prevents rotating pads, gloves and stick from sweeping through the goal frame.
- Wrist releases are 18–24m/s and slap releases 25–31m/s across the power-rating
  range, about 20% below the previous profiles. Normal passes/clearances use 75%
  of their previous commanded speed, bounded to 6–18m/s before inherited motion.
  Ballistic net targeting remains intact; difficulty does not change physics.
- AI and human releases in Match and Practice trigger distinct procedural pass,
  wrist-shot and slap-shot actions. These move the blade, shaft, both IK hands
  and torso through a smooth follow-through/recovery while skating continues.
  Passes sweep low; wrist and slap follow-throughs lift approximately 38cm and
  66cm. Duration is 0.44s, 0.66s and 0.82s respectively. No charge-to-power shot
  mechanic was introduced. This is a procedural release layer, not a complete
  motion-capture wind-up/one-timer library.

## Engine previews

Real Godot 4.6.2 Compatibility viewport JPEGs, inspected after capture. These
are controlled production-match inspection scenarios, with HUD hidden and
camera frozen. The goalie preview places the puck behind the goal; release
previews sample the normal production release functions at follow-through peak.
They are not a fresh continuous gameplay recording.

[Behind-net goalie tracking](screenshots/video-fix-behind-net-20261021.jpg) ·
[Ready](screenshots/video-fix-ready-20261021.jpg) ·
[Pass](screenshots/video-fix-pass-20261021.jpg) ·
[Wrist](screenshots/video-fix-shot-20261021.jpg) ·
[Slap](screenshots/video-fix-slap-20261021.jpg)

Reproduce the previews with the working display and Compatibility renderer:

```sh
DISPLAY=:10 LP_NUM_THREADS=4 build/renderer-diagnostic/godot-4.6.2 \
  --path . --rendering-method gl_compatibility --audio-driver Dummy \
  --script tools/capture_video_corrections.gd
```

## Verification and remaining work

Eleven affected suites pass under Godot 4.6.3 headless: focused video corrections,
net shooting, goal net, goalie polish/proportions/saves, skate/stick, spectator,
tactical match, overtime/shootout and Play Now. The focused suite has 2,590 checks:
full-circle tracking, gear clearance at both ends, physical goalie-body exclusion,
puck scoring access, distinct/recovering blade paths and hands retained on the
shaft. Existing rigid-body scoring and net-containment tests still pass.

The initial fixture and old fast-clearance assumption were corrected and the two
affected suites rerun; full results and image hashes are in
[the verification record](verification/video-corrections-20261021.json).
These checks do not establish human-rated realism. Post-hug/reverse-VH poses,
turning footwork, anticipation/wind-up and one-timer/contact timing still need
animation work and playtesting. Newer Claude replay/crowd/role work at `2ff37ab`
remains preserved on its branch; this narrow correction does not claim integration.
