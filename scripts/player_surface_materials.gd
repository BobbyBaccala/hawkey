extends RefCounted
## Restore semantic facial surfaces lost when the original clay asset was prepared.
## Contract is the bundled CC0 player-base-v1.glb: base surfaces 0..5, high-poly eyes.
const EyeShader=preload("res://assets/player_eyes.gdshader")
static var eye_material: ShaderMaterial
static var eye_meshes: Dictionary={}
static var skin_meshes: Dictionary={}
static func eyes() -> ShaderMaterial:
	if eye_material==null:
		eye_material=ShaderMaterial.new();eye_material.shader=EyeShader
	return eye_material
static func eye_mesh(source: Mesh) -> ArrayMesh:
	var key:=source.get_rid().get_id()
	if eye_meshes.has(key): return eye_meshes[key]
	var result:=ArrayMesh.new()
	for surface in range(source.get_surface_count()):
		var arrays: Array=source.surface_get_arrays(surface)
		var points: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
		var uv:=PackedVector2Array();var uv2:=PackedVector2Array()
		for p in points:
			uv.append(Vector2(p.x-(0.0306 if p.x>=0 else -0.0306),p.y-1.6762))
			uv2.append(Vector2(p.z,0))
		arrays[Mesh.ARRAY_TEX_UV]=uv;arrays[Mesh.ARRAY_TEX_UV2]=uv2
		result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	eye_meshes[key]=result
	return result

static func skin_mesh(source: Mesh) -> ArrayMesh:
	var key:=source.get_rid().get_id()
	if skin_meshes.has(key): return skin_meshes[key]
	var result:=ArrayMesh.new()
	for surface in range(source.get_surface_count()):
		var arrays: Array=source.surface_get_arrays(surface)
		var uv:=PackedVector2Array()
		for p in arrays[Mesh.ARRAY_VERTEX]:
			uv.append(Vector2(atan2(p.x,p.z)/TAU+0.5,p.y*0.5))
		arrays[Mesh.ARRAY_TEX_UV]=uv
		result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	skin_meshes[key]=result
	return result

static func apply(instance: MeshInstance3D, skin: ShaderMaterial) -> void:
	if instance.mesh.get_surface_count()==6:
		instance.mesh=skin_mesh(instance.mesh)
		instance.material_override=null
		var lip_material: ShaderMaterial=skin.duplicate()
		lip_material.set_shader_parameter("lip_surface",true)
		for surface in range(6): instance.set_surface_override_material(surface,lip_material if surface==2 else skin)
	elif String(instance.name).ends_with("high-poly"):
		instance.mesh=eye_mesh(instance.mesh)
		instance.material_override=eyes()
	else: instance.material_override=skin
