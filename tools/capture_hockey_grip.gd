extends SceneTree
## Production poses, deliberately staged for hand inspection; not live gameplay.
var m
var v
var caption:Label
var output:="/workspace/hawkey/build/grip"
func _initialize()->void:call_deferred("run")
func shot(label_:String,close_:bool=false,other_side:bool=false)->void:
	caption.text="GRIP / DEKE INSPECTION  ·  staged production pose\n"+label_.replace("-"," ").to_upper()
	if close_:
		var grip:Vector3=v.rig.to_global(v.stick_grip())
		m.camera.position=grip+Vector3(0.95 if other_side else -0.95,0.55,-1.15)
		m.camera.look_at(grip+Vector3(0,-0.06,0));m.camera.fov=38
	else:
		m.camera.position=Vector3(-2.6,1.9,-3.1);m.camera.look_at(Vector3(0,0.8,-0.15));m.camera.fov=42
	if label_.begins_with("reference-stance") and not close_:
		m.camera.position=Vector3(-1.8,1.6,-2.9);m.camera.look_at(Vector3(0,0.8,-0.15))
	m.puck.position=v.get_blade_world()
	for f in range(3):await process_frame
	await RenderingServer.frame_post_draw
	print("GRIP_CAPTURE ",label_," ",root.get_texture().get_image().save_jpg(output+"-"+label_+".jpg",0.95))
func run()->void:
	root.size=Vector2i(1200,800);root.content_scale_size=root.size
	load("res://scripts/game_settings.gd").path="res://build/grip-capture-settings.json"
	load("res://scripts/match.gd").skip_title=true
	m=load("res://main.tscn").instantiate();root.add_child(m);current_scene=m
	m.set_physics_process(false);m.set_process(false);m.hud_node.hide();m.selection.hide();m.puck.freeze=true
	for actor in m.skaters:actor.visible=actor==m.player
	for actor in m.goalkeepers:actor.hide()
	m.player.position=Vector3.ZERO;v=m.player.get_child(1);v.rotation.y=0
	caption=Label.new();caption.position=Vector2(24,24);caption.add_theme_font_size_override("font_size",19)
	var layer=CanvasLayer.new();m.add_child(layer);layer.add_child(caption)
	for f in range(120):v.animate(3,1.0/120,0,true)
	await shot("ready-hand",true)
	await shot("ready-hand-reverse",true,true)
	for kind in ["cut","toe_drag","sweep"]:
		var skill=load("res://scripts/puck_skills.gd").new();skill.request(kind)
		var seconds:float=skill.DURATIONS[kind]*(0.50 if kind=="toe_drag" else 0.27)
		for f in range(int(seconds*120)):
			skill.advance(1.0/120,true);v.desired_stick=skill.stick(Vector2.ZERO,4,true);v.skill_lean=skill.lean();v.animate(4,1.0/120,0,true)
		await shot(kind)
		if kind=="toe_drag":await shot("toe-drag-hand",true)
		v.desired_stick=Vector2.ZERO;v.skill_lean=0
		for f in range(120):v.animate(3,1.0/120,0,true)
	# Reference-inspired inspection: mirrored wrist/arm relationships, edge lean.
	v.desired_stick=Vector2(-0.55,0.05);v.skill_lean=-0.75
	for f in range(90):v.animate(4,1.0/120,-0.12,true)
	await shot("reference-stance")
	await shot("reference-stance-hand",true)
	quit()
