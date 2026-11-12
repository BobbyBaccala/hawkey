extends SceneTree
## Butterfly pads and committed save poses (owner 2026-11-12: real pads do not
## bend in the butterfly, and the skate never shows through the pad). The
## thigh rise is a rigid part of the pad in every pose; in a full butterfly the
## two rigid pads lie along the ice face-on to the shooter and meet at the
## five-hole without crossing; the skates sit behind the pads (toes back). Glove
## and pad saves move the upper body toward the puck.
var failures := 0
func check(ok: bool, msg: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", msg)
func _initialize() -> void: call_deferred("run")

## Extremes of a thigh rise's real vertices in rig space.
func rise_bounds(g, i: int) -> Dictionary:
	var rise: Node3D = g.thigh_rises[i]
	var mi := rise.get_child(0) as MeshInstance3D
	var xf: Transform3D = g.pads[i].transform*rise.transform*mi.transform
	var side := 1.0 if i == 0 else -1.0
	var inner := INF
	var low := INF
	var high := -INF
	for s in range(mi.mesh.get_surface_count()):
		for v in (mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector3Array):
			var p: Vector3 = xf*v
			inner = minf(inner, side*p.x)
			low = minf(low, p.y)
			high = maxf(high, p.y)
	return {"inner": inner, "low": low, "high": high, "face": (g.pads[i].basis*rise.basis.orthonormalized()).z}

func pad_top(g, i: int) -> float:
	var mi := g.pad_visuals[i].get_child(0) as MeshInstance3D
	var xf: Transform3D = g.pads[i].transform*g.pad_visuals[i].transform*mi.transform
	var top := -INF
	for s in range(mi.mesh.get_surface_count()):
		for v in (mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector3Array):
			top = maxf(top, (xf*v).y)
	return top

func settle(g, kind: String, target: Vector2, down: bool) -> void:
	for f in range(90):
		g.butterfly = move_toward(g.butterfly, 1.0 if down else 0.0, 6.0/60)
		g.set_save(kind, target, 1.0/60)
		g.animate(0, 1.0/60, 0, false)

func run() -> void:
	var SV = preload("res://scripts/skater_visual.gd")
	var g = SV.new()
	g.goalie = true
	root.add_child(g)
	await process_frame
	var upright: float = 0.0
	# Rigid pad: the rise keeps one fixed transform relative to the drawn pad
	# through the whole drop and in every save.
	var drop_poses := [["", Vector2(0, 0.8), 0.0], ["", Vector2(0, 0.8), 0.5], ["butterfly", Vector2(0.1, 0.15), 1.0],
		["pad_left", Vector2(0.95, 0.1), 1.0], ["splits_left", Vector2(1.15, 0.1), 0.0], ["stack_right", Vector2(-0.9, 0.1), 0.0]]
	var ref: Array = []
	for pose in drop_poses:
		for f in range(90):
			g.butterfly = move_toward(g.butterfly, pose[2], 6.0 / 60)
			g.set_save(pose[0], pose[1], 1.0 / 60)
			g.animate(0, 1.0 / 60, 0, false)
		if pose[0] == "" and pose[2] == 0.0: upright = g.torso_pose.basis.y.normalized().x
		for i in range(2):
			var rel: Transform3D = (g.pad_visuals[i] as Node3D).transform.affine_inverse() * (g.thigh_rises[i] as Node3D).transform * ((g.thigh_rises[i] as Node3D).get_child(0) as Node3D).transform
			if ref.size() < 2: ref.append(rel)
			else:
				var d: float = (rel.origin - (ref[i] as Transform3D).origin).length() + (rel.basis.x - (ref[i] as Transform3D).basis.x).length() + (rel.basis.y - (ref[i] as Transform3D).basis.y).length() + (rel.basis.z - (ref[i] as Transform3D).basis.z).length()
				check(d < 0.002, "%s b=%.1f: rise %d rigid with its pad (%.4f)" % [pose[0], pose[2], i, d])
	# Full butterfly: one straight wall along the ice.
	settle(g, "", Vector2(0, 0.8), false)
	settle(g, "butterfly", Vector2(0.1, 0.15), true)
	for i in range(2):
		var b := rise_bounds(g, i)
		check(b.inner > -0.012 and b.inner < 0.012, "butterfly: pad %d meets the other at the five-hole (%.4f m)" % [i, b.inner])
		var face: Vector3 = (b.face as Vector3).normalized()
		check(face.z > 0.85, "butterfly: pad %d faces the shooter (%s)" % [i, face])
		check(b.high < 0.40, "butterfly: rise %d lies with the pad, not standing up (top %.3f m)" % [i, b.high])
		# Skate behind the pad: toe back, inside the pad's length, behind its face.
		var sk: Node3D = g.skates[i]
		var toe: Vector3 = (sk.basis as Basis).z.normalized()
		check(toe.z < -0.5, "butterfly: skate %d toe points back behind the pad (%s)" % [i, toe])
		var side := 1.0 if i == 0 else -1.0
		var pad_out := -INF
		var mi := g.pad_visuals[i].get_child(0) as MeshInstance3D
		var pxf: Transform3D = g.pads[i].transform * g.pad_visuals[i].transform * mi.transform
		for vtx in (mi.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array):
			pad_out = maxf(pad_out, side * (pxf * vtx).x)
		var sk_out := -INF
		for n in sk.find_children("*", "MeshInstance3D", true, false):
			var sxf: Transform3D = sk.transform * (n as MeshInstance3D).transform
			for vtx in ((n as MeshInstance3D).mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array):
				sk_out = maxf(sk_out, side * (sxf * vtx).x)
		check(sk_out < pad_out + 0.01, "butterfly: skate %d stays within the pad's end (%.3f vs %.3f)" % [i, sk_out, pad_out])
	# The toe window in the pad face is closed.
	check(g.pad_visuals[0].get_node_or_null("ToeCover") != null, "pad toe window is closed")
	# High glove save: shoulders tip toward the glove, arm nearly straight,
	# pocket square to the shooter.
	settle(g, "glove", Vector2(0.75, 1.35), false)
	var lean: float = g.torso_pose.basis.y.normalized().x - upright
	check(lean > 0.25, "glove save leans the torso toward the glove (%.3f)" % lean)
	var arm: float = g.shoulder_of(0).distance_to(g.posed_wrists[0])
	check(arm > SV.ARM_REACH - 0.02, "glove arm fully extended (%.3f m)" % arm)
	var pocket: Vector3 = (g.goalie_gloves[0].basis as Basis).z.normalized()
	check(pocket.z > 0.85, "catcher pocket square to the shooter (%s)" % pocket)
	# Pad extensions: chest out over the lead pad, both directions.
	for save in [["pad_left", Vector2(0.95, 0.1), 1.0], ["pad_right", Vector2(-0.95, 0.1), -1.0]]:
		settle(g, "", Vector2(0, 0.8), false)
		settle(g, save[0], save[1], true)
		var side: float = save[2]
		var chest: Vector3 = (g.shoulder_of(0)+g.shoulder_of(1))*0.5
		var hips: Vector3 = g.posed_drop
		check(side*(chest.x - hips.x) > 0.10, "%s: chest out over the lead pad (%.3f m past the hips)" % [save[0], side*(chest.x - hips.x)])
		check(g.torso_pose.basis.y.normalized().z > 0.12, "%s: chest bends forward over the pad (%.3f)" % [save[0], g.torso_pose.basis.y.normalized().z])
	# The drop is eased: the match ramps the commanded value at a constant
	# rate and reads it back unchanged; the pose leaves the stance and lands
	# with ~zero speed and is half-way at the same moment.
	g.butterfly = 0.0
	g.animate(0, 1)
	var posed: Array[float] = []
	for f in range(11):
		g.butterfly = move_toward(g.butterfly, 1.0, 6.0 / 60)
		g.animate(0, 1.0 / 60, 0, false)
		posed.append(g.butterfly_posed)
	check(is_equal_approx(g.butterfly, 1.0), "commanded drop reads back unchanged (%.3f)" % g.butterfly)
	check(posed[0] < 0.035, "drop leaves the stance gently (first step %.3f of 0.1)" % posed[0])
	check(posed[9] - posed[8] < 0.035, "knees land gently (last step %.3f of 0.1)" % (posed[9] - posed[8]))
	check(absf(posed[4] - 0.5) < 0.01, "half-way at the same moment (%.3f)" % posed[4])
	print("Butterfly wall failures: ", failures)
	quit(1 if failures > 0 else 0)
