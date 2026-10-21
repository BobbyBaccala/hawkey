extends SceneTree
const Visual=preload("res://scripts/skater_visual.gd")
var checks:=0
var failures:=0
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok: failures+=1;push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var v:=Visual.new();root.add_child(v);await process_frame
	var profile=preload("res://scripts/jersey_profile.gd")
	check(v.jersey.material_override.get_shader_parameter("collar_profile")==profile.SHADER_PROFILE,"Mesh and shader share the same neckline")
	check(v.jersey.material_override.get_shader_parameter("collar_band_width")==profile.BAND_WIDTH,"Trim band uses shared physical width")
	check(v.jersey_neck(PI/2)>1.51,"Front neckline covers the upper chest")
	check(v.jersey_neck(-PI/2)-v.jersey_neck(PI/2)<0.05,"Collar stays shallow")
	check(v.neck_guard.material_override.get_shader_parameter("roughness")>0.85,"Neck guard uses matte fabric")
	check(v.neck_guard.material_override.get_shader_parameter("specular")<0.3,"Neck fabric has no plastic glare")
	for i in range(60):
		v.animate(6.0,1.0/120.0,0,true)
		var ends: Array=v.neck_guard.get_meta("pose")
		check(ends[0].distance_to(ends[1])<0.11,"Neck guard follows torso/head without a tall funnel")
	var arrays:=v.neck_guard.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
	var valid:=true
	for i in range(vertices.size()): valid=valid and vertices[i].is_finite() and normals[i].is_finite()
	check(valid,"Posed collar/neck geometry finite")
	check(v.neck_guard.mesh.get_aabb().size.x<0.16,"Guard fits the neck rather than the shoulders")
	print("Jersey collar: %d checks; %d failures"%[checks,failures])
	v.queue_free();await process_frame;quit(failures)
