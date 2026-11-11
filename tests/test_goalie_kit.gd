extends SceneTree
## Goalie sweater and pad detail: accent shoulder yoke only on goalies, wider
## protector shoulders/arms than a skater sweater, pads carry kit + accent.
var failures := 0
func check(ok: bool, msg: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", msg)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var SV = preload("res://scripts/skater_visual.gd")
	var Kit = preload("res://scripts/kit_materials.gd")
	var g = SV.new()
	g.goalie = true
	g.kit = Color("#b3162c")
	g.accent = Color("#1b2a4a")
	root.add_child(g)
	var s = SV.new()
	s.kit = Color("#b3162c")
	s.accent = Color("#1b2a4a")
	root.add_child(s)
	await physics_frame
	var gm := g.jersey.material_override as ShaderMaterial
	var sm := s.jersey.material_override as ShaderMaterial
	check(is_equal_approx(float(gm.get_shader_parameter("yoke_v")), SV.GOALIE_YOKE), "goalie sweater has the shoulder yoke")
	check(float(sm.get_shader_parameter("yoke_v")) == 0.0, "skater sweater has no yoke")
	check(gm != sm, "goalie and skater sweaters use different materials")
	var gw: float = absf(g.jersey_point(0.0, 1.40).x)
	var gwaist: float = absf(g.jersey_point(0.0, 1.10).x)
	check(gw > 0.31, "goalie shoulders are protector-wide: %.3f" % gw)
	check(gwaist > 0.24, "goalie waist is not pinched: %.3f" % gwaist)
	var pad_mat: ShaderMaterial = null
	for pad in g.pads:
		for c in pad.get_children():
			if c is MeshInstance3D: pad_mat = c.material_override
	check(pad_mat != null and pad_mat.get_shader_parameter("pad_graphics") == true, "pads use pad graphics")
	if pad_mat != null:
		check((pad_mat.get_shader_parameter("pad_team") as Color).is_equal_approx(g.kit), "pad team colour follows the kit")
		check((pad_mat.get_shader_parameter("pad_accent") as Color).is_equal_approx(g.accent), "pad accent follows the kit accent")
		check((pad_mat.get_shader_parameter("base_color") as Color).get_luminance() > 0.8, "pad base is white, not grey")
	check(Kit.goalie_pad(Color.RED, Color.BLUE) != Kit.goalie_pad(Color.RED, Color.GREEN), "pad materials are per accent")
	print("Goalie kit failures: ", failures)
	quit(1 if failures > 0 else 0)
