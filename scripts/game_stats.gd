extends RefCounted
## Per-period team stats for the intermission and final screens
## (scripts/stats_screen.gd): goals, shots on goal, hits, faceoffs won,
## power plays (goals / opportunities) and penalty minutes.
##
## Most numbers are read off state match.gd already keeps: sync() is called
## once per tick and books whatever changed since the last tick to the period
## being played (score, the score-bug shot counts, faceoff wins, new minors in
## match_state.penalties). Hits are the one explicit hook (add_hit()).

const PERIODS := 3
## Two minutes in the box per minor.
const MINOR_PIM := 2

## stat name -> [team][period index] counts.
var counts := {}
var _last_score: Array = [0, 0]
var _last_shots: Array = [0, 0]
var _last_faceoffs: Array = [0, 0]
## Skaters each side had on the ice at the last sync (to tell PP goals).
var _last_strength: Array = [5, 5]

func _init() -> void:
	for stat in ["goals", "shots", "hits", "faceoffs", "pp_goals", "pp_opps", "pim"]:
		counts[stat] = [_zeros(), _zeros()]

func _zeros() -> Array:
	var a := []
	a.resize(PERIODS)
	a.fill(0)
	return a

func period_index(period: int) -> int:
	return clampi(period - 1, 0, PERIODS - 1)

func add(stat: String, team: int, period: int, amount := 1) -> void:
	counts[stat][team][period_index(period)] += amount

## A body check that landed (match.gd defensive_action()).
func add_hit(team: int, period: int) -> void:
	add("hits", team, period)

## Books everything that changed since the last call to `match_state.period`.
## `shots` and `faceoff_wins` are match.gd's running per-team totals.
func sync(match_state, shots: Array, faceoff_wins: Array) -> void:
	var period: int = match_state.period
	for team in range(2):
		var goals: int = int(match_state.score[team]) - int(_last_score[team])
		if goals > 0:
			add("goals", team, period, goals)
			# Scored while the other side had fewer skaters out: a power-play goal.
			if int(_last_strength[team]) > int(_last_strength[1 - team]):
				add("pp_goals", team, period, goals)
		var new_shots: int = int(shots[team]) - int(_last_shots[team])
		if new_shots > 0: add("shots", team, period, new_shots)
		var won: int = int(faceoff_wins[team]) - int(_last_faceoffs[team])
		if won > 0: add("faceoffs", team, period, won)
	# Each new minor: penalty minutes for that team, a power-play chance for
	# the other. The penalty dictionary is tagged so it is only booked once.
	for p in match_state.penalties:
		if p.get("stats_booked", false): continue
		p["stats_booked"] = true
		add("pim", int(p.team), period, MINOR_PIM)
		add("pp_opps", 1 - int(p.team), period)
	_last_score = [int(match_state.score[0]), int(match_state.score[1])]
	_last_shots = [int(shots[0]), int(shots[1])]
	_last_faceoffs = [int(faceoff_wins[0]), int(faceoff_wins[1])]
	_last_strength = [match_state.count(0), match_state.count(1)]

## Sum of one stat for a team over periods 1..`through` (default: all).
func total(stat: String, team: int, through := PERIODS) -> int:
	var sum := 0
	for i in range(clampi(through, 0, PERIODS)):
		sum += int(counts[stat][team][i])
	return sum

func in_period(stat: String, team: int, period: int) -> int:
	return int(counts[stat][team][period_index(period)])

## Faceoff win percentage (0..100) through `through`; 50 each with no draws.
func faceoff_pct(team: int, through := PERIODS) -> int:
	var mine := total("faceoffs", team, through)
	var all := mine + total("faceoffs", 1 - team, through)
	if all == 0: return 50
	return int(round(100.0 * mine / all))

## "1/3" style power-play line.
func power_play_text(team: int, through := PERIODS) -> String:
	return "%d/%d" % [total("pp_goals", team, through), total("pp_opps", team, through)]

## Rows for the stats screen: [label, tor text, mtl text, tor value, mtl value].
## The values drive the comparison bar (PIM is "less is better", but the bar
## still just shows the split).
func rows(through := PERIODS) -> Array:
	var out := []
	out.append(["SHOTS", str(total("shots", 0, through)), str(total("shots", 1, through)), total("shots", 0, through), total("shots", 1, through)])
	out.append(["HITS", str(total("hits", 0, through)), str(total("hits", 1, through)), total("hits", 0, through), total("hits", 1, through)])
	out.append(["FACEOFFS", "%d  ·  %d%%" % [total("faceoffs", 0, through), faceoff_pct(0, through)], "%d%%  ·  %d" % [faceoff_pct(1, through), total("faceoffs", 1, through)], total("faceoffs", 0, through), total("faceoffs", 1, through)])
	out.append(["POWER PLAY", power_play_text(0, through), power_play_text(1, through), total("pp_goals", 0, through), total("pp_goals", 1, through)])
	out.append(["PENALTY MIN", str(total("pim", 0, through)), str(total("pim", 1, through)), total("pim", 0, through), total("pim", 1, through)])
	return out

## Screenshot/demo numbers (match.gd --stats-demo): a plausible game through
## `through` periods. Also marks them as already seen by sync(), so the caller
## can copy the returned totals into match.gd without them being booked twice.
## Returns {"score", "shots", "faceoffs"} per-team totals.
func fill_demo(through: int) -> Dictionary:
	var demo := {
		"goals": [[1, 0, 2], [0, 2, 0]],
		"shots": [[11, 8, 13], [9, 12, 7]],
		"hits": [[7, 5, 9], [6, 8, 4]],
		"faceoffs": [[9, 7, 10], [6, 9, 8]],
		"pp_goals": [[1, 0, 0], [0, 1, 0]],
		"pp_opps": [[2, 1, 1], [1, 2, 0]],
		"pim": [[2, 4, 0], [4, 2, 2]],
	}
	var n := clampi(through, 1, PERIODS)
	for stat in demo:
		for team in range(2):
			for i in range(PERIODS):
				counts[stat][team][i] = demo[stat][team][i] if i < n else 0
	var result := {"score": [total("goals", 0), total("goals", 1)], "shots": [total("shots", 0), total("shots", 1)], "faceoffs": [total("faceoffs", 0), total("faceoffs", 1)]}
	_last_score = result.score.duplicate()
	_last_shots = result.shots.duplicate()
	_last_faceoffs = result.faceoffs.duplicate()
	return result
