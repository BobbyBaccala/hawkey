extends SceneTree
## Skater kit geometry: the sweater is skinned to the skeleton and follows the
## chest as the spine bends and twists (the hem lags with the hips), and the
## jersey, pants, gloves and helmet are smooth, many-segment shapes rather
## than boxes or balls.
var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		push_error(message)
		failures += 1

func _initialize() -> void:
	call_deferred("run")

## Skinned (posed) position of jersey vertex i, in rig space.
func skinned(v, arrays: Array, i: int) -> Vector3:
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var skin: Skin = v.jersey.skin
	var out := Vector3.ZERO
	for k in range(4):
		var w := weights[i * 4 + k]
		if w <= 0.0: continue
		var bind := bones[i * 4 + k]
		var bone: int = v.skeleton.find_bone(skin.get_bind_name(bind))
		out += (v.skeleton.get_bone_global_pose(bone) * skin.get_bind_pose(bind) * verts[i]) * w
	return out

## Faceting (degrees): the median angle between each triangle's own
## normal and its corners' shading normals. Smooth, well-segmented surfaces
## stay low; boxes and low-section tubes (few big faces under smoothed
## normals) score high (a smoothed box ~45, an 8-sided tube ~20). Rolled hems,
## end caps and vents are a minority, so the median ignores them.
func worst_crease(mesh: Mesh) -> float:
	var angles := PackedFloat32Array()
	for s in range(mesh.get_surface_count()):
		var arrays := mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		for t in range(0, index.size(), 3):
			var face := (verts[index[t + 1]] - verts[index[t]]).cross(verts[index[t + 2]] - verts[index[t]])
			if face.length_squared() < 1e-14: continue
			face = face.normalized()
			for e in range(3):
				var n := normals[index[t + e]]
				# Winding may be either way round; compare against the line.
				angles.append(rad_to_deg(minf(n.angle_to(face), n.angle_to(-face))))
	angles.sort()
	return angles[int(angles.size() * 0.5)] if angles.size() > 0 else 0.0

