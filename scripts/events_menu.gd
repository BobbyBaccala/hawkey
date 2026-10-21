extends Control
const UI=preload("res://scripts/mode_ui.gd")
const Session=preload("res://scripts/event_session.gd")
var teams: Array=[]
var club_choice: OptionButton
var away_choice: OptionButton
var shootout_home: OptionButton
var seed_choice: SpinBox
var message: Label
var confirm: ConfirmationDialog
var primary_button: Button
func _ready() -> void:
	Session.mode=""
	rebuild()
func choice(parent: Node, caption: String) -> OptionButton:
	parent.add_child(UI.text(caption,15,UI.MUTED))
	var field:=OptionButton.new();field.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	for team in teams: field.add_item(team.city+" "+team.name)
	parent.add_child(field);return field
func rebuild() -> void:
	for child in get_children(): remove_child(child);child.queue_free()
	primary_button=null
	var outer:=UI.setup(self)
	outer.add_child(UI.text("MORE MODES  /  HL",14,UI.ACCENT))
	outer.add_child(UI.text("A trophy run. A deciding shot.",38))
	if not Session.ensure_database():
		outer.add_child(UI.text(Session.error));outer.add_child(UI.button("Return to menu",return_to_menu));return
	teams=Session.database.teams.filter(func(t): return t.league_id=="hl")
	var scroll:=ScrollContainer.new();scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;outer.add_child(scroll)
	var content:=VBoxContainer.new();content.size_flags_horizontal=Control.SIZE_EXPAND_FILL;content.add_theme_constant_override("separation",18);scroll.add_child(content)
	if Session.cup!=null: build_bracket(content)
	var cards:=HBoxContainer.new();cards.add_theme_constant_override("separation",18);content.add_child(cards)
	var left:=UI.card(cards);left.add_child(UI.text("Knockout Cup",29))
	left.add_child(UI.text("Eight HL clubs. Quarterfinals to the final.\nPlay or simulate every game. Results autosave.",17,UI.MUTED))
	club_choice=choice(left,"YOUR CUP CLUB")
	if Session.cup!=null:
		for i in range(teams.size()):
			if teams[i].id==Session.cup.state.club_id: club_choice.select(i)
	left.add_child(UI.text("DRAW NUMBER",15,UI.MUTED))
	seed_choice=SpinBox.new();seed_choice.min_value=0;seed_choice.max_value=2147483647;seed_choice.step=1;seed_choice.value=20261021;left.add_child(seed_choice)
	var new_button:=UI.button("Start new cup",request_create);left.add_child(new_button)
	new_button.disabled=not Session.pending_result.is_empty()
	if FileAccess.file_exists(Session.slot_path) or FileAccess.file_exists(Session.slot_path+".bak"):
		var resume:=UI.button("Continue saved cup",resume_cup);resume.disabled=not Session.pending_result.is_empty();left.add_child(resume)
	var right:=UI.card(cards);right.add_child(UI.text("Shootout",29))
	right.add_child(UI.text("Skip regulation. Three rounds, then sudden death.\nYou shoot for home; the opponent is controlled by AI.",17,UI.MUTED))
	shootout_home=choice(right,"HOME CLUB")
	away_choice=choice(right,"AWAY CLUB");away_choice.select(1)
	var shoot:=UI.button("Start shootout",start_shootout);shoot.disabled=not Session.pending_result.is_empty();right.add_child(shoot)
	right.add_child(UI.text("Uses the same goalies, net aiming and skill-stick\ncontrols as a match. Rematch from the result screen.",16,UI.MUTED))
	message=UI.text(Session.error if not Session.error.is_empty() else Session.notice,16,UI.ACCENT);message.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;content.add_child(message)
	if not Session.pending_result.is_empty(): content.add_child(UI.button("Retry saving played result",retry_result))
	var back:=UI.button("Return to menu",return_to_menu);outer.add_child(back)
	confirm=ConfirmationDialog.new();confirm.title="Start a new cup?";confirm.dialog_text="Replace this cup slot? The previous valid save is retained as a backup. GM saves are separate."
	confirm.confirmed.connect(create_cup);add_child(confirm)
	if is_instance_valid(primary_button) and not primary_button.disabled: primary_button.grab_focus()
	elif Session.cup!=null: back.grab_focus()
	else: new_button.grab_focus()
func team_name(id_: String) -> String:
	var team: Dictionary=Session.cup.club(id_);return team.city+" "+team.name
func build_bracket(parent: Node) -> void:
	var cup=Session.cup
	var title:="Cup bracket"
	if not cup.champion().is_empty(): title="CHAMPIONS  /  "+team_name(cup.champion())
	parent.add_child(UI.text(title,27,UI.ACCENT))
	var actions:=HBoxContainer.new();actions.add_theme_constant_override("separation",12);parent.add_child(actions)
	var play:=UI.button("Play next cup game",play_cup);actions.add_child(play);primary_button=play
	var sim:=UI.button("Simulate next game",simulate_game);actions.add_child(sim)
	play.disabled=cup.current_fixture().is_empty() or not Session.pending_result.is_empty();sim.disabled=play.disabled
	parent.add_child(UI.text("Control your club whenever it appears; otherwise control the home club.\nCup draws and results are separate from GM. Games use exhibition OT/shootout tie-breaks.",15,UI.MUTED))
	var columns:=HBoxContainer.new();columns.add_theme_constant_override("separation",14);parent.add_child(columns)
	for round_ in range(3):
		var card:=UI.card(columns);card.add_child(UI.text(["QUARTERFINALS","SEMIFINALS","FINAL"][round_],19))
		var found:=false
		for game in cup.fixtures():
			if game.round!=round_: continue
			found=true
			var line:=team_name(game.home)+"\nvs "+team_name(game.away)
			if not game.result.is_empty(): line+="\n%d – %d  ·  %s  ·  %s"%[game.result.home,game.result.away,game.result.decision,game.result.source]
			else: line+="\nNEXT GAME" if game.id==cup.current_fixture().get("id","") else "\nUPCOMING"
			var label:=UI.text(line,16);label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;card.add_child(label)
		if not found: card.add_child(UI.text("Waiting for winners",16,UI.MUTED))
func request_create() -> void:
	if FileAccess.file_exists(Session.slot_path) or FileAccess.file_exists(Session.slot_path+".bak"): confirm.popup_centered()
	else: create_cup()
func create_cup() -> void:
	if Session.create(teams[club_choice.selected].id,int(seed_choice.value)): rebuild()
	else: message.text=Session.error
func resume_cup() -> void:
	if Session.resume(): rebuild()
	else: message.text=Session.error
func simulate_game() -> void:
	if Session.simulate_next(): rebuild()
	else: message.text=Session.error
func retry_result() -> void:
	if Session.finish_match(): rebuild()
	else: message.text=Session.error
func launch(ids: Array[String]) -> void:
	var match_script=load("res://scripts/match.gd")
	match_script.selected_team_ids=ids;match_script.skip_title=true;match_script.return_to_title=false
	get_tree().change_scene_to_file("res://main.tscn")
func play_cup() -> void:
	var ids:=Session.prepare_match()
	if ids.size()==2: launch(ids)
func start_shootout() -> void:
	if shootout_home.selected==away_choice.selected: message.text="Choose two different clubs.";return
	Session.mode="shootout";Session.fixture_id=""
	var ids: Array[String]=[teams[shootout_home.selected].id,teams[away_choice.selected].id];launch(ids)
func return_to_menu() -> void:
	Session.mode=""
	load("res://scripts/match.gd").return_to_title=true
	get_tree().change_scene_to_file("res://main.tscn")
