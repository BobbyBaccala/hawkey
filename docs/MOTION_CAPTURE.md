# Mixamo motion capture (0.9)

Mixamo's terms allow its animations inside games but forbid redistributing the raw files, so they are not in this repository. Put the FBX files in `assets/mixamo/` on your own machine (the folder is git-ignored). Godot imports them on the next editor launch.

| File (Mixamo name) | Used for |
| --- | --- |
| `Goalkeeper Idle.fbx` | Goalie breathing, bounce and weight shift in the ready stance |
| `Left Strafe.fbx`, `Right Strafe.fbx` | Goalie lateral shuffle footwork, timed to the slide distance |
| `Goalkeeper Body Block.fbx` | Torso reaction to hard shots off the pads or body |
| `Standing Cheering.fbx` | Goal celebration for the scoring team, stick raised |

Download settings: FBX Binary, 30 fps, no keyframe reduction; "With Skin" or "Without Skin" both work. Mixamo's own names are accepted as downloaded, including duplicates like `Left Strafe (2).fbx`. Extra files are ignored.

`scripts/mocap.gd` samples each clip once at 30 fps into skeleton-independent data: unit directions for the spine and limb segments, and hip and foot positions scaled by hip height. Root travel is removed so clips play in place. `scripts/skater_visual.gd` blends these into the procedural pose, so pads, gloves, sticks and collision keep working.

The captured layers are constrained so they never break hockey posture or clip gear:
- Idle hip sway is reduced.
- Shuffle steps stay between 25 and 33 cm from centre.
- Thigh rises are rolled apart whenever they would touch.
- Celebrating hands hang outside the pants.

`tests/test_clipping.gd` checks the shuffle and celebration poses, and `tests/test_mocap.gd` checks the live-match triggers. Both skip the captured cases when the clips are absent; the game then falls back to procedural motion.

Skating legs remain procedural, since no free skating capture exists. `tools/capture_mocap.gd` renders a review of the captured poses.

---

# Video-based motion reference — evaluated, not retargeted

A video overlay is a review aid, not a skeletal animation. The pipeline must estimate joints, reject occlusion/low-confidence frames, solve camera/body coordinates, correct foot contact, preserve bone lengths, retarget the hockey rig and blend animation under player input.

## Tool
tools/extract_video_pose.py uses MediaPipe Pose Landmarker video mode and world/image landmarks.
Official API: https://developers.google.com/edge/mediapipe/solutions/vision/pose_landmarker/python
Dependencies: mediapipe, opencv-python-headless, numpy, plus MediaPipe model weights supplied separately.
The model weights and source footage are not bundled.

Example:
```
python tools/extract_video_pose.py --video full_body_skating.mp4 --model pose_landmarker.task --out pose_report.json
```

It samples at 15 Hz and checks visibility of shoulders, elbows, wrists, hips, knees, ankles, heels and toes. Required minimum visibility is 0.75 for all critical joints, with 80% accepted frame coverage. A failed gate exits with code 2 and leaves an inspectable report. Passing this gate would still require human review; inferred depth is not ground truth.

## Actual experiment, 2026-10-19
Source: "Brooks Orpik skating on Wednesday after Knee Injury", rmnbblog, 2014-12-31.
Page: https://commons.wikimedia.org/wiki/File:Brooks_Orpik_skating_on_Wednesday_after_Knee_Injury.webm
Original: https://www.youtube.com/watch?v=IVv52oumwqM
Licence identified on the source page: CC BY 3.0, https://creativecommons.org/licenses/by/3.0/
Use: local evaluation only. No face, team branding, footage, extracted pose samples or player identity are shipped.
The source is an injury-recovery clip and is not representative training data for normal elite skating.

426×240, approximately 25.6 seconds. MediaPipe sampled 383 frames. Zero passed the all-critical-joint visibility gate; highest minimum visibility was 0.5448.
Result: rejected. No video-derived motion has been integrated. Current gameplay animation remains procedural.

## Next required input
Clear 1080p-or-better full-body clips with skates and stick visible, a stable camera, minimal occlusion, and usable permission/licensing. Separate side/front views and forward skating, starts, stops, crossovers, backward skating, shots and goalkeeper saves are more useful than broadcast footage with distant overlapping players.
Do not portray a successful landmark extraction alone as accurate motion capture.
