extends RefCounted
## Authoritative clock, period, score and timed minor-penalty eligibility.
enum Phase { FACEOFF, PLAY, STOPPAGE, INTERMISSION, FINAL }
var phase := Phase.FACEOFF
var period := 1
var period_seconds := 1200.0
var clock := 1200.0
var clock_rate := 4.0
var phase_timer := 2.0
var score: Array[int] = [0,0]
var penalties: Array[Dictionary] = []
var event := "Opening faceoff"
var ended_period := false
var faceoff_serial := 0

func count(team: int) -> int:
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
	if phase == Phase.FINAL or penalized(team,roster_id): return false
	var starts := active_penalties(team).size() < 2
	penalties.append({"team":team,"roster_id":roster_id,"reason":reason,"remaining":duration,"active":starts})
	event = ("TOR" if team == 0 else "MTL")+" — "+reason+"  2:00"
	phase = Phase.STOPPAGE
	phase_timer = 2.2
	return true

func goal(team: int) -> void:
	if phase != Phase.PLAY: return
	var opponent := 1-team
	# A power-play goal releases the oldest active minor only while advantaged.
	if count(team) > count(opponent):
		for i in range(penalties.size()):
			if penalties[i].team == opponent and penalties[i].active:
				penalties.remove_at(i)
				break
		activate_queued()
	score[team] += 1
	event = ("TORONTO" if team == 0 else "MONTREAL")+" GOAL"
	phase = Phase.STOPPAGE
	phase_timer = 3.0

func activate_queued() -> void:
	for team in range(2):
		var running := active_penalties(team).size()
		for p in penalties:
			if p.team == team and not p.active and running < 2:
				p.active = true
				running += 1

func advance(delta: float) -> void:
	if phase == Phase.FINAL: return
	if phase == Phase.PLAY:
		var game_delta := minf(clock,delta * clock_rate)
		clock = maxf(0,clock-game_delta)
		for p in penalties:
			if p.active: p.remaining = maxf(0,p.remaining-game_delta)
		for i in range(penalties.size()-1,-1,-1):
			if penalties[i].remaining <= 0: penalties.remove_at(i)
		activate_queued()
		if clock <= 0:
			if period >= 3:
				phase = Phase.FINAL
				event = "FINAL" if score[0] != score[1] else "FINAL — DRAW (overtime not implemented)"
			else:
				phase = Phase.INTERMISSION
				phase_timer = 5.0
				event = "END OF PERIOD "+str(period)
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
		clock = period_seconds
		phase = Phase.FACEOFF
		phase_timer = 2.0
		faceoff_serial += 1
		event = "Period "+str(period)+" — ends switched"
	elif phase == Phase.FACEOFF:
		phase = Phase.PLAY
		event = "Play"

func clock_text() -> String:
	var seconds := int(ceil(clock))
	return "%02d:%02d" % [seconds/60,seconds%60]

func penalty_text() -> String:
	var result := ""
	for p in penalties:
		var seconds := int(ceil(p.remaining))
		result += "%s  %s  %d:%02d%s\n" % ["TOR" if p.team==0 else "MTL",p.reason,seconds/60,seconds%60," Q" if not p.active else ""]
	return result.strip_edges()
