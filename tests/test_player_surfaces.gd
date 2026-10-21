extends SceneTree
const Visual=preload("res://scripts/skater_visual.gd")
const Surfaces=preload("res://scripts/player_surface_materials.gd")
var failures:=0
var checks:=0
func check(ok: bool, why: String) -> void:
	checks+=1
	if not ok: push_error(why);failures+=1
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var visual:=Visual.new();root.add_child(visual);await process_frame
	var skin: MeshInstance3D
	var eyes: MeshInstance3D
	for child in visual.skeleton.get_children():
		if not child is MeshInstance3D or child==visual.jersey: continue
		if child.mesh.get_surface_count()==6: skin=child
		elif child.material_override==Surfaces.eyes(): eyes=child
	check(visual.helmet.get_node("Visor").cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,"Clear visor cannot cast an opaque face shadow")
	check(skin!=null and eyes!=null,"Bundled player has distinct skin and eye meshes")
	if skin==null or eyes==null: quit(1);return
	check(skin.get_surface_override_material(2).get_shader_parameter("lip_surface")==true,"Lip geometry has a distinct warm-skin surface")
	check(skin.get_surface_override_material(0).shader==preload("res://assets/uniform.gdshader"),"Skin keeps its clothing/region shader")
	for node in [skin,eyes]:
		for surface in range(node.mesh.get_surface_count()):
			var arrays: Array=node.mesh.surface_get_arrays(surface)
			check(arrays[Mesh.ARRAY_TEX_UV].size()==arrays[Mesh.ARRAY_VERTEX].size(),"Stable rest-space UV for each vertex")
			check(arrays[Mesh.ARRAY_BONES].size()==arrays[Mesh.ARRAY_VERTEX].size()*4,"Original skeletal bone indices retained")
			check(arrays[Mesh.ARRAY_WEIGHTS].size()==arrays[Mesh.ARRAY_VERTEX].size()*4,"Original skin weights retained")
	var original=load("res://assets/player-base-v1.glb").instantiate();root.add_child(original);await process_frame
	var original_meshes: Array=original.find_children("*","MeshInstance3D",true,false)
	for node in [skin,eyes]:
		var matches: Array=original_meshes.filter(func(m): return m.mesh.get_surface_count()==node.mesh.get_surface_count())
		check(matches.size()==1,"Unambiguous bundled source mesh")
		for surface in range(node.mesh.get_surface_count()):
			var before: Array=matches[0].mesh.surface_get_arrays(surface)
			var after: Array=node.mesh.surface_get_arrays(surface)
			for key in [Mesh.ARRAY_VERTEX,Mesh.ARRAY_NORMAL,Mesh.ARRAY_INDEX,Mesh.ARRAY_BONES,Mesh.ARRAY_WEIGHTS]:
				if before[key]!=after[key] and key==Mesh.ARRAY_NORMAL:
					var error:=0.0
					for i in range(before[key].size()): error=maxf(error,before[key][i].distance_to(after[key][i]))
					print("NORMAL_REENCODE_ERROR ",error)
					check(error<0.0005,"Normal re-encoding stays below 0.0005 vector error")
				else: check(before[key]==after[key],"Material remap preserves geometry and rig exactly")
	for spray in visual.sprays:
		check(not spray.visible and not spray.is_spraying(),"No idle uninitialised particle specks")
		spray.spray(true,0.8,6.0);check(spray.visible and spray.is_spraying(),"Real stop reveals snow")
		spray.spray(false,0.0);spray._process(0.2);check(spray.visible,"Existing snow fades after emission stops")
		spray._process(1.0);check(not spray.visible and not spray.is_spraying(),"Spent effect hides once its tail expires")
	original.queue_free();visual.queue_free();await process_frame
	print("Player surface review: %d checks; %d failures"%[checks,failures]);quit(failures)
