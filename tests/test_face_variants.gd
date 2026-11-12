extends SceneTree
## Skater faces: several skin tones across jersey numbers, stable per number,
## and an explicit face_variant overrides the pick.
var failures := 0
func check(ok: bool, msg: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", msg)
func _initialize() -> void: call_deferred("run")
func tone_of(v: Node3D) -> Color:
	for n in v.head_nodes:
		if n.name == "MeshHead":
			return (n.material_override as ShaderMaterial).get_shader_parameter("tone")
	return Color.BLACK
func run() -> void:
	var SV = preload("res://scripts/skater_visual.gd")
	var tones := {}
	for num in ["4","9","17","23","31","44","58","71","88","91"]:
		var v = SV.new()
		v.number = num
		root.add_child(v)
		await physics_frame
		tones[tone_of(v).to_html()] = true
		var v2 = SV.new()
		v2.number = num
		root.add_child(v2)
		await physics_frame
		check(tone_of(v) == tone_of(v2), "stable face for number " + num)
	check(tones.size() >= 3, "ten numbers give >= 3 distinct skin tones: %d" % tones.size())
	var a = SV.new()
	a.face_variant = 0
	root.add_child(a)
	var b = SV.new()
	b.face_variant = 5
	root.add_child(b)
	await physics_frame
	check(tone_of(a).get_luminance() > tone_of(b).get_luminance() + 0.2, "variant 0 lighter than 5")
	print("Face variant failures: ", failures)
	quit(1 if failures > 0 else 0)
