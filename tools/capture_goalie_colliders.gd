extends SceneTree
## Goalie save colliders drawn over the goalie (get_goalie_gear boxes): green
## = current, red outline = the pad boxes as they were before the full-length
## fix (stopped at the knee break in the butterfly). Front and low views of
## the butterfly. Writes <out>-<which>-front.png and -low.png (--out=, default
## /tmp/hawkey-colliders; --which=new|old draws only that pad box).
## xvfb-run -a -s "-screen 0 1728x1080x24" godot --rendering-method gl_compatibility --resolution 900x900 --script tools/capture_goalie_colliders.gd
const Gear = preload("res://scripts/gear_builder.gd")
func _initialize() -> void: call_deferred("run")

func box_mesh(size: Vector3, color: Color) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	m.mesh = b
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.no_depth_test = true
	m.material_override = mat
	return m

func run() -> void:
	var out := "/tmp/hawkey-colliders"
	var which := "new"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): out = arg.substr(6)
		if arg.begins_with("--which="): which = arg.substr(8)
	var scene = load("res://practice.tscn").instantiate()
	root.add_child(scene)
	await physics_frame
	scene.set_physics_process(false)
	for actor in [scene.player, scene.teammate] + scene.goalkeepers: actor.queue_free()
	scene.puck.visible = false
	scene.selection.visible = false
	scene.hud.get_parent().get_parent().visible = false
	var v = load("res://scripts/skater_visual.gd").new()
	v.goalie = true
	v.kit = Color("#b3162c")
	v.accent = Color("#1b2a4a")
	scene.add_child(v)
	v.rotation.y = PI
	for k in range(120):
		v.butterfly = move_toward(v.butterfly, 1.0, 6.0 / 60)
		v.set_save("butterfly", Vector2(0.0, 0.1), 1.0 / 60)
		v.animate(0, 1.0 / 60, 0, false)
	var gear: Dictionary = v.get_goalie_gear()
	for name_ in gear:
		if which == "old" and name_.begins_with("Pad"): continue
		var spec: Dictionary = gear[name_]
		var col := Color(0.1, 0.9, 0.3, 0.35) if name_.begins_with("Pad") else Color(0.2, 0.6, 1.0, 0.25)
		var m := box_mesh(spec.size, col)
		scene.add_child(m)
		m.transform = spec.transform
	# The old pad box: knee break at the top in the butterfly.
	var length: float = lerpf(Gear.PAD_LENGTH, Gear.PAD_BREAK + Gear.PAD_LENGTH * 0.5, v.butterfly_posed)
	var center: float = lerpf(0.0, Gear.PAD_BREAK - length * 0.5, v.butterfly_posed)
	for i in range(2 if which == "old" else 0):
		var m := box_mesh(Vector3(v.pad_size.x + 0.01, length, v.pad_size.z + 0.01), Color(1.0, 0.15, 0.1, 0.40))
		scene.add_child(m)
		m.transform = v.transform * v.rig.transform * v.pads[i].transform * Transform3D(Basis(), Vector3(0, center, 0))
	var cam: Camera3D = scene.camera
	for shot in [["front", Vector3(0.0, 0.9, 2.6), Vector3(0, 0.3, 0)], ["low", Vector3(0.0, 0.25, 2.4), Vector3(0, 0.2, 0)]]:
		cam.position = shot[1]
		cam.look_at(shot[2])
		cam.fov = 44
		for k in range(3): await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("%s-%s-%s.png" % [out, which, shot[0]])
	quit()
