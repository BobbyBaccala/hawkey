#!/usr/bin/env python3
"""Validate the delivered MP4 and retain the real match telemetry beside it."""
import hashlib
import json
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]
VIDEO = ROOT / "docs/videos/ai-vs-ai-60s-20261021.mp4"
TRACE = ROOT / "build/ai-gameplay.json"

def main():
    probe = json.loads(subprocess.check_output([
        "ffprobe", "-v", "error", "-count_frames", "-show_streams",
        "-show_format", "-of", "json", str(VIDEO)
    ]))
    video = next(s for s in probe["streams"] if s["codec_type"] == "video")
    audio = next(s for s in probe["streams"] if s["codec_type"] == "audio")
    assert abs(float(probe["format"]["duration"]) - 60) < 0.05
    assert int(video["nb_read_frames"]) == 1800
    assert video["width"] == 960 and video["height"] == 600
    assert video["avg_frame_rate"] == "30/1"
    assert video["codec_name"] == "h264" and video["pix_fmt"] == "yuv420p"
    assert audio["codec_name"] == "aac"
    decoded = subprocess.run([
        "ffmpeg", "-v", "error", "-i", str(VIDEO), "-f", "null", "-"
    ], capture_output=True, text=True, check=True)
    assert not decoded.stderr.strip(), decoded.stderr
    trace = json.loads(TRACE.read_text())
    samples = trace["samples"]
    assert trace["ai_vs_ai"] and samples[-1]["second"] >= 60
    active = [s for s in samples if s["phase"] == 1]
    assert active and all(s["ai_actors_with_targets"] == 10 for s in active)
    assert len({tuple(s["puck"]) for s in active}) > 10
    assert active[-1]["clock"] < active[0]["clock"]
    result = {
        "video": VIDEO.name,
        "sha256": hashlib.sha256(VIDEO.read_bytes()).hexdigest(),
        "bytes": VIDEO.stat().st_size,
        "duration_seconds": float(probe["format"]["duration"]),
        "frames": int(video["nb_read_frames"]),
        "resolution": [video["width"], video["height"]],
        "fps": video["avg_frame_rate"],
        "codecs": [video["codec_name"], audio["codec_name"]],
        "full_decode_errors": decoded.stderr,
        "regression_tests": json.loads((ROOT / "build/ai-video-checks/results.json").read_text()),
        "capture": trace,
    }
    target = VIDEO.with_suffix(".verification.json")
    target.write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps({k: v for k, v in result.items() if k != "capture"}, indent=2))

if __name__ == "__main__":
    main()
