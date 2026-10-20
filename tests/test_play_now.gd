extends SceneTree
const Match = preload("res://scripts/match.gd")
var failures := 0
var checks := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		push_error(message)
		failures += 1
func _initialize() -> void: call_deferred("run")
func settle() -> void:
	for i in range(4): await process_frame
func run() -> void:
	Match.selected_team_ids.assign(["har", "sum"])
	Match.return_to_title = true
	change_scene_to_file("res://main.tscn")
	await settle()
	var scene = current_scene
	check(scene.in_menu and scene.hud_node.title_screen.visible, "Return flag opens title")
	var clock = scene.match_state.clock
	await physics_frame
	check(scene.match_state.clock == clock, "Title freezes simulation")
	scene.hud_node.team_choices[1].select(0)
	scene.hud_node.play_requested.emit()
	check(scene.in_menu and not scene.hud_node.selection_error.text.is_empty(), "Duplicate team selection blocked")
	scene.hud_node.team_choices[0].select(1)
	scene.hud_node.play_requested.emit()
	await settle()
	scene = current_scene
	check(not scene.in_menu, "Selected teams start Play Now")
	check(scene.selected_teams[0].id == "sum" and scene.selected_teams[1].id == "har", "Side selection survives reload")
	check(scene.hud_node.team_codes == ["SUM", "HAR"], "HUD follows selection")
	for actor in scene.skaters:
		check(actor.get_meta("player_id") == scene.roster(actor).id, "Actor references stable identity")
	check(scene.goalkeepers[0].get_meta("player_id") == scene.rosters[0][18].id, "Goalie uses roster identity")
	scene.match_state.phase = scene.MatchState.Phase.STOPPAGE
	scene.request_line(0, 1)
	check(scene.skaters[0].get_meta("player_id") == scene.rosters[0][3].id, "Line change updates stable identity")
	scene.match_state.phase = scene.MatchState.Phase.PLAY
	scene.match_state.period = 3
	scene.match_state.clock = 0.01
	scene.match_state.score.assign([3, 2])
	scene.match_state.advance(0.1)
	scene.update_match_hud()
	check(is_instance_valid(scene.hud_node.results_panel), "Final results show")
	check(scene.hud_node.results_panel.is_visible_in_tree(), "Results panel is visible")
	check("SUMMIT 3" in scene.hud_node.results_text.text, "Final uses selected team and score")
	scene.hud_node.restart_requested.emit()
	await settle()
	scene = current_scene
	check(scene.match_state.score == [0, 0] and not scene.in_menu, "Rematch resets game")
	check(scene.selected_teams[0].id == "sum", "Rematch preserves selection")
	scene.hud_node.menu_requested.emit()
	await settle()
	scene = current_scene
	check(scene.in_menu and scene.hud_node.selected_ids() == ["sum", "har"], "Menu preserves preset")
	scene.hud_node.practice_requested.emit()
	await settle()
	scene = current_scene
	check(scene.scene_file_path == "res://practice.tscn", "Practice navigation")
	var menu: Button
	for child in scene.get_children():
		if child is CanvasLayer:
			for control in child.get_children():
				if control is Button and control.text == "Return to menu": menu = control
	check(is_instance_valid(menu), "Practice return control exists")
	if is_instance_valid(menu):
		menu.pressed.emit()
		await settle()
		check(current_scene.in_menu, "Practice returns to title")
	scene = current_scene
	check(scene.hud_node.team_choices[0].item_count == 32, "All HL clubs selectable")
	check("y-u18" not in scene.hud_node.league_choice_ids, "Youth not advertised with adult rules")
	for target in [["hda",32,23], ["eu-se",14,23], ["j-west",24,25]]:
		var index: int = scene.hud_node.league_choice_ids.find(target[0])
		check(index >= 0, "League is selectable: " + target[0])
		scene.hud_node.league_choice.select(index)
		scene.hud_node.league_choice.item_selected.emit(index)
		check(scene.hud_node.team_choices[0].item_count == target[1], "Complete filtered team list")
		scene.hud_node.play_requested.emit()
		await settle()
		scene = current_scene
		check(not scene.in_menu and scene.selected_teams[0].league_id == target[0], "Selected league reaches match")
		check(scene.rosters[0].size() == target[2], "Reserves survive match snapshot")
		check(scene.rosters[0][18].position == "G", "Starting goalie slot preserved")
		scene.hud_node.menu_requested.emit()
		await settle()
		scene = current_scene
		check(scene.hud_node.league_choice_ids[scene.hud_node.league_choice.selected] == target[0], "League selection retained on return")
	current_scene.queue_free()
	await settle()
	print("Play Now: %d checks; %d failures" % [checks, failures])
	quit(failures)
