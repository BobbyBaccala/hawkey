extends SceneTree
## Equipment interpenetration test. Samples surface points of each gear piece and
## counts those lying deeper than TOLERANCE inside another piece's closed mesh
## (ray parity), across goalie and skater poses. Pairs that are meant to meet
## (hand inside glove holding the stick, sock tucked into the skate) are allowed.
## Run with --report to list every offending pair.
const TOLERANCE := 0.008
const CELL := 0.025
var failures := 0
var report := false

func check(ok: bool, message: String) -> void:
	if not ok:
		if not report:
			push_error(message)
		failures += 1

func _initialize() -> void:
	call_deferred("run")

class Solid:
	var name := ""
	var points := PackedVector3Array()
	var tris := PackedVector3Array()
	var grid := {}
	var aabb := AABB()

	func _init(name_: String, instances: Array) -> void:
		name = name_
		var first := true
		for instance: MeshInstance3D in instances:
			var mesh := instance.mesh
			var xf := instance.global_transform
			for s in range(mesh.get_surface_count()):
				var arrays := mesh.surface_get_arrays(s)
				var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				var index = arrays[Mesh.ARRAY_INDEX]
				var world := PackedVector3Array()
				for v in verts:
					var w := xf * v
					world.append(w)
					if first:
						aabb = AABB(w, Vector3.ZERO)
						first = false
					else:
						aabb = aabb.expand(w)
				var stride := maxi(1, world.size() / 500)
				for i in range(0, world.size(), stride):
					points.append(world[i])
				if index == null or index.is_empty():
					for i in range(0, world.size() - 2, 3):
						tris.append_array(PackedVector3Array([world[i], world[i + 1], world[i + 2]]))
				else:
					for i in range(0, index.size() - 2, 3):
						tris.append_array(PackedVector3Array([world[index[i]], world[index[i + 1]], world[index[i + 2]]]))
		# Bucket triangles on the Y/Z plane for +X parity rays.
		for t in range(0, tris.size(), 3):
			var a := tris[t]
			var b := tris[t + 1]
			var c := tris[t + 2]
			var y0 := floori(minf(a.y, minf(b.y, c.y)) / CELL)
			var y1 := floori(maxf(a.y, maxf(b.y, c.y)) / CELL)
			var z0 := floori(minf(a.z, minf(b.z, c.z)) / CELL)
			var z1 := floori(maxf(a.z, maxf(b.z, c.z)) / CELL)
			for y in range(y0, y1 + 1):
				for z in range(z0, z1 + 1):
					var key := Vector2i(y, z)
					if not grid.has(key):
						grid[key] = PackedInt32Array()
					grid[key].append(t)

	## Posed (skeleton-space) vertices of a skinned mesh surface.
	static func skinned(instance: MeshInstance3D, skel: Skeleton3D, arrays: Array) -> PackedVector3Array:
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		var per := bones.size() / maxi(1, verts.size())
		var mats := []
		for b in range(instance.skin.get_bind_count()):
			var bone := skel.find_bone(instance.skin.get_bind_name(b))
			mats.append(skel.get_bone_global_pose(bone) * instance.skin.get_bind_pose(b) if bone >= 0 else Transform3D())
		var out := PackedVector3Array()
		out.resize(verts.size())
		for i in range(verts.size()):
			var p := Vector3.ZERO
			for k in range(per):
				var w := weights[i * per + k]
				if w > 0.0:
					p += ((mats[bones[i * per + k]] as Transform3D) * verts[i]) * w
			out[i] = p
		return out

	## Inside test. Ray parity (+X and -X) finds candidates cheaply; each
	## candidate is confirmed by its generalized winding number, which stays
	## right where a mesh is made of overlapping closed shells (a pad's outer
	## roll over its face) or has boolean slivers that make a ray miscount.
	func contains(p: Vector3) -> bool:
		if not aabb.grow(0.001).has_point(p):
			return false
		if not (_parity(p) or _parity(p, -1.0)):
			return false
		return absf(winding(p)) > 0.5

	func winding(p: Vector3) -> float:
		var total := 0.0
		for t in range(0, tris.size(), 3):
			var a := tris[t] - p
			var b := tris[t + 1] - p
			var c := tris[t + 2] - p
			var la := a.length()
			var lb := b.length()
			var lc := c.length()
			var det := a.dot(b.cross(c))
			var div := la * lb * lc + a.dot(b) * lc + b.dot(c) * la + c.dot(a) * lb
			total += 2.0 * atan2(det, div)
		return total / (4.0 * PI)

	func _parity(p: Vector3, sign_ := 1.0) -> bool:
		var key := Vector2i(floori(p.y / CELL), floori(p.z / CELL))
		if not grid.has(key):
			return false
		var hits: Array[float] = []
		# Buckets cover a fixed Y/Z cell, so the ray must stay parallel to X.
		# Tilting it can omit the exit face in a neighbouring cell.
		var dir := Vector3.RIGHT * sign_
		for t in grid[key]:
			var hit = Geometry3D.ray_intersects_triangle(p, dir, tris[t], tris[t + 1], tris[t + 2])
			if hit != null:
				var distance: float = (hit.x - p.x) * sign_
				var duplicate := false
				for previous in hits:
					# Boolean-cut meshes have sliver triangles: a ray through their
					# shared edges hits each at almost the same distance.
					if absf(previous - distance) < 0.0001:
						duplicate = true
						break
				if not duplicate: hits.append(distance)
		return hits.size() % 2 == 1

	func depth(p: Vector3) -> float:
		var best := INF
		for t in range(0, tris.size(), 3):
			var c := (tris[t] + tris[t + 1] + tris[t + 2]) / 3.0
			if absf(c.x - p.x) > best or absf(c.y - p.y) > best or absf(c.z - p.z) > best:
				continue
			var q := Geometry3D.get_closest_point_to_segment(p, tris[t], tris[t + 1])
			best = minf(best, p.distance_to(q))
			q = Geometry3D.get_closest_point_to_segment(p, tris[t + 1], tris[t + 2])
			best = minf(best, p.distance_to(q))
			q = Geometry3D.get_closest_point_to_segment(p, tris[t + 2], tris[t])
			best = minf(best, p.distance_to(q))
			best = minf(best, p.distance_to(c))
		return best

