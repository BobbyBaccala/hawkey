extends RefCounted
## Independent cup save slot; commit live state only after validated atomic save.
const Cup=preload("res://scripts/knockout_cup.gd")
const Database=preload("res://scripts/roster_database.gd")
const Store=preload("res://scripts/save_store.gd")
static var database: RefCounted
static var signature:=""
static var cup: RefCounted
static var slot_path:="user://cup/slot-1.json"
static var mode:=""
static var fixture_id:=""
static var controlled_id:=""
static var pending_result: Dictionary={}
static var error:=""
static var notice:=""
static func ensure_database() -> bool:
	if database!=null: return true
	var text:=FileAccess.get_file_as_string(Database.DEFAULT_PATH)
	var candidate:=Database.new()
	if not candidate.load_text(text): error=candidate.error;return false
	database=candidate;signature=text.sha256_text();return true
static func commit(candidate: RefCounted) -> bool:
	var store:=Store.new()
	if not store.save_file(slot_path,"knockout-cup",candidate.state,candidate.validate): error=store.error;return false
	cup=candidate;error="";return true
static func create(club_id: String, seed_value: int=20261021) -> bool:
	if not pending_result.is_empty(): error="Save the pending result before starting again.";return false
	if not ensure_database(): return false
	var candidate:=Cup.new(database,signature)
	if not candidate.create(club_id,seed_value) or not commit(candidate): return false
	fixture_id="";mode="";notice="New cup saved.";return true
static func resume() -> bool:
	if not pending_result.is_empty(): error="Save the pending result before resuming.";return false
	if not ensure_database(): return false
	var candidate:=Cup.new(database,signature);var store:=Store.new()
	var data:=store.load_file(slot_path,"knockout-cup",candidate.validate)
	if data.is_empty(): error=store.error;return false
	candidate.state=data;cup=candidate;fixture_id="";mode="";error=""
	notice=store.error if store.recovered else "Cup resumed.";return true
static func simulate_next() -> bool:
	if cup==null or not pending_result.is_empty(): error="Save the pending played result first.";return false
	var candidate:=Cup.new(database,signature);candidate.state=cup.state.duplicate(true)
	var game: Dictionary=candidate.current_fixture()
	if game.is_empty(): return false
	if not candidate.record(game.id,candidate.simulate()) or not commit(candidate): return false
	notice="Game simulated and saved.";return true
static func prepare_match() -> Array[String]:
	if cup==null or not pending_result.is_empty(): return []
	var game: Dictionary=cup.current_fixture()
	if game.is_empty(): return []
	fixture_id=game.id;mode="cup"
	controlled_id=game.away if game.away==cup.state.club_id else game.home
	var opponent: String=game.home if controlled_id==game.away else game.away
	var ids: Array[String]=[controlled_id,opponent];return ids
static func finish_match(score: Array=[],decision: String="") -> bool:
	if cup==null or fixture_id.is_empty(): return false
	var game: Dictionary=cup.current_fixture()
	if game.is_empty() or game.id!=fixture_id: error="Cup fixture changed.";return false
	if pending_result.is_empty():
		if score.size()!=2: return false
		var result:={"home":score[0] if controlled_id==game.home else score[1],"away":score[1] if controlled_id==game.home else score[0],"decision":decision,"source":"played"}
		if not cup.valid_result(result): error="Invalid played cup result.";return false
		pending_result=result
	var candidate:=Cup.new(database,signature);candidate.state=cup.state.duplicate(true)
	if not candidate.record(fixture_id,pending_result): error=candidate.error;return false
	if not commit(candidate): return false
	pending_result={};fixture_id="";notice="Played result saved to the bracket.";return true
