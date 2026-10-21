extends SceneTree
const Session=preload("res://scripts/event_session.gd")
const Cup=preload("res://scripts/knockout_cup.gd")
var failures:=0
var checks:=0
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok: failures+=1;push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	Session.slot_path="res://build/cup-test/slot.json"
	for suffix in ["",".bak",".tmp",".bak.tmp"]:
		if FileAccess.file_exists(Session.slot_path+suffix): DirAccess.remove_absolute(Session.slot_path+suffix)
	check(Session.ensure_database(),"Load production world")
	var clubs: Array=Session.database.teams.filter(func(t): return t.league_id=="hl")
	check(Session.create(clubs[0].id,42),"Create and save seeded cup")
	var initial: Dictionary=Session.cup.state.duplicate(true)
	var other:=Cup.new(Session.database,Session.signature);other.create(clubs[0].id,42)
	check(other.state==initial,"Seeded draw reproducible")
	check(initial.teams.size()==8 and Session.cup.fixtures().size()==4,"Eight clubs and four quarterfinals")
	check(not Session.cup.record("cup-1",{"home":2,"away":2,"decision":"REG","source":"played"}),"Reject tied knockout result")
	check(not Session.cup.record("cup-9",{"home":2,"away":1,"decision":"REG","source":"played"}),"Reject stale/out-of-order fixture")
	var invalid: Dictionary=initial.duplicate(true);invalid.teams[1]=invalid.teams[0]
	check(not Session.cup.validate(invalid),"Reject repeated club")
	invalid=initial.duplicate(true);invalid.world_signature="changed"
	check(not Session.cup.validate(invalid),"Reject mismatched world snapshot")
	var id_: String=Session.cup.current_fixture().id
	Session.cup.state.club_id=Session.cup.current_fixture().away
	var ids:=Session.prepare_match()
	check(ids[0]==Session.cup.state.club_id,"Away club maps to controlled side")
	check(not Session.finish_match([2,2],"REG") and Session.pending_result.is_empty(),"Invalid result cannot lock pending state")
	check(Session.finish_match([4,2],"REG"),"Played away result saved")
	check(Session.cup.state.results[0].home==2 and Session.cup.state.results[0].away==4,"Score orientation preserved")
	check(not Session.finish_match([4,2],"REG") and Session.cup.state.results.size()==1,"Duplicate result cannot advance bracket")
	check(Session.resume() and Session.cup.state.results.size()==1,"Resume saved cup")
	for i in range(6): check(Session.simulate_next(),"Simulate/save remaining knockout game")
	check(Session.cup.state.results.size()==7 and not Session.cup.champion().is_empty(),"Final resolves a champion")
	check(Session.cup.current_fixture().is_empty() and not Session.simulate_next(),"Completed cup cannot advance")
	check(Session.resume() and not Session.cup.champion().is_empty(),"Champion persists across resume")
	# Invalid current file recovers the prior validated checkpoint.
	FileAccess.open(Session.slot_path,FileAccess.WRITE).store_string("broken")
	check(Session.resume() and Session.cup.state.results.size()==6,"Corrupt current file recovers backup")
	# Failed atomic save preserves both live bracket and pending result for retry.
	var good_path:=Session.slot_path
	Session.slot_path="/proc/hawkey-cup-test/slot.json"
	Session.prepare_match();var before: Dictionary=Session.cup.state.duplicate(true)
	check(not Session.finish_match([3,1],"REG"),"Unwritable played checkpoint rejected")
	check(Session.cup.state==before and not Session.pending_result.is_empty(),"Failed save preserves live bracket/pending result")
	check(not Session.simulate_next() and not Session.create(clubs[0].id),"Pending result blocks replacement/simulation")
	Session.slot_path=good_path
	check(Session.finish_match() and Session.pending_result.is_empty(),"Pending result retry saves once")
	check(Session.cup.state.results.size()==7,"Retry produces exactly one final result")
	for suffix in ["",".bak",".tmp",".bak.tmp"]:
		if FileAccess.file_exists(Session.slot_path+suffix): DirAccess.remove_absolute(Session.slot_path+suffix)
	Session.mode="";Session.fixture_id="";Session.cup=null
	print("Knockout cup: %d checks; %d failures"%[checks,failures]);quit(failures)
