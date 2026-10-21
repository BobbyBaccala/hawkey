extends SceneTree
const V=preload("res://scripts/skater_visual.gd")
const G=preload("res://scripts/gear_builder.gd")
var checks:=0
var failures:=0
var measurements:={}
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok: failures+=1;push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var mitt:=G.catcher(1,Color.RED,Color.BLUE)
	var a:=mitt.surface_get_arrays(0)
	var points:=PackedVector2Array();var bounds:=AABB(a[Mesh.ARRAY_VERTEX][0],Vector3.ZERO)
	for point in a[Mesh.ARRAY_VERTEX]: points.append(Vector2(point.x,point.y));bounds=bounds.expand(point)
	var hull:=Geometry2D.convex_hull(points);var perimeter:=0.0
	for i in range(hull.size()-1): perimeter+=hull[i].distance_to(hull[i+1])
	check(bounds.size.x<0.34 and bounds.size.y<0.37,"Complete glove including cuff is adult sized, not an oversized double board")
	check(perimeter<=1.143,"Projected glove silhouette stays under the 45-inch sanity ceiling (not a 3D certification)")
	var outline:=G.catcher_pocket_outline();var web:=Rect2(outline[0]*Vector2(0.83,0.78),Vector2.ZERO)
	for point in outline: web=web.expand(point*Vector2(0.83,0.78))
	check(web.size.x<0.18 and web.size.y<0.12,"Laced catching web is a compact part of the mitt")
	measurements={"glove_base_width_m":bounds.size.x,"glove_base_height_m":bounds.size.y,"projected_convex_perimeter_m":perimeter,"web_width_m":web.size.x,"web_height_m":web.size.y,"pad_length_m":G.PAD_LENGTH,"pad_width_m":G.PAD_WIDTH}
	var v:=V.new();v.goalie=true;root.add_child(v);await process_frame
	for i in range(2): check(v.pads[i].get_child_count()==1 and v.pads[i].get_child(0) is MeshInstance3D,"Pad is a single shell without detached knee/thigh nodes")
	for command in [0.0,0.25,0.5,0.75,1.0]:
		v.butterfly=command;v.animate(0,1.0/60,0,false)
		for i in range(2):
			check(v.pads[i].get_child(0).transform==Transform3D.IDENTITY,"Pad top shares shell transform throughout drop")
			check(is_equal_approx(v.pad_box()[1].y,G.PAD_LENGTH),"Contact coverage follows the entire visible pad, including thigh rise")
		var heel: Vector3=v.stick_blade.transform*Vector3(-v.stick_blade_length*0.5,0,0)
		var paddle_bottom: Vector3=v.goalie_paddle.transform*Vector3(0,-0.5,0)
		var shaft_bottom: Vector3=v.stick_shaft.transform*Vector3(0,-0.5,0)
		check(heel.distance_to(paddle_bottom)<0.0001 and heel.distance_to(shaft_bottom)<0.0001,"Blade, paddle and shaft share an exact heel anchor")
		check(v.goalie_heel.mesh!=null and v.goalie_heel.mesh.get_aabb().has_point(Vector3.ZERO),"Solid curved heel fills the visible blade/paddle junction")
	for save in ["butterfly","pad_left","pad_right"]:
		for frame in range(90):
			v.butterfly=move_toward(v.butterfly,1.0,0.1)
			v.set_save(save,Vector2(0.95 if save=="pad_left" else -0.95,0.1),1.0/60)
			v.animate(0,1.0/60,0,false)
		for i in range(2):
			var inv: Transform3D=v.pads[i].transform.affine_inverse()
			for foot_point in [Vector3(0,0.03,0.20),Vector3(-0.035,0.04,0.17),Vector3(0.035,0.04,0.17),Vector3(0,0.08,0.03)]:
				var point: Vector3=inv*(v.skates[i].transform*foot_point)
				check(absf(point.x)<G.PAD_WIDTH*0.5 and absf(point.y)<G.PAD_LENGTH*0.5 and point.z<G.FACE_Z,"Butterfly pad occludes the skate boot/toe from shooter view: "+save+" "+str(foot_point)+" -> "+str(point))
			check(absf(v.pads[i].basis.z.y)<0.01,"Pad face stays vertical and long inner edge seals the ice")
	# Reaching blocker cannot reopen the visible stick joint.
	for frame in range(60): v.butterfly=move_toward(v.butterfly,0,0.1);v.set_save("blocker",Vector2(-0.7,1.1),1.0/60);v.animate(0,1.0/60,0,false)
	var heel: Vector3=v.stick_blade.transform*Vector3(-v.stick_blade_length*0.5,0,0)
	check(heel.distance_to(v.goalie_paddle.transform*Vector3(0,-0.5,0))<0.0001,"Blocker reach retains continuous heel joint")
	v.queue_free();await process_frame
	DirAccess.make_dir_recursive_absolute("res://build")
	FileAccess.open("res://build/goalie-proportions.json",FileAccess.WRITE).store_string(JSON.stringify(measurements,"\t"))
	print("Goalie proportions: %d checks; %d failures"%[checks,failures]);quit(failures)
