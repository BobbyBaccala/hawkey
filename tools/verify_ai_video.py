#!/usr/bin/env python3
"""Validate the delivered MP4 and retain the real match telemetry beside it."""
import argparse
import math
import re
import hashlib
import json
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--video", default="docs/videos/ai-vs-ai-60s-20261021.mp4")
    parser.add_argument("--trace", default="build/ai-gameplay.json")
    parser.add_argument("--checks", default="build/ai-video-checks/results.json")
    parser.add_argument("--seconds", type=int, default=60)
    args = parser.parse_args()
    video_path = ROOT / args.video
    trace_path = ROOT / args.trace
    probe = json.loads(subprocess.check_output([
        "ffprobe", "-v", "error", "-count_frames", "-show_streams",
        "-show_format", "-of", "json", str(video_path)
    ]))
    video = next(s for s in probe["streams"] if s["codec_type"] == "video")
    audio = next(s for s in probe["streams"] if s["codec_type"] == "audio")
    assert abs(float(probe["format"]["duration"]) - args.seconds) < 0.05
    assert int(video["nb_read_frames"]) == args.seconds * 30
    assert video["width"] == 960 and video["height"] == 600
    assert video["avg_frame_rate"] == "30/1"
    assert video["codec_name"] == "h264" and video["pix_fmt"] == "yuv420p"
    assert audio["codec_name"] == "aac"
    decoded = subprocess.run([
        "ffmpeg", "-v", "error", "-i", str(video_path), "-f", "null", "-"
    ], capture_output=True, text=True, check=True)
    assert not decoded.stderr.strip(), decoded.stderr
    trace = json.loads(trace_path.read_text())
    samples = trace["samples"]
    assert trace["ai_vs_ai"] and samples[-1]["second"] >= args.seconds
    active = [s for s in samples if s["phase"] == 1]
    assert active and all(s["ai_actors_with_targets"] == 10 for s in active)
    assert len({tuple(s["puck"]) for s in active}) > min(10, args.seconds // 2)
    assert active[-1]["clock"] < active[0]["clock"]
    volume = subprocess.run([
        "ffmpeg", "-hide_banner", "-i", str(video_path), "-af", "volumedetect",
        "-vn", "-sn", "-f", "null", "-"
    ], capture_output=True, text=True, check=True)
    peak = re.search(r"max_volume:\s+(-?[0-9.]+) dB", volume.stderr)
    assert peak and math.isfinite(float(peak.group(1))) and float(peak.group(1)) > -90
    result = {
        "video": video_path.name,
        "sha256": hashlib.sha256(video_path.read_bytes()).hexdigest(),
        "bytes": video_path.stat().st_size,
        "duration_seconds": float(probe["format"]["duration"]),
        "frames": int(video["nb_read_frames"]),
        "resolution": [video["width"], video["height"]],
        "fps": video["avg_frame_rate"],
        "codecs": [video["codec_name"], audio["codec_name"]],
        "full_decode_errors": decoded.stderr,
        "audio_peak_db": float(peak.group(1)),
        "regression_tests": json.loads((ROOT / args.checks).read_text()),
        "capture": trace,
    }
    target = video_path.with_suffix(".verification.json")
    target.write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps({k: v for k, v in result.items() if k != "capture"}, indent=2))

if __name__ == "__main__":
    main()
