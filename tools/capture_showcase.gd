extends SceneTree
## Character showcase: one skater and one goalie in the team kit on a dark teal
## studio floor (soft key, cool rim, light fog, glossy floor), turned to the
## front, three-quarter and back views like a customisation-screen turntable.
## The yardstick for player-model work (art/NIGHT_SHIFT_PLAYER_MODELS.md 0b).
## xvfb-run -a -s "-screen 0 1728x1080x24" godot --rendering-method gl_compatibility --rendering-driver opengl3 --resolution 1728x1080 --script tools/capture_showcase.gd -- [--out=<prefix>] [--only=skater|goalie]
## Writes <prefix>-skater-front.png, -skater-three-q.png, -skater-back.png,
## -goalie-front.png, -goalie-three-q.png, -goalie-back.png, -pair.png
## (default prefix /tmp/hawkey-showcase).
const KIT := Color("#185c73")
const ACCENT := Color("#e8eef2")
# The visual faces -Z at rotation 0; the camera sits on +Z.
const VIEWS := [["front", PI], ["three-q", PI * 0.75], ["back", 0.0]]

func _initialize() -> void: call_deferred("run")

func studio() -> Node3D:
	var stage := Node3D.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#0b2a2e")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#3d6f74")
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.05
	env.fog_enabled = true
	env.fog_light_color = Color("#123b40")
	env.fog_density = 0.035
	env.fog_sky_affect = 0.0
	env.glow_enabled = true
	env.glow_intensity = 0.35
	var world := WorldEnvironment.new()
	world.environment = env
	stage.add_child(world)
	# Glossy dark floor; a reflection probe gives it the studio's sheen.
	var floor := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(40, 40)
	floor.mesh = plane
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color("#0d2326")
	fm.roughness = 0.12
	fm.metallic = 0.35
	fm.metallic_specular = 0.9
	floor.material_override = fm
	stage.add_child(floor)
	var probe := ReflectionProbe.new()
	probe.size = Vector3(12, 6, 12)
	probe.position = Vector3(0, 1.0, 0)
	probe.update_mode = ReflectionProbe.UPDATE_ALWAYS
	stage.add_child(probe)
	# Soft warm-white key from the front left, high.
	var key := DirectionalLight3D.new()
	key.light_color = Color("#fff4e6")
	key.light_energy = 1.25
	key.shadow_enabled = true
	key.rotation = Vector3(deg_to_rad(-38), deg_to_rad(-32), 0)
	stage.add_child(key)
	# Fill from the camera side, low and dim.
	var fill := OmniLight3D.new()
	fill.light_color = Color("#cfe6ea")
	fill.light_energy = 0.6
	fill.omni_range = 9.0
	fill.position = Vector3(2.2, 1.2, 4.0)
	stage.add_child(fill)
	# Cool rim lights behind the players, both sides.
	for side in [-1.0, 1.0]:
		var rim := SpotLight3D.new()
		rim.light_color = Color("#7fd8ff")
		rim.light_energy = 6.0
		rim.spot_range = 5.0
		rim.spot_attenuation = 1.6
		rim.spot_angle = 35.0
		rim.look_at_from_position(Vector3(side * 2.2, 3.0, -2.6), Vector3(0, 1.2, 0))
		stage.add_child(rim)
	return stage

func player(goalie: bool) -> Node3D:
	var v = load("res://scripts/skater_visual.gd").new()
	v.goalie = goalie
	v.kit = KIT
	v.accent = ACCENT
	v.number = "31" if goalie else "17"
	return v

func settle(v) -> void:
	for k in range(120):
		if v.goalie: v.set_save("", Vector2(0, 0.8), 1.0 / 60)
		v.animate(0, 1.0 / 60, 0, false)

func shot(cam: Camera3D, pos: Vector3, at: Vector3, fov: float, path: String) -> void:
	cam.position = pos
	cam.look_at(at)
	cam.fov = fov
	for i in range(3): await process_frame
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)
	print("SHOWCASE ", path)

func run() -> void:
	var out := "/tmp/hawkey-showcase"
	var only := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): out = arg.substr(6)
		if arg.begins_with("--only="): only = arg.substr(7)
	var stage := studio()
	root.add_child(stage)
	var cam := Camera3D.new()
	stage.add_child(cam)
	cam.current = true
	var skater = player(false)
	var goalie = player(true)
	stage.add_child(skater)
	stage.add_child(goalie)
	skater.set_nameplate("Larsen")
	goalie.set_nameplate("Okafor")
	for v in [skater, goalie]:
		if v.nameplate: v.nameplate.visible = false
	await process_frame
	for who in [["skater", skater, goalie], ["goalie", goalie, skater]]:
		if only != "" and only != who[0]: continue
		var v = who[1]
		who[2].visible = false
		v.visible = true
		v.position = Vector3.ZERO
		var height := 1.0 if v.goalie else 1.05
		for view in VIEWS:
			v.rotation.y = view[1]
			settle(v)
			await shot(cam, Vector3(0, height + 0.1, 4.2), Vector3(0, height - 0.12, 0), 27, "%s-%s-%s.png" % [out, who[0], view[0]])
	if only == "":
		skater.visible = true
		goalie.visible = true
		skater.position = Vector3(-0.85, 0, 0)
		goalie.position = Vector3(0.85, 0, 0)
		skater.rotation.y = PI * 0.9
		goalie.rotation.y = PI * 1.1
		settle(skater)
		settle(goalie)
		await shot(cam, Vector3(0, 1.25, 5.6), Vector3(0, 0.95, 0), 36, out + "-pair.png")
	quit()
