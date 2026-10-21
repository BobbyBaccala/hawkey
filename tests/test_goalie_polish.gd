extends SceneTree
const Visual=preload("res://scripts/skater_visual.gd")
const Gear=preload("res://scripts/gear_builder.gd")
const Match=preload("res://scripts/match.gd")
const Settings=preload("res://scripts/game_settings.gd")
var checks:=0
var failures:=0
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok: failures+=1;push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var v:=Visual.new();v.goalie=true;root.add_child(v);await process_frame
	for mesh in [Gear.goalie_pad(1,Color.RED,Color.BLUE),Gear.blocker(-1,Color.RED,Color.BLUE),Gear.catcher(1,Color.RED,Color.BLUE)]:
		var material=mesh.surface_get_material(0)
		check(material.normal_enabled and material.normal_texture!=null and material.roughness_texture!=null,"Goalie leather has normal and roughness maps")
		check(material.normal_texture.get_image().has_mipmaps() and material.roughness_texture.get_image().has_mipmaps(),"Microfinish mipmaps avoid distant shimmer")
		var a=mesh.surface_get_arrays(0);var tangents: PackedFloat32Array=a[Mesh.ARRAY_TANGENT]
		check(tangents.size()==a[Mesh.ARRAY_VERTEX].size()*4,"Normal map has a tangent per vertex")
		var finite:=true;var orthogonal:=true
		for i in range(a[Mesh.ARRAY_VERTEX].size()):
			var t:=Vector3(tangents[i*4],tangents[i*4+1],tangents[i*4+2])
			finite=finite and t.is_finite() and absf(t.length()-1)<0.01
			orthogonal=orthogonal and absf(t.dot(a[Mesh.ARRAY_NORMAL][i]))<0.02
		check(finite and orthogonal,"Degenerate atlas UVs retain finite orthogonal tangents")
		if RenderingServer.get_current_rendering_method()=="gl_compatibility":
			check(material.texture_filter==BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS,"Compatibility avoids anisotropic constant-UV artifact")
	v.butterfly=0.1;v.animate(0,1.0/60,0,false)
	check(v.goalie_drop<v.butterfly,"Butterfly begins with eased knee movement")
	v.butterfly=0.9;v.animate(0,1.0/60,0,false)
	check(v.goalie_drop>v.butterfly,"Butterfly eases into full seal")
	v.butterfly=1;v.animate(0,1.0/60,0,false)
	check(is_equal_approx(v.goalie_drop,1.0),"Full drop still reaches exact terminal pose")
	for i in range(30): v.set_save("glove",Vector2(0.75,1.35),1.0/60);v.animate(0,1.0/60,0,false)
	check(v.catch_close==0,"Reading a glove save never closes the pocket before contact")
	v.secure_catch()
	for i in range(15): v.animate(0,1.0/60,0,false)
	check(v.catch_close>0.98,"Confirmed catch folds fingers smoothly")
	var mitt=v.goalie_gloves[0].get_child(0)
	check(mitt.mesh.get_blend_shape_count()==1 and mitt.get_blend_shape_value(0)>0.98,"Visible catcher uses the secured-catch morph")
	v.release_catch()
	for i in range(60): v.animate(0,1.0/60,0,false)
	check(v.catch_close<0.002,"Catcher reopens after release")
	# Exact save-weight response at two frame rates.
	v.save_weights.glove=0
	for i in range(15): v.set_save("glove",Vector2(0.6,1.2),1.0/30)
	var at30: float=v.save_weights.glove;v.save_weights.glove=0
	for i in range(60): v.set_save("glove",Vector2(0.6,1.2),1.0/120)
	check(absf(at30-v.save_weights.glove)<0.0001,"Save blend independent of frame rate")
	# Force empty optional clips; fallback step still advances on lateral travel.
	v.butterfly=0;v.shuffle_data=[{},{}];v.shuffle_weight=1;v.lateral=1.2
	v.shuffle_time=0.15;v.pose(0,0);var foot: Vector3=v.feet[0]
	v.shuffle_time=0.80;v.pose(0,0)
	check(v.feet[0].distance_to(foot)>0.025,"No-mocap lateral shuffle changes foot placement")
	check(v.feet[0].x>0.20 and v.feet[1].x< -0.20,"Shuffle stance never crosses the feet")
	v.queue_free();await process_frame
	Settings.path="res://build/goalie-polish/settings.json";Match.skip_title=true
	change_scene_to_file("res://main.tscn")
	for i in range(3): await process_frame
	var m=current_scene;m.set_physics_process(false);m.set_process(false)
	var keeper=m.goalkeepers[0];var catcher=keeper.get_node("Catcher")
	var front: Vector3=catcher.global_basis.z
	m.puck.global_position=catcher.global_position+front*0.06
	m.last_puck_velocity=-front*12;m.goalie_contact_timer=0;m.match_state.phase=m.MatchState.Phase.PLAY
	m._on_puck_contact(catcher)
	check(m.caught_by==keeper and keeper.get_child(1).catch_hold>0,"Actual pocket catch triggers visual closure")
	for i in range(20): m._physics_process(1.0/60)
	check(keeper.get_child(1).catch_close>0.99,"Whistle phase continues goalie catch animation")
	var pocket: Vector3=keeper.get_child(1).goalie_gloves[0].to_global(Vector3(0.02,0.15,0.01))
	check(m.puck.global_position.distance_to(pocket)<0.001,"Frozen caught puck stays with glove")
	m.setup_faceoff()
	check(m.caught_by==null and keeper.get_child(1).catch_hold==0,"Faceoff releases caught-puck ownership")
	change_scene_to_file("res://events.tscn");await process_frame
	print("Goalie polish: %d checks; %d failures"%[checks,failures]);quit(failures)
