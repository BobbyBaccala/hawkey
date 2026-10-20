extends RefCounted
## Atomic, versioned native loader. Invalid input never replaces a valid snapshot.
const DEFAULT_PATH := "res://data/examples/fictional-roster.json"
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
	return text_field(value) and not " " in value and not "\n" in value and not "\t" in value

func reject(message: String) -> bool:
	error = message
	return false

func load_text(text: String) -> bool:
	var parser := JSON.new()
	if parser.parse(text) != OK:
		return reject("Invalid JSON: " + parser.get_error_message())
	var data: Variant = parser.data
	if not data is Dictionary or data.get("schema_version") != 1 or data.get("database_metadata_version") != 1:
		return reject("Unsupported roster version")
	if not data.get("teams") is Array or data.teams.size() < 2:
		return reject("Play Now requires at least two teams")
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
		if not team.get("players") is Array or team.players.size() != 20:
			return reject("Each team needs 12 forwards, 6 defenders and 2 goalies")
		var counts := {"C":0,"LW":0,"RW":0,"D":0,"G":0}
		for p in team.players:
			if not p is Dictionary or not stable_id(p.get("id")) or player_ids.has(p.id) or not text_field(p.get("name")):
				return reject("Invalid or duplicate player identity")
			player_ids[p.id] = true
			if not counts.has(p.get("position", "")):
				return reject("Invalid player position")
			counts[p.position] += 1
			# Licensed real datasets require a separate reviewed adapter; never silently accept one.
			if p.get("identity_kind") not in ["fictional", "generated"] or p.get("source") != null:
				return reject("This native fixture loader accepts original identities only")
			var meta: Variant = p.get("rating_metadata")
			if not meta is Dictionary or meta.get("kind") != "estimate" or not text_field(meta.get("method")) or meta.get("confidence") != "unassessed":
				return reject("Ratings require explicit estimate metadata")
			if not p.get("ratings") is Dictionary:
				return reject("Missing ratings")
			for key in ["speed", "acceleration", "agility"]:
				if not p.ratings.has(key): return reject("Missing rating " + key)
			for value in p.ratings.values():
				if (not value is float and not value is int) or not is_finite(float(value)) or value < 0 or value > 100:
					return reject("Rating outside finite 0–100 range")
		if counts != {"C":4,"LW":4,"RW":4,"D":6,"G":2}:
			return reject("Illegal position coverage")
	teams = data.teams.duplicate(true)
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
			if p.position == position: result.append(p.duplicate(true))
	for i in range(result.size()):
		result[i].merge({"number":i+1,"stamina":1.0,"speed":result[i].ratings.speed,"goals":0,"shots":0})
	return result
