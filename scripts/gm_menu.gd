extends Control
const UI=preload("res://scripts/mode_ui.gd")
const Session=preload("res://scripts/gm_session.gd")
const Database=preload("res://scripts/roster_database.gd")
var box: VBoxContainer
var choice: OptionButton
var message: Label
var teams: Array=[]
var confirm: ConfirmationDialog
var play_button: Button
var sim_button: Button
var checkpoint_job: RefCounted

func _ready() -> void:
	if not Session.pending_result.is_empty():
		Session.finish_match([],"")
	rebuild()

func rebuild() -> void:
	for child in get_children():
		remove_child(child);child.queue_free()
	box=UI.setup(self)
	if Session.season==null: build_setup()
	else: build_dashboard()

func build_setup() -> void:
	box.add_child(UI.text("GENERAL MANAGER  /  HL",14,UI.ACCENT))
	box.add_child(UI.text("Build your season",42))
	box.add_child(UI.text("32 clubs. 62 games each. Your team, one league day at a time.",20,UI.MUTED))
	var card:=UI.card(box)
	card.add_child(UI.text("Choose your club",24))
	var db:=Database.new()
	if not db.load_file():
		card.add_child(UI.text(db.error));return
	teams=db.teams.filter(func(t): return t.league_id=="hl")
	teams.sort_custom(func(a,b): return a.city<b.city)
	choice=OptionButton.new()
	for team in teams: choice.add_item(team.city+" "+team.name)
	card.add_child(choice)
	var new_button:=UI.button("Start new season",request_create);card.add_child(new_button)
	if FileAccess.file_exists(Session.slot_path) or FileAccess.file_exists(Session.slot_path+".bak"):
		card.add_child(UI.button("Continue saved season",resume_season))
	card.add_child(UI.text("Single local save slot with backup recovery. Starting again asks before replacing it.",16,UI.MUTED))
	card.add_child(UI.text("Season alpha: play or simulate, standings, autosave and resume.\nFree agents, contracts and team statistics are available.\nDrafts, development and playoffs are still to come.",16,UI.MUTED))
	message=UI.text(Session.error,17,UI.ACCENT);box.add_child(message)
	box.add_child(UI.button("Return to menu",return_to_menu))
	confirm=ConfirmationDialog.new();confirm.title="Replace saved season?"
	confirm.dialog_text="Starting a new season replaces this slot. The previous valid save is kept as a backup."
	confirm.confirmed.connect(create_season);add_child(confirm)
	new_button.grab_focus()

func request_create() -> void:
	if FileAccess.file_exists(Session.slot_path) or FileAccess.file_exists(Session.slot_path+".bak"): confirm.popup_centered()
	else: create_season()

func create_season() -> void:
	if Session.create(teams[choice.selected].id): rebuild()
	else: message.text=Session.error

func resume_season() -> void:
	if Session.resume(): rebuild()
	else: message.text=Session.error

