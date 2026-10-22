extends SceneTree
## Verify shaft channels, explicit palm roles and unwarped gauntlet dimensions.
const Skills=preload("res://scripts/puck_skills.gd")
var checks:=0
var failures:=0
var min_parallel:=1.0
var min_mouth_axis:=1.0
var max_mouth_error:=0.0
func check(ok:bool,why:String)->void:
	checks+=1
	if not ok:failures+=1;push_error(why)
func _initialize()->void:call_deferred("run")
func inspect(v)->void:
	var top:Vector3=v.stick_grip();var shaft:Vector3=(v.stick_heel(top)-top).normalized()
	for i in range(2):
		var fist:Node3D=v.skater_gloves[i]
		var parallel:=absf(fist.basis.x.dot(shaft));min_parallel=minf(min_parallel,parallel)
		check(parallel>0.9999,"Actual closed-fist channel is parallel to shaft")
		var center:Vector3=fist.transform*v.GLOVE_HOLE
		for along in [-0.035,0.0,0.035]:
			var local:Vector3=fist.transform.affine_inverse()*(center+shaft*along)
			check(Vector2(local.y-v.GLOVE_HOLE.y,local.z-v.GLOVE_HOLE.z).length()<0.0001,"Shaft stays in finger tunnel across the whole fist")
		var cuff:MeshInstance3D=v.skater_glove_cuffs[i]
		var verts:PackedVector3Array=cuff.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var xf:Transform3D=fist.transform*cuff.transform
		var mouth:=Vector3.ZERO
		for k in range(28):mouth+=xf*verts[3*28+k]
		mouth/=28
		var forearm:Vector3=(v.posed_elbows[i]-v.posed_wrists[i]).normalized()
		var normal:Vector3=((xf*verts[91]-xf*verts[84]).cross(xf*verts[98]-xf*verts[84])).normalized()
		var axis:=absf(normal.dot(forearm));min_mouth_axis=minf(min_mouth_axis,axis)
		var error_:float=mouth.distance_to(v.posed_wrists[i]+forearm*0.080)
		max_mouth_error=maxf(max_mouth_error,error_)
		check(axis>0.998,"Rigid cuff mouth follows forearm")
		check(error_<0.001,"Cuff mouth stays around wrist without stretching")
		check((verts[84]-verts[98]).length()>0.135 and (verts[84]-verts[98]).length()<0.137,"Rigid cuff width is always 136 mm")
		check(absf((verts[0]-verts[84]).length()-sqrt(0.105*0.105+0.019*0.019))<0.001,"Cuff length stays rigid through animation")
		var palm:Vector3=-fist.basis.z
		var desired:=Vector3.DOWN if i==v.top_hand_index() else Vector3.UP
		var projected:Vector3=(desired-shaft*shaft.dot(desired)).normalized()
		check(palm.dot(projected)>0.999,"Top palm DOWN, lower palm UP, projected perpendicular to shaft")

func run()->void:
	var v=load("res://scripts/skater_visual.gd").new();root.add_child(v);await process_frame
	for hand in ["R","L"]:
		v.set_shoots(hand)
		for raw in [Vector2.ZERO,Vector2.LEFT,Vector2.RIGHT,Vector2.DOWN,Vector2.UP]:
			v.desired_stick=raw
			for f in range(60):v.animate(4,1.0/120,0,true)
			inspect(v)
		for kind in ["cut","toe_drag","sweep"]:
			var skill:=Skills.new();skill.request(kind,v.shot_side())
			for f in range(120):
				skill.advance(1.0/120,true);v.desired_stick=skill.stick(Vector2.ZERO,4,true);v.skill_lean=skill.lean();v.animate(4,1.0/120,0,true)
				if f%6==0:inspect(v)
		v.desired_stick=Vector2.ZERO;v.skill_lean=0
		for kind in ["pass","shot","slap"]:
			v.play_release(kind,Vector3.FORWARD)
			for f in range(120):
				v.animate(4,1.0/120,0,true)
				if f%6==0:inspect(v)
	print("Shaft grip: ",checks," checks; ",failures," failures; parallel ",min_parallel," actual mouth axis ",min_mouth_axis," mouth offset ",max_mouth_error)
	quit(failures)
