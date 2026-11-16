#!/usr/bin/env python3
"""Positioning and flow report for a CPU-vs-CPU log from tools/ai_flow_probe.gd.

Usage: python3 tools/ai_flow_report.py <log.json> [<out.png>] [--label NAME]

Everything is measured in "attack space" per team: a = z * attack (toward the
net the team attacks), and x from the team's own view (-x * attack: its left on
the left when attacking up). Situations (frames in open play only):
  OZ  - the team has the puck in its offensive zone (a > blue line)
  DZ  - the other team has the puck in this team's defensive zone
  NZ  - the puck is between the blue lines
Prints per-slot mean positions per situation, spacing/clumping, skating, and
flow numbers, with real-hockey reference values next to them.
"""
import json
import math
import sys

BLUE = 7.62
GOAL = 26.65
SLOTS = ["C", "LW", "RW", "LD", "RD"]


def load(path):
    with open(path) as f:
        return json.load(f)


def situations(frames):
    """Yields (frame, team, situation) for open-play frames."""
    for fr in frames:
        if fr["phase"] != 1:
            continue
        ct = fr["carrier"][0]
        pz = fr["puck"][1]
        for team in (0, 1):
            att = fr["attack"][team]
            pa = pz * att
            if ct == team and pa > BLUE:
                yield fr, team, "OZ"
            elif ct == 1 - team and pa < -BLUE:
                yield fr, team, "DZ"
            elif ct >= 0 and abs(pa) <= BLUE:
                yield fr, team, "NZ+" if ct == team else "NZ-"


def stats(log):
    frames = log["frames"]
    play = [f for f in frames if f["phase"] == 1]
    out = {}
    # Per-slot positions per situation, in attack space (x mirrored so that a
    # player's own side is comparable for both teams: x * attack).
    pos = {}
    for fr, team, sit in situations(frames):
        att = fr["attack"][team]
        for t, slot, x, z, vx, vz, ch in fr["sk"]:
            if t != team or ch:
                continue
            # x from the player's own view (attacking up, his left on the left).
            pos.setdefault((sit, slot), []).append((-x * att, z * att))
    out["pos"] = pos
    # Spacing and clumping (open play, both teams).
    clump3 = []
    spacing = []
    near_puck = []
    still = 0
    moving = 0
    speeds = []
    for fr in play:
        px, pz = fr["puck"][0], fr["puck"][1]
        for team in (0, 1):
            mates = [(x, z) for t, s, x, z, vx, vz, ch in fr["sk"] if t == team and not ch]
            if len(mates) < 4:
                continue
            d = [math.hypot(x - px, z - pz) for x, z in mates]
            clump3.append(sum(1 for v in d if v < 3.0))
            near_puck.append(sorted(d)[1])  # second-closest team-mate to the puck
            pair = [math.hypot(a[0] - b[0], a[1] - b[1]) for i, a in enumerate(mates) for b in mates[i + 1:]]
            spacing.append(min(pair))
        for t, s, x, z, vx, vz, ch in fr["sk"]:
            if ch:
                continue
            v = math.hypot(vx, vz)
            speeds.append(v)
            if v < 0.6:
                still += 1
            else:
                moving += 1
    out["clump3"] = sum(clump3) / max(1, len(clump3))
    out["clump_2plus"] = sum(1 for c in clump3 if c >= 2) / max(1, len(clump3))
    out["min_spacing"] = sum(spacing) / max(1, len(spacing))
    out["min_spacing_lt2"] = sum(1 for v in spacing if v < 2.0) / max(1, len(spacing))
    out["second_to_puck"] = sum(near_puck) / max(1, len(near_puck))
    out["still"] = still / max(1, still + moving)
    out["speed"] = sum(speeds) / max(1, len(speeds))
    # Flow: possession changes, zone time, possession length.
    dt = (frames[1]["t"] - frames[0]["t"]) if len(frames) > 1 else 0.1
    changes = 0
    last = None
    runs = []
    run = 0
    zone = {"O0": 0, "N": 0, "O1": 0}
    for fr in play:
        ct = fr["carrier"][0]
        if ct >= 0:
            if last is not None and ct != last:
                changes += 1
                runs.append(run)
                run = 0
            last = ct
            run += 1
        pz = fr["puck"][1]
        a0 = pz * fr["attack"][0]
        zone["O0" if a0 > BLUE else ("O1" if a0 < -BLUE else "N")] += 1
    if run:
        runs.append(run)
    minutes = len(play) * dt / 60.0
    out["minutes_play"] = minutes
    out["changes_per_min"] = changes / max(minutes, 1e-6)
    out["mean_possession_s"] = (sum(runs) / max(1, len(runs))) * dt
    tot = max(1, sum(zone.values()))
    out["zone"] = {k: v / tot for k, v in zone.items()}
    out["stoppage_share"] = 1.0 - len(play) / max(1, len(frames))
    s = log["summary"]
    out["attempts_per_min"] = sum(s["shot_attempts"]) / (s["seconds"] / 60.0)
    out["passes_per_min"] = sum(s["passes"]) / (s["seconds"] / 60.0)
    out["summary"] = s
    return out


