extends SceneTree
## Knee, sock and breezer side stripe (2026-11-19). A bent knee used to show
## the sock as a flat-topped tube sticking out in front of the knee below the
## breezer hem (a lid, with a gap behind it), and the breezer side stripe -
## drawn from the vertex normal - was torn into a jagged band by the quilted
## pad bumps.
## Checks: the shin sock is domed over the knee joint (no flat lid) with a
## shin-guard knee cap in front; a thigh sock runs from the knee up under the
## breezer hem in every skating pose; the stripe coordinate is a smooth band
## of constant width down the outside of each breezer leg.
const Gear = preload("res://scripts/gear_builder.gd")
var failures := 0
func check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		failures += 1

func _initialize() -> void:
	call_deferred("run")

func verts(m: Mesh) -> PackedVector3Array:
	return m.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]

func run() -> void:
	# --- Shin sock mesh: domed top, knee cap forward, calf behind.
	var sock := verts(Gear.sock(Color.TEAL, Color.WHITE))
	var top_r := 0.0
	var front := -INF
	var back := INF
	var high := -INF
	for p in sock:
		high = maxf(high, p.y)
		var r := Vector2(p.x, p.z).length()
		if p.y > Gear.SOCK_DOME * 0.85: top_r = maxf(top_r, r)
		if p.y < 0.02 and p.y > -0.12:
			front = maxf(front, p.z)
			back = minf(back, p.z)
	check(high > Gear.SOCK_DOME * 0.95, "Sock top is domed above the knee joint (%.3f)" % high)
	check(top_r < 0.04, "No flat lid: the sock's top closes in a dome (radius %.3f m near the apex)" % top_r)
	check(front + back > 0.010, "Shin-guard knee cap bulges forward (front %.3f vs back %.3f)" % [front, -back])
	# --- Skater: thigh sock in place through skating poses.
	var v = load("res://scripts/skater_visual.gd").new()
	root.add_child(v)
	await process_frame
	check(v.sock_thighs.size() == 2, "Each skater leg has a sock above the knee")
	check(v.sock_thighs.size() == 0 or v.sock_thighs[0].material_override == v.socks[0].material_override, "Thigh sock shares the sock material")
	var hem := INF
	if v.mesh_kit:
		for p in verts(v.kit_pants.mesh): hem = minf(hem, p.y)
	var worst_join := 0.0
	var worst_cover := INF
	for speed in [0.0, 3.0, 8.0]:
		for f in range(240):
			v.animate(speed, 1.0 / 120, 0, speed > 0.5)
			for i in range(2):
				var knee: Vector3 = v.socks[i].transform.origin
				var thigh: Transform3D = v.sock_thighs[i].transform
				worst_join = maxf(worst_join, thigh.origin.distance_to(knee))
				# Sleeve top rises up the thigh well past the knee (under the hem).
				var top: Vector3 = thigh * Vector3(0, Gear.SOCK_THIGH_LEN, 0)
				worst_cover = minf(worst_cover, (top - knee).length())
	check(worst_join < 0.001, "Thigh sock and shin sock meet at the knee joint (worst %.4f m)" % worst_join)
	check(worst_cover > Gear.SOCK_THIGH_LEN * 0.99, "Thigh sock reaches %.2f m up the thigh (worst %.3f)" % [Gear.SOCK_THIGH_LEN, worst_cover])
	if v.mesh_kit:
		# The breezer leg opening is lower than the thigh sock's top, so it tucks in.
		var knee_rest: float = (v.rest["lowerleg01.L"] as Transform3D).origin.y
		check(knee_rest + Gear.SOCK_THIGH_LEN > hem + 0.04, "Thigh sock top (%.3f) goes up under the breezer hem (%.3f)" % [knee_rest + Gear.SOCK_THIGH_LEN, hem])
		# --- Breezer side stripe: one straight band down the outside of each leg.
		var arrays: Array = v.kit_pants.mesh.surface_get_arrays(0)
		var pv: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var uv2: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
		var hip: Vector3 = (v.rest["upperleg01.L"] as Transform3D).origin
		var knee_l: Vector3 = (v.rest["lowerleg01.L"] as Transform3D).origin
		var slices := [0, 0, 0, 0, 0]
		var worst_off := 0.0
		for k in range(pv.size()):
			var p := pv[k]
			if p.x <= 0.0 or uv2[k].x <= 0.975: continue
			# Distance in front of / behind the outward line through the leg axis.
			var c := Geometry3D.get_closest_point_to_segment(p, hip, knee_l)
			worst_off = maxf(worst_off, absf(p.z - c.z))
			var t := inverse_lerp(hip.y, knee_l.y + 0.08, p.y)
			if t >= 0.0 and t < 1.0: slices[int(t * 5.0)] += 1
		check(worst_off < 0.045, "Breezer stripe stays a narrow band on the outside (worst %.3f m off the side line)" % worst_off)
		check(slices.min() > 0, "Breezer stripe runs unbroken hip to hem (points per slice %s)" % str(slices))
	print("Knee/sock/stripe failures: %d" % failures)
	quit(1 if failures > 0 else 0)