func build_dashboard() -> void:
	var model=Session.season
	var managed: Dictionary=model.club(model.state.club_id)
	box.add_child(UI.text("GENERAL MANAGER  /  "+str(model.state.season),14,UI.ACCENT))
	box.add_child(UI.text(managed.city+" "+managed.name,38))
	var complete: bool=model.state.day>=62
	var standings: Array=model.standings()
	var club_row: Dictionary=standings.filter(func(row): return row.id==managed.id)[0]
	var rank: int=standings.find(club_row)+1
	var day_text: String="REGULAR SEASON COMPLETE" if complete else "LEAGUE DAY %d / 62"%[int(model.state.day)+1]
	box.add_child(UI.text("%s   ·   %d–%d–%d   ·   %d PTS   ·   #%d IN THE HL"%[day_text,club_row.w,club_row.l,club_row.otl,club_row.pts,rank],16,UI.MUTED))
	var fixture: Dictionary=model.current_fixture()
	var actions:=HBoxContainer.new();actions.add_theme_constant_override("separation",12);box.add_child(actions)
	play_button=UI.button("Play scheduled game",play_game);actions.add_child(play_button)
	play_button.disabled=complete or fixture.is_empty() or not fixture.result.is_empty() or not Session.pending_result.is_empty()
	sim_button=UI.button("Simulate rest of day" if not fixture.is_empty() and not fixture.result.is_empty() else "Simulate league day",advance_day);actions.add_child(sim_button)
	sim_button.disabled=complete or not Session.pending_result.is_empty()
	actions.add_child(UI.button("Roster room",func(): get_tree().change_scene_to_file("res://gm_rosters.tscn")))
	actions.add_child(UI.button("Front office",func(): get_tree().change_scene_to_file("res://gm_office.tscn")))
	actions.add_child(UI.button("Save & return to menu",save_exit))
	var columns:=HBoxContainer.new();columns.add_theme_constant_override("separation",20);columns.size_flags_vertical=Control.SIZE_EXPAND_FILL;box.add_child(columns)
	var table:=UI.card(columns)
	table.add_child(UI.text("League standings",24))
	var head:=HBoxContainer.new();table.add_child(head)
	standing_row(head,"CLUB",["GP","W","L","OTL","PTS"],false)
	var scroll:=ScrollContainer.new();scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;scroll.size_flags_horizontal=Control.SIZE_EXPAND_FILL;table.add_child(scroll)
	var inset:=MarginContainer.new();inset.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	inset.add_theme_constant_override("margin_right",12);scroll.add_child(inset)
	var rows:=VBoxContainer.new();rows.size_flags_horizontal=Control.SIZE_EXPAND_FILL;inset.add_child(rows)
	var place:=0
	for row in standings:
		place+=1
		var team: Dictionary=model.club(row.id)
		var line:=HBoxContainer.new();line.custom_minimum_size.y=33;rows.add_child(line)
		standing_row(line,"%02d  %s %s"%[place,team.city,team.name],[str(row.gp),str(row.w),str(row.l),str(row.otl),str(row.pts)],row.id==managed.id)
	var side:=UI.card(columns);side.get_parent().custom_minimum_size.x=400
	var panel: PanelContainer=side.get_parent();panel.size_flags_horizontal=Control.SIZE_FILL
	side.add_child(UI.text("Your next shift",24))
	if complete:
		side.add_child(UI.text("62 games in the books",21,UI.ACCENT))
		side.add_child(UI.text("Final standings are saved.\nPlayoffs and next-season rollover\nare not implemented yet.",17,UI.MUTED))
	elif not fixture.is_empty():
		var home: Dictionary=model.club(fixture.home)
		var away: Dictionary=model.club(fixture.away)
		side.add_child(UI.text(away.city+"\nat "+home.city,25,UI.ACCENT))
		side.add_child(UI.text("You control "+managed.city+".\nPlaying replaces only this fixture.\nSimulating advances the whole league.",16,UI.MUTED))
		if not fixture.result.is_empty():
			var r: Dictionary=fixture.result
			side.add_child(UI.text("FINAL  %s %d–%d %s · %s"%[home.code,r.home,r.away,away.code,r.decision],17))
	side.add_child(UI.text("Recent club results",20))
	var recent: Array=model.state.fixtures.filter(func(f): return managed.id in [f.home,f.away] and not f.result.is_empty())
	recent.reverse()
	if recent.is_empty(): side.add_child(UI.text("Opening day. Make it count.",16,UI.MUTED))
	for f in recent.slice(0,7):
		var opponent: Dictionary=model.club(f.away if f.home==managed.id else f.home)
		var own: int=int(f.result.home if f.home==managed.id else f.result.away)
		var other: int=int(f.result.away if f.home==managed.id else f.result.home)
		side.add_child(UI.text("%s  %d–%d  %s · %s"%["W" if own>other else "L",own,other,opponent.code,f.result.decision],17,UI.ACCENT if own>other else UI.MUTED))
	side.add_child(UI.text("2 points: win · 1: OT/SO loss\nTies: points, regulation wins, goal\ndifference, then stable club ID.",14,UI.MUTED))
	message=UI.text(Session.error if not Session.error.is_empty() else Session.notice,16,UI.ACCENT);box.add_child(message)
	message.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	if not play_button.disabled: play_button.grab_focus()
	else: sim_button.grab_focus()

func standing_row(parent: HBoxContainer, club: String, stats: Array, selected: bool) -> void:
	var name_label:=UI.text(club,16,UI.ACCENT if selected else UI.INK)
	name_label.size_flags_horizontal=Control.SIZE_EXPAND_FILL;name_label.custom_minimum_size.x=330;parent.add_child(name_label)
	for value in stats:
		var cell:=UI.text(value,16,UI.ACCENT if selected else UI.MUTED);cell.custom_minimum_size.x=48;cell.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT;parent.add_child(cell)

func advance_day() -> void:
	if checkpoint_job!=null or Session.checkpoint_active: return
	if not Session.pending_result.is_empty():
		message.text="Save the pending result before advancing."
		return
	if Session.season.state.day>=62: return
	checkpoint_job=preload("res://scripts/gm_checkpoint_job.gd").new()
	if checkpoint_job.start(Session.season.state,Session.season.strengths,Session.slot_path)!=OK:
		checkpoint_job=null;message.text="Could not start checkpoint. Previous save retained."
		return
	Session.checkpoint_active=true
	for node in box.find_children("*","BaseButton",true,false): node.disabled=true
	message.text="SIMULATING & SAVING — please wait. Your current save stays protected."
	while is_inside_tree() and checkpoint_job!=null and not checkpoint_job.completed(): await get_tree().process_frame
	if not is_inside_tree(): return
	apply_checkpoint()
	rebuild()

func apply_checkpoint() -> void:
	if checkpoint_job==null: return
	var result: Dictionary=checkpoint_job.finish()
	Session.checkpoint_active=false
	if result.get("ok",false):
		if Session.season!=null: Session.season.state=result.state
		Session.notice="Day complete. All league results and standings saved."
		Session.error=""
	else: Session.error=result.get("error","Checkpoint failed; previous save retained.")
	checkpoint_job=null

func _exit_tree() -> void:
	# An externally requested close waits for the finite atomic checkpoint.
	apply_checkpoint()

func play_game() -> void:
	var fixture: Dictionary=Session.season.current_fixture()
	if fixture.is_empty() or not fixture.result.is_empty() or not Session.pending_result.is_empty(): return
	Session.fixture_id=fixture.id
	var managed: String=Session.season.state.club_id
	var opponent: String=fixture.away if fixture.home==managed else fixture.home
	var match_script=load("res://scripts/match.gd")
	match_script.selected_team_ids.assign([managed,opponent])
	match_script.skip_title=true
	match_script.return_to_title=false
	get_tree().change_scene_to_file("res://main.tscn")

func save_exit() -> void:
	if Session.save(): return_to_menu()
	else: message.text=Session.error

func return_to_menu() -> void:
	load("res://scripts/match.gd").return_to_title=true
	Session.season=null
	Session.fixture_id=""
	get_tree().change_scene_to_file("res://main.tscn")
