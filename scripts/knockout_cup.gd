extends RefCounted
## Eight-team, single-elimination competition. Results replay the bracket on load.
var state: Dictionary={}
var database: RefCounted
var signature:=""
var error:=""
func _init(db: RefCounted=null, world_signature: String="") -> void:
	database=db;signature=world_signature
func club(id_: String) -> Dictionary:
	for team in database.teams:
		if team.id==id_: return team
	return {}
func integer(value: Variant, maximum: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value)==floor(float(value)) and value>=0 and value<=maximum
func valid_result(result: Variant) -> bool:
	if not result is Dictionary: return false
	if not integer(result.get("home"),99) or not integer(result.get("away"),99) or result.home==result.away: return false
	if not result.get("decision") in ["REG","OT","SO"] or not result.get("source") in ["played","simulated"]: return false
	return result.decision=="REG" or absf(result.home-result.away)==1
func fixtures(data: Dictionary={}) -> Array:
	if data.is_empty(): data=state
	if data.is_empty(): return []
	var participants: Array=data.teams.duplicate()
	var games: Array=[];var cursor:=0;var round_:=0
	while participants.size()>1:
		var winners: Array=[]
		for i in range(0,participants.size(),2):
			var result: Dictionary=data.results[cursor] if cursor<data.results.size() else {}
			games.append({"id":"cup-%d"%(cursor+1),"round":round_,"home":participants[i],"away":participants[i+1],"result":result})
			if not result.is_empty(): winners.append(participants[i] if result.home>result.away else participants[i+1])
			cursor+=1
		if winners.size()!=participants.size()/2: break
		participants=winners;round_+=1
	return games
func validate(data: Dictionary) -> bool:
	if database==null or data.get("schema")!=1 or data.get("world_signature")!=signature or signature.is_empty(): return false
	if not integer(data.get("seed"),2147483647) or not data.get("teams") is Array or data.teams.size()!=8: return false
	var seen: Dictionary={}
	for id_ in data.teams:
		if not id_ is String or seen.has(id_): return false
		var team:=club(id_)
		if team.is_empty() or team.league_id!="hl": return false
		seen[id_]=true
	if not data.get("club_id") in data.teams or not data.get("results") is Array or data.results.size()>7: return false
	for result in data.results:
		if not valid_result(result): return false
	var games:=fixtures(data)
	if data.results.size()>games.size(): return false
	for i in range(data.results.size()):
		if data.results[i].get("id")!=games[i].id: return false
	return true
func create(club_id: String, seed_value: int=20261021) -> bool:
	if database==null or not integer(seed_value,2147483647): return false
	var eligible: Array=database.teams.filter(func(t): return t.league_id=="hl").map(func(t): return t.id)
	if not club_id in eligible: return false
	eligible.erase(club_id)
	var rng:=RandomNumberGenerator.new();rng.seed=seed_value
	for i in range(eligible.size()-1,0,-1):
		var j:=rng.randi_range(0,i);var swap: Variant=eligible[i];eligible[i]=eligible[j];eligible[j]=swap
	var teams: Array=[club_id];teams.append_array(eligible.slice(0,7))
	var candidate:={"schema":1,"world_signature":signature,"club_id":club_id,"seed":seed_value,"teams":teams,"results":[]}
	if not validate(candidate): return false
	state=candidate;return true
func current_fixture() -> Dictionary:
	for game in fixtures():
		if game.result.is_empty(): return game
	return {}
func champion() -> String:
	if state.is_empty() or state.results.size()!=7: return ""
	var game: Dictionary=fixtures()[-1]
	return game.home if game.result.home>game.result.away else game.away
func record(id_: String, result: Dictionary) -> bool:
	var game:=current_fixture()
	if game.is_empty() or game.id!=id_ or not valid_result(result):
		error="This result does not match the next cup game.";return false
	var candidate: Dictionary=state.duplicate(true)
	var entry: Dictionary=result.duplicate(true);entry.id=id_;candidate.results.append(entry)
	if not validate(candidate): error="Cup result failed validation.";return false
	state=candidate;error="";return true
func strength(id_: String) -> float:
	var team:=club(id_);var total:=0.0;var count_:=0
	for player in team.players:
		if player.position!="G": total+=float(player.ratings.speed);count_+=1
	return total/maxi(count_,1)
func simulate() -> Dictionary:
	var game:=current_fixture()
	if game.is_empty(): return {}
	var rng:=RandomNumberGenerator.new();rng.seed=(str(state.seed)+":"+game.id).sha256_text().substr(0,15).hex_to_int()
	var scores: Array[int]=[0,0]
	var difference:=strength(game.home)-strength(game.away)
	for side in range(2):
		var probability:=clampf(0.25+difference*0.004*(1 if side==0 else -1)+(0.015 if side==0 else 0),0.12,0.4)
		for chance in range(12):
			if rng.randf()<probability: scores[side]+=1
	var decision:="REG"
	if scores[0]==scores[1]:
		decision="OT" if rng.randf()<0.6 else "SO";scores[rng.randi_range(0,1)]+=1
	return {"home":scores[0],"away":scores[1],"decision":decision,"source":"simulated"}
