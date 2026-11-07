extends SceneTree
## Scanned skater head (skater_visual.gd MESH_HEAD): triangle budget, skinned to
## the game's skeleton, sits under the helmet, base head hidden for skaters only.
var failures := 0
func check(ok: bool, msg: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", msg)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var SV = preload("res://scripts/skater_visual.gd")
	check(SV.MESH_HEAD, "MESH_HEAD enabled")
	var parts: Dictionary = SV.head_parts()
	var tris := 0
	for n in ["Head","Eyes"]:
		var mesh: Mesh = parts[n][0]
		var skin: Skin = parts[n][1]
		check(skin != null and skin.get_bind_count() > 0, n + " is skinned")
		var arr := mesh.surface_get_arrays(0)
		tris += (arr[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
		check(arr[Mesh.ARRAY_BONES] != null and (arr[Mesh.ARRAY_BONES] as PackedInt32Array).size() > 0, n + " has bone weights")
		var aabb := mesh.get_aabb()
		check(aabb.position.y > 1.5 and aabb.end.y < 1.85, n + " height range " + str(aabb))
	check(tris <= 10000, "head tris <= 10k: %d" % tris)
	var v = SV.new()
	v.kit = Color.RED
	root.add_child(v)
	await physics_frame
	check(v.mesh_head and v.head_nodes.size() == 2, "skater builds head meshes")
	var sk: Skeleton3D = v.skeleton
	for n in v.head_nodes:
		check(n.get_parent() == sk and n.skin != null, "head node bound to skeleton")
	var g = SV.new()
	g.goalie = true
	root.add_child(g)
	var r = SV.new()
	r.referee = true
	root.add_child(r)
	await physics_frame
	check(not g.mesh_head and g.head_nodes.is_empty(), "goalie keeps base head")
	check(not r.mesh_head and r.head_nodes.is_empty(), "referee keeps base head")
	print("head tris ", tris, " failures: ", failures)
	quit(1 if failures > 0 else 0)
