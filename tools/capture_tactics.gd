extends SceneTree
## Actual viewport evidence. Formation image is a staged planner inspection, not live play.
const T=preload("res://scripts/team_tactics.gd")
func _initialize() -> void: call_deferred("run")
func shot(name_: String) -> void:
	for i in range(3): await process_frame
	await RenderingServer.frame_post_draw
	print("TACTICS_CAPTURE ",name_," ",root.get_texture().get_image().save_jpg("res://build/tactics-"+name_+".jpg",0.96))
func run() -> void:
	root.size=Vector2i(1440,900);root.content_scale_size=Vector2i(1440,900)
	load("res://scripts/game_settings.gd").path="res://build/tactics-capture-settings.json"
	load("res://scripts/match.gd").skip_title=true
	change_scene_to_file("res://main.tscn")
	for i in range(4): await process_frame
	var m=current_scene
	m.set_physics_process(false);m.set_process(false);m.in_menu=false
	m.set_paused(true)
	await shot("coaching")
	m.set_paused(false);m.hud_node.visible=false
	# Use actual planner targets as explicit inspection stations; no played-game claim.
	var groups: Array=[[],[]]
	for actor in m.skaters:
		groups[m.body_team(actor)].append({"id":actor.get_instance_id(),"slot":int(actor.get_meta("slot")),"position":actor.position})
	groups[1].pop_back()
	var attack: float=m.attack_direction(0)
	m.puck.position=Vector3(7,0.08,17*attack)
	m.player.position=Vector3(7,0,17*attack)
	var plans: Array=[T.plan(groups[0],groups[1],m.puck.position,m.player.get_instance_id(),attack,T.defaults()),T.plan(groups[1],groups[0],m.puck.position,-1,-attack,T.defaults())]
	m.skaters[9].visible=false
	for actor in m.skaters:
		var team: int=m.body_team(actor)
		if not plans[team].has(actor.get_instance_id()): continue
		var item: Dictionary=plans[team][actor.get_instance_id()]
		if actor!=m.player: actor.position=item.target
		actor.velocity=Vector3.ZERO
		actor.get_child(1).rotation.y=0 if team==0 else PI
		var caption:=Label3D.new();caption.text=("PP " if team==0 else "PK ")+str(actor.get_meta("slot"))
		caption.font_size=42;caption.pixel_size=0.015;caption.billboard=BaseMaterial3D.BILLBOARD_ENABLED
		caption.position=Vector3(0,2.6,0);caption.no_depth_test=true;caption.modulate=Color("#63e6cf") if team==0 else Color("#ffb787")
		actor.add_child(caption)
	m.camera.position=Vector3(0,34,19*attack+10);m.camera.look_at(Vector3(0,0,19*attack));m.camera.fov=45
	var overlay:=CanvasLayer.new();root.add_child(overlay)
	var panel:=PanelContainer.new();panel.position=Vector2(40,28);overlay.add_child(panel)
	var label:=Label.new();label.text="TACTICAL INSPECTION  •  1–3–1 POWER PLAY vs BOX PK\nActual planner stations • staged positions, not live match footage"
	label.add_theme_font_size_override("font_size",23);panel.add_child(label)
	await shot("special-teams")
	FileAccess.open("res://build/tactics-capture.json",FileAccess.WRITE).store_string(JSON.stringify({"engine":Engine.get_version_info().string,"adapter":RenderingServer.get_video_adapter_name(),"source":"Direct Godot viewport JPEGs. Real match pause coaching UI; special-teams image explicitly staged at actual planner targets, with temporary inspection labels. No photo manipulation."},"\t"))
	quit()
