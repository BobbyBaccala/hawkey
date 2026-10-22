extends SceneTree
## Genuine close-up production poses; puck placed for inspection, not gameplay.
var m
var v
var caption:Label
func _initialize()->void:call_deferred("run")
func shot(label_:String,reverse_:bool=false,blade_:bool=false)->void:
	caption.text="PALM / BLADE CONTACT  ·  staged production pose\n"+label_.replace("-"," ").to_upper()
	var top:Vector3=v.rig.to_global(v.stick_grip())
	var side:float=v.shot_side()
	m.camera.position=top+Vector3((0.75 if reverse_ else -0.75)*side,0.30,-0.85)
	m.camera.look_at(top+Vector3(0,-0.12,0));m.camera.fov=42
	if blade_:
		var target:Vector3=v.get_blade_world()
		var normal:Vector3=v.stick_blade.global_basis.z*side
		m.camera.position=target+normal*0.65+Vector3.UP*0.45-v.stick_blade.global_basis.x*0.20
		m.camera.look_at(target);m.camera.fov=40
	m.puck.position=v.get_blade_world()
	for f in range(3):await process_frame
	await RenderingServer.frame_post_draw
	print("PALM_CAPTURE ",label_," ",root.get_texture().get_image().save_jpg("/workspace/hawkey/build/palm-blade-"+label_+".jpg",0.95))
func run()->void:
	root.size=Vector2i(1200,800);root.content_scale_size=root.size
	load("res://scripts/game_settings.gd").path="res://build/palm-blade-capture-settings.json"
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
		await shot("right-shot-blade" if hand=="R" else "left-shot-blade",false,true)
	quit()
