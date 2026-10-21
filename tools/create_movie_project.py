#!/usr/bin/env python3
"""Prepare a disposable low-cost Movie Maker project, sharing production resources.

Run the normal project import first. This does not edit project.godot or assets.
The capture profile is recorded in the video provenance, never a hardware FPS claim.
"""
from pathlib import Path


def main():
    root = Path(__file__).resolve().parents[1]
    target = root / "build" / "movie-project"
    target.mkdir(parents=True, exist_ok=True)
    for name in ["assets", "data", "scripts", "tools", ".godot"] + [p.name for p in root.glob("*.tscn")]:
        link = target / name
        if not link.exists():
            link.symlink_to(root / name, target_is_directory=(root / name).is_dir())
    project = (root / "project.godot").read_text()
    for before, after in [
        ("viewport_width=1440", "viewport_width=960"),
        ("viewport_height=900", "viewport_height=600"),
        ("directional_shadow/size=4096", "directional_shadow/size=1024"),
        ("quality/msaa_3d=2", "quality/msaa_3d=0"),
        ("quality/screen_space_aa=2", "quality/screen_space_aa=0"),
    ]:
        project = project.replace(before, after)
    (target / "project.godot").write_text(project)
    (target / "build").mkdir(exist_ok=True)
    print(target)


if __name__ == "__main__":
    main()
