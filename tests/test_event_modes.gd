extends SceneTree
const Session=preload("res://scripts/event_session.gd")
const Match=preload("res://scripts/match.gd")
const Settings=preload("res://scripts/game_settings.gd")
var failures:=0
var checks:=0
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok: failures+=1;push_error(message)
func _initialize() -> void: call_deferred("run")
func settle() -> void:
	for i in range(4): await process_frame
func run() -> void:
	Settings.path="res://build/event-modes/settings.json"
	Session.slot_path="res://build/event-modes/cup.json"
	for suffix in ["",".bak",".tmp",".bak.tmp"]:
		if FileAccess.file_exists(Session.slot_path+suffix): DirAccess.remove_absolute(Session.slot_path+suffix)
	check(Session.ensure_database(),"Production mode database loads")
	var clubs: Array=Session.database.teams.filter(func(t): return t.league_id=="hl")
	check(Session.create(clubs[0].id,88),"Save cup")
	Match.selected_team_ids=Session.prepare_match();Match.skip_title=true;Match.return_to_title=false
	change_scene_to_file("res://main.tscn");await settle()
	var scene=current_scene
	check(scene.event_mode=="cup" and not scene.is_gm_match and not scene.in_menu,"Cup launches actual match independently of GM")
	scene.set_physics_process(false)
	check(scene.selected_teams[0].id==Session.controlled_id,"Selected cup roster reaches ice")
	scene.match_state.score.assign([3,1]);scene.match_state.finish(0,"REG");scene.update_match_hud()
	check(Session.cup.state.results.size()==1 and FileAccess.file_exists(Session.slot_path),"Actual final saves bracket once")
	scene.update_match_hud();check(Session.cup.state.results.size()==1,"Repeated HUD update cannot duplicate result")
	scene.hud_node.menu_requested.emit();await settle()
	check(current_scene.get_script()==load("res://scripts/events_menu.gd") and Session.mode.is_empty(),"Cup result returns to mode hub")
	var hub=current_scene
	hub.away_choice.select(hub.shootout_home.selected);hub.start_shootout()
	check(current_scene==hub and hub.message.text.contains("different"),"Shootout rejects same-club setup")
	hub.away_choice.select((hub.shootout_home.selected+1)%clubs.size());hub.start_shootout();await settle()
	scene=current_scene
	check(scene.event_mode=="shootout" and scene.match_state.is_shootout() and not scene.in_menu,"Standalone shootout skips regulation")
	scene.set_physics_process(false);scene.setup_shootout_attempt()
	check(scene.shootout_actor!=null and scene.goalkeepers.size()==2,"Real roster shooter and goalies prepared")
	var attempts:=0
	while scene.match_state.phase!=scene.MatchState.Phase.FINAL and attempts<8:
		scene.match_state.phase=scene.MatchState.Phase.SHOOTOUT_ATTEMPT
		scene.match_state.record_attempt(scene.match_state.shootout_team==0)
		attempts+=1
	scene.update_match_hud()
	check(scene.match_state.decision=="SO" and is_instance_valid(scene.hud_node.results_panel),"Shootout reaches a result")
	check(Session.cup.state.results.size()==1,"Shootout never modifies saved cup")
	scene.hud_node.restart_requested.emit();await settle()
	check(current_scene.match_state.is_shootout() and current_scene.match_state.shootout_attempts.is_empty(),"Rematch starts a clean shootout")
	current_scene.hud_node.menu_requested.emit();await settle()
	check(Session.mode.is_empty() and current_scene.get_script()==load("res://scripts/events_menu.gd"),"Shootout returns to mode hub")
	current_scene.return_to_menu();await settle()
	check(current_scene.in_menu and current_scene.event_mode.is_empty(),"Returning to exhibition title clears mode routing")
	current_scene.queue_free();await process_frame
	for suffix in ["",".bak",".tmp",".bak.tmp"]:
		if FileAccess.file_exists(Session.slot_path+suffix): DirAccess.remove_absolute(Session.slot_path+suffix)
	Session.mode="";Session.fixture_id="";Session.cup=null
	print("Event modes: %d checks; %d failures"%[checks,failures]);quit(failures)