def mean(ps):
    if not ps:
        return (float("nan"), float("nan"), 0)
    return (sum(p[0] for p in ps) / len(ps), sum(p[1] for p in ps) / len(ps), len(ps))


def print_report(st, label):
    print(f"== {label}")
    print(f"open-play minutes {st['minutes_play']:.1f}, stoppages {st['stoppage_share']*100:.0f}% of time")
    print(f"shot attempts/min {st['attempts_per_min']:.2f} (NHL ~2.0 both teams)   passes/min {st['passes_per_min']:.1f} (NHL ~10)")
    print(f"possession changes/min {st['changes_per_min']:.1f} (NHL ~6-8)   mean possession {st['mean_possession_s']:.1f} s (NHL ~6-10)")
    z = st["zone"]
    print(f"zone time: team0 O-zone {z['O0']*100:.0f}%  neutral {z['N']*100:.0f}%  team1 O-zone {z['O1']*100:.0f}%  (NHL ~ 35/30/35)")
    print(f"team-mates within 3 m of the puck {st['clump3']:.2f} avg, 2+ in {st['clump_2plus']*100:.0f}% of frames (want ~1 / <15%)")
    print(f"closest team-mate pair {st['min_spacing']:.1f} m avg, <2 m in {st['min_spacing_lt2']*100:.0f}% of frames (want >4 m / <10%)")
    print(f"second team-mate to the puck {st['second_to_puck']:.1f} m (support distance, want ~5-9 m)")
    print(f"skaters standing still {st['still']*100:.0f}% (want <10%)   mean speed {st['speed']:.1f} m/s")
    for sit in ["OZ", "DZ", "NZ+", "NZ-"]:
        row = []
        for slot in range(5):
            mx, ma, n = mean(st["pos"].get((sit, slot), []))
            row.append(f"{SLOTS[slot]} a{ma:+5.1f} x{mx:+5.1f}")
        print(f"  {sit:4s} " + " | ".join(row))


def draw(st_list, labels, out_png):
    from PIL import Image, ImageDraw, ImageFont
    W, H = 460, 700  # one half-rink panel (attack space, a from -30 to +30 vertical)
    font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 18)
    small = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 15)
    cols = {0: (230, 200, 40), 1: (60, 200, 90), 2: (60, 160, 240), 3: (230, 70, 70), 4: (200, 90, 220)}
    sits = [("OZ", "Our puck, offensive zone"), ("DZ", "Their puck, our zone")]
    sheet = Image.new("RGB", (W * len(sits) * len(st_list) + 10 * (len(st_list) - 1), H + 70), (20, 24, 30))
    d = ImageDraw.Draw(sheet)
    sx = (W - 40) / (2 * 13.0)
    sy = (H - 40) / 60.0
    def P(x, a):
        return (20 + (x + 13.0) * sx, 20 + (30.0 - a) * sy + 50)
    for k, st in enumerate(st_list):
        for j, (sit, title) in enumerate(sits):
            ox = (k * len(sits) + j) * W + k * 10
            def Q(x, a):
                p = P(x, a)
                return (p[0] + ox, p[1])
            d.rectangle([Q(-13, 30), Q(13, -30)], outline=(160, 170, 180), fill=(232, 238, 244))
            for a, col in [(BLUE, (40, 80, 200)), (-BLUE, (40, 80, 200)), (0, (200, 40, 40)), (GOAL, (200, 40, 40)), (-GOAL, (200, 40, 40))]:
                d.line([Q(-13, a), Q(13, a)], fill=col, width=3 if abs(a) < 20 else 1)
            for slot in range(5):
                ps = st["pos"].get((sit, slot), [])
                for x, a in ps[::3]:
                    q = Q(x, a)
                    d.ellipse([q[0] - 1.5, q[1] - 1.5, q[0] + 1.5, q[1] + 1.5], fill=cols[slot])
            for slot in range(5):
                mx, ma, n = mean(st["pos"].get((sit, slot), []))
                if n:
                    q = Q(mx, ma)
                    d.ellipse([q[0] - 9, q[1] - 9, q[0] + 9, q[1] + 9], fill=cols[slot], outline=(0, 0, 0), width=2)
                    d.text((q[0] + 11, q[1] - 9), SLOTS[slot], font=small, fill=(0, 0, 0))
            d.text((ox + 20, 8), labels[k], font=font, fill=(255, 220, 90))
            d.text((ox + 20, 32), title + " (attacking up)", font=small, fill=(230, 230, 230))
    sheet.save(out_png)


if __name__ == "__main__":
    args = [a for a in sys.argv[1:]]
    logs = [a for a in args if a.endswith(".json")]
    png = next((a for a in args if a.endswith(".png")), None)
    sts = [stats(load(p)) for p in logs]
    for p, st in zip(logs, sts):
        print_report(st, p.split("/")[-1])
    if png:
        draw(sts, [p.split("/")[-1].replace(".json", "") for p in logs], png)
