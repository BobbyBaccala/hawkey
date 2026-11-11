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
	check(g.mesh_head and g.head_nodes.size() == 2, "goalie wears the scanned head")
	check(r.mesh_head and r.head_nodes.size() == 2, "referee wears the scanned head")
	for fig in [v, g, r]:
		check(fig.body_material.get_shader_parameter("hide_head") and fig.body_material.get_shader_parameter("hide_neck"), "base head and neck hidden under the scanned head")
		check(fig.neck_guard != null, "neck guard covers the stump")
	# Baked masks (vertex colour): r hair, g under-helmet liner, b crown skin, a ears.
	var hm: Mesh = parts["Head"][0]
	var ha := hm.surface_get_arrays(0)
	var hv: PackedVector3Array = ha[Mesh.ARRAY_VERTEX]
	var hc: PackedColorArray = ha[Mesh.ARRAY_COLOR]
	check(hc.size() == hv.size(), "head has a mask colour per vertex")
	var crown_dark := true
	var face_clean := true
	var ears := 0
	for i in range(hv.size()):
		var p := hv[i]
		if p.y > 1.745 and maxf(hc[i].r*hc[i].g, hc[i].b) < 0.9: crown_dark = false
		if p.z > 0.11 and p.y > 1.60 and p.y < 1.70 and (hc[i].r > 0.05 or hc[i].b > 0.05): face_clean = false
		if hc[i].a < 0.5:
			ears += 1
			if absf(p.x) < 0.07: face_clean = false
	check(crown_dark, "everything under the helmet crown is liner-dark (vents never show skin)")
	check(face_clean, "no hair or liner on the face; ear mask only on the ears")
	check(ears > 20, "ears are masked for goalie masks: %d verts" % ears)
	# Rigid head: every vertex follows the head bone only.
	var skin_h: Skin = parts["Head"][1]
	var hb: PackedInt32Array = ha[Mesh.ARRAY_BONES]
	var hw: PackedFloat32Array = ha[Mesh.ARRAY_WEIGHTS]
	var per := hb.size()/hv.size()
	var rigid := true
	for i in range(hv.size()):
		if skin_h.get_bind_name(hb[i*per]) != "head" or absf(hw[i*per]-1.0) > 0.001: rigid = false
	check(rigid, "head mesh is rigidly bound to the head bone")
	check((g.head_nodes[0].material_override as ShaderMaterial).get_shader_parameter("hide_ears") == true, "goalie hides the ears")
	check((v.head_nodes[0].material_override as ShaderMaterial).get_shader_parameter("hide_ears") != true, "skaters keep their ears")
	# Neck guard top ring encloses the neck stump (rest pose, head space).
	v.animate(0.0, 1.0/120, 0, false)
	var ga: AABB = v.neck_guard.mesh.get_aabb()
	check(ga.size.x > 0.15 and ga.size.x < 0.25, "neck guard wider than the neck stump: %.3f" % ga.size.x)
	print("head tris ", tris, " failures: ", failures)
	quit(1 if failures > 0 else 0)
