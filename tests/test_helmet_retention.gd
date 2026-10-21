extends SceneTree
## Flat, finite retention webbing and stable head attachment across animation.
const Gear=preload("res://scripts/gear_builder.gd")
const Visual=preload("res://scripts/skater_visual.gd")
var checks:=0
var failures:=0
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok: failures+=1;push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var mesh:=Gear.chinstrap()
	var a:=mesh.surface_get_arrays(0)
	var points: PackedVector3Array=a[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array=a[Mesh.ARRAY_NORMAL]
	check(mesh==Gear.chinstrap(),"Retention mesh shared by all players")
	check(points.size()<1200,"Retention stays below 1200 vertices")
	var finite:=true
	for i in range(points.size()): finite=finite and points[i].is_finite() and normals[i].is_finite() and absf(normals[i].length()-1)<0.001
	check(finite,"Retention geometry and unit normals finite")
	var path:=Gear.chinstrap_path()
	check(path[0].distance_to(Vector3(-0.101,-0.078,0.026))<0.0001,"Left endpoint meets snap")
	check(path[-1].distance_to(Vector3(0.101,-0.078,0.026))<0.0001,"Right endpoint meets snap")
	var mirrored:=true
	for i in range(path.size()): mirrored=mirrored and Vector3(-path[i].x,path[i].y,path[i].z).distance_to(path[-i-1])<0.0001
	check(mirrored,"Retention fits both sides symmetrically")
	check(Gear.CHINSTRAP_WIDTH/Gear.CHINSTRAP_THICKNESS>6,"Flat webbing rather than a round cord")
	var v:=Visual.new();root.add_child(v);await process_frame
	var strap: MeshInstance3D=v.helmet.get_node("Chinstrap")
	check(strap.mesh==mesh,"Production helmet uses the retention mesh")
	check(strap.material_override.get_shader_parameter("roughness")>0.8,"Retention uses matte nylon finish")
	var visor: MeshInstance3D=v.helmet.get_node("Visor")
	var local:=visor.transform
	for i in range(90):
		v.animate(6.0,1.0/120.0,0,true)
		check(strap.transform==Transform3D.IDENTITY,"Webbing stays attached to posed helmet")
	check(visor.transform==local,"Approved visor attachment unchanged by retention animation")
	print("Helmet retention: %d checks; %d failures; %d vertices"%[checks,failures,points.size()])
	v.queue_free();await process_frame;quit(failures)
