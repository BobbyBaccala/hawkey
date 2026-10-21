extends SceneTree
const GM=preload("res://scripts/gm_season.gd")
const Session=preload("res://scripts/gm_session.gd")
var checks:=0
var failures:=0
func check(ok: bool, why: String) -> void:
	checks+=1
	if not ok: push_error(why);failures+=1
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var model:=GM.new()
	check(model.new_season(FileAccess.get_file_as_string(GM.Database.DEFAULT_PATH),"har",42),"Create 32-team HL season")
	check(model.state.fixtures.size()==992,"32 clubs x 62 games / 2 fixtures")
	var coverage: Dictionary={}
	var daily: Dictionary={}
	for f in model.state.fixtures:
		var key: String=f.home+":"+f.away
		coverage[key]=int(coverage.get(key,0))+1
		for id_ in [f.home,f.away]:
			var daily_key: String=str(f.day)+":"+id_
			check(not daily.has(daily_key),"Each club plays once per league day")
			daily[daily_key]=true
	check(coverage.size()==992,"Every directed home/away pair occurs once")
	for count in coverage.values(): check(count==1,"No duplicate fixture pairing")
	check(model.validate(model.state),"New full snapshot validates")
	var f: Dictionary=model.current_fixture()
	var first:=model.simulate(f)
	model.simulate(model.state.fixtures[2])
	check(model.simulate(f)==first,"Simulation independent of call order")
	check(not model.record_result(f.id,{"home":2,"away":2,"decision":"REG","source":"played"}),"Reject tied final")
	check(model.record_result(f.id,{"home":3,"away":2,"decision":"OT","source":"played"}),"Record played overtime game")
	check(not model.record_result(f.id,first),"Reject duplicate result")
	var rows:=model.standings()
	var home: Array=rows.filter(func(row): return row.id==f.home)
	var away: Array=rows.filter(func(row): return row.id==f.away)
	check(home[0].pts==2 and home[0].w==1 and home[0].rw==0,"OT winner receives two points")
	check(away[0].pts==1 and away[0].otl==1 and away[0].l==0,"OT loser receives one point")
	check(model.simulate_day() and f.result.source=="played","Simulating day preserves played result")
	var bad:=model.state.duplicate(true);bad.fixtures[0].home=bad.fixtures[0].away
	check(not model.validate(bad),"Reject schedule/reference corruption")
	bad=model.state.duplicate(true);bad.fixtures[0].result={}
	check(not model.validate(bad),"Past day cannot contain unplayed fixtures")
	for day in range(61): check(model.simulate_day(),"Advance all regular-season days")
	check(not model.simulate_day() and model.state.day==62,"Season end cannot advance past schedule")
	check(model.validate(model.state),"Completed season validates")
	var wins:=0;var losses:=0;var gf:=0;var ga:=0
	for row in model.standings():
		check(row.gp==62 and row.w+row.l+row.otl==62,"Every club finishes 62 games")
		wins+=row.w;losses+=row.l+row.otl;gf+=row.gf;ga+=row.ga
	check(wins==992 and losses==992 and gf==ga,"League standings reconcile all results")
	var restored:=GM.new();check(restored.load_state(model.state),"Snapshot loads independently of bundled file")
	check(restored.standings()==model.standings(),"Loaded standings reproduce exactly")
	check(restored.state.world.teams.size()==643,"Save snapshots all feeder leagues, not only HL")
	print("GM season: %d checks; %d failures"%[checks,failures]);quit(failures)