## Points of a lying more than TOLERANCE inside b.
func penetration(a: Solid, b: Solid) -> Array:
	var count := 0
	var deepest := 0.0
	if not a.aabb.intersects(b.aabb):
		return [0, 0.0]
	for p in a.points:
		if b.contains(p):
			var d := b.depth(p)
			if d > TOLERANCE:
				count += 1
				deepest = maxf(deepest, d)
	return [count, deepest]

func meshes(node: Node) -> Array:
	var out := []
	if node is MeshInstance3D and node.visible:
		out.append(node)
	for child in node.get_children():
		out.append_array(meshes(child))
	return out

func gear_solids(v) -> Dictionary:
	var solids := {}
	for i in range(v.skates.size()):
		var side := "L" if i == 0 else "R"
		solids["skate" + side] = Solid.new("skate" + side, meshes(v.skates[i]))
		if v.pant_legs.size() > i and not v.mesh_kit:
			solids["pants" + side] = Solid.new("pants" + side, [v.pant_legs[i]])
		if v.socks.size() > i:
			solids["sock" + side] = Solid.new("sock" + side, [v.socks[i]])
	if v.mesh_kit:
		# Sculpted breezers: one skinned mesh over both legs.
		solids["pants"] = Solid.new("pants", [v.kit_pants])
	if v.goalie:
		for i in range(2):
			var side := "L" if i == 0 else "R"
			solids["pad" + side] = Solid.new("pad" + side, [v.pad_visuals[i].get_child(0)])
			if v.pad_rears.size() > i:
				solids["rear" + side] = Solid.new("rear" + side, [v.pad_rears[i]])
			solids["thigh" + side] = Solid.new("thigh" + side, meshes(v.thigh_rises[i]))
		solids["catcher"] = Solid.new("catcher", meshes(v.goalie_gloves[0]))
		solids["blocker"] = Solid.new("blocker", meshes(v.goalie_gloves[1]))
		# The drawn stick replaces the box proxies (which only carry the saves).
		if v.goalie_stick_mesh != null and v.goalie_stick_mesh.visible:
			solids["stick"] = Solid.new("stick", [v.goalie_stick_mesh])
		else:
			solids["paddle"] = Solid.new("paddle", [v.goalie_paddle])
	else:
		solids["gloveL"] = Solid.new("gloveL", meshes(v.skater_gloves[0]))
		solids["gloveR"] = Solid.new("gloveR", meshes(v.skater_gloves[1]))
	if v.stick_blade.visible:
		solids["blade"] = Solid.new("blade", [v.stick_blade])
	if v.stick_shaft.visible:
		solids["shaft"] = Solid.new("shaft", [v.stick_shaft])
	solids["mask"] = Solid.new("mask", meshes(v.helmet))
	return solids

