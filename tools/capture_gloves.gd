extends SceneTree
## Catcher and blocker on their own, front/back/side, neutral light.
func _initialize(): call_deferred("run")
func run():
	var G = load("res://scripts/gear_builder.gd")
	var w := Node3D.new(); root.add_child(w)
	var env := WorldEnvironment.new(); env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("#3a424a")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("#b0bac4"); env.environment.ambient_light_energy = 0.6
	w.add_child(env)
	var key := DirectionalLight3D.new(); key.rotation = Vector3(-0.6, 0.5, 0); key.light_energy = 1.2; w.add_child(key)
	var fill := DirectionalLight3D.new(); fill.rotation = Vector3(-0.3, 2.6, 0); fill.light_energy = 0.5; w.add_child(fill)
	var kit := Color("#b3162c"); var acc := Color("#1b2a4a")
	var c := MeshInstance3D.new(); c.mesh = G.catcher(1.0, kit, acc); w.add_child(c); c.position = Vector3(-0.2, 0, 0)
	var b := MeshInstance3D.new(); b.mesh = G.blocker(-1.0, kit, acc); w.add_child(b); b.position = Vector3(0.2, 0, 0)
	var cam := Camera3D.new(); w.add_child(cam); cam.fov = 40
	var shots := [["front", Vector3(0, 0.05, 1.3)], ["back", Vector3(0, 0.05, -1.3)], ["side", Vector3(1.2, 0.2, 0.6)]]
	var out: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "/tmp/glove"
	for s in shots:
		cam.position = s[1]; cam.look_at(Vector3(0, 0.02, 0))
		for k in range(3): await process_frame
		await RenderingServer.frame_post_draw
		get_root().get_texture().get_image().save_png("%s-%s.png" % [out, s[0]])
	quit()
