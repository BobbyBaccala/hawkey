#!/usr/bin/env python3
"""Run local/CI checks with honest skips, timeouts, logs, JSON and JUnit output."""
from __future__ import annotations

import argparse
import concurrent.futures
import json
import math
import os
from pathlib import Path
import re
import subprocess
import sys
import time
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
VERSION = "4.6.3"
SMOKE = ("roster_database", "controller", "match_state", "save_store", "play_now", "accessibility")


def classify(name: str, code: int, output: str) -> tuple[str, str]:
    # Godot can log a GDScript exception and still exit zero: never report that green.
    if code != 0:
        return "failed", f"Process exited {code}"
    if "SCRIPT ERROR:" in output or "Failed to load script" in output:
        return "failed", "Godot script error despite zero process exit"
    if re.search(r"\bskip(?:ped)?\b", output, re.IGNORECASE):
        if name == "test_mocap" and "clips not installed" in output:
            return "skipped", "Optional local motion-capture clips are absent"
        return "failed", "Unexpected skip; required checks must execute"
    if name == "engine_version" and not any(line.startswith(VERSION + ".") for line in output.splitlines()):
        return "failed", f"Use pinned Godot {VERSION}; found {output.strip()}"
    if name.startswith("test_") and not re.search(r"\b(?:0 failures|failures:\s*0|PASS)\b", output):
        return "failed", "Engine suite returned without a completion summary"
    if name == "python" and not re.search(r"Ran [1-9][0-9]* tests?", output):
        return "failed", "Python discovery did not report executed tests"
    return "passed", ""


def run_check(name: str, command: list[str], output_dir: Path, env: dict[str, str], timeout: float) -> dict:
    started = time.monotonic()
    try:
        process = subprocess.run(command, cwd=ROOT, env=env, stdout=subprocess.PIPE,
                                 stderr=subprocess.STDOUT, text=True, timeout=timeout)
        code, output = process.returncode, process.stdout
        status, reason = classify(name, code, output)
    except subprocess.TimeoutExpired as exc:
        partial = exc.stdout or b""
        output = partial.decode(errors="replace") if isinstance(partial, bytes) else partial
        code, status, reason = 124, "failed", f"Exceeded {timeout:g}s timeout"
    except OSError as exc:
        output, code, status, reason = str(exc), 127, "failed", "Could not launch check"
    (output_dir / f"{name}.log").write_text(output, encoding="utf-8")
    result = {"name": name, "status": status, "reason": reason, "returncode": code,
              "seconds": round(time.monotonic() - started, 3), "log": f"{name}.log"}
    print(f"{status.upper():7} {name} ({result['seconds']:.2f}s) {reason}", flush=True)
    return result


def write_reports(output_dir: Path, results: list[dict], version: str) -> dict:
    counts = {key: sum(r["status"] == key for r in results) for key in ("passed", "failed", "skipped")}
    report = {"godot": version, "counts": counts, "checks": results,
              "scope": "Headless regressions; not GPU, physical controller, human feel or release approval"}
    (output_dir / "results.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    suite = ET.Element("testsuite", name="Hawkey", tests=str(len(results)),
                       failures=str(counts["failed"]), skipped=str(counts["skipped"]),
                       time=str(round(sum(r["seconds"] for r in results), 3)))
    for result in results:
        case = ET.SubElement(suite, "testcase", name=result["name"], classname="hawkey",
                             time=str(result["seconds"]))
        if result["status"] == "failed":
            failure = ET.SubElement(case, "failure", message=result["reason"])
            failure.text = (output_dir / result["log"]).read_text(encoding="utf-8")[-8000:]
        elif result["status"] == "skipped":
            ET.SubElement(case, "skipped", message=result["reason"])
    ET.indent(suite)
    ET.ElementTree(suite).write(output_dir / "junit.xml", encoding="utf-8", xml_declaration=True)
    return report


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--suite", choices=("smoke", "all"), default="smoke")
    parser.add_argument("--godot", default=os.environ.get("GODOT", "godot"))
    parser.add_argument("--workers", type=int, choices=range(1, 5), default=2)
    parser.add_argument("--timeout", type=float, default=360)
    parser.add_argument("--output", type=Path, default=ROOT / "build" / "checks")
    args = parser.parse_args(argv)
    if not math.isfinite(args.timeout) or args.timeout <= 0:
        parser.error("--timeout must be positive")
    output_dir = args.output.resolve()
    output_dir.mkdir(parents=True, exist_ok=True)
    env = os.environ.copy()
    # Separate test cache from user profiles; tests themselves use isolated save slots.
    for variable, name in (("XDG_CACHE_HOME", "cache"), ("XDG_CONFIG_HOME", "config"), ("XDG_DATA_HOME", "data")):
        location = output_dir / "xdg" / name
        location.mkdir(parents=True, exist_ok=True)
        env[variable] = str(location)
    results = [run_check("engine_version", [args.godot, "--headless", "--version"], output_dir, env, 30)]
    version = (output_dir / "engine_version.log").read_text(encoding="utf-8").strip()
    if results[0]["status"] == "passed":
        results.append(run_check("import", [args.godot, "--headless", "--path", str(ROOT),
                                            "--editor", "--import", "--quit"], output_dir, env, args.timeout))
    if all(r["status"] == "passed" for r in results):
        paths = sorted((ROOT / "tests").glob("test_*.gd")) if args.suite == "all" else [ROOT / "tests" / f"test_{name}.gd" for name in SMOKE]
        if not paths:
            results.append({"name": "test_discovery", "status": "failed", "reason": "No engine tests discovered",
                            "returncode": 1, "seconds": 0, "log": "test_discovery.log"})
            (output_dir / "test_discovery.log").write_text("No engine tests discovered", encoding="utf-8")
        else:
            def run_engine(path: Path) -> dict:
                return run_check(path.stem, [args.godot, "--headless", "--fixed-fps", "120", "--path", str(ROOT),
                                             "--script", str(path)], output_dir, env, args.timeout)
            with concurrent.futures.ThreadPoolExecutor(max_workers=args.workers) as executor:
                results.extend(executor.map(run_engine, paths))
        results.append(run_check("python", [sys.executable, "-m", "unittest", "discover", "-s", "tests", "-p", "test_*.py"],
                                 output_dir, env, args.timeout))
    report = write_reports(output_dir, results, version)
    print("Checks: " + ", ".join(f"{count} {status}" for status, count in report["counts"].items()), flush=True)
    print(f"Reports: {output_dir / 'results.json'} and junit.xml", flush=True)
    return 1 if report["counts"]["failed"] else 0


if __name__ == "__main__":
    raise SystemExit(main())
