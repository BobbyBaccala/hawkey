extends SceneTree
## Displayed-GPU regression: the old deep-V shader painted a white bib below the collar.
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size=Vector2i(256,256);root.content_scale_size=Vector2i(256,256)
	var scene:=Node3D.new();root.add_child(scene)
	var world:=WorldEnvironment.new();world.environment=Environment.new()
	world.environment.background_mode=Environment.BG_COLOR;world.environment.background_color=Color.BLACK
	world.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color=Color.WHITE;world.environment.ambient_light_energy=0.8;scene.add_child(world)
	var light:=DirectionalLight3D.new();scene.add_child(light)
	var camera:=Camera3D.new();scene.add_child(camera);camera.position=Vector3(0,1.49,1);camera.look_at(Vector3(0,1.49,0));camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=0.18;camera.current=true
	var arrays: Array=[];arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=PackedVector3Array([Vector3(-0.09,1.425,0),Vector3(0.09,1.425,0),Vector3(0.09,1.555,0),Vector3(-0.09,1.555,0)])
	arrays[Mesh.ARRAY_NORMAL]=PackedVector3Array([Vector3.BACK,Vector3.BACK,Vector3.BACK,Vector3.BACK])
	arrays[Mesh.ARRAY_TEX_UV]=PackedVector2Array([Vector2(-0.03,0),Vector2(0.03,0),Vector2(0.03,1),Vector2(-0.03,1)])
	arrays[Mesh.ARRAY_TEX_UV2]=PackedVector2Array([Vector2(0.25,1.425),Vector2(0.25,1.425),Vector2(0.25,1.555),Vector2(0.25,1.555)])
	arrays[Mesh.ARRAY_INDEX]=PackedInt32Array([0,1,2,0,2,3])
	var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var surface:=MeshInstance3D.new();surface.mesh=mesh
	var material=preload("res://scripts/kit_materials.gd").jersey(Color("#164a9a"),Color.WHITE,"","").duplicate()
	var negative_control: bool="--negative-control" in OS.get_cmdline_user_args()
	if negative_control: material.set_shader_parameter("collar_profile",Vector4(1.56,0.095,0.014,10));material.set_shader_parameter("collar_band_width",0.022)
	surface.material_override=material;scene.add_child(surface)
	for i in range(4): await process_frame;await RenderingServer.frame_post_draw
	var frame:=root.get_texture().get_image()
	var body:=frame.get_pixel(128,128);var band:=frame.get_pixel(128,92)
	var pass_body:=body.b>body.r*1.3
	var pass_band:=absf(band.b-band.r)<0.12 and band.r>0.1
	var report:={"engine":Engine.get_version_info().string,"adapter":RenderingServer.get_video_adapter_name(),"negative_control":negative_control,"body_is_team_blue":pass_body,"trim_is_white":pass_band,"body":str(body),"band":str(band)}
	var name_:="collar-render-negative" if negative_control else "collar-render"
	frame.save_jpg("res://build/"+name_+".jpg",0.96)
	FileAccess.open("res://build/"+name_+".json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	var passed: bool=(not pass_body) if negative_control else (pass_body and pass_band)
	print("Collar render: ","PASS" if passed else "FAIL"," ",report)
	quit(0 if passed else 1)
