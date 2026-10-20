extends RefCounted
## Atomic, versioned native loader. Invalid input never replaces a valid snapshot.
const LEGACY_PATH := "res://data/examples/fictional-roster.json"
const DEFAULT_PATH := "res://data/world/fictional-world.json"
var leagues: Array = []
var development_routes: Array = []
var draft_policy: Dictionary = {}
var as_of := ""
var teams: Array = []
var error := ""

func load_file(path: String = DEFAULT_PATH) -> bool:
	if not FileAccess.file_exists(path):
		error = "Roster file not found: " + path
		return false
	return load_text(FileAccess.get_file_as_string(path))

func text_field(value: Variant) -> bool:
	return value is String and not value.strip_edges().is_empty()

func stable_id(value: Variant) -> bool:
	return text_field(value) and not " " in value and not "\n" in value and not "\t" in value and not "\r" in value

func reject(message: String) -> bool:
	error = message
	return false

func load_text(text: String) -> bool:
	var parser := JSON.new()
	if parser.parse(text) != OK:
		return reject("Invalid JSON: " + parser.get_error_message())
	var data: Variant = parser.data
	if not data is Dictionary or (data.get("schema_version") != 1 and data.get("schema_version") != 2) or data.get("database_metadata_version") != 1:
		return reject("Unsupported roster version")
	if not data.get("teams") is Array or data.teams.size() < 2:
		return reject("Play Now requires at least two teams")
	var world: bool = data.schema_version == 2
	var league_ids := {}
	if world and not validate_leagues(data, league_ids): return false
	var team_ids := {}
	var player_ids := {}
	for team in data.teams:
		if not team is Dictionary:
			return reject("Invalid team")
		for key in ["id", "city", "name", "league_id", "season"]:
			if not text_field(team.get(key)):
				return reject("Missing team " + key)
		if not stable_id(team.id) or team_ids.has(team.id):
			return reject("Invalid or duplicate team ID")
		team_ids[team.id] = true
		if world and (not league_ids.has(team.league_id) or team.season != data.season):
			return reject("Unknown league or season mismatch")
		var roster_size: int = int(league_ids[team.league_id].roster_size) if world else 20
		if not team.get("players") is Array or team.players.size() != roster_size:
			return reject("Each team needs 12 forwards, 6 defenders and 2 goalies")
		var jersey_numbers := {}
		var counts := {"C":0,"LW":0,"RW":0,"D":0,"G":0}
		for p in team.players:
			if not p is Dictionary or not stable_id(p.get("id")) or player_ids.has(p.id) or not text_field(p.get("name")):
				return reject("Invalid or duplicate player identity")
			player_ids[p.id] = true
			if world:
				if not validate_player(p, league_ids[team.league_id], data.as_of, jersey_numbers): return false
			if not counts.has(p.get("position", "")):
				return reject("Invalid player position")
			counts[p.position] += 1
			# Licensed real datasets require a separate reviewed adapter; never silently accept one.
			if p.get("identity_kind") not in ["fictional", "generated"] or not p.has("source") or p.get("source") != null:
				return reject("This native fixture loader accepts original identities only")
			var meta: Variant = p.get("rating_metadata")
			if not meta is Dictionary or meta.get("kind") != "estimate" or not text_field(meta.get("method")) or meta.get("confidence") != "unassessed":
				return reject("Ratings require explicit estimate metadata")
			if not p.get("ratings") is Dictionary:
				return reject("Missing ratings")
			for key in ["speed", "acceleration", "agility"]:
				if not p.ratings.has(key): return reject("Missing rating " + key)
			if world:
				var skills := ["stamina","strength","balance","discipline"]
				skills.append_array(["reflexes","glove","blocker","rebound_control","positioning","recovery","puck_handling"] if p.position == "G" else ["passing","puck_control","shot_accuracy","shot_power","offensive_awareness","defensive_awareness","checking","poke_check","faceoffs"])
				for key in skills:
					if not p.ratings.has(key): return reject("Missing position-specific skill: " + key)
				var skill_meta: Variant = p.get("skill_rating_metadata")
				if not skill_meta is Dictionary or skill_meta.get("kind") != "estimate" or skill_meta.get("confidence") != "unassessed" or not text_field(skill_meta.get("method")): return reject("Skills require estimate provenance")
			for value in p.ratings.values():
				if (not value is float and not value is int) or not is_finite(float(value)) or value < 0 or value > 100:
					return reject("Rating outside finite 0–100 range")
				if world and p.potential < value: return reject("Potential below current ability")
		var expected := {"C":4,"LW":4,"RW":4,"D":6,"G":2}
		if roster_size >= 23: expected = {"C":4,"LW":5,"RW":5,"D":7,"G":2}
		if roster_size == 25: expected = {"C":5,"LW":5,"RW":5,"D":7,"G":3}
		if counts != expected:
			return reject("Illegal position coverage")
	if world and not validate_references(data, league_ids): return false
	teams = data.teams.duplicate(true)
	leagues = data.leagues.duplicate(true) if world else []
	development_routes = data.development_routes.duplicate(true) if world else []
	draft_policy = data.draft_policy.duplicate(true) if world else {}
	as_of = data.as_of if world else ""
	error = ""
	return true

