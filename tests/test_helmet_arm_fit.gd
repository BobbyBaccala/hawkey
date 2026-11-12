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
	var top: float = centre.y + Gear.HELMET_H
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
	if v.MESH_HELMET:
		check_mesh_helmet(v, centre, hc, hr, mx)
	# Neck guard and sleeves after some skating.
	for k in range(60): v.animate(6.0, 1.0 / 120, 0, true)
	check(v.neck_guard != null and v.neck_guard.mesh.get_surface_count() == 1, "Skaters wear a neck guard")
	var aabb: AABB = v.neck_guard.mesh.get_aabb()
	check(aabb.size.x < 0.25 and aabb.size.y > 0.05, "Neck guard is a collar-sized tube")
	if v.mesh_kit:
		check_sculpted_sleeves(v)
	else:
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
	check(goalie.neck_guard != null, "Goalies wear a throat/neck guard under the scanned head")
	print("Helmet/arm fit failures: %d" % failures)
	quit(failures)

## Posed rig-space position of vertex i of a skinned mesh instance.
func skinned(v, mi: MeshInstance3D, arrays: Array, i: int) -> Vector3:
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var out := Vector3.ZERO
	for k in range(4):
		var w := weights[i * 4 + k]
		if w <= 0.0: continue
		var bone: int = v.skeleton.find_bone(mi.skin.get_bind_name(bones[i * 4 + k]))
		out += (v.skeleton.get_bone_global_pose(bone) * mi.skin.get_bind_pose(bones[i * 4 + k]) * verts[i]) * w
	return out

## Sculpted sleeves: arm-sized round the rest arm, and the cuff stays at the
## posed wrist (so gloves meet it) while skating.
func check_sculpted_sleeves(v) -> void:
	var arrays: Array = v.kit_sleeves.mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var radii := PackedFloat32Array()
	for i in range(verts.size()):
		# Below the shoulder pad: the sleeve proper round the arm.
		if uvs[i].y < 0.25: continue
		var p := verts[i]
		var sfx := ".L" if p.x > 0.0 else ".R"
		var s: Vector3 = v.rest["upperarm01" + sfx].origin
		var e: Vector3 = v.rest["lowerarm01" + sfx].origin
		var w: Vector3 = v.rest["wrist" + sfx].origin
		radii.append(minf(p.distance_to(Geometry3D.get_closest_point_to_segment(p, s, e)), p.distance_to(Geometry3D.get_closest_point_to_segment(p, e, w))))
	radii.sort()
	var typical := radii[int(radii.size() * 0.9)]
	print("sleeve radius median %.3f 90th %.3f max %.3f" % [radii[radii.size() / 2], typical, radii[-1]])
	# Over elbow pads a pro sleeve hangs full (~10 cm off the arm bone), but
	# never balloons.
	check(radii[radii.size() / 2] < 0.10 and typical < 0.115, "Sleeves are arm-sized, not balloons (median %.3f, 90th pct %.3f m)" % [radii[radii.size() / 2], typical])
	var worst := 0.0
	var cuffs := 0
	for i in range(verts.size()):
		if uvs[i].y < 0.97: continue
		cuffs += 1
		var side := 0 if verts[i].x > 0.0 else 1
		worst = maxf(worst, skinned(v, v.kit_sleeves, arrays, i).distance_to(v.posed_wrists[side]))
	print("cuff to wrist %.3f" % worst)
	check(cuffs > 10, "Sleeve cuffs found (%d)" % cuffs)
	check(worst < 0.10, "Sleeve cuffs follow the posed wrists (%.3f m)" % worst)

## Blender helmet (assets/gear/helmet-v2.glb): same fit rules as the procedural
## shell, checked on the real vertices, plus the gear triangle budget.
func check_mesh_helmet(v, centre: Vector3, hc: Vector3, hr: Vector3, head_max: Vector3) -> void:
	var shell: MeshInstance3D = v.helmet.get_node("Shell")
	var fittings: MeshInstance3D = v.helmet.get_node("Fittings")
	var visor: MeshInstance3D = v.helmet.get_node("Visor")
	check(shell.mesh == v.helmet_part("helmet_shell") and visor.mesh == v.helmet_part("helmet_visor"), "Skaters wear the Blender helmet")
	var tris := 0
	for mi: MeshInstance3D in [shell, fittings, visor]:
		for s in range(mi.mesh.get_surface_count()):
			tris += (mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
	check(tris <= 3200, "Helmet stays inside the 3k triangle budget (%d)" % tris)
	var top := -9.0
	var half_w := 0.0
	var inside := 0
	var verts: PackedVector3Array = shell.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	for p0 in verts:
		var p: Vector3 = centre + shell.position + p0 * shell.scale
		top = maxf(top, p.y)
		half_w = maxf(half_w, absf(p.x - centre.x))
		if ((p - hc) / hr).length() < 0.98:
			inside += 1
			print("helmet vertex inside the head: ", p - centre, " q=%.3f" % ((p - hc) / hr).length())
	print("Blender helmet crown gap %.3f, side gap %.3f" % [top - head_max.y, half_w - head_max.x])
	check(top - head_max.y > 0.015 and top - head_max.y < 0.045, "Blender helmet crown sits 1.5-4.5 cm above the head (%.3f)" % (top - head_max.y))
	check(half_w - head_max.x > 0.012 and half_w - head_max.x < 0.04, "Blender helmet sides sit close to the head (%.3f)" % (half_w - head_max.x))
	check(inside == 0, "Blender helmet shell never cuts into the head (%d vertices)" % inside)
	var vaabb: AABB = visor.mesh.get_aabb()
	check(vaabb.position.z + visor.position.z > 0.0, "Visor sits in front of the face")
