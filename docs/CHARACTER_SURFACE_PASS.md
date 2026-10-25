# Character surface pass — 2026-10-25

Owner: Codex, explicitly reassigned to player/goalie visuals by the owner.
Branch: codex/character-surface-pass, based on Claude's presentation-goalie-gear
796fe0f. Existing gear geometry, rig, stride/save selection and colliders retained.
Review as a stacked PR; do not overwrite later Claude changes or merge automatically.

## Implemented

- Continuous 40-ring, 64-side original sweater torso with smooth normals and
  shallow modeled folds; separate skater and padded goalie cross sections.
- Bound knit collar and a fitted neck guard that preserves scale during posing.
- Antialiased restrained fabric pattern replaces the aliasing vertical stripes.
- Shared team/accent colors on torso and curved sleeves, with forearm bands.
- Lower-profile skater helmet, curved transparent visor and subdued jaw straps.
- Reproducible neutral-studio capture using the actual runtime character code.

This is a surface/garment iteration, not a replacement production human model.
The faces remain the existing generic CC0 derivative; body topology, pants,
boots, sleeve/shoulder integration and hand detail still need specialist work.
The goalie pads/catcher/blocker/mask shown are Claude's existing v2 assets, not
newly authored by this pass. No new motion capture or simulated cloth is claimed.

## Research applied

- EA's May 8, 2024 technology account separates anatomically accurate character
  skeletons/models from garment density, cloth/body interaction and lighting:
  https://www.ea.com/news/2024-ea-sports-latest-tech-innovations
- Visual Concepts' September 19, 2024 interview explains NBA 2K25 ProPLAY's
  footage-derived motion library and transition work. Motion capture/retargeting
  is a separate pipeline; putting a video over the character is not equivalent:
  https://developer.microsoft.com/en-us/games/articles/2024/09/closer-look-at-nba-2k25-proplay-system/

Applied here: repair silhouette and shading in the actual character rather than
trying to obscure them with arena effects. Keep rig/collider interfaces intact.
Next art tasks: a properly authored continuous jersey/arm mesh weighted to the
rig, textured faces/skin, more convincing pants/boots, then retargeted skating
and recovery clips with contact cleanup. Do not claim this pass reaches the
mobile benchmark or EA quality.

## Verification and reproduction

Godot 4.6 Linux, headless fixed 120 fps: all 18 existing test scripts exited 0,
with zero reported assertion failures. test_mocap skipped its optional external
clips because assets/mixamo is absent. Synthetic controller checks do not test
physical hardware. Some scene suites report resource-leak warnings on exit;
these are not a clean release-validation result. A first real-time boards run
hit a 90-second timeout; the fixed-step run completed and reported zero failures.
New test_jersey_surface checks finite/unit normals, attached collars and a
sub-20 cm neck guard through ready/butterfly posing; zero failures.

Actual OpenGL/Mesa software-render captures, identical studio camera/lighting:
- screenshots/characters-surface-before.png
- screenshots/characters-surface-after.png
- screenshots/characters-surface-butterfly.png
- screenshots/characters-surface-match.png (live match at 19:50)

Run:
```
godot --path . --script tools/capture_character_review.gd -- --output=/tmp/characters.png
godot --path . --script tools/capture_character_review.gd -- --butterfly --output=/tmp/butterfly.png
godot --headless --fixed-fps 120 --path . --script tests/test_jersey_surface.gd
```

No Windows, hardware frame-rate or external human playtest claim. No generated
concept image is presented as a runtime result. Studio render is a controlled
asset review; normal gameplay was also captured at the normal follow camera. The scene still falls short of the visual benchmark, particularly faces, pants/skates and crowd art.
