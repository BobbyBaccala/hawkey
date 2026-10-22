extends SceneTree
## Staged production poses for frontal/three-quarter handedness inspection.
var m
var v
var caption:Label
func _initialize()->void:call_deferred("run")
func shot(label_:String,close_:bool=false)->void:
	caption.text="STRONG-SIDE CARRY  ·  staged production pose\n"+label_.replace("-"," ").to_upper()
	if close_:
		var top:Vector3=v.rig.to_global(v.stick_grip())
		m.camera.position=top+Vector3(-1.1,0.5,-1.5);m.camera.look_at(top+Vector3(0,-0.15,0));m.camera.fov=40
	else:
		m.camera.position=Vector3(0,1.65,-3.6);m.camera.look_at(Vector3(0,0.75,0));m.camera.fov=46
	m.puck.position=v.get_blade_world()
	for f in range(3):await process_frame
	await RenderingServer.frame_post_draw
	print("STRONG_CAPTURE ",label_," ",root.get_texture().get_image().save_jpg("/workspace/hawkey/build/strong-side-"+label_+".jpg",0.95))
func run()->void:
	root.size=Vector2i(1200,800);root.content_scale_size=root.size
	load("res://scripts/game_settings.gd").path="res://build/strong-side-capture-settings.json"
	load("res://scripts/match.gd").skip_title=true
	m=load("res://main.tscn").instantiate();root.add_child(m);current_scene=m
	m.set_physics_process(false);m.set_process(false);m.hud_node.hide();m.selection.hide();m.puck.freeze=true
	for actor in m.skaters:actor.visible=actor==m.player
	for actor in m.goalkeepers:actor.hide()
	m.player.position=Vector3.ZERO;v=m.player.get_child(1);v.rotation.y=0
	caption=Label.new();caption.position=Vector2(24,24);caption.add_theme_font_size_override("font_size",19)
	var layer=CanvasLayer.new();m.add_child(layer);layer.add_child(caption)
	for hand in ["R","L"]:
		v.set_shoots(hand);v.phase=0;v.desired_stick=Vector2.ZERO;v.stick_intent=Vector2.ZERO;v.skill_lean=0
		for f in range(120):v.animate(3,1.0/120,0,false)
		await shot("right-shot" if hand=="R" else "left-shot")
		await shot("right-hand-alignment" if hand=="R" else "left-hand-alignment",true)
	quit()
