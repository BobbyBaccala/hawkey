extends RefCounted
## Original, deterministic single-season HL alpha with versioned management overlay.
const Management=preload("res://scripts/gm_management.gd")
const Database=preload("res://scripts/roster_database.gd")
var state: Dictionary={}
var database:=Database.new()
var error:=""
var strengths: Dictionary={}

func new_season(world_text: String, club: String, seed_value: int=20261020) -> bool:
	if not database.load_text(world_text):
		error=database.error
		return false
	var ids: Array=database.teams.filter(func(t): return t.league_id=="hl").map(func(t): return t.id)
	ids.sort()
	if ids.size()!=32 or club not in ids:
		error="Choose one of the 32 HL clubs."
		return false
	var world: Dictionary=JSON.parse_string(world_text)
	state={"schema_version":1,"season":world.season,"club_id":club,"seed":seed_value,"day":0,"team_ids":ids,"world":world,"fixtures":schedule(ids)}
	ensure_management()
	cache_strengths()
	error=""
	return true

func schedule(ids: Array) -> Array:
	var rotation:=ids.duplicate()
	var first: Array=[]
	for round_ in range(ids.size()-1):
		for pair in range(ids.size()/2):
			var home: String=rotation[pair]
			var away: String=rotation[ids.size()-1-pair]
			if (round_+pair)%2==1:
				var swap:=home;home=away;away=swap
			first.append({"id":"hl-%02d-%02d"%[round_,pair],"day":round_,"home":home,"away":away,"result":{}})
		rotation.insert(1,rotation.pop_back())
	var result:=first.duplicate(true)
	for fixture in first:
		result.append({"id":fixture.id+"-r","day":int(fixture.day)+31,"home":fixture.away,"away":fixture.home,"result":{}})
	return result