func match_roster(team: Dictionary) -> Array:
	var result: Array = []
	for line in range(4):
		for position in ["C", "LW", "RW"]:
			var players: Array = team.players.filter(func(p): return p.position == position)
			result.append(players[line].duplicate(true))
	for position in ["D", "G"]:
		for p in team.players:
			if p.position == position and result.filter(func(v): return v.position == position).size() < (6 if position == "D" else 2):
				result.append(p.duplicate(true))
	# The first 20 are dressed, preserving existing line/penalty indices. Reserves follow.
	var dressed := {}
	for p in result: dressed[p.id] = true
	for p in team.players:
		if not dressed.has(p.id): result.append(p.duplicate(true))
	for i in range(result.size()):
		result[i].merge({"number":result[i].get("jersey_number", i+1),"stamina":1.0,"speed":result[i].ratings.speed,"goals":0,"shots":0})
	return result

func integer_between(value: Variant, low: int, high: int) -> bool:
	return (value is float or value is int) and is_finite(float(value)) and float(value) == floor(float(value)) and value >= low and value <= high

func valid_date(value: Variant) -> bool:
	if not value is String or value.length() != 10 or value[4] != "-" or value[7] != "-": return false
	var pieces: PackedStringArray = value.split("-")
	if pieces.size() != 3: return false
	for part in pieces:
		for c in part:
			if c not in "0123456789": return false
	var y := int(pieces[0])
	var m := int(pieces[1])
	var d := int(pieces[2])
	if y < 1900 or y > 2200 or m < 1 or m > 12: return false
	var days := [31, 29 if y % 400 == 0 or (y % 4 == 0 and y % 100 != 0) else 28, 31,30,31,30,31,31,30,31,30,31]
	return d >= 1 and d <= days[m-1]

func age_at(birth: String, when: String) -> int:
	return int(when.substr(0,4)) - int(birth.substr(0,4)) - (1 if when.substr(5) < birth.substr(5) else 0)

func validate_leagues(data: Dictionary, ids: Dictionary) -> bool:
	if not text_field(data.get("world_id")) or data.get("generator_version") != 1 or not text_field(data.get("identity_policy")): return reject("Invalid world identity/generator metadata")
	if not valid_date(data.get("as_of")) or not text_field(data.get("season")) or not data.get("leagues") is Array:
		return reject("Missing world date, season or leagues")
	for league in data.leagues:
		if not league is Dictionary or not stable_id(league.get("id")) or ids.has(league.id) or not text_field(league.get("name")):
			return reject("Invalid or duplicate league")
		if not league.has("parent_league_id"): return reject("Missing league parent")
		if league.get("tier") not in ["top", "minor", "junior", "europe", "youth"] or not league.get("play_now") is bool:
			return reject("Invalid league tier/playability")
		if not integer_between(league.get("team_count"),2,100) or (league.get("roster_size") != 20 and league.get("roster_size") != 23 and league.get("roster_size") != 25):
			return reject("Invalid league roster/team limits")
		if not integer_between(league.get("min_age"),5,40) or not integer_between(league.get("max_age"),league.min_age,50):
			return reject("Invalid league age limits")
		if league.tier == "youth" and league.play_now: return reject("Youth needs age-appropriate match rules before Play Now")
		ids[league.id] = league
	if not ids.has("hl") or ids.hl.tier != "top" or ids.hl.team_count != 32:
		return reject("HL requires 32 top-league clubs")
	for league in data.leagues:
		if not league.has("parent_league_id"): return reject("Missing parent league field")
		if league.tier == "minor" and league.parent_league_id == null: return reject("Farm league requires a parent")
		if league.parent_league_id != null:
			if not ids.has(league.parent_league_id) or league.parent_league_id == league.id: return reject("Unknown parent league")
			if league.tier != "minor" or ids[league.parent_league_id].tier not in ["minor","top"]: return reject("Invalid farm league hierarchy")
	for league in data.leagues:
		var visited := {}
		var cursor: Dictionary = league
		while cursor.parent_league_id != null:
			if visited.has(cursor.id): return reject("Farm league cycle")
			visited[cursor.id] = true
			cursor = ids[cursor.parent_league_id]
	var policy: Variant = data.get("draft_policy")
	if not policy is Dictionary or not valid_date(policy.get("date")) or policy.date < data.as_of or policy.get("min_age") != 18 or policy.get("max_age") != 20 or policy.get("rights_required") != "unowned":
		return reject("Invalid HL draft policy")
	if not data.get("development_routes") is Array: return reject("Missing development routes")
	var route_sources := {}
	for route in data.development_routes:
		if not route is Dictionary or not ids.has(route.get("from_league_id", "")) or route_sources.has(route.from_league_id) or not route.get("to_league_ids") is Array or route.to_league_ids.is_empty(): return reject("Invalid development route")
		route_sources[route.from_league_id] = route.to_league_ids
		var destinations := {}
		for target in route.to_league_ids:
			if not ids.has(target) or target == route.from_league_id or destinations.has(target): return reject("Broken/duplicate development destination")
			destinations[target] = true
	for league in data.leagues:
		if league.id != "hl" and not reaches_hl(league.id, route_sources, {}): return reject("Development route must reach HL without cycles")
	return true

