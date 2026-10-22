# Stance refinement from the supplied photograph

2026-10-22, source `abf97b9`. The owner supplied the visible image `MPP.jpg`
after external coaching references were blocked. The image is an anatomical
reference only: no identity, uniform, brand art or photograph is added to the
game or redistributed in this repository.

The reference shows a bent top arm, the top hand in front of the hip, a forearm
sloping down toward that hand, a lower hand farther along the shaft, and a body
lean into the skating edge. These relationships are mirrored for the existing
right-shot rig. A single photograph does not establish exact 3D joint angles,
measurements or the hidden side of the glove. This pass refines arm placement;
it is not a claim of matching the entire photographed pose or finishing anatomy.

## Production changes

- Top-grip command moves 6.5 cm lower and 8 cm forward relative to the shoulder.
- Top-elbow preference is raised to retain a visible bent-elbow/downward-forearm
  relationship; the previous bench/board-carry elbow preference is retained.
- Glove wrist cock is capped at 0.42 rad (24.1°) so deep drags do not pull cuffs
  off the forearms. Both fists stay seated on the shaft with the previous thumb
  direction retained.
- During a deep inward drag, the top hand rises 6.5 cm and pulls back 8 cm
  progressively. This separates glove cuffs while keeping the lower neutral
  carrying posture and both fists on the same shaft. The first regression run
  exposed this overlap; the production pose was corrected with thresholds intact.
- Neutral blade command moves 13 cm farther ahead to preserve the stick-length
  acceptance gate as the top hand moves forward. This is shared by animation
  and puck control; there is no separate displayed puck or puck teleport.

The previous exaggerated handling range, move timing, input mappings, goalie
gear and Claude's newer branch are preserved. This is still the current right-shot
rig; complete per-player handedness remains open.

## Verification

The existing grip fixture now also checks the neutral top-grip height/forward
reach, top elbow above wrist and 60–120° elbow bend. The original direction,
contact, cuff, arm-reach and stick-length acceptance thresholds are retained.
All extremes and both sides of each move continue to be sampled.

Actual engine stills deliberately stage inspection poses; a separate moving
training video uses scripted input and the real rigid-body puck. Neither is a
natural AI exhibition. Final executed evidence follows.


- [Reference-guided stance JPEG](screenshots/photo-reference-stance-20261022.jpg)
- [Hand close-up JPEG](screenshots/photo-reference-grip-20261022.jpg)
- [Opposite hand view JPEG](screenshots/photo-reference-grip-opposite-20261022.jpg)
- [Eight-second moving training demo](videos/photo-reference-dekes-8s-20261022.mp4)
- [Exact results, capture samples and artifact hashes](verification/photo-stance-20261022.json)

All **15 affected engine suites pass** on `abf97b9`. Grip: 3,167 checks,
minimum thumb dot 0.4645 and cuff/forearm dot 0.9131; maximum arm reach 0.565 m,
shaft contact error below 0.001 mm. Existing full-stick-length and mesh-clipping
checks pass. Physical moving dekes: 720/720 ticks held, maximum blade gap 0.2202 m.

Headless checks use Godot 4.6.3. Stills are actual Godot 4.6.2 Compatibility
viewports at 1200×800. Video uses the same production resources, 960×600,
30 output FPS, 240 frames, 8.000 seconds, H.264 yuv420p, silent without an audio
track; full decode is clean. All half-second video samples retain control,
maximum sampled gap 0.1189 m. Capture uses llvmpipe, no MSAA/screen AA, 1024px
shadows; 273 source frames render offline in 1m18s with one-second warmup removed.
This does not measure real-time consumer hardware performance or prove human
feel, full-match balance, complete handedness or a finished commercial animation.