func whole(value: Variant, minimum: int, maximum: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value==floor(float(value)) and value>=minimum and value<=maximum

func validate(data: Dictionary) -> bool:
	if data.get("schema_version")!=1 or not whole(data.get("day"),0,62) or not whole(data.get("seed"),0,2147483647): return false
	if not data.get("world") is Dictionary or not data.get("team_ids") is Array or not data.get("fixtures") is Array: return false
	var db:=Database.new()
	if not db.load_text(JSON.stringify(data.world)): return false
	var ids: Array=db.teams.filter(func(t): return t.league_id=="hl").map(func(t): return t.id)
	ids.sort()
	if ids.size()!=32 or data.team_ids!=ids or data.get("club_id") not in ids or data.get("season")!=data.world.season: return false
	var expected:=schedule(ids)
	if data.fixtures.size()!=expected.size(): return false
	for i in range(expected.size()):
		var fixture: Variant=data.fixtures[i]
		if not fixture is Dictionary: return false
		for key in ["id","day","home","away"]:
			if fixture.get(key)!=expected[i][key]: return false
		if not fixture.get("result") is Dictionary: return false
		if fixture.result.is_empty():
			if fixture.day<data.day: return false
		else:
			if fixture.day>data.day or not valid_result(fixture.result): return false
	if data.has("management") and not Management.validate(data.management,data.world,ids,int(data.day),whole): return false
	return true

func load_state(data: Dictionary) -> bool:
	if not validate(data):
		error="Invalid GM season. Existing season retained."
		return false
	state=data.duplicate(true)
	database.load_text(JSON.stringify(state.world))
	ensure_management()
	cache_strengths()
	error=""
	return true

func valid_result(result: Dictionary) -> bool:
	if result.get("decision") not in ["REG","OT","SO"] or result.get("source") not in ["simulated","played"]: return false
	if not whole(result.get("home"),0,100) or not whole(result.get("away"),0,100) or result.home==result.away: return false
	return result.decision=="REG" or absf(result.home-result.away)==1

func cache_strengths() -> void:
	strengths.clear()
	for team in database.teams:
		if team.league_id!="hl": continue
		var attack:=0.0
		var active: Dictionary=Management.active_team(state.management,team) if state.has("management") else team
		for p in active.players:
			attack+=float(p.ratings.get("shot_accuracy",p.ratings.get("reflexes",50)))
		strengths[team.id]=attack/active.players.size()

func club(id_: String) -> Dictionary:
	for team in database.teams:
		if team.id==id_: return team
	return {}

func current_fixture() -> Dictionary:
	if state.is_empty(): return {}
	for fixture in state.fixtures:
		if fixture.day==state.day and state.club_id in [fixture.home,fixture.away]: return fixture
	return {}

func record_result(id_: String, result: Dictionary) -> bool:
	if not valid_result(result):
		error="Invalid game result."
		return false
	for fixture in state.fixtures:
		if fixture.id==id_ and fixture.day==state.day and fixture.result.is_empty():
			fixture.result=result.duplicate(true)
			error=""
			return true
	error="Game already recorded or not on the current day."
	return false

func simulate(fixture: Dictionary) -> Dictionary:
	var rng:=RandomNumberGenerator.new()
	# Stable fixture-local seed; independent of navigation/reload/call order.
	rng.seed=(str(state.seed)+":"+fixture.id).sha256_text().substr(0,15).hex_to_int()
	var scores: Array[int]=[0,0]
	for side in range(2):
		var own: String=fixture.home if side==0 else fixture.away
		var opponent: String=fixture.away if side==0 else fixture.home
		var probability:=clampf(0.25+(strengths[own]-strengths[opponent])*0.004+(0.015 if side==0 else 0),0.12,0.4)
		for chance in range(12):
			if rng.randf()<probability: scores[side]+=1
	var decision:="REG"
	if scores[0]==scores[1]:
		decision="OT" if rng.randf()<0.6 else "SO"
		scores[rng.randi_range(0,1)]+=1
	return {"home":scores[0],"away":scores[1],"decision":decision,"source":"simulated"}

func simulate_day() -> bool:
	if state.is_empty() or state.day>=62:
		error="Regular season complete."
		return false
	for fixture in state.fixtures:
		if fixture.day==state.day and fixture.result.is_empty(): fixture.result=simulate(fixture)
	state.day+=1
	error=""
	return true

func standings() -> Array:
	var rows: Dictionary={}
	for id_ in state.team_ids:
		rows[id_]={"id":id_,"gp":0,"w":0,"l":0,"otl":0,"pts":0,"gf":0,"ga":0,"rw":0}
	for fixture in state.fixtures:
		if fixture.result.is_empty(): continue
		var result: Dictionary=fixture.result
		for side in range(2):
			var row: Dictionary=rows[fixture.home if side==0 else fixture.away]
			var own: int=int(result.home if side==0 else result.away)
			var other: int=int(result.away if side==0 else result.home)
			row.gp+=1;row.gf+=own;row.ga+=other
			if own>other:
				row.w+=1;row.pts+=2
				if result.decision=="REG": row.rw+=1
			elif result.decision=="REG": row.l+=1
			else: row.otl+=1;row.pts+=1
	var result: Array=rows.values()
	result.sort_custom(func(a,b):
		if a.pts!=b.pts: return a.pts>b.pts
		if a.rw!=b.rw: return a.rw>b.rw
		if a.gf-a.ga!=b.gf-b.ga: return a.gf-a.ga>b.gf-b.ga
		return a.id<b.id)
	return result

func ensure_management() -> void:
	if not state.has("management"): state.management=Management.initial(state.world)

func match_roster(id_: String) -> Array:
	return database.match_roster(Management.active_team(state.management,club(id_)))

func sign_free_agent(id_: String, aav: Variant, years: Variant) -> bool:
	if state.is_empty() or state.day>=62:
		error="The regular-season market is closed."
		return false
	var fixture:=current_fixture()
	if not fixture.is_empty() and not fixture.result.is_empty():
		error="Advance the completed league day before changing the roster."
		return false
	error=Management.rejection(state.management,state.club_id,id_,aav,years,whole)
	if not error.is_empty(): return false
	state.management.contracts[id_]={"club":state.club_id,"aav":aav,"years":years}
	state.management.transactions.append({"sequence":state.management.transactions.size()+1,"day":state.day,"club":state.club_id,"player":id_,"aav":aav,"years":years})
	cache_strengths()
	return true

func team_statistics() -> Array:
	var rows:=standings()
	for row in rows:
		row.gd=int(row.gf)-int(row.ga)
		row.pts_pct=float(row.pts)/(2*row.gp) if row.gp>0 else 0.0
		row.gf_gp=float(row.gf)/row.gp if row.gp>0 else 0.0
		row.ga_gp=float(row.ga)/row.gp if row.gp>0 else 0.0
		row.home_w=0;row.away_w=0;row.shutouts=0
		row.payroll=Management.payroll(state.management,row.id)
	for fixture in state.fixtures:
		if fixture.result.is_empty(): continue
		for row in rows:
			if row.id not in [fixture.home,fixture.away]: continue
			var home: bool=row.id==fixture.home
			var own: int=int(fixture.result.home if home else fixture.result.away)
			var other: int=int(fixture.result.away if home else fixture.result.home)
			if other==0: row.shutouts+=1
			if own>other:
				if home: row.home_w+=1
				else: row.away_w+=1
	return rows

func season_records() -> Array:
	var records: Array=[]
	for f in state.fixtures:
		if f.result.is_empty(): continue
		records.append({"fixture":f,"total":int(f.result.home)+int(f.result.away),"margin":absi(int(f.result.home)-int(f.result.away))})
	records.sort_custom(func(a,b): return a.total>b.total if a.total!=b.total else a.fixture.id<b.fixture.id)
	return records

func assign_scout(id_: String) -> bool:
	var pool:=Management.Scouting.candidates(state.world)
	error=Management.Scouting.rejection(state.management.scouting_jobs,id_,int(state.day),pool)
	if not error.is_empty(): return false
	state.management.scouting_jobs.append({"player":id_,"day":state.day})
	return true

func scouting_report(id_: String) -> Dictionary:
	for job in state.management.scouting_jobs:
		if job.player==id_ and job.day<state.day:
			var pool:=Management.Scouting.candidates(state.world)
			return Management.Scouting.report(pool[id_].player,int(job.day)+1)
	return {}
