extends SceneTree
const Settings=preload("res://scripts/game_settings.gd")
const Match=preload("res://scripts/match.gd")
var checks:=0
var failures:=0
func check(ok: bool, why: String) -> void:
	checks+=1
	if not ok: push_error(why);failures+=1
func settle() -> void:
	for i in range(5): await process_frame
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var original:=Settings.path;Settings.path="user://tests/comfort.json"
	var settings:=Settings.new()
	check(settings.valid_typed({"schema_version":1,"camera":0,"deadzone":0.18}),"Older settings without comfort fields remain valid")
	check(not settings.valid_typed({"schema_version":1,"camera":0,"deadzone":0.18,"reduce_motion":"false"}),"Comfort flags must be booleans")
	change_scene_to_file("res://settings.tscn");await settle()
	var prefs=current_scene
	check(root.gui_get_focus_owner()==prefs.camera,"Preferences establish initial keyboard focus")
	for i in range(prefs.focus_order.size()):
		var control: Control=prefs.focus_order[i]
		check(control.get_node(control.focus_next)==prefs.focus_order[(i+1)%prefs.focus_order.size()],"Tab follows explicit complete focus loop")
		check(control.get_node(control.focus_previous)==prefs.focus_order[(i-1+prefs.focus_order.size())%prefs.focus_order.size()],"Reverse Tab follows complete focus loop")
	var tab:=InputEventAction.new();tab.action="ui_focus_next";tab.pressed=true
	Input.parse_input_event(tab);await settle()
	check(root.gui_get_focus_owner()==prefs.zone,"Actual built-in Tab action moves to next setting")
	tab.pressed=false;Input.parse_input_event(tab)
	prefs.motion.button_pressed=true;prefs.puck_cue.button_pressed=true;prefs.save_preferences()
	settings.load_settings()
	check(settings.values.reduce_motion and settings.values.puck_indicator,"Comfort and visibility preferences persist")
	Match.skip_title=true;Match.return_to_title=false
	change_scene_to_file("res://main.tscn");await settle()
	var game=current_scene
	game.set_physics_process(false);game.in_menu=false;game.paused=false
	check(game.reduce_motion and game.show_puck_indicator and game.hud_node.reduce_motion,"Saved accessibility preferences reach real match/HUD")
	game.update_camera(1.0/120)
	var fixed: Transform3D=game.camera.global_transform
	game.puck.position=Vector3(7,0.03,-18);game.player.position=Vector3(-6,0,13)
	game.update_camera(1.0/120)
	check(game.camera.global_transform.is_equal_approx(fixed),"Reduced-motion camera does not chase puck or player")
	game.sync_puck_shadow()
	check(game.puck_marker.visible,"Actual puck marker is visible on rink")
	var projected: Vector2=game.camera.unproject_position(game.puck.global_position)
	check((game.puck_marker.position+Vector2(16,16)).distance_to(projected)<0.01,"Marker tracks actual puck projection")
	game.set_paused(true);check(not game.puck_marker.visible,"Pause hides puck marker")
	game.set_paused(false)
	game.hud_node.show_banner("GOAL","COMFORT TEST",Color.WHITE,0.1)
	check(game.hud_node.banner.scale==Vector2.ONE and game.hud_node.banner.modulate.a==1,"Reduced-motion banner is stable, without zoom/fade")
	game.match_state.phase=game.MatchState.Phase.PLAY
	game.previous_puck=Vector3(0.1,0.02,game.Arena.GOAL_LINE-0.25)
	game.puck.position=Vector3(0.1,0.02,game.Arena.GOAL_LINE+0.4)
	game._physics_process(1.0/120)
	check(game.match_state.score[1]==1 and not game.celebration.is_active(),"Reduced motion suppresses goal flashes while preserving an actual scored goal")
	game.reduce_motion=false;game.show_puck_indicator=false;game.sync_puck_shadow()
	check(not game.puck_marker.visible,"Puck marker can be disabled without puck changes")
	change_scene_to_file("res://practice.tscn");await settle()
	var practice=current_scene;practice.set_physics_process(false)
	practice.update_camera(1.0/120)
	var practice_camera: Transform3D=practice.camera.global_transform
	practice.puck.position=Vector3(8,0.03,15);practice.update_camera(1.0/120)
	check(practice.reduce_motion and practice.camera.global_transform.is_equal_approx(practice_camera),"Practice respects fixed comfort camera")
	check(practice.puck_marker.visible,"Practice uses same visible puck marker")
	current_scene.queue_free();await process_frame
	for suffix in ["",".bak",".tmp",".bak.tmp"]:
		if FileAccess.file_exists(Settings.path+suffix): DirAccess.remove_absolute(Settings.path+suffix)
	Settings.path=original
	print("Accessibility: %d checks; %d failures"%[checks,failures]);quit(failures)
