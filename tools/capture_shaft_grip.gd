extends SceneTree
## Genuine close-up production poses; puck placed for inspection, not gameplay.
var m
var v
var caption:Label
func _initialize()->void:call_deferred("run")
func shot(label_:String,reverse_:bool=false)->void:
	caption.text="SHAFT-ALIGNED GRIP  ·  staged production pose\n"+label_.replace("-"," ").to_upper()
	var top:Vector3=v.rig.to_global(v.stick_grip())
	var side:float=v.shot_side()
	m.camera.position=top+Vector3((0.75 if reverse_ else -0.75)*side,0.30,-0.85)
	m.camera.look_at(top+Vector3(0,-0.12,0));m.camera.fov=42
	m.puck.position=v.get_blade_world()
	for f in range(3):await process_frame
	await RenderingServer.frame_post_draw
	print("SHAFT_CAPTURE ",label_," ",root.get_texture().get_image().save_jpg("/workspace/hawkey/build/shaft-grip-"+label_+".jpg",0.95))
func run()->void:
	root.size=Vector2i(1200,800);root.content_scale_size=root.size
	load("res://scripts/game_settings.gd").path="res://build/shaft-grip-capture-settings.json"
	load("res://scripts/match.gd").skip_title=true
	m=load("res://main.tscn").instantiate();root.add_child(m);current_scene=m
	m.set_physics_process(false);m.set_process(false);m.hud_node.hide();m.selection.hide();m.puck.freeze=true
	for actor in m.skaters:actor.visible=actor==m.player
	for actor in m.goalkeepers:actor.hide()
	m.player.position=Vector3.ZERO;v=m.player.get_child(1);v.rotation.y=0
	caption=Label.new();caption.position=Vector2(24,24);caption.add_theme_font_size_override("font_size",18)
	var layer=CanvasLayer.new();m.add_child(layer);layer.add_child(caption)
	for hand in ["R","L"]:
		v.set_shoots(hand);v.phase=0;v.desired_stick=Vector2.ZERO;v.stick_intent=Vector2.ZERO;v.skill_lean=0
		for f in range(120):v.animate(3,1.0/120,0,false)
		await shot("right-shot-front" if hand=="R" else "left-shot-front")
		await shot("right-shot-reverse" if hand=="R" else "left-shot-reverse",true)
	quit()
