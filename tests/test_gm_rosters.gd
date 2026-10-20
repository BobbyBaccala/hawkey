extends SceneTree
const Session=preload("res://scripts/gm_session.gd")
const Season=preload("res://scripts/gm_season.gd")
var failures:=0
var checks:=0
func check(ok: bool, why: String) -> void:
	checks+=1
	if not ok: push_error(why);failures+=1
func settle() -> void:
	for i in range(4): await process_frame
func _initialize() -> void: call_deferred("run")
func run() -> void:
	Session.season=Season.new()
	check(Session.season.new_season(FileAccess.get_file_as_string(Season.Database.DEFAULT_PATH),"har"),"Roster browser has saved-world model")
	var before_state: String=JSON.stringify(Session.season.state).sha256_text()
	change_scene_to_file("res://gm_rosters.tscn");await settle()
	var view=current_scene
	check(view.entries.size()==14745 and view.teams_by_id.size()==643,"Browser indexes whole career world")
	check(view.filtered.size()==23,"Default managed-club roster includes reserves")
	var managed: String=Session.season.state.club_id
	check(view.filtered.all(func(entry): return entry.team.id==managed),"Default view belongs to managed club")
	view.select_source(1)
	check(view.filtered.size()>23 and view.filtered.all(view.is_organization),"Organization includes genuine affiliations/rights only")
	view.select_source(2)
	check(view.filtered.size()==view.eligible.size() and view.filtered.size()==3256,"Draft view matches validated world eligibility")
	check(view.rows.get_child_count()==view.PAGE_SIZE,"Large prospect pool paginates rendered rows")
	for entry in view.filtered:
		var age: int=Session.season.database.age_at(entry.player.birth_date,Session.season.database.draft_policy.date)
		check(age>=18 and age<=20 and entry.player.hl_rights_team_id==null,"Candidate age and rights eligibility")
	var before: String=view.rows.get_child(0).get_meta("player_id")
	view.next.pressed.emit()
	check(view.page==1 and view.rows.get_child(0).get_meta("player_id")!=before,"Next page displays different candidates")
	var button: Button=view.rows.get_child(3)
	var id_: String=button.get_meta("player_id")
	button.pressed.emit()
	check(view.selected_id==id_ and root.gui_get_focus_owner().get_meta("player_id")==id_,"Player selection updates details and preserves keyboard/controller focus")
	view.search.text="no-player-with-this-name-zz";view.search.text_changed.emit(view.search.text)
	check(view.filtered.is_empty() and view.rows.get_child_count()==0,"Search handles empty result without stale player rows")
	view.search.text="";view.select_source(0)
	var youth: Array=Session.season.database.leagues.filter(func(l): return l.tier=="youth")
	view.league_choice.select(view.league_ids.find(youth[0].id));view.select_league(0)
	check(view.filtered.size()==640,"Youth data browsable without making youth gameplay playable")
	view.team_choice.select(1);view.refresh()
	check(view.filtered.size()==20,"Youth club full roster browsable")
	check(view.filtered.all(func(entry): return not view.leagues_by_id[entry.team.league_id].play_now),"Youth browser does not change exhibition eligibility")
	check(Session.season.state.day==0 and Session.season.current_fixture().result.is_empty(),"Read-only browsing cannot advance or mutate the season")
	check(JSON.stringify(Session.season.state).sha256_text()==before_state,"All roster and prospect browsing leaves snapshot bytes unchanged")
	change_scene_to_file("res://gm.tscn");await settle()
	check(is_instance_valid(current_scene.play_button),"Browser returns to functional season dashboard")
	var buttons: Array=current_scene.find_children("*","Button",true,false).filter(func(button): return button.text=="Roster room")
	check(buttons.size()==1,"Dashboard has a functional roster-room entry")
	buttons[0].pressed.emit();await settle()
	check(current_scene.entries.size()==14745,"Dashboard roster action opens actual saved-world browser")
	current_scene.queue_free();await process_frame;Session.season=null
	print("GM roster browser: %d checks; %d failures"%[checks,failures]);quit(failures)
