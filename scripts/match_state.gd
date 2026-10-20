extends RefCounted
## Original HL exhibition rules: regulation, sudden-death 3v3 OT, then shootout.
enum Phase { FACEOFF, PLAY, STOPPAGE, INTERMISSION, FINAL, SHOOTOUT_READY, SHOOTOUT_ATTEMPT }
var phase := Phase.FACEOFF
var period := 1
var period_seconds := 1200.0
var overtime_seconds := 300.0
var clock := 1200.0
var clock_rate := 4.0
var phase_timer := 2.0
var score: Array[int] = [0,0]
var penalties: Array[Dictionary] = []
var team_codes: Array[String] = ["HOME", "AWAY"]
var team_names: Array[String] = ["HOME", "AWAY"]
var event := "Opening faceoff"
var ended_period := false
var faceoff_serial := 0
var winner := -1
var decision := ""
var shootout_score: Array[int] = [0,0]
var shootout_attempts: Array[Dictionary] = []
var shootout_player_id := ""
var shootout_team := 0
var shootout_seconds := 20.0
var shootout_remaining := 20.0
var shootout_rounds := 3

func is_shootout() -> bool:
	return phase in [Phase.SHOOTOUT_READY, Phase.SHOOTOUT_ATTEMPT]

func period_text() -> String:
	if is_shootout() or decision == "SO": return "SO"
	if period > 3: return "OT"
	return ["1ST", "2ND", "3RD"][clampi(period-1,0,2)]

func count(team: int) -> int:
	if is_shootout(): return 1 if team == shootout_team else 0
	if period > 3:
		# Overtime adds skaters to the advantaged team, never below three.
		return 3 + clampi(active_penalties(1-team).size()-active_penalties(team).size(),0,2)
	return 5 - mini(2, active_penalties(team).size())

