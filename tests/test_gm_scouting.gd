extends SceneTree
const Season=preload("res://scripts/gm_season.gd")
const Scouting=preload("res://scripts/gm_scouting.gd")
const Session=preload("res://scripts/gm_session.gd")
var checks:=0
var failures:=0
func check(ok: bool, why: String) -> void:
	checks+=1
	if not ok: push_error(why);failures+=1
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var model:=Season.new()
	check(model.new_season(FileAccess.get_file_as_string(Season.Database.DEFAULT_PATH),"har"),"Create scouting season")
	var pool:=Scouting.candidates(model.state.world)
	check(pool.size()>1000,"Complete eligible North American junior pool")
	var goalie: String="";var skater: String=""
	for id_ in pool:
		var row: Dictionary=pool[id_]
		check(model.club(row.team).league_id==row.league and row.player.hl_rights_team_id==null,"Prospect club and rights references valid")
		if row.player.position=="G": goalie=id_
		else: skater=id_
	check(model.assign_scout(goalie) and model.assign_scout(skater),"Assign goalie and skater")
	check(not model.assign_scout(goalie),"Duplicate scouting assignment rejected")
	var third: String=pool.keys().filter(func(id_): return id_ not in [goalie,skater])[0]
	var fourth: String=pool.keys().filter(func(id_): return id_ not in [goalie,skater,third])[0]
	check(model.assign_scout(third) and not model.assign_scout(fourth),"Only three scouts per league day")
	check(model.scouting_report(goalie).is_empty(),"No report before observation day")
	check(not model.assign_scout("not-a-prospect"),"Invalid prospect rejected")
	check(model.validate(model.state),"Scouting assignments persist in valid season")
	var bad:=model.state.duplicate(true);bad.management.scouting_jobs.append(bad.management.scouting_jobs[0])
	check(not model.validate(bad),"Corrupted duplicate job rejected")
	check(model.simulate_day(),"League day advances scouting clock")
	for id_ in [goalie,skater]:
		var report:=model.scouting_report(id_)
		check(not report.is_empty() and report.observed_day==1,"Report available next league day")
		check(report.primary_label==("Reflexes" if pool[id_].player.position=="G" else "Shot accuracy"),"Position-specific scouting skill")
		for field in ["speed","primary_skill","potential"]:
			check(report[field][0]>=0 and report[field][1]<=100 and report[field][0]<report[field][1],"Bounded uncertain range")
	check(model.assign_scout(fourth),"Scouts become available on new day")
	var restored:=Season.new();check(restored.load_state(model.state),"Scouting state loads")
	check(restored.scouting_report(goalie)==model.scouting_report(goalie),"Reports deterministic across resume")
	Session.season=restored;Session.slot_path="user://tests/scouting-office.json"
	change_scene_to_file("res://gm_office.tscn")
	for i in range(4): await process_frame
	var screen=current_scene;screen.tab=4;screen.build()
	print("Scout UI rows ",screen.scouting_rows.get_child_count()," query ",screen.scout_query," page ",screen.scout_page)
	check(screen.scouting_rows.get_child_count()==26,"Scouting page has 25 prospects and page count")
	screen.scouting_id=goalie;screen.show_scouting()
	check(screen.scouting_detail.get_child_count()>5,"Completed report rendered")
	screen.scout_query="not-a-real-name";screen.refresh_scouting()
	check(screen.scouting_rows.get_child_count()==1 and screen.scouting_id.is_empty(),"Empty search is safe")
	screen.scout_query="";screen.scouting_id=pool.keys().filter(func(id_): return not Session.season.state.management.scouting_jobs.any(func(job): return job.player==id_))[0]
	var old_count: int=Session.season.state.management.scouting_jobs.size()
	await screen.assign_selected_scout()
	check(Session.season.state.management.scouting_jobs.size()==old_count+1,"Scouting UI atomically saves a real assignment")
	check(Session.resume() and Session.season.state.management.scouting_jobs.size()==old_count+1,"Assignment survives validated disk resume")
	current_scene.queue_free();await process_frame;Session.season=null
	for suffix in ["",".bak",".tmp",".bak.tmp"]:
		if FileAccess.file_exists(Session.slot_path+suffix): DirAccess.remove_absolute(Session.slot_path+suffix)
	print("GM scouting: %d checks; %d failures; %d eligible junior prospects"%[checks,failures,pool.size()]);quit(failures)
