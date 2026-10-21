extends SceneTree
## GPU/driver regression: facial shader regions must not turn black from NaN pow().
## Requires a display; intentionally separate from the headless suite.
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size=Vector2i(256,256);root.content_scale_size=Vector2i(256,256)
	root.msaa_3d=Viewport.MSAA_DISABLED;root.screen_space_aa=Viewport.SCREEN_SPACE_AA_DISABLED
	var scene:=Node3D.new();root.add_child(scene)
	var env:=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR
	env.environment.background_color=Color("#555555");env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color.WHITE;env.environment.ambient_light_energy=0.7;scene.add_child(env)
	var camera:=Camera3D.new();scene.add_child(camera);camera.position=Vector3(0,0,2);camera.look_at(Vector3.ZERO);camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=2.2;camera.current=true
	var light:=DirectionalLight3D.new();scene.add_child(light);light.light_energy=1.0
	var arrays: Array=[];arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=PackedVector3Array([Vector3(-1,-1,0),Vector3(1,-1,0),Vector3(1,1,0),Vector3(-1,1,0)])
	arrays[Mesh.ARRAY_NORMAL]=PackedVector3Array([Vector3.BACK,Vector3.BACK,Vector3.BACK,Vector3.BACK])
	arrays[Mesh.ARRAY_TEX_UV]=PackedVector2Array([Vector2(0.43,0),Vector2(0.57,0),Vector2(0.57,1),Vector2(0.43,1)])
	arrays[Mesh.ARRAY_COLOR]=PackedColorArray([Color(0,1.54/2,1),Color(0,1.54/2,1),Color(0,1.76/2,1),Color(0,1.76/2,1)])
	arrays[Mesh.ARRAY_INDEX]=PackedInt32Array([0,1,2,0,2,3])
	var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var instance:=MeshInstance3D.new();instance.mesh=mesh
	var material:=ShaderMaterial.new();material.shader=preload("res://assets/uniform.gdshader")
	var negative_control: bool="--negative-control" in OS.get_cmdline_user_args()
	if negative_control:
		var faulty:=Shader.new()
		faulty.code=material.shader.code.replace("abs(face_u)","face_u").replace("abs(brow_u)","brow_u").replace("abs(rest_height - 1.601)","(rest_height - 1.601)").replace("abs(rest_height - brow_y)","(rest_height - brow_y)")
		material.shader=faulty
	instance.material_override=material;scene.add_child(instance)
	for i in range(4):
		await process_frame
		await RenderingServer.frame_post_draw
	var frame:=root.get_texture().get_image()
	var black:=0;var samples:=0
	for y in range(32,224,8):
		for x in range(32,224,8):
			var c:=frame.get_pixel(x,y);samples+=1
			if maxf(c.r,maxf(c.g,c.b))<0.01: black+=1
	DirAccess.make_dir_recursive_absolute("res://build")
	frame.save_jpg("res://build/skin-render-negative-control.jpg" if negative_control else "res://build/skin-render-probe.jpg",0.96)
	var file:=FileAccess.open("res://build/skin-render-negative-control.json" if negative_control else "res://build/skin-render-probe.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"engine":Engine.get_version_info().string,"adapter":RenderingServer.get_video_adapter_name(),"negative_control":negative_control,"samples":samples,"black_samples":black},"\t"));file.close()
	print("Skin render probe: ",samples," checks; ",black," failures")
	quit(0 if (black>0 if negative_control else black==0) else 1)
