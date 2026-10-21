# One minute of AI vs AI

The MP4 is a continuous 60-second capture of the production match, with both
teams under computer control. The broadcast camera, score, game clock, puck,
roster, tactical planner and goalie AI are the actual game. No goals or passes
are forced for the recording. Normal match clock speed is 4×; this is a minute
of playback, not a minute of game-clock time.

Capture source: `02bcdb5`. Godot 4.6.2 Compatibility (the working diagnostic
renderer) on llvmpipe software graphics, rendered offline at fixed 30 FPS.
Output resolution is 960×600, without MSAA or screen AA, with a 1024px two-split
key shadow map. This is a capture profile, not a real-time hardware benchmark.
Production project settings and models are unchanged. The capture uses isolated
settings under `build/movie-project/build/`.

## Reproduce

Import the normal project first, then prepare the disposable capture project:

```sh
python3 tools/create_movie_project.py
```

Run a compatible Godot renderer with a working display (adjust the executable
and display for your machine):

```sh
DISPLAY=:10 LP_NUM_THREADS=4 build/renderer-diagnostic/godot-4.6.2 \
  --path build/movie-project --rendering-method gl_compatibility \
  --audio-driver Dummy --fixed-fps 30 --disable-vsync \
  --write-movie /workspace/hawkey/build/ai-gameplay.avi --quit-after 1833 \
  --script tools/record_ai_match.gd -- --ai-vs-ai --warmup-frames=30 \
  --prefix=/workspace/hawkey/build/ai-gameplay --source-sha=02bcdb5
```

The first second warms up the scene while paused. Encode the following minute:

```sh
ffmpeg -y -ss 1 -i build/ai-gameplay.avi -t 60 \
  -vf scale=in_range=pc:out_range=tv -color_range tv \
  -c:v libx264 -preset fast -crf 24 -maxrate 3M -bufsize 6M -pix_fmt yuv420p \
  -c:a aac -b:a 128k -ac 2 -movflags +faststart \
  docs/videos/ai-vs-ai-60s-20261021.mp4
```

The capture harness writes per-second match telemetry and JPEG previews.
The final verification record accompanies the video. Automated regression checks
passed for spectator control, match tactics, Play Now, and overtime/shootouts.
