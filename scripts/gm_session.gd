extends RefCounted
const Season=preload("res://scripts/gm_season.gd")
const Store=preload("res://scripts/save_store.gd")
static var slot_path:="user://gm/slot-1.json"
static var season: RefCounted
static var fixture_id:=""
static var error:=""
static var notice:=""
static var pending_result: Dictionary={}
static var checkpoint_active:=false

static func save() -> bool:
	if checkpoint_active:
		error="Wait for the current checkpoint to finish."
		return false
	if season==null: return false
	var store:=Store.new()
	if not store.save_file(slot_path,"gm-season",season.state,season.validate):
		error=store.error
		return false
	error=""
	return true

static func resume() -> bool:
	if checkpoint_active:
		error="Wait for the current checkpoint to finish."
		return false
	var candidate:=Season.new()
	var store:=Store.new()
	var data:=store.load_file(slot_path,"gm-season",candidate.validate)
	if data.is_empty():
		error=store.error
		return false
	if not candidate.load_state(data):
		error=candidate.error
		return false
	season=candidate;fixture_id="";pending_result={};error=""
	notice=store.error if store.recovered else ("Save upgraded in memory; next save writes the current format." if store.migrated else "Season resumed.")
	return true

static func create(club: String, seed_value: int=20261020) -> bool:
	if checkpoint_active:
		error="Wait for the current checkpoint to finish."
		return false
	var candidate:=Season.new()
	if not candidate.new_season(FileAccess.get_file_as_string(Season.Database.DEFAULT_PATH),club,seed_value):
		error=candidate.error
		return false
	var previous:=season
	season=candidate
	if not save():
		season=previous
		return false
	fixture_id="";pending_result={};notice="New season saved."
	return true

static func advance_day() -> bool:
	if checkpoint_active:
		error="Wait for the current checkpoint to finish."
		return false
	if not pending_result.is_empty():
		error="Save the pending played result before advancing."
		return false
	if season==null: return false
	var before: Dictionary=season.state.duplicate(true)
	if not season.simulate_day():
		error=season.error
		return false
	if not save():
		season.state=before
		return false
	notice="Day complete. All league results and standings saved."
	return true

static func finish_match(score: Array, decision: String) -> bool:
	if checkpoint_active:
		error="Wait for the current checkpoint to finish."
		return false
	if season==null or fixture_id.is_empty(): return false
	var fixture: Dictionary=season.current_fixture()
	if fixture.is_empty() or fixture.id!=fixture_id:
		error="The scheduled game no longer matches this session."
		return false
	if pending_result.is_empty():
		var managed_home: bool=fixture.home==season.state.club_id
		pending_result={"home":score[0] if managed_home else score[1],"away":score[1] if managed_home else score[0],"decision":decision,"source":"played"}
	if fixture.result.is_empty() and not season.record_result(fixture_id,pending_result):
		error=season.error
		return false
	if not save(): return false
	pending_result={};fixture_id="";notice="Your game result was saved. Simulate the rest of the day to advance."
	return true