## Pairs designed to meet: hands grip the stick inside the gloves, socks tuck into
## skates and under pants, each pad's halves share the hinge, the shaft joins the
## paddle and blade, and a pad's boot channel sits over its own skate.
const ALLOWED := [
	["blocker", "shaft"], ["blocker", "paddle"], ["blocker", "stick"], ["gloveL", "shaft"], ["gloveR", "shaft"],
	["sockL", "skateL"], ["sockR", "skateR"], ["sockL", "pantsL"], ["sockR", "pantsR"], ["sockL", "pants"], ["sockR", "pants"],
	["padL", "thighL"], ["padR", "thighR"], ["shaft", "paddle"], ["shaft", "blade"], ["paddle", "blade"],
]

func allowed(a: String, b: String) -> bool:
	for pair in ALLOWED:
		if (pair[0] == a and pair[1] == b) or (pair[0] == b and pair[1] == a):
			return true
	return false

var _pad_src := {}
## Solid of a pad mesh in its own (unscaled) space, cached per mesh.
func pad_source(mi: MeshInstance3D) -> Solid:
	if not _pad_src.has(mi.mesh):
		var probe := MeshInstance3D.new()
		probe.mesh = mi.mesh
		root.add_child(probe)
		_pad_src[mi.mesh] = Solid.new("pad_src", [probe])
		probe.queue_free()
	return _pad_src[mi.mesh]

func check_pose(v, label: String) -> void:
	var solids := gear_solids(v)
	var names := solids.keys()
	for i in range(names.size()):
		for j in range(i + 1, names.size()):
			if allowed(names[i], names[j]):
				continue
			var ab := penetration(solids[names[i]], solids[names[j]])
			var ba := penetration(solids[names[j]], solids[names[i]])
			var count: int = ab[0] + ba[0]
			var deepest: float = maxf(ab[1], ba[1])
			if report and count > 0:
				print("  %s: %s x %s  points=%d  depth=%.1f cm" % [label, names[i], names[j], count, deepest * 100])
			# Goalie pad over its own skate: the boot channel is a recess in the
			# back half of the pad from the bottom up to the top of the skate cuff
			# and the start of the calf wrap (0.33 m drawn), where the boot sits on
			# a real pad; plus the toe cap, which wraps over the skate toe.
			# Skate points inside the pad anywhere else - through the face, or up
			# by the knee - are real clipping.
			var sk_name: String = names[i] if names[i].begins_with("skate") else names[j]
			var pd_name: String = names[j] if sk_name == names[i] else names[i]
			if pd_name == "pad" + sk_name.substr(5) and v.goalie:
				var vis: Node3D = v.pad_visuals[0 if sk_name.ends_with("L") else 1]
				var to_pad: Transform3D = vis.global_transform.affine_inverse()
				# Judge the skate against the pad in the pad mesh's own space: the
				# moulded boot channel and toe pocket are empty there, and the
				# parity rays stay axis-aligned with the channel walls.
				var src: Solid = pad_source(vis.get_child(0))
				var outside := 0
				var worst := 0.0
				for p in (solids[sk_name] as Solid).points:
					var q: Vector3 = to_pad * p
					if not src.contains(q): continue
					# Pad-space depth, scaled by the largest drawn-pad axis scale so it is
					# never smaller than the real (world) penetration.
					var sc: Vector3 = vis.global_transform.basis.get_scale()
					var d: float = src.depth(q) * maxf(sc.x, maxf(sc.y, sc.z))
					if d <= TOLERANCE: continue
					outside += 1
					worst = maxf(worst, d)
					if report: print("    out ", q.snapped(Vector3.ONE*0.005), " d=", snappedf(d,0.001))
				check(outside == 0, "%s: %s clips into %s by %.1f cm (pad space)" % [label, sk_name, pd_name, worst * 100])
				continue
			check(count == 0, "%s: %s clips into %s by %.1f cm" % [label, names[i], names[j], deepest * 100])

