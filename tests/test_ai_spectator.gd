extends SceneTree
const Match=preload("res://scripts/match.gd")
const Settings=preload("res://scripts/game_settings.gd")
var failures:=0
func check(ok: bool,message: String) -> void:
	if not ok: failures+=1;push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	Settings.path="res://build/ai-spectator-test/settings.json"
	Match.skip_title=true
	change_scene_to_file("res://main.tscn")
	for i in range(3): await process_frame
	var m=current_scene;m.set_physics_process(false);m.set_process(false)
	m.ai_vs_ai=true;m.cooldown=10
	for actor in m.skaters:
		actor.position=Vector3((int(actor.get_meta("slot"))-2)*3,0,8 if m.body_team(actor)==0 else -8)
		actor.velocity=Vector3.ZERO
	m.puck.position=Vector3.ZERO;m.carrier=null
	var player=m.player;var before: Vector3=player.position
	m.control_player(1.0/60)
	check(player.position==before,"Spectator does not receive human skating input")
	m.update_team_ai(1.0/60)
	check(player.has_meta("tactical_target") and player.velocity.length()>0,"AI drives normally human-controlled skater")
	for actor in m.skaters: check(actor.has_meta("tactical_target"),"Every active skater receives an AI assignment")
	m.update_camera(1.0/60);m.update_match_hud()
	check(not m.selection.visible and not m.hud_node.shot_reticle.visible,"No human selection or shot aim in AI video")
	check("AI vs AI" in m.help.text,"HUD identifies both computer-controlled teams")
	m.release_velocity(player,Vector3(0,0,10))
	check(is_equal_approx(m.puck.angular_velocity.y,6),"Spectator AI uses AI puck spin instead of human stick input")
	m.ai_vs_ai=false;player.velocity=Vector3.ZERO;before=player.position
	m.update_team_ai(1.0/60)
	check(player.position==before,"Normal human control preserved outside spectator mode")
	change_scene_to_file("res://events.tscn");await process_frame
	print("AI spectator failures: ",failures);quit(failures)
