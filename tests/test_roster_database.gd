extends SceneTree
const Database = preload("res://scripts/roster_database.gd")
var failures := 0
var checks := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		push_error(message)
		failures += 1
func _initialize() -> void:
	var db := Database.new()
	check(db.load_file(Database.LEGACY_PATH), "Complete original fixture loads: " + db.error)
	var original: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Database.LEGACY_PATH))
	for team in db.teams:
		var roster := db.match_roster(team)
		check(roster.size() == 20, "20 dressed players")
		check(roster[0].position == "C" and roster[11].position == "RW" and roster[12].position == "D" and roster[18].position == "G", "Legal line layout independent of JSON sort")
		roster[0].name = "Changed locally"
		check(db.match_roster(team)[0].name != "Changed locally", "Match snapshots isolated")
	var bad_cases: Array = []
	var bad := original.duplicate(true)
	bad.schema_version = 2
	bad_cases.append(bad)
	bad = original.duplicate(true)
	bad.database_metadata_version = 2
	bad_cases.append(bad)
	bad = original.duplicate(true)
	bad.teams[1].id = bad.teams[0].id
	bad_cases.append(bad)
	bad = original.duplicate(true)
	bad.teams[1].players[0].id = bad.teams[0].players[0].id
	bad_cases.append(bad)
	bad = original.duplicate(true)
	bad.teams[0].players.pop_back()
	bad_cases.append(bad)
	bad = original.duplicate(true)
	bad.teams[0].players[0].position = "G"
	bad_cases.append(bad)
	for value in [-1, 101, "80", true, null]:
		bad = original.duplicate(true)
		bad.teams[0].players[0].ratings.speed = value
		bad_cases.append(bad)
	for key in ["ratings", "rating_metadata", "id", "name"]:
		bad = original.duplicate(true)
		bad.teams[0].players[0].erase(key)
		bad_cases.append(bad)
	bad = original.duplicate(true)
	bad.teams[0].players[0].identity_kind = "real"
	bad_cases.append(bad)
	bad = original.duplicate(true)
	bad.teams[0].players[0].rating_metadata.kind = "verified"
	bad_cases.append(bad)
	for item in bad_cases:
		check(not db.load_text(JSON.stringify(item)), "Reject invalid roster")
		check(db.teams == original.teams and not db.error.is_empty(), "Failure preserves prior snapshot and explains error")
	check(not db.load_text("{broken"), "Reject malformed JSON")
	check(not db.load_file("res://missing-roster.json"), "Reject missing file")
	check(db.teams == original.teams, "I/O failure preserves snapshot")
	print("Native roster: %d checks; %d failures" % [checks, failures])
	quit(failures)