func validate_player(p: Dictionary, league: Dictionary, date_: String, numbers: Dictionary) -> bool:
	if not valid_date(p.get("birth_date")): return reject("Invalid birth date")
	var age := age_at(p.birth_date, date_)
	if age < league.min_age or age > league.max_age: return reject("Player outside league age limits")
	if not integer_between(p.get("jersey_number"),1,99) or numbers.has(p.jersey_number): return reject("Invalid/duplicate jersey number")
	numbers[p.jersey_number] = true
	if p.get("shoots") not in ["L","R"] or not text_field(p.get("nationality")) or p.nationality.length() != 2 or p.nationality != p.nationality.to_upper(): return reject("Missing player profile")
	if not integer_between(p.get("height_cm"),100,230) or not integer_between(p.get("weight_kg"),20,150) or not integer_between(p.get("potential"),0,100): return reject("Invalid development profile")
	if not p.has("hl_rights_team_id"): return reject("Missing rights ownership")
	return true

func validate_references(data: Dictionary, league_ids: Dictionary) -> bool:
	var team_ids := {}
	var counts := {}
	var affiliations := {}
	var codes := {}
	for team in data.teams:
		team_ids[team.id] = team
		counts[team.league_id] = counts.get(team.league_id,0) + 1
	for league in data.leagues:
		if counts.get(league.id,0) != league.team_count: return reject("Incomplete league: " + league.id)
	for team in data.teams:
		var parent: Variant = league_ids[team.league_id].parent_league_id
		if not team.has("affiliate_of") or not text_field(team.get("code")) or team.code.length() > 3: return reject("Missing team affiliation/code")
		var code_key: String = team.league_id + ":" + team.code
		if codes.has(code_key): return reject("Duplicate team code within league")
		codes[code_key] = true
		if parent == null:
			if team.affiliate_of != null: return reject("Unexpected team affiliate")
		else:
			if not team_ids.has(team.affiliate_of) or team_ids[team.affiliate_of].league_id != parent: return reject("Broken farm affiliation")
			var key: String = team.league_id + ":" + team.affiliate_of
			if affiliations.has(key): return reject("Duplicate farm affiliate")
			affiliations[key] = true
		for p in team.players:
			if p.hl_rights_team_id != null:
				if not team_ids.has(p.hl_rights_team_id) or team_ids[p.hl_rights_team_id].league_id != "hl": return reject("Rights owner must be an HL club")
			if league_ids[team.league_id].tier == "youth" and p.hl_rights_team_id != null: return reject("Youth rights cannot be preassigned")
	return true

func draft_pool(when: String = "") -> Array:
	var result: Array = []
	var date_: String = draft_policy.get("date", "") if when.is_empty() else when
	if not valid_date(date_): return result
	for team in teams:
		for p in team.players:
			if p.get("hl_rights_team_id") == null and valid_date(p.get("birth_date")):
				var age := age_at(p.birth_date,date_)
				if age >= 18 and age <= 20: result.append(p.duplicate(true))
	return result

func reaches_hl(id_: String, routes: Dictionary, visited: Dictionary) -> bool:
	if id_ == "hl": return true
	if visited.has(id_) or not routes.has(id_): return false
	var next := visited.duplicate()
	next[id_] = true
	for target in routes[id_]:
		if not reaches_hl(target, routes, next): return false
	return true
