extends SceneTree
## Export the in-game players as static glTF for the Unreal project (and any
## other DCC): exactly what the game draws, posed, in one file per player.
##
##   godot --headless --script tools/export_player_gltf.gd -- --out=<dir>
##
## Writes <dir>/hawkey_skater.glb (home #17), hawkey_skater_away.glb (#28)
## and hawkey_goalie.glb (#31), in the game's idle skating stance.
## For each visible mesh: skinned meshes are baked in their current pose
## (MeshInstance3D.bake_mesh_from_current_skeleton_pose), the base body keeps
## only the regions uniform.gdshader draws for that player (head/neck, socks;
## the shell, sleeves, hands and - for skaters - shorts and scalp are covered
## by kit and gear), and every material's colour is folded into vertex
## colours, so a single vertex-colour material shows it all. Three material
## names tell the importer what's special: HK_VC (everything), HK_FACE (the
## scanned face, base-colour texture), HK_VISOR (clear, see-through).
## Everything is in metres, Y up, the player facing -Z (Godot forward).

var out_dir := "/tmp/hawkey-export"

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if str(arg).begins_with("--out="): out_dir = str(arg).substr(6)
	call_deferred("run")

func run() -> void:
	DirAccess.make_dir_recursive_absolute(out_dir)
	var stage := Node3D.new()
	root.add_child(stage)
	var ok := 0
	# Warm-up: the first visual built settles into a deeper crouch than the
	# rest; build and drop one so every export gets the same ready stance.
	var warm = load("res://scripts/skater_visual.gd").new()
	stage.add_child(warm)
	await process_frame
	for k in range(120): warm.animate(0, 1.0 / 60, 0, false)
	warm.queue_free()
	await process_frame
	# Home and away skater kits as in a Play Now game, and the home goalie,
	# each in the game's idle skating stance (as tools/capture_showcase.gd).
	for spec in [["hawkey_skater", false, Color("#164a9a"), Color("#e8eef5"), "17"],
			["hawkey_skater_away", false, Color("#e9edf0"), Color("#b3162c"), "28"],
			["hawkey_goalie", true, Color("#164a9a"), Color("#e8eef5"), "31"]]:
		var v = load("res://scripts/skater_visual.gd").new()
		v.goalie = spec[1]
		v.kit = spec[2]
		v.accent = spec[3]
		v.number = spec[4]
		stage.add_child(v)
		if v.get("nameplate") != null and v.nameplate: v.nameplate.visible = false
		await process_frame
		for k in range(120):
			if v.goalie: v.set_save("", Vector2(0, 0.8), 1.0 / 60)
			v.animate(0, 1.0 / 60, 0, false)
		await process_frame
		ok += export_actor(v, out_dir.path_join(spec[0] + ".glb"))
		v.queue_free()
		await process_frame
	print("HAWKEY_GLTF_EXPORT ", ok, " files -> ", out_dir)
	quit(0 if ok == 3 else 1)

