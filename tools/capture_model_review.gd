extends SceneTree
## Genuine isolated native 3D review. No arena load, AI or presentation effects.
const Visual=preload("res://scripts/skater_visual.gd")
var stage:="baseline"
var goalkeeper:=false
var pose_name:="idle"
var helmet_only:=false
var captures: Array=[]
var camera: Camera3D
var visual: Node3D
func _initialize() -> void: call_deferred("run")
func shot(name_: String, position_: Vector3, target: Vector3, fov: float=35.0) -> void:
	camera.position=position_;camera.look_at(target);camera.fov=fov
	await RenderingServer.frame_post_draw
	var path: String="res://build/model-review-"+stage+"-"+name_+".jpg"
	var result:=root.get_texture().get_image().save_jpg(path,0.96)
	captures.append({"path":path,"error":result,"camera":str(position_),"target":str(target),"fov":fov})
	print("REVIEW_CAPTURE ",path," result ",result)
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--stage="): stage=arg.trim_prefix("--stage=").validate_filename()
		if arg=="--goalie": goalkeeper=true
		if arg=="--helmet-only": helmet_only=true
		if arg.begins_with("--pose="): pose_name=arg.trim_prefix("--pose=")
	DirAccess.make_dir_recursive_absolute("res://build")
	root.size=Vector2i(960,960);root.content_scale_size=Vector2i(960,960)
	root.msaa_3d=Viewport.MSAA_DISABLED;root.screen_space_aa=Viewport.SCREEN_SPACE_AA_DISABLED
	var scene:=Node3D.new();root.add_child(scene)
	var world:=WorldEnvironment.new();world.environment=Environment.new()
	world.environment.background_mode=Environment.BG_COLOR;world.environment.background_color=Color("#333b44")
	world.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color=Color.WHITE;world.environment.ambient_light_energy=0.55
	world.environment.tonemap_mode=Environment.TONE_MAPPER_FILMIC
	scene.add_child(world)
	for config in [[Vector3(-45,-30,0),1.2,Color("#fff5eb")],[Vector3(-20,135,0),0.7,Color("#dcecff")]]:
		var light:=DirectionalLight3D.new();light.rotation_degrees=config[0];light.light_energy=config[1];light.light_color=config[2];scene.add_child(light)
	var floor_mesh:=MeshInstance3D.new();floor_mesh.mesh=PlaneMesh.new();floor_mesh.mesh.size=Vector2(8,8)
	var floor_material:=StandardMaterial3D.new();floor_material.albedo_color=Color("#66717e");floor_material.roughness=0.92
	floor_mesh.material_override=floor_material;scene.add_child(floor_mesh)
	camera=Camera3D.new();scene.add_child(camera);camera.current=true
	visual=Visual.new();visual.goalie=goalkeeper;visual.kit=Color("#185c73");visual.number="17";scene.add_child(visual);visual.set_nameplate("LARSEN")
	for i in range(8): visual.animate(0,1.0/60.0)
	if goalkeeper and pose_name=="pad_right":
		for i in range(60):
			visual.butterfly=move_toward(visual.butterfly,1.0,0.1)
			visual.set_save("pad_right",Vector2(-0.95,0.1),1.0/60.0)
			visual.animate(0,1.0/60.0)
	await process_frame
	if helmet_only:
		var h: Vector3=visual.helmet.global_position
		for view in [["front",Vector3(0,0.04,-0.75)],["quarter",Vector3(0.4,0.08,-0.65)],["side",Vector3(0.75,0.06,0)],["rear",Vector3(0.35,0.18,0.65)]]:
			await shot(view[0],h+view[1],h+Vector3(0,-0.025,0),32)
		write_metadata();quit();return
	await shot("back",Vector3(0,0.9,3.5),Vector3(0,0.75,0))
	await shot("three-quarter",Vector3(2.2,1.2,-3.0),Vector3(0,0.75,0))
	await shot("side",Vector3(3.5,0.9,0),Vector3(0,0.75,0))
	var head: Vector3=visual.helmet.global_position
	await shot("head",head+Vector3(0.4,0.05,-0.65),head+Vector3(0,-0.03,0),32)
	if not goalkeeper:
		var glove: Vector3=visual.skater_gloves[0].global_position
		await shot("glove",glove+Vector3(0.4,0.15,-0.55),glove,32)
	write_metadata()
	quit()
func write_metadata() -> void:
	var metadata: Dictionary={"engine":Engine.get_version_info().string,"source":"Actual isolated Godot 3D stage, current production player, fixed neutral lighting; staged pose, not gameplay","stage":stage,"goalkeeper":goalkeeper,"pose":pose_name,"renderer":RenderingServer.get_video_adapter_name(),"captures":captures,"size":"960x960"}
	var file:=FileAccess.open("res://build/model-review-"+stage+".json",FileAccess.WRITE);file.store_string(JSON.stringify(metadata,"\t"));file.close()
