---
description: Render the goalie from fixed cameras (and clay) for a before/after review
---
Render the goalie review set from the current working tree and show me the
images:
- `tools/capture_goalie.gd` (all shots, or `--only=$ARGUMENTS` if given)
- `tools/capture_goalie_drop.gd` (continuous drop/recovery; report the
  largest per-frame steps it prints) and the same with `--clay`
- `tools/capture_gloves.gd`

Run each as `godot --rendering-method gl_compatibility --resolution 1728x1080 --script <tool> -- <options>`
(on headless Linux prefix `xvfb-run -a -s "-screen 0 1728x1080x24"`).
Look at every image yourself and list concrete visual defects (attachment,
silhouette, clipping, pops), ranked. Don't fix anything unless I ask.