func export_actor(visual: Node3D, path: String) -> int:
	var root_node := Node3D.new()
	root_node.name = "HawkeyPlayer"
	var origin := visual.global_transform.origin
	var facing := visual.global_transform.basis.get_rotation_quaternion()
	var to_local := Transform3D(Basis(facing), origin).affine_inverse()
	var count := 0
	var tris := 0
	for node in all_children(visual):
		var mi := node as MeshInstance3D
		if mi == null or mi.mesh == null or not mi.is_visible_in_tree():
			continue
		var mesh: Mesh = mi.mesh
		var skel: Skeleton3D = mi.get_node_or_null(mi.skeleton) as Skeleton3D if mi.skin != null else null
		var baked := ArrayMesh.new()
		for s in range(mesh.get_surface_count()):
			var material := surface_material(mi, s)
			var rest_arrays := mesh.surface_get_arrays(s)
			var arrays := rest_arrays.duplicate()
			if skel != null:
				# CPU skinning in the current pose (headless has no GPU skinning).
				var posed := skin_surface(mi, skel, rest_arrays)
				arrays[Mesh.ARRAY_VERTEX] = posed[0]
				arrays[Mesh.ARRAY_NORMAL] = posed[1]
			var built := convert_surface(arrays, rest_arrays, material)
			if built.is_empty():
				continue
			baked.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, built.arrays)
			baked.surface_set_material(baked.get_surface_count() - 1, built.material)
			tris += (built.arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
		if baked.get_surface_count() == 0:
			continue
		var copy := MeshInstance3D.new()
		copy.name = "%s_%d" % [mi.name, count]
		copy.mesh = baked
		copy.transform = to_local * (skel.global_transform if skel != null else mi.global_transform)
		root_node.add_child(copy)
		count += 1
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	if doc.append_from_scene(root_node, state) != OK:
		return 0
	var err := doc.write_to_filesystem(state, path)
	print("EXPORT ", path, " meshes ", count, " tris ", tris, " err ", err)
	root_node.free()
	return 1 if err == OK else 0

## Posed skeleton-space positions and normals of a skinned surface.
func skin_surface(mi: MeshInstance3D, skel: Skeleton3D, arrays: Array) -> Array:
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals = arrays[Mesh.ARRAY_NORMAL]
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var per := bones.size() / maxi(1, verts.size())
	var mats := []
	for b in range(mi.skin.get_bind_count()):
		var bone := skel.find_bone(mi.skin.get_bind_name(b))
		if bone < 0 and mi.skin.get_bind_bone(b) >= 0: bone = mi.skin.get_bind_bone(b)
		mats.append(skel.get_bone_global_pose(bone) * mi.skin.get_bind_pose(b) if bone >= 0 else Transform3D())
	var out_v := PackedVector3Array()
	var out_n := PackedVector3Array()
	out_v.resize(verts.size())
	out_n.resize(verts.size())
	for i in range(verts.size()):
		var p := Vector3.ZERO
		var n := Vector3.ZERO
		for k in range(per):
			var w := weights[i * per + k]
			if w > 0.0:
				var m: Transform3D = mats[bones[i * per + k]]
				p += (m * verts[i]) * w
				if normals != null: n += (m.basis * (normals as PackedVector3Array)[i]) * w
		out_v[i] = p
		out_n[i] = n.normalized() if n.length_squared() > 0.0 else Vector3.UP
	return [out_v, out_n]

func all_children(node: Node) -> Array:
	var result := []
	for child in node.get_children():
		result.append(child)
		result.append_array(all_children(child))
	return result

func surface_material(mi: MeshInstance3D, s: int) -> Material:
	if mi.material_override != null: return mi.material_override
	var m := mi.get_surface_override_material(s)
	if m != null: return m
	return mi.mesh.surface_get_material(s) if s < mi.mesh.get_surface_count() else null

func shader_name(material: Material) -> String:
	if material is ShaderMaterial and material.shader != null:
		return material.shader.resource_path.get_file().get_basename()
	return ""

func param(material: Material, name: String, fallback):
	if material is ShaderMaterial:
		var v = material.get_shader_parameter(name)
		if v != null: return v
	return fallback

## Which triangles of a surface the game draws, and in what colour.
func convert_surface(arrays: Array, rest_arrays: Array, material: Material) -> Dictionary:
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals = arrays[Mesh.ARRAY_NORMAL]
	var uvs = arrays[Mesh.ARRAY_TEX_UV]
	var colors = arrays[Mesh.ARRAY_COLOR]
	var indices = arrays[Mesh.ARRAY_INDEX]
	if indices == null or (indices as PackedInt32Array).is_empty():
		indices = PackedInt32Array(range(verts.size()))
	var rest_verts: PackedVector3Array = rest_arrays[Mesh.ARRAY_VERTEX] if rest_arrays[Mesh.ARRAY_VERTEX] != null else verts
	var kind := shader_name(material)
	var out_name := "HK_VC"
	var base := Color(0.8, 0.8, 0.8)
	var keep_region := func(_i: int) -> bool: return true
	var region_color := func(i: int) -> Color: return base
	match kind:
		"uniform":
			# The base body: only what uniform.gdshader doesn't discard.
			var team: Color = param(material, "team_color", Color(0.2, 0.3, 0.5))
			var hide_pants: bool = param(material, "hide_pants", false)
			var hide_socks: bool = param(material, "hide_socks", false)
			var hide_neck: bool = param(material, "hide_neck", false)
			var hide_head: bool = param(material, "hide_head", false)
			var skin := Color(0.62, 0.45, 0.36)
			keep_region = func(i: int) -> bool:
				var region: float = (colors[i] as Color).r * 8.0 if colors != null else 0.0
				if region > 3.5 or (region > 0.5 and region < 1.5): return false
				if hide_pants and region > 1.5 and region < 2.5: return false
				if hide_socks and region > 2.5 and region < 3.5: return false
				if region < 0.5:
					var h := rest_verts[i].y if i < rest_verts.size() else 0.0
					if hide_neck and h < 1.545: return false
					if hide_head and h >= 1.545: return false
				return true
			region_color = func(i: int) -> Color:
				var region: float = (colors[i] as Color).r * 8.0 if colors != null else 0.0
				return skin if region < 0.5 else (team.darkened(0.15) if region < 2.5 else team)
		"kit_cloth":
			base = param(material, "kit", Color(0.1, 0.35, 0.5))
			var trim: Color = param(material, "trim_color", Color(0.9, 0.9, 0.9))
			region_color = func(i: int) -> Color: return base
		"kit_gear":
			base = param(material, "base_color", Color(1, 1, 1))
			region_color = func(i: int) -> Color: return base * (colors[i] as Color) if colors != null else base
		"kit_visor":
			out_name = "HK_VISOR"
			base = param(material, "tint", Color(0.62, 0.74, 0.8))
			region_color = func(i: int) -> Color: return Color(base, 0.25)
		"skater_face":
			out_name = "HK_FACE"
			var tone: Color = param(material, "tone", Color(1, 1, 1))
			region_color = func(i: int) -> Color: return tone
		_:
			if material is BaseMaterial3D:
				base = (material as BaseMaterial3D).albedo_color
				var use_vc := (material as BaseMaterial3D).vertex_color_use_as_albedo
				region_color = func(i: int) -> Color: return base * (colors[i] as Color) if (use_vc and colors != null) else base
				if (material as BaseMaterial3D).transparency != BaseMaterial3D.TRANSPARENCY_DISABLED and base.a < 0.6:
					out_name = "HK_VISOR"
	var new_verts := PackedVector3Array()
	var new_normals := PackedVector3Array()
	var new_uvs := PackedVector2Array()
	var new_colors := PackedColorArray()
	var new_indices := PackedInt32Array()
	var remap := {}
	var idx: PackedInt32Array = indices
	for t in range(0, idx.size() - 2, 3):
		var a := idx[t]
		var b := idx[t + 1]
		var c := idx[t + 2]
		if not (keep_region.call(a) and keep_region.call(b) and keep_region.call(c)):
			continue
		for v in [a, b, c]:
			if not remap.has(v):
				remap[v] = new_verts.size()
				new_verts.append(verts[v])
				new_normals.append((normals as PackedVector3Array)[v] if normals != null else Vector3.UP)
				new_uvs.append((uvs as PackedVector2Array)[v] if uvs != null else Vector2.ZERO)
				var col: Color = region_color.call(v)
				col.a = 1.0 if out_name != "HK_VISOR" else col.a
				new_colors.append(col)
			new_indices.append(remap[v])
	if new_indices.is_empty():
		return {}
	var out := []
	out.resize(Mesh.ARRAY_MAX)
	out[Mesh.ARRAY_VERTEX] = new_verts
	out[Mesh.ARRAY_NORMAL] = new_normals
	out[Mesh.ARRAY_TEX_UV] = new_uvs
	out[Mesh.ARRAY_COLOR] = new_colors
	out[Mesh.ARRAY_INDEX] = new_indices
	var m := StandardMaterial3D.new()
	m.resource_name = out_name
	m.vertex_color_use_as_albedo = true
	m.roughness = 0.6
	if out_name == "HK_FACE":
		var tex = param(material, "albedo_tex", null)
		if tex is Texture2D: m.albedo_texture = tex
	if out_name == "HK_VISOR":
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return {"arrays": out, "material": m}