func active_penalties(team: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for p in penalties:
		if p.team == team and p.active: result.append(p)
	return result

func penalized(team: int, roster_id: int) -> bool:
	for p in penalties:
		if p.team == team and p.roster_id == roster_id: return true
	return false

func minor(team: int, roster_id: int, reason: String, duration: float = 120.0) -> bool:
	if phase == Phase.FINAL or is_shootout() or penalized(team,roster_id): return false
	var starts := active_penalties(team).size() < 2
	penalties.append({"team":team,"roster_id":roster_id,"reason":reason,"remaining":duration,"active":starts})
	event = team_codes[team]+" — "+reason+"  2:00"
	phase = Phase.STOPPAGE
	phase_timer = 2.2
	return true

func finish(team: int, how: String) -> void:
	if phase == Phase.FINAL: return
	winner = team
	decision = how
	phase = Phase.FINAL
	event = "FINAL — " + {"REG":"REGULATION", "OT":"OVERTIME", "SO":"SHOOTOUT"}.get(how,how)

func goal(team: int) -> void:
	if phase != Phase.PLAY: return
	var opponent := 1-team
	if count(team) > count(opponent):
		for i in range(penalties.size()):
			if penalties[i].team == opponent and penalties[i].active:
				penalties.remove_at(i)
				break
		activate_queued()
	score[team] += 1
	if period > 3:
		finish(team,"OT")
		return
	event = team_names[team]+" GOAL"
	phase = Phase.STOPPAGE
	phase_timer = 3.0

func activate_queued() -> void:
	for team in range(2):
		var running := active_penalties(team).size()
		for p in penalties:
			if p.team == team and not p.active and running < 2:
				p.active = true
				running += 1

func start_shootout() -> void:
	if phase == Phase.FINAL or is_shootout(): return
	penalties.clear()
	shootout_team = 0
	shootout_remaining = shootout_seconds
	phase = Phase.SHOOTOUT_READY
	phase_timer = 2.5
	event = "SHOOTOUT — " + team_codes[0] + " ATTEMPT 1"

func shootout_taken(team: int) -> int:
	return shootout_attempts.filter(func(a): return a.team == team).size()

func record_attempt(scored: bool, player_id: String = "") -> bool:
	if phase != Phase.SHOOTOUT_ATTEMPT: return false
	var team := shootout_team
	shootout_attempts.append({"team":team,"scored":scored,"player_id":shootout_player_id if player_id.is_empty() else player_id})
	if scored: shootout_score[team] += 1
	var taken: Array[int] = [shootout_taken(0),shootout_taken(1)]
	var winning_team := -1
	if taken[0] <= shootout_rounds and taken[1] <= shootout_rounds:
		for side in range(2):
			if shootout_score[side] > shootout_score[1-side] + shootout_rounds-taken[1-side]: winning_team = side
	if taken[0] == taken[1] and taken[0] >= shootout_rounds and shootout_score[0] != shootout_score[1]:
		winning_team = 0 if shootout_score[0] > shootout_score[1] else 1
	if winning_team >= 0:
		# Exactly one deciding goal; attempt goals do not inflate game/player stats.
		score[winning_team] += 1
		finish(winning_team,"SO")
		return true
	shootout_team = 1-team
	shootout_remaining = shootout_seconds
	phase = Phase.SHOOTOUT_READY
	phase_timer = 2.0
	event = "SHOOTOUT — %s ATTEMPT %d" % [team_codes[shootout_team],shootout_taken(shootout_team)+1]
	return true

func advance(delta: float) -> void:
	if phase == Phase.FINAL: return
	if phase == Phase.SHOOTOUT_ATTEMPT:
		shootout_remaining = maxf(0,shootout_remaining-delta)
		if shootout_remaining <= 0: record_attempt(false)
		return
	if phase == Phase.SHOOTOUT_READY:
		phase_timer = maxf(0,phase_timer-delta)
		if phase_timer <= 0:
			phase = Phase.SHOOTOUT_ATTEMPT
			event = "SHOOTOUT — " + team_codes[shootout_team] + " GO"
		return
	if phase == Phase.PLAY:
		var game_delta := minf(clock,delta * clock_rate)
		clock = maxf(0,clock-game_delta)
		for p in penalties:
			if p.active: p.remaining = maxf(0,p.remaining-game_delta)
		for i in range(penalties.size()-1,-1,-1):
			if penalties[i].remaining <= 0: penalties.remove_at(i)
		activate_queued()
		if clock <= 0:
			if period >= 3 and score[0] != score[1]: finish(0 if score[0] > score[1] else 1,"OT" if period > 3 else "REG")
			elif period > 3: start_shootout()
			else:
				phase = Phase.INTERMISSION
				phase_timer = 5.0
				event = "OVERTIME NEXT — SUDDEN DEATH 3 ON 3" if period == 3 else "END OF PERIOD "+str(period)
		return
	phase_timer = maxf(0,phase_timer-delta)
	if phase_timer > 0: return
	if phase == Phase.STOPPAGE:
		phase = Phase.FACEOFF
		phase_timer = 2.0
		event = "Centre faceoff"
		faceoff_serial += 1
	elif phase == Phase.INTERMISSION:
		period += 1
		clock = overtime_seconds if period > 3 else period_seconds
		phase = Phase.FACEOFF
		phase_timer = 2.0
		faceoff_serial += 1
		event = "OVERTIME — SUDDEN DEATH" if period > 3 else "Period "+str(period)+" — ends switched"
	elif phase == Phase.FACEOFF:
		phase = Phase.PLAY
		event = "Play"

func clock_text() -> String:
	var seconds := int(ceil(shootout_remaining if is_shootout() else clock))
	return "%02d:%02d" % [seconds/60,seconds%60]

func penalty_text() -> String:
	var result := ""
	for p in penalties:
		var seconds := int(ceil(p.remaining))
		result += "%s  %s  %d:%02d%s\n" % [team_codes[p.team],p.reason,seconds/60,seconds%60," Q" if not p.active else ""]
	return result.strip_edges()
