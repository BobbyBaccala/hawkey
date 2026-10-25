extends SceneTree
var failures:=0
func check(ok: bool, message: String) -> void:
	if not ok:
		push_error(message)
		failures+=1
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var builder=load("res://scripts/jersey_surface.gd")
	for goalie in [false,true]:
		var mesh:ArrayMesh=builder.torso(goalie)
		var arrays:=mesh.surface_get_arrays(0)
		var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
		var normals:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
		check(vertices.size()==normals.size(),"Every sweater vertex needs a normal")
		for i in range(vertices.size()):
			check(vertices[i].is_finite() and normals[i].is_finite(),"Finite garment geometry")
			check(absf(normals[i].length()-1.0)<.001,"Unit surface normals")
		var actor=load("res://scripts/skater_visual.gd").new()
		actor.goalie=goalie
		root.add_child(actor)
		await process_frame
		for butterfly in [0.0,1.0]:
			actor.butterfly=butterfly
			actor.animate(0,.1)
			var size:Vector3=actor.neck_guard.get_aabb().size*actor.neck_guard.basis.get_scale()
			check(size.x<.20 and size.y<.20 and size.z<.20,"Neck guard must retain human scale after posing")
			check(actor.shirt.get_node_or_null("BoundCollar")!=null,"Sweater has a finished collar")
		check(actor.helmet.get_child_count()>0,"Helmet/mask remains attached")
		actor.queue_free()
		await process_frame
	print("Jersey surface failures: ",failures)
	quit(failures)
