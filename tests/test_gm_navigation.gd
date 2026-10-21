extends SceneTree
const Session=preload("res://scripts/gm_session.gd")
const Settings=preload("res://scripts/game_settings.gd")
const Match=preload("res://scripts/match.gd")
const Store=preload("res://scripts/save_store.gd")
var checks:=0
var failures:=0
var slot:="user://tests/gm-nav.json"
func check(ok: bool, why: String) -> void:
	checks+=1
	if not ok: push_error(why);failures+=1
func _initialize() -> void: call_deferred("run")
func settle() -> void:
	for i in range(6): await process_frame
func clean(path: String) -> void:
	for suffix in ["",".tmp",".bak",".bak.tmp"]:
		if FileAccess.file_exists(path+suffix): DirAccess.remove_absolute(path+suffix)
func run() -> void:
	Session.slot_path=slot;clean(slot)
	Settings.path="user://tests/gm-nav-settings.json";clean(Settings.path)
	Match.return_to_title=true
	change_scene_to_file("res://main.tscn");await settle()
	check(current_scene.in_menu,"Start at real title")
	current_scene.hud_node.settings_requested.emit();await settle()
	check(current_scene.get_script().resource_path.ends_with("settings_menu.gd"),"Title opens preferences")
	current_scene.camera.select(2);current_scene.zone.value=0.27;current_scene.save_preferences()
	check(current_scene.message.text=="Preferences saved.","Preferences save through native UI")
	Match.return_to_title=true;change_scene_to_file("res://main.tscn");await settle()
	check(current_scene.camera_mode==2 and is_equal_approx(current_scene.controller.deadzone,0.27),"Saved settings applied to match")
	current_scene.hud_node.gm_requested.emit();await settle()
	check(is_instance_valid(current_scene.choice),"GM opens club setup")
	current_scene.create_season();await settle()
	check(Session.season!=null and FileAccess.file_exists(slot),"New season saves before entering dashboard")
	check(not current_scene.play_button.disabled,"Dashboard offers scheduled game")
	# Exercise managed-away score mapping, independent of rink control side.
	var away: String=Session.season.current_fixture().away
	check(Session.create(away,765),"Create managed-away fixture")
	var club: String=Session.season.state.club_id
	for team in Session.season.state.world.teams:
		if team.id==club: team.city="Snapshot City"
	check(Session.season.load_state(Session.season.state) and Session.save(),"Save per-career roster snapshot")
	current_scene.rebuild()
	var fixture: Dictionary=Session.season.current_fixture().duplicate(true)
	current_scene.play_game();await settle()
	var game=current_scene
	game.set_physics_process(false)
	check(game.is_gm_match and not game.in_menu,"GM opens actual match without exhibition title")
	check(game.selected_teams[0].id==club and game.selected_teams[0].city=="Snapshot City","Match uses managed club and saved roster snapshot")
	var match_save_path:=Session.slot_path
	Session.slot_path="/proc/hawkey-no-write/slot.json"
	game.match_state.finish(0,"REG")
	game.match_state.score.assign([4,2]);game.update_match_hud()
	check(not Session.pending_result.is_empty() and game.hud_node.results_text.text.contains("NOT SAVED"),"Failed final save is visible and retains pending result")
	Session.slot_path=match_save_path
	var result: Dictionary=Session.season.current_fixture().result
	check(result.source=="played" and result.away==4 and result.home==2,"Managed-away score maps to actual fixture sides")
	game.hud_node.menu_requested.emit();await settle()
	check(Session.fixture_id.is_empty() and Session.pending_result.is_empty(),"Returning to GM retries and saves the pending result")
	check(not current_scene.play_button.visible or current_scene.play_button.disabled,"Completed fixture cannot replay and double-count")
	await current_scene.advance_day()
	check(Session.season.state.day==1,"Advance simulates other clubs after played fixture")
	var standings: Array=Session.season.standings()
	check(Session.resume() and Session.season.standings()==standings,"Resume reproduces complete league state")
	check(Session.season.club(club).city=="Snapshot City","Resume retains roster snapshot")
	# Reject an interrupted write; roll back the in-memory day as well.
	var good_path:=Session.slot_path;Session.slot_path="/proc/hawkey-no-write/slot.json"
	check(not Session.advance_day() and Session.season.state.day==1,"Save failure rolls back league day")
	Session.slot_path=good_path
	# Corrupt the primary; surface recovery and leave its bytes unchanged until explicit save.
	Store.new().write_text(slot,"truncated")
	check(Session.resume() and Session.notice.contains("backup"),"Season recovery surfaced to player")
	check(FileAccess.get_file_as_string(slot)=="truncated","Resume recovery never silently overwrites files")
	Session.season=null;Session.fixture_id="";Session.pending_result={}
	current_scene.return_to_menu();await settle()
	check(current_scene.in_menu,"GM returns to title")
	clean(slot);clean(Settings.path)
	Session.slot_path="user://gm/slot-1.json";Settings.path="user://settings.json"
	current_scene.queue_free();await process_frame
	print("GM navigation: %d checks; %d failures"%[checks,failures]);quit(failures)
