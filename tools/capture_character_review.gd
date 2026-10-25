extends SceneTree
## Actual character assets in a neutral studio; no generated-image substitution.
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("#202d3c")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("#cad8eb")
	environment.environment.ambient_light_energy = 0.50
	world.add_child(environment)
	for spec in [[Vector3(-45,-32,0),1.1],[Vector3(-20,140,0),0.65]]:
		var light := DirectionalLight3D.new()
		light.rotation_degrees = spec[0]
		light.light_energy = spec[1]*0.65
		light.shadow_enabled = true
		world.add_child(light)
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(30,30)
	floor_mesh.mesh = plane
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color("#283646")
	floor_material.roughness = 0.8
	floor_mesh.material_override = floor_material
	world.add_child(floor_mesh)
	for i in [0,2]:
		var actor = load("res://scripts/skater_visual.gd").new()
		actor.goalie = i>=2
		actor.kit = Color("#175b87")
		actor.accent = Color("#e6edf0")
		actor.number = "31" if actor.goalie else "17"
		world.add_child(actor)
		actor.position.x = -0.82 if i==0 else 0.82
		actor.rotation.y = PI-0.25 if i!=1 else -PI/2.5
		actor.butterfly = 1.0 if actor.goalie and "--butterfly" in OS.get_cmdline_user_args() else 0.0
		actor.animate(0.0,1.0)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.position = Vector3(0,1.8,4.3)
	camera.look_at(Vector3(0,0.8,0))
	camera.fov = 32
	camera.current = true
	for i in range(3): await process_frame
	await RenderingServer.frame_post_draw
	var path := "/tmp/hawkey-characters.png"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): path=arg.substr(9)
	get_root().get_texture().get_image().save_png(path)
	quit()
