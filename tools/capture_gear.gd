extends SceneTree
## Renders the sculpted equipment on its own, front and three-quarter views.
## xvfb-run godot --rendering-driver opengl3 --resolution 1728x1080 --script tools/capture_gear.gd
const Gear = preload("res://scripts/gear_builder.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("#2b333b")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("#aab6c0")
	env.environment.ambient_light_energy = 0.55
	env.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.add_child(env)
	var key := DirectionalLight3D.new()
	key.rotation = Vector3(-0.75, 0.55, 0)
	key.light_energy = 1.25
	key.shadow_enabled = true
	world.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation = Vector3(-0.3, -2.3, 0)
	fill.light_energy = 0.35
	world.add_child(fill)
	var kit := Color("#185c73")
	var accent := Color("#e0a33a")
	var items := [
		[Gear.goalie_pad(1, kit, accent), Vector3(-1.05, 0.44, 0), 0.0],
		[Gear.goalie_pad(-1, kit, accent), Vector3(-0.72, 0.44, 0), 0.0],
		[Gear.goalie_pad(1, kit, accent), Vector3(-0.30, 0.44, 0), 1.0],
		[Gear.blocker(-1, kit, accent), Vector3(0.12, 0.62, 0), 0.0],
		[Gear.blocker(-1, kit, accent), Vector3(0.12, 0.17, 0), -0.9],
		[Gear.catcher(1, kit, accent), Vector3(0.48, 0.62, 0), 0.0],
		[Gear.catcher(1, kit, accent), Vector3(0.48, 0.15, 0), 0.9],
		[Gear.goalie_mask(kit, accent), Vector3(0.86, 0.66, 0), 0.0],
		[Gear.goalie_mask(kit, accent), Vector3(0.86, 0.24, 0), 1.1],
		[Gear.skate(true), Vector3(1.16, 0.10, 0), 1.3],
		[Gear.skater_glove(kit), Vector3(1.18, 0.50, 0), 0.4],
	]
	for item in items:
		var instance := MeshInstance3D.new()
		instance.mesh = item[0]
		instance.position = item[1]
		instance.rotation.y = item[2]
		world.add_child(instance)
	var camera := Camera3D.new()
	camera.position = Vector3(0.05, 0.55, 2.35)
	camera.fov = 45
	world.add_child(camera)
	camera.look_at(Vector3(0.05, 0.42, 0))
	camera.current = true
	for i in range(3):
		await process_frame
	await RenderingServer.frame_post_draw
	var path := "/tmp/hawkey-gear-gallery.png"
	if OS.get_cmdline_user_args().size() > 0:
		path = OS.get_cmdline_user_args()[0]
	get_root().get_texture().get_image().save_png(path)
	quit()
