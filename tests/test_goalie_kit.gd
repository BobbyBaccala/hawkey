extends SceneTree
const Gear = preload("res://scripts/gear_builder.gd")
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
	# The yoke carries over the shoulder onto goalie sleeves only.
	if g.cloth_sleeves.size() > 0 and s.cloth_sleeves.size() > 0:
		check(float((g.cloth_sleeves[0].material_override as ShaderMaterial).get_shader_parameter("sleeve_yoke")) > 0.0, "goalie sleeve carries the yoke cap")
		check(float((s.cloth_sleeves[0].material_override as ShaderMaterial).get_shader_parameter("sleeve_yoke")) == 0.0, "skater sleeve has no yoke cap")
	var gw: float = absf(g.jersey_point(0.0, 1.40).x)
	var gwaist: float = absf(g.jersey_point(0.0, 1.10).x)
	check(gw > 0.31, "goalie shoulders are protector-wide: %.3f" % gw)
	check(gwaist > 0.24, "goalie waist is not pinched: %.3f" % gwaist)
	var pad_mat: ShaderMaterial = null
	for vis in g.pad_visuals:
		for c in vis.get_children():
			if c is MeshInstance3D: pad_mat = c.material_override
		# Constant drawn size: 91 cm long, 11 in wide, deeper than the 10 cm source.
		check(vis.scale.is_equal_approx(SV.PAD_VIS_SCALE), "pad drawn at its constant size (%s)" % vis.scale)
	check(pad_mat != null and pad_mat.get_shader_parameter("pad_graphics") == true, "pads use pad graphics")
	if pad_mat != null:
		check((pad_mat.get_shader_parameter("pad_team") as Color).is_equal_approx(g.kit), "pad team colour follows the kit")
		check((pad_mat.get_shader_parameter("pad_accent") as Color).is_equal_approx(g.accent), "pad accent follows the kit accent")
		check((pad_mat.get_shader_parameter("base_color") as Color).get_luminance() > 0.8, "pad base is white, not grey")
	check(Kit.goalie_pad(Color.RED, Color.BLUE) != Kit.goalie_pad(Color.RED, Color.GREEN), "pad materials are per accent")
	# Pad assembly through the drop and back: no telescoping (the pad and the
	# thigh rise keep one size), the knee landing stays on the knee, the rise
	# only rotates, and the skate stays on the ankle.
	for b in [0.0, 0.25, 0.5, 0.75, 1.0, 0.5, 0.0]:
		for k in range(30):
			g.butterfly = b
			g.animate(0, 1.0/60, 0, false)
		for i in range(2):
			var vis: Node3D = g.pad_visuals[i]
			var rise: Node3D = g.thigh_rises[i]
			check(vis.scale.is_equal_approx(SV.PAD_VIS_SCALE), "pad size constant at butterfly %.2f" % b)
			var sc: Vector3 = (rise.basis as Basis).get_scale()
			check(absf(sc.y - SV.PAD_VIS_SCALE.y) < 0.002 and absf(sc.z - SV.PAD_VIS_SCALE.z) < 0.002, "thigh rise size constant at butterfly %.2f (%s)" % [b, sc])
			# Knee in 3D, in the (unscaled) pad node's frame: level with the
			# knee landing, within the boot channel's width of the pad centre,
			# and behind the pad's back face with clearance (not welded to the
			# shin, not floating more than 12 cm off it).
			var to_pad: Transform3D = g.pads[i].transform.affine_inverse()
			var knee_p: Vector3 = to_pad * g.knees[i]
			var mark_p: Vector3 = to_pad * (g.pads[i].transform * (vis.transform * Vector3(0, Gear.PAD_KNEE, 0)))
			var back_z: float = vis.position.z - 0.04 * SV.PAD_VIS_SCALE.z
			check(absf(knee_p.y - mark_p.y) < 0.005, "knee landing level with the knee at butterfly %.2f (%.3f)" % [b, knee_p.y - mark_p.y])
			check(absf(knee_p.x - mark_p.x) < 0.07, "knee within the channel width at butterfly %.2f (%.3f)" % [b, knee_p.x - mark_p.x])
			var gap: float = back_z - knee_p.z
			check(gap > 0.0 and gap < 0.12, "knee behind the pad back with clearance at butterfly %.2f (%.3f)" % [b, gap])
			# The boot pivots about the ankle: its ankle point is the rig ankle.
			var ankle_from_boot: Vector3 = g.skates[i].transform * Vector3(0, 0.0525, 0)
			check(ankle_from_boot.distance_to(g.feet[i]) < 0.005, "boot on the ankle at butterfly %.2f (%.3f m)" % [b, ankle_from_boot.distance_to(g.feet[i])])
	# The stick is the de-branded downloaded model, drawn instead of the proxies.
	check(g.goalie_stick_mesh != null and g.goalie_stick_mesh.visible, "goalie draws the stick model")
	check(not g.goalie_paddle.visible and not g.stick_shaft.visible, "box stick proxies hidden")
	# The paddle carries the team colours (painted over the de-branded bake).
	var stick_mat := g.goalie_stick_mesh.material_override as ShaderMaterial
	check(stick_mat != null and (stick_mat.get_shader_parameter("kit") as Color).is_equal_approx(g.kit), "goalie stick paddle carries the kit colour")
	check(stick_mat != null and stick_mat.get_shader_parameter("albedo_tex") != null, "goalie stick keeps its baked texture")
	var stick_len: float = g.goalie_stick_mesh.mesh.get_aabb().size.y * SV.GOALIE_STICK_SCALE
	check(stick_len > 1.4 and stick_len < 1.55, "goalie stick about 1.45 m (%.2f)" % stick_len)
	# Each pad is held on by a knee cradle, calf wrap and straps that follow the knee.
	check(g.pad_rears.size() == 2, "both pads have rear straps")
	for i in range(2):
		var knee_l: Vector3 = g.pads[i].transform.affine_inverse() * g.knees[i]
		check(absf(g.pad_rears[i].position.y - knee_l.y) < 0.005, "straps ride with the knee")
	check(g.skate_cuffs.size() == 2, "goalie skates have shin-following cuffs")
	# Goalie pants: bright team colour with an accent stripe and white piping
	# down the outside (reference photos); skater breezers stay dark.
	var pc: PackedColorArray = (g.pant_legs[0].mesh as ArrayMesh).surface_get_arrays(0)[Mesh.ARRAY_COLOR]
	var kit_n := 0
	var acc_n := 0
	var white_n := 0
	for c in pc:
		if c.is_equal_approx(g.kit): kit_n += 1
		elif c.is_equal_approx(g.accent): acc_n += 1
		elif c.get_luminance() > 0.85: white_n += 1
	check(kit_n > pc.size() * 0.6, "goalie pants are kit colour (%d of %d)" % [kit_n, pc.size()])
	check(acc_n > 20 and white_n > 20, "goalie pants carry an accent stripe with white piping (%d, %d)" % [acc_n, white_n])
	var sc_cols: PackedColorArray = (s.pant_legs[0].mesh as ArrayMesh).surface_get_arrays(0)[Mesh.ARRAY_COLOR] if s.pant_legs.size() > 0 and s.pant_legs[0].mesh is ArrayMesh and not s.mesh_kit else PackedColorArray()
	if sc_cols.size() > 0:
		var dark := 0
		for c in sc_cols:
			if c.get_luminance() < 0.2: dark += 1
		check(dark > sc_cols.size() * 0.6, "skater breezers stay dark")
	print("Goalie kit failures: ", failures)
	quit(1 if failures > 0 else 0)
