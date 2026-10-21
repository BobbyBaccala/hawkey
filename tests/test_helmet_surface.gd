extends SceneTree
## Rendering contracts: smooth crown, outward normals, finite topology and mesh budget.
const Gear=preload("res://scripts/gear_builder.gd")
var failures:=0
var checks:=0
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok:
		failures+=1;push_error(message)
func _initialize() -> void:
	var loop:=Gear.MeshBuilder.new()
	loop.add_tube(PackedVector3Array([Vector3(0,0,0),Vector3(0,0.03,0),Vector3(0,0.03,0.03),Vector3(0,0,0.03),Vector3(0,0,0)]),0.002,Color.WHITE,8)
	var spread:=0.0;var raw_normals:=true
	for vertex in loop.vertices: spread=maxf(spread,absf(vertex.x))
	for normal in loop.normals: raw_normals=raw_normals and normal.length_squared()>0.9
	check(spread>0.0019 and raw_normals,"Closed ear/buckle frames retain thickness and nonzero normals")
	var mesh:=Gear.skater_helmet()
	check(mesh==Gear.skater_helmet(),"Helmet shell is shared, not rebuilt for each bench player")
	var a:=mesh.surface_get_arrays(0)
	var points: PackedVector3Array=a[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array=a[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array=a[Mesh.ARRAY_INDEX]
	check(points.size()<5000 and indices.size()/3<=9500,"Helmet stays within 5k vertices / 9.5k triangles")
	var finite:=true;var unit:=true;var valid:=true
	for i in range(points.size()):
		finite=finite and points[i].is_finite() and normals[i].is_finite()
		unit=unit and absf(normals[i].length()-1.0)<0.001
	for index in indices: valid=valid and index>=0 and index<points.size()
	check(finite,"All shell vertices/normals finite")
	check(unit,"All shell normals unit length")
	check(valid,"Triangle indices in range")
	# Side-to-side reflection continuity across all cardinal seams. Away from
	# intentional vent boundaries, a 0.1-degree step must not kink a highlight.
	var max_seam:=0.0
	for angle in [0.0,PI/2,PI,3*PI/2]:
		for phi in [0.15,0.35,0.85,1.1,1.4]:
			var left:=Gear.helmet_normal(angle-0.001,phi)
			var right:=Gear.helmet_normal(angle+0.001,phi)
			max_seam=maxf(max_seam,rad_to_deg(left.angle_to(right)))
			check(left.dot(Gear.helmet_point(angle,phi).normalized())>0.2,"Outer shell normal points outwards")
	check(max_seam<1.0,"Cardinal highlight seams under one degree (%.4f)"%max_seam)
	for angle in range(0,360,15):
		check(Gear.helmet_normal(deg_to_rad(angle),0.008).dot(Vector3.UP)>0.999,"Crown has no pinched pole")
	# Each intended vent must be an opening, not just a dark colour/dented skin.
	for vent in Gear.HELMET_VENTS:
		var angle: float=vent[0];var phi: float=vent[1]
		var surface:=Gear.helmet_point(angle,phi)
		var normal:=Gear.helmet_normal(angle,phi)
		var origin:=surface+normal*0.02
		var blocked:=false
		for t in range(0,indices.size(),3):
			var hit=Geometry3D.ray_intersects_triangle(origin,-normal,points[indices[t]],points[indices[t+1]],points[indices[t+2]])
			if hit!=null and origin.distance_to(hit)<0.024:
				blocked=true;break
		var crown:=Gear.helmet_crown_panel().surface_get_arrays(0)
		var cv: PackedVector3Array=crown[Mesh.ARRAY_VERTEX]
		var ci: PackedInt32Array=crown[Mesh.ARRAY_INDEX]
		for t in range(0,ci.size(),3):
			var hit=Geometry3D.ray_intersects_triangle(origin,-normal,cv[ci[t]],cv[ci[t+1]],cv[ci[t+2]])
			if hit!=null and origin.distance_to(hit)<0.024: blocked=true;break
		check(not blocked,"Vent opens through both the shell and crown panel")
	var parts: Array=[Gear.helmet_ear_guards(),Gear.helmet_hardware(),Gear.helmet_crown_panel(),Gear.helmet_fittings()]
	check(parts==[Gear.helmet_ear_guards(),Gear.helmet_hardware(),Gear.helmet_crown_panel(),Gear.helmet_fittings()],"New helmet parts are shared across bench/on-ice players")
	parts.append_array([Gear.chinstrap(),Gear.visor()])
	var total_vertices:=points.size();var total_triangles:=indices.size()/3
	for part: Mesh in parts:
		var arrays:=part.surface_get_arrays(0)
		var vp: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
		var vn: PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
		var vi: PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
		var good:=true
		for i in range(vp.size()):
			good=good and vp[i].is_finite() and vn[i].is_finite() and absf(vn[i].length()-1)<0.001
		check(good,"Ear/crown/retention/liner geometry has finite unit normals")
		total_vertices+=vp.size();total_triangles+=vi.size()/3
	check(total_vertices<8500 and total_triangles<17000,"Complete helmet remains within 8.5k vertices /17k triangles")
	print("Complete helmet: %d vertices; %d triangles"%[total_vertices,total_triangles])
	print("Helmet surface: %d checks; %d failures; %d vertices; %d triangles; max seam %.4f degrees"%[checks,failures,points.size(),indices.size()/3,max_seam])
	quit(failures)
