extends SceneTree
## Product-shot review of one piece of goalie gear on a light backdrop, from the
## angles equipment photos use, so the model can be compared side by side with
## reference photos of real gear.
## xvfb-run ... godot --rendering-method gl_compatibility --script tools/capture_piece.gd -- --piece=pad|catcher|blocker|mask [--white]
## Writes /tmp/hawkey-piece-<piece>.png.
const Gear = preload("res://scripts/gear_builder.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var piece := "pad"
	var white := false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--piece="): piece = arg.substr(8)
		if arg == "--white": white = true
	var world := Node3D.new()
	root.add_child(world)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("#e9ecef")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("#ffffff")
	env.environment.ambient_light_energy = 0.12
	env.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.add_child(env)
	var key := DirectionalLight3D.new()
	key.rotation = Vector3(-0.45, -0.85, 0)
	key.light_energy = 0.62
	key.shadow_enabled = true
	world.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation = Vector3(-0.3, 0.9, 0)
	fill.light_energy = 0.30
	world.add_child(fill)
	# All-white gear like the reference photos, or a team colourway.
	var kit := Color("#f2f4f5") if white else Color("#b3162c")
	var accent := Color("#c9cfd4") if white else Color("#1b2a4a")
	var views := []  # [mesh, position, yaw, pitch]
	var look := Vector3.ZERO
	var distance := 1.6
	match piece:
		"pad":
			# Pair from the front three-quarter, then inside and outside profiles.
			views = [[Gear.goalie_pad(1, kit, accent), Vector3(-0.62, 0, 0), -0.25, 0.0],
				[Gear.goalie_pad(-1, kit, accent), Vector3(-0.30, 0, 0), -0.25, 0.0],
				[Gear.goalie_pad(1, kit, accent), Vector3(0.18, 0, 0), PI * 0.5, 0.0],
				[Gear.goalie_pad(1, kit, accent), Vector3(0.62, 0, 0), -PI * 0.62, 0.0]]
			distance = 1.75
		"catcher":
			views = [[Gear.catcher(1, kit, accent), Vector3(-0.50, 0, 0), 0.0, 0.0],
				[Gear.catcher(1, kit, accent), Vector3(0.0, 0, 0), 0.7, 0.0],
				[Gear.catcher(1, kit, accent), Vector3(0.50, 0, 0), PI, 0.0]]
			distance = 1.55
		"blocker":
			views = [[Gear.blocker(-1, kit, accent), Vector3(-0.25, 0, 0), 0.0, 0.0],
				[Gear.blocker(-1, kit, accent), Vector3(0.0, 0, 0), -0.9, 0.0],
				[Gear.blocker(-1, kit, accent), Vector3(0.25, 0, 0), PI, 0.0]]
			distance = 0.95
		"mask":
			views = [[Gear.goalie_mask(kit, accent), Vector3(-0.32, 0, 0), 0.0, 0.0],
				[Gear.goalie_mask(kit, accent), Vector3(0.0, 0, 0), 0.75, 0.0],
				[Gear.goalie_mask(kit, accent), Vector3(0.34, 0, 0), PI * 0.5, 0.0]]
			distance = 1.25
			look = Vector3(0, -0.04, 0)
	for v in views:
		var instance := MeshInstance3D.new()
		instance.mesh = v[0]
		instance.position = v[1]
		instance.rotation = Vector3(v[3], v[2], 0)
		world.add_child(instance)
	var camera := Camera3D.new()
	camera.position = look + Vector3(0, 0.05, distance)
	camera.fov = 40
	world.add_child(camera)
	camera.look_at(look)
	camera.current = true
	for i in range(3):
		await process_frame
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png("/tmp/hawkey-piece-%s.png" % piece)
	quit()
