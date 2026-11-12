extends SceneTree
## Butterfly wall and committed save poses (reference: pro butterfly and save
## photos, EA NHL goalies). In a full butterfly the two thigh rises stand over
## the knee stacks face-on to the shooter and meet at the five-hole, seated on
## the lower pads, at their constant size. Glove and pad saves move the upper
## body toward the puck: the shoulders tip toward a high glove reach with the
## arm extended and the pocket square to the shooter, and on a pad extension
## the chest drops out over the lead pad.
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
	# Standing: the rises continue the pads up the thighs (no wall yet).
	settle(g, "", Vector2(0, 0.8), false)
	var stand_gap: float = rise_bounds(g, 0).inner
	check(stand_gap > 0.008, "standing, the wall is not applied (inner edge %.3f m from centre)" % stand_gap)
	var upright: float = g.torso_pose.basis.y.normalized().x
	# Full butterfly: one wall.
	settle(g, "butterfly", Vector2(0.1, 0.15), true)
	for i in range(2):
		var b := rise_bounds(g, i)
		check(b.inner > -0.002 and b.inner < 0.008, "butterfly rise %d inner edge at the five-hole (%.4f m)" % [i, b.inner])
		var top := pad_top(g, i)
		check(b.low < top and b.low > top - 0.06, "butterfly rise %d seated on its pad (bottom %.3f, pad top %.3f)" % [i, b.low, top])
		check(b.high > 0.42, "butterfly rise %d stands up the five-hole (top %.3f m)" % [i, b.high])
		var face: Vector3 = (b.face as Vector3).normalized()
		check(face.z > 0.85 and absf(face.y) < 0.35, "butterfly rise %d faces the shooter (%s)" % [i, face])
		var sc: Vector3 = (g.thigh_rises[i].basis as Basis).get_scale()
		check(absf(sc.y - SV.PAD_VIS_SCALE.y) < 0.002 and absf(sc.z - SV.PAD_VIS_SCALE.z) < 0.002, "butterfly rise %d keeps its size (%s)" % [i, sc])
	var l := rise_bounds(g, 0)
	var r := rise_bounds(g, 1)
	check(absf(l.low - r.low) < 0.005 and absf(l.high - r.high) < 0.005, "the two rises line up (%.3f/%.3f, %.3f/%.3f)" % [l.low, r.low, l.high, r.high])
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
