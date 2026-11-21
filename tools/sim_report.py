#!/usr/bin/env python3
"""Summarise tools/sim_game.gd JSON results against NHL targets.
Usage: python3 tools/sim_report.py game1.json [game2.json ...]"""
import json, sys
from collections import defaultdict
games = [json.load(open(p)) for p in sys.argv[1:]]
sog, goals, att, svs = [], [], [], []
pts = defaultdict(lambda: [0, 0, 0, 0])  # g, a, games, line
for g in games:
    per = 3.0 / max(g["periods"], 1)  # scale partial games to 60 min
    for t in range(2):
        sog.append(g["sog"][t] * per); goals.append(g["score"][t] * per); att.append(g["attempts"][t] * per)
        svs.append(g["sv"][t])
    for p in g["players"]:
        k = (p["team"], p["id"], p["name"], p["pos"] + str(p["line"]))
        pts[k][0] += p["g"]; pts[k][1] += p["a"]; pts[k][2] += 1
n = len(games)
avg = lambda xs: sum(xs) / max(len(xs), 1)
print(f"{n} games (scaled to 3 periods)")
print(f"SOG per team   {avg(sog):5.1f}  range {min(sog):.0f}-{max(sog):.0f}   (NHL 25-30)")
print(f"attempts/team  {avg(att):5.1f}")
print(f"goals per team {avg(goals):5.2f}  (NHL ~3.0)")
tot_s = sum(sog); tot_g = sum(goals)
print(f"save %         {1 - tot_g / max(tot_s, 1):.3f} overall, per-goalie games {min(svs):.3f}-{max(svs):.3f}   (NHL .870-.930)")
rows = sorted(pts.items(), key=lambda kv: -(kv[1][0] + kv[1][1]))
print("top scorers (points per game):")
for (team, i, name, pos), (g_, a_, gp, _) in rows[:10]:
    print(f"   {'TOR' if team == 0 else 'MTL'} {name:11s} {pos}  {g_}G {a_}A  {(g_ + a_) / gp:.2f} P/GP")
ppg = [(g_ + a_) / gp for (_, (g_, a_, gp, _)) in rows]
print(f"players at >= 1.0 P/GP: {sum(1 for x in ppg if x >= 1.0)} of {len(ppg)}")
