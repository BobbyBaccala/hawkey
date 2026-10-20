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
	check(db.load_file(), "World loads: " + db.error)
	if db.teams.is_empty(): quit(1); return
	check(db.leagues.size() == 33 and db.teams.size() == 643, "Complete league coverage")
	var players := 0
	for team in db.teams:
		players += team.players.size()
		var roster := db.match_roster(team)
		check(roster.size() == team.players.size(), "Reserves preserved")
		check(roster[0].position == "C" and roster[11].position == "RW" and roster[12].position == "D" and roster[17].position == "D" and roster[18].position == "G" and roster[19].position == "G", "Dressed positions stay legal")
	check(players == 14745, "All player records present")
	var pool := db.draft_pool()
	check(not pool.is_empty(), "Draft class exists")
	for p in pool:
		check(p.hl_rights_team_id == null and db.age_at(p.birth_date,db.draft_policy.date) in [18,19,20], "Only age-eligible unowned prospects")
	check(db.age_at("2009-09-15","2027-09-15") == 18 and db.age_at("2009-09-16","2027-09-15") == 17, "Birthday cutoff")
	check(db.valid_date("2008-02-29") and not db.valid_date("2009-02-29") and not db.valid_date("2026-02-30"), "Calendar validation")
	var original: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Database.DEFAULT_PATH))
	# Mutate one thing at a time; every failure must retain the accepted world.
	var count := db.teams.size()
	var cases: Array = [
		["unknown league", func(d): d.teams[0].league_id = "missing"],
		["missing HL club", func(d): d.teams.remove_at(0)],
		["duplicate player", func(d): d.teams[1].players[0].id = d.teams[0].players[0].id],
		["rights target", func(d): d.teams[0].players[0].hl_rights_team_id = "missing"],
		["birth date", func(d): d.teams[0].players[0].birth_date = "2026-02-30"],
		["age eligibility", func(d): d.teams[0].players[0].birth_date = "2020-01-01"],
		["jersey collision", func(d): d.teams[0].players[1].jersey_number = d.teams[0].players[0].jersey_number],
		["unknown affiliate", func(d): d.teams[32].affiliate_of = "missing"],
		["wrong affiliate tier", func(d): d.teams[32].affiliate_of = "hdb-01"],
		["bad route", func(d): d.development_routes[0].to_league_ids = ["missing"]],
		["bad draft", func(d): d.draft_policy.min_age = 16],
		["missing parent field", func(d): d.leagues[2].erase("parent_league_id")],
		["missing farm parent", func(d): d.leagues[1].parent_league_id = null],
		["code collision", func(d): d.teams[1].code = d.teams[0].code],
		["missing route", func(d): d.development_routes.pop_back()],
		["development cycle", func(d): d.development_routes[-1].to_league_ids = ["y-u9"]],
		["potential below rating", func(d): d.teams[0].players[0].potential = 1],
		["unsupported generator", func(d): d.generator_version = 2],
		["parent cycle", func(d): d.leagues[1].parent_league_id = "hdb"],
	]
	for test in cases:
		var broken := original.duplicate(true)
		test[1].call(broken)
		check(not db.load_text(JSON.stringify(broken)), "Reject " + test[0])
		check(db.teams.size() == count and db.leagues.size() == 33 and not db.error.is_empty(), "Preserve accepted world after " + test[0])
	print("World database: %d checks; %d failures; %d draft candidates" % [checks,failures,pool.size()])
	quit(failures)
