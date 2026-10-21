extends RefCounted
## Original one-day junior scouting loop. Ranges are estimates, not verified assessments.
static func candidates(world: Dictionary) -> Dictionary:
	var leagues: Dictionary={}
	for league in world.leagues:
		if league.tier=="junior" and league.region=="NA": leagues[league.id]=true
	var result: Dictionary={}
	var policy: Dictionary=world.draft_policy
	for team in world.teams:
		if not leagues.has(team.league_id): continue
		for player in team.players:
			var age:=int(policy.date.substr(0,4))-int(player.birth_date.substr(0,4))
			if policy.date.substr(5)<player.birth_date.substr(5): age-=1
			if age>=policy.min_age and age<=policy.max_age and player.hl_rights_team_id==null:
				result[player.id]={"player":player,"team":team.id,"league":team.league_id}
	return result

static func rejection(jobs: Array, id_: String, day: int, pool: Dictionary) -> String:
	if day>=62: return "Scouting closes at the end of this regular season."
	if not pool.has(id_): return "Choose an eligible North American junior prospect."
	if jobs.any(func(job): return job.player==id_): return "This prospect already has an assignment or report."
	if jobs.filter(func(job): return job.day==day).size()>=3: return "All three scouts are assigned today. Advance the league day for reports."
	return ""

static func validate(jobs: Variant, world: Dictionary, day: int, whole: Callable) -> bool:
	if not jobs is Array or jobs.size()>186: return false
	var pool:=candidates(world)
	var replay: Array=[]
	for job in jobs:
		if not job is Dictionary or job.keys().size()!=2 or not job.get("player") is String or not whole.call(job.get("day"),0,mini(day,61)): return false
		if not replay.is_empty() and job.day<replay[-1].day: return false
		if not rejection(replay,job.player,int(job.day),pool).is_empty(): return false
		replay.append(job)
	return true

static func report(player: Dictionary, observed_day: int) -> Dictionary:
	var result: Dictionary={"player":player.id,"observed_day":observed_day,"confidence":"preliminary","primary_label":"Reflexes" if player.position=="G" else "Shot accuracy"}
	for field in ["speed","primary_skill","potential"]:
		var actual: int=int(player.potential if field=="potential" else player.ratings[("reflexes" if player.position=="G" else "shot_accuracy") if field=="primary_skill" else field])
		var seed_value: int=(player.id+":"+field).sha256_text().substr(0,7).hex_to_int()
		var radius:=6 if field!="potential" else 10
		var center: int=clampi(actual+seed_value%7-3,0,100)
		result[field]=[maxi(center-radius,0),mini(center+radius,100)]
	return result