func run() -> void:
	report = "--report" in OS.get_cmdline_user_args()
	var Visual = load("res://scripts/skater_visual.gd")
	var keeper = Visual.new()
	keeper.goalie = true
	root.add_child(keeper)
	await process_frame
	for pose in [[0.0, 0.0], [0.25, 0.0], [0.5, 0.0], [0.75, 0.0], [1.0, 0.0], [0.0, 0.25], [1.0, 0.2]]:
		keeper.butterfly = pose[0]
		keeper.goalie_save_height = pose[1]
		keeper.animate(0, 1)
		await process_frame
		check_pose(keeper, "goalie butterfly=%.1f save=%.2f" % pose)
	# Save poses: glove, blocker and both pad extensions.
	for save in [["glove", Vector2(0.8, 1.35)], ["blocker", Vector2(-0.7, 0.95)], ["pad_left", Vector2(0.95, 0.1)], ["pad_right", Vector2(-0.95, 0.1)]]:
		var down: bool = save[0].begins_with("pad")
		for f in range(60):
			keeper.butterfly = move_toward(keeper.butterfly, 1.0 if down else 0.0, 0.1)
			keeper.set_save(save[0], save[1], 1.0 / 60)
			keeper.animate(0, 1.0 / 60)
		await process_frame
		check_pose(keeper, "goalie %s save" % save[0])
	for f in range(90):
		keeper.butterfly = move_toward(keeper.butterfly, 0.0, 0.1)
		keeper.set_save("", Vector2(0, 0.8), 1.0 / 60)
		keeper.animate(0, 1.0 / 60)
	var Mocap = load("res://scripts/mocap.gd")
	if Mocap.available("Left_Strafe"):
		# Captured lateral shuffle, both directions, sampled through the stride.
		keeper.butterfly = 0.0
		keeper.goalie_save_height = 0.0
		for direction in [1.0, -1.0]:
			for f in range(48):
				keeper.position.x += direction * 2.4 / 60
				keeper.animate(0, 1.0 / 60)
				if f % 8 == 7:
					await process_frame
					check_pose(keeper, "goalie shuffle %+d frame %d" % [direction, f])
	keeper.queue_free()
	var skater = Visual.new()
	root.add_child(skater)
	await process_frame
	for stick in [Vector2.ZERO, Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
		skater.desired_stick = stick
		for i in range(40):
			skater.animate(0, 1.0 / 60)
		await process_frame
		check_pose(skater, "skater stick=%s" % stick)
	for i in range(8):
		for k in range(10):
			skater.animate(8, 1.0 / 120)
		await process_frame
		check_pose(skater, "skater stride %d" % i)
	if skater.play_mocap("Standing_Cheering", false, ["spine", "arms", "stick_up"]):
		for f in range(200):
			skater.animate(0, 1.0 / 60)
			if f % 25 == 24:
				await process_frame
				check_pose(skater, "skater celebration %.1fs" % ((f + 1) / 60.0))
	skater.queue_free()
	await process_frame
	print("Clipping failures: ", failures)
	quit(failures)