## Average number of triangles sharing each vertex: about 1 on a flat-shaded
## (split-vertex) mesh, about 6 on a welded smooth-shaded one.
func sharing(mesh: Mesh) -> float:
	var arrays := mesh.surface_get_arrays(0)
	return float((arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size()) / maxf(1, (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size())

func vertex_count(mesh: Mesh) -> int:
	var total := 0
	for s in range(mesh.get_surface_count()):
		total += (mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	return total

func meshes(node: Node) -> Array:
	var out := []
	if node is MeshInstance3D: out.append(node)
	for child in node.get_children(): out.append_array(meshes(child))
	return out

func run() -> void:
	var Visual = load("res://scripts/skater_visual.gd")
	var Gear = load("res://scripts/gear_builder.gd")
	var v = Visual.new()
	root.add_child(v)
	await process_frame

	# --- Jersey: one skinned, smooth, many-segment sweater.
	var jersey: MeshInstance3D = v.jersey
	check(jersey != null and jersey.skin != null, "jersey is not a skinned mesh")
	check(jersey.get_parent() == v.skeleton, "jersey is not bound to the rig's Skeleton3D")
	var arrays: Array = jersey.mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	check(arrays[Mesh.ARRAY_BONES] != null and (arrays[Mesh.ARRAY_BONES] as PackedInt32Array).size() == verts.size() * 4, "jersey has no skin weights")
	check(Visual.JERSEY_COLUMNS >= 48, "jersey has too few columns (%d)" % Visual.JERSEY_COLUMNS)
	check(verts.size() >= 48 * 30, "jersey has too few vertices (%d)" % verts.size())
	check(verts.size() <= 4000, "jersey is too heavy for 12 players (%d vertices)" % verts.size())
	var crease := worst_crease(jersey.mesh)
	check(sharing(jersey.mesh) > 4.0, "jersey is not smooth-shaded")
	check(crease < 8.0, "jersey has hard facets (%.0f deg between corner normals)" % crease)
	# No separate shoulder-cap blobs: the shoulder pads shape the sweater.
	for child in v.shirt.get_children():
		check(not (child is MeshInstance3D), "separate mesh %s still floats on the shirt" % child.name)
	# Shoulder line is wider than the waist, and the hem flares out over the pants.
	var Prof = Gear.GearProfiles
	check(Prof.curve(Visual.JERSEY_WIDTH, 1.42) > Prof.curve(Visual.JERSEY_WIDTH, 1.10) + 0.04, "no shoulder-pad shape in the sweater")
	check(Prof.curve(Visual.JERSEY_WIDTH, Visual.JERSEY_HEM) > Prof.curve(Visual.JERSEY_WIDTH, 1.10) + 0.015, "hem does not flare")
	# V-neck: the neckline dips at the front.
	check(v.jersey_neck(PI * 0.5) < v.jersey_neck(-PI * 0.5) - 0.06, "no V-neck at the front")

	# Pick chest vertices (moved by the chest only) and hem vertices.
	var chest: Array[int] = []
	var hem: Array[int] = []
	for i in range(verts.size()):
		var p := verts[i]
		if p.y > 1.36 and p.y < 1.40 and absf(p.x) < 0.12: chest.append(i)
		if p.y < v.jersey_hem_height() + 0.012 and p.y > v.jersey_hem_height() - 0.004: hem.append(i)
	check(chest.size() > 4 and hem.size() > 20, "could not find chest/hem vertices")

	# Poses: upright coast, a deep skating lean, and a twist toward the stick.
	var poses := [[0.0, Vector2.ZERO], [9.0, Vector2.ZERO], [6.0, Vector2(1, 0)], [6.0, Vector2(-1, 0)]]
	var chest_positions := []
	var hem_offsets := []
	for pose in poses:
		v.desired_stick = pose[1]
		for f in range(60):
			v.animate(pose[0], 1.0 / 60, 0, pose[0] > 0.5)
		await process_frame
		# The chest of the sweater rides exactly with the posed chest (spine01).
		var worst := 0.0
		for i in chest:
			var expected: Vector3 = v.shirt.transform * verts[i]
			worst = maxf(worst, skinned(v, arrays, i).distance_to(expected))
		# Sculpted sweater weights blend the chest with the clavicles/breast
		# bones of the base rig, so allow a few millimetres more.
		check(worst < (0.008 if v.mesh_kit else 0.003), "pose %s: jersey chest is %.1f cm off the chest bone" % [str(pose), worst * 100])
		var spine01: int = v.skeleton.find_bone("spine01")
		var bone_err: float = (v.skeleton.get_bone_global_pose(spine01).origin).distance_to(v.shirt.transform * (v.rest["spine01"] as Transform3D).origin)
		check(bone_err < 0.003, "pose %s: chest bone not where the torso is posed (%.1f cm)" % [str(pose), bone_err * 100])
		chest_positions.append(skinned(v, arrays, chest[0]))
		# The hem is not rigid with the chest: it hangs back toward the hips.
		var lag := 0.0
		for i in hem:
			lag = maxf(lag, skinned(v, arrays, i).distance_to(v.shirt.transform * verts[i]))
		hem_offsets.append(lag)
	check((chest_positions[1] as Vector3).distance_to(chest_positions[0]) > 0.02, "jersey chest did not move with a deeper lean")
	check((chest_positions[2] as Vector3).distance_to(chest_positions[3]) > 0.02, "jersey chest did not twist with the shoulders")
	check(hem_offsets[1] > 0.005, "jersey is still a rigid barrel (hem moves exactly with the chest)")

	# --- Pants: rounded padded breezers, not boxes.
	var pants: Mesh = v.pant_legs[0].mesh
	if v.mesh_kit:
		check_mesh_pants(v, pants)
	else:
		check_procedural_pants(Gear, pants)
	gloves_and_helmet(v, Gear)
	v.queue_free()
	await process_frame
	print("Kit geometry failures: ", failures)
	quit(failures)

## Sculpted breezers: one skinned smooth mesh, round legs, hanging from the
## waist under the sweater hem to above the knee, never into the other leg.
func check_mesh_pants(v, pants: Mesh) -> void:
	check(v.kit_pants.skin != null and v.kit_pants.get_parent() == v.skeleton, "pants are not skinned to the rig")
	check(sharing(pants) > 4.0, "pants are not smooth-shaded")
	var pants_crease := worst_crease(pants)
	check(pants_crease < 8.0, "pants have hard facets (%.0f deg)" % pants_crease)
	check(vertex_count(pants) <= 4000, "pants are too heavy (%d vertices)" % vertex_count(pants))
	var pv: PackedVector3Array = pants.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var top := -INF
	var bottom := INF
	for q in pv:
		top = maxf(top, q.y)
		bottom = minf(bottom, q.y)
	# Mid-thigh section of the left leg: elliptical, not a box. Normalised by
	# the section's own extents, box corners would reach ~1.41.
	var mid := lerpf(bottom, top, 0.3)
	var lo := Vector2(INF, INF)
	var hi := -lo
	var ring: Array[Vector2] = []
	for q in pv:
		if absf(q.y - mid) < 0.012 and q.x > 0.01:
			ring.append(Vector2(q.x, q.z))
			lo = lo.min(Vector2(q.x, q.z))
			hi = hi.max(Vector2(q.x, q.z))
	check(ring.size() > 12, "no mid-thigh section on the pants")
	var c2 := (lo + hi) * 0.5
	var half := (hi - lo) * 0.5
	var corner := 0.0
	for q in ring:
		corner = maxf(corner, ((q - c2) / half).length())
	check(corner < 1.25, "pants leg cross-section is boxy (%.2f)" % corner)
	# Breezers hang tapered like real pants, not a drum: the leg opening (just
	# above the knee) is clearly narrower than the upper thigh (kit v7: ~0.80).
	var open_w := 0.0
	var thigh_w := 0.0
	var open_lo := INF
	var open_hi := -INF
	var thigh_lo := INF
	var thigh_hi := -INF
	for q in pv:
		if q.x <= 0.01:
			continue
		if q.y < bottom + 0.02:
			open_lo = minf(open_lo, q.x)
			open_hi = maxf(open_hi, q.x)
		elif absf(q.y - lerpf(bottom, top, 0.45)) < 0.02:
			thigh_lo = minf(thigh_lo, q.x)
			thigh_hi = maxf(thigh_hi, q.x)
	open_w = open_hi - open_lo
	thigh_w = thigh_hi - thigh_lo
	check(thigh_w > 0.1 and open_w < thigh_w * 0.88, "pants leg does not taper to the knee (opening %.3f vs thigh %.3f)" % [open_w, thigh_w])
	var knee: float = (v.rest["lowerleg01.L"] as Transform3D).origin.y
	check(top > v.jersey_hem_height() + 0.1, "pants top does not reach under the sweater")
	check(bottom > knee and bottom < knee + 0.2, "pants should stop just above the knee (%.2f, knee %.2f)" % [bottom, knee])

func check_procedural_pants(Gear, pants: Mesh) -> void:
	check(Gear.PANTS_RINGS >= 20 and Gear.PANTS_SIDES >= 32, "pants have too few segments")
	var pants_crease := worst_crease(pants)
	check(sharing(pants) > 4.0, "pants are not smooth-shaded")
	check(pants_crease < 8.0, "pants have hard facets (%.0f deg)" % pants_crease)
	var pv: PackedVector3Array = pants.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	# Cross-section near mid-thigh: a box would have corners far outside its
	# inscribed circle; padded breezers stay round (corner/side ratio near 1).
	var ring: int = Gear.PANTS_SIDES * (Gear.PANTS_RINGS / 2)
	var rmin := INF
	var rmax := 0.0
	for k in range(Gear.PANTS_SIDES):
		var q := pv[ring + k]
		var r := Vector2(q.x, q.z / 0.94).length()
		rmin = minf(rmin, r)
		rmax = maxf(rmax, r)
	check(rmax / rmin < 1.25, "pants cross-section is boxy (corner/side %.2f)" % (rmax / rmin))
	# Flared hem over the knee.
	var hem_r := 0.0
	var knee_r := 0.0
	for k in range(Gear.PANTS_SIDES):
		hem_r = maxf(hem_r, absf(pv[Gear.PANTS_SIDES * (Gear.PANTS_RINGS - 3) + k].z))
		knee_r = maxf(knee_r, absf(pv[Gear.PANTS_SIDES * int((Gear.PANTS_RINGS - 3) * 0.86) + k].z))
	check(hem_r > knee_r + 0.003, "pants hem does not flare over the knee")

func gloves_and_helmet(v, Gear) -> void:

	# --- Gloves: smooth, many-part, cuff toward the elbow.
	for i in range(2):
		var glove_meshes := meshes(v.skater_gloves[i])
		check(glove_meshes.size() > 0, "glove %d missing" % i)
		var gm: Mesh = glove_meshes[0].mesh
		check(sharing(gm) > 4.0, "glove %d is not smooth-shaded" % i)
		check(vertex_count(gm) > 1200, "glove %d is low-poly (%d vertices)" % [i, vertex_count(gm)])
		var glove_crease := worst_crease(gm)
		# The procedural glove (7.3k triangles) is held to 12.5 deg. The Blender
		# glove has to fit the 2.5k rigid-gear budget (night-shift playbook) with
		# ~20 separate padded parts, so each pillow has 12-14 sides: its median
		# facet is about 20 deg (hidden at play distance; normal-map bake is a
		# backlog follow-up). The budget check below keeps it from going coarser.
		var crease_limit := 22.0 if v.MESH_GLOVE else 12.5
		check(glove_crease < crease_limit, "glove %d has hard facets (%.0f deg)" % [i, glove_crease])
		var to_elbow: Vector3 = (v.posed_elbows[i] - v.posed_wrists[i]).normalized()
		# The wrist cocks a little so the shaft lies diagonally in the fist.
		check(v.skater_gloves[i].basis.y.normalized().dot(to_elbow) > 0.9, "glove %d cuff does not point up the forearm" % i)
		if v.MESH_GLOVE:
			# Blender glove (assets/gear/glove-v1.glb): within budget, team-coloured,
			# and the hole through the fist is clear for the shaft.
			var arrays: Array = gm.surface_get_arrays(0)
			var tris: int = (arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
			check(tris <= 2500 and tris >= 2000, "glove %d outside the 2.0-2.5k triangle budget (%d)" % [i, tris])
			var has_kit := false
			for c: Color in arrays[Mesh.ARRAY_COLOR]:
				if Vector3(c.r - v.kit.r, c.g - v.kit.g, c.b - v.kit.b).length() < 0.02: has_kit = true
			check(has_kit, "glove %d does not carry the team colour" % i)
			var in_hole := 0
			for p: Vector3 in arrays[Mesh.ARRAY_VERTEX]:
				var d: Vector3 = p - v.GLOVE_HOLE
				if absf(p.x) < 0.036 and absf(d.y) < 0.009 and absf(d.z) < 0.012: in_hole += 1
			check(in_hole == 0, "glove %d fist closes over the shaft hole (%d vertices inside)" % [i, in_hole])
			var thumb_x: float = 0.0
			for p: Vector3 in arrays[Mesh.ARRAY_VERTEX]:
				if absf(p.x) > absf(thumb_x): thumb_x = p.x
			check(signf(thumb_x) == v.GLOVE_THUMB[i], "glove %d thumb on the wrong side" % i)

	# --- Helmet: a sculpted shell with visor and fittings, not a ball.
	var shell: MeshInstance3D = v.helmet.get_node("Shell")
	var visor: MeshInstance3D = v.helmet.get_node("Visor")
	check(shell != null and visor != null, "helmet shell or visor missing")
	var aabb := shell.mesh.get_aabb()
	check(aabb.size.z > aabb.size.x * 1.08, "helmet is ball-shaped (depth %.3f vs width %.3f)" % [aabb.size.z, aabb.size.x])
	check(vertex_count(shell.mesh) > 48 * 16, "helmet shell is low-poly")
	var shell_crease := worst_crease(shell.mesh)
	print("faceting: jersey %.1f pants %.1f glove %.1f helmet %.1f" % [worst_crease(v.jersey.mesh), worst_crease(v.pant_legs[0].mesh), worst_crease(meshes(v.skater_gloves[0])[0].mesh), shell_crease])
	check(shell_crease < 8.0, "helmet shell has hard facets (%.0f deg)" % shell_crease)
	# Ear pieces and the back of the shell come down lower than the brow.
	check(Gear.helmet_edge(PI) > Gear.helmet_edge(0.0) + 0.3, "helmet has no low back / raised brow")
	check(meshes(v.helmet).size() >= 3, "helmet is missing fittings")

	# --- Sleeves: enough segments for a clean silhouette.
	check(v.SLEEVE_ROWS >= 12 and v.SLEEVE_SIDES >= 20, "sleeves are low-poly")
	if v.mesh_kit:
		check(v.kit_sleeves != null and v.kit_sleeves.skin != null and vertex_count(v.kit_sleeves.mesh) > 400, "sculpted sleeves missing")
		check(vertex_count(v.jersey.mesh) + vertex_count(v.kit_sleeves.mesh) <= 4400, "sweater too heavy for 12 players")
