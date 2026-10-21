extends SceneTree
## Helmet sized to the head, neck guard filling the collar, and sleeves that
## follow the arm (straight segments, rounded elbow, realistic girth).
const Gear = preload("res://scripts/gear_builder.gd")
var failures := 0
func check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		failures += 1

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var v = load("res://scripts/skater_visual.gd").new()
	root.add_child(v)
	await process_frame
	# Head bounds of the base human (rest), around the head bone.
	var head_o: Vector3 = v.rest["head"].origin
	var mn := Vector3(9, 9, 9)
	var mx := Vector3(-9, -9, -9)
	for child in v.skeleton.get_children():
		if child is MeshInstance3D and child.name == "base_male_body":
			for p in child.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
				if p.y > head_o.y - 0.02:
					mn = mn.min(p)
					mx = mx.max(p)
	var centre: Vector3 = head_o + Gear.HELMET_OFFSET
	var top: float = centre.y + Gear.helmet_point(0.0,0.0).y
	check(top - mx.y > 0.015 and top - mx.y < 0.045, "Helmet crown sits 1.5-4.5 cm above the head (%.3f)" % (top - mx.y))
	check(Gear.HELMET_W - mx.x > 0.012 and Gear.HELMET_W - mx.x < 0.035, "Helmet sides sit close to the head (%.3f)" % (Gear.HELMET_W - mx.x))
	var back: float = centre.z - Gear.HELMET_D * 1.04
	check(back < mn.z - 0.01 and back > mn.z - 0.05, "Helmet back clears the skull snugly (%.3f)" % (mn.z - back))
	# Every sampled shell point stays outside the head's bounding ellipsoid.
	var inside := 0
	var hc := (mn + mx) * 0.5
	hc.z = (mn.z + 0.15) * 0.5
	var hr := Vector3(mx.x - hc.x, mx.y - hc.y, 0.15 - hc.z)
	for i in range(48):
		for j in range(12):
			var a := TAU * i / 48
			var phi: float = Gear.helmet_edge(a) * float(j) / 12
			var p: Vector3 = centre + Gear.helmet_point(a, phi)
			var q := (p - hc) / hr
			if q.length() < 0.98: inside += 1
	check(inside == 0, "Helmet shell never cuts into the head (%d points)" % inside)
	# Neck guard and sleeves after some skating.
	for k in range(60): v.animate(6.0, 1.0 / 120, 0, true)
	check(v.neck_guard != null and v.neck_guard.mesh.get_surface_count() == 1, "Skaters wear a neck guard")
	var aabb: AABB = v.neck_guard.mesh.get_aabb()
	check(aabb.size.x < 0.25 and aabb.size.y > 0.05, "Neck guard is a collar-sized tube")
	var sleeve: MeshInstance3D = v.cloth_sleeves[0]
	var verts: PackedVector3Array = sleeve.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var cols: int = v.SLEEVE_SIDES + 1
	var widest := 0.0
	for r in range(v.SLEEVE_ROWS + 1):
		var c := Vector3.ZERO
		for k in range(cols - 1): c += verts[r * cols + k]
		c /= cols - 1
		for k in range(cols - 1): widest = maxf(widest, verts[r * cols + k].distance_to(c))
	check(widest < 0.085, "Sleeves are arm-sized, not balloons (max radius %.3f m)" % widest)
	var goalie = load("res://scripts/skater_visual.gd").new()
	goalie.goalie = true
	root.add_child(goalie)
	await process_frame
	check(goalie.neck_guard == null, "Goalies keep their mask and no neck guard")
	print("Helmet/arm fit failures: %d" % failures)
	quit(failures)
