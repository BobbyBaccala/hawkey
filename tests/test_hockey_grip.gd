extends SceneTree
## Direction matters: a fist can touch the shaft while gripping it backwards.
const Skills=preload("res://scripts/puck_skills.gd")
var failures:=0
var checks:=0
var min_thumb:=1.0
var min_cuff:=1.0
var max_gap:=0.0
var max_reach:=0.0
var max_shaft:=0.0
func check(ok:bool,why:String)->void:
	checks+=1
	if not ok:failures+=1;push_error(why)
func _initialize()->void:call_deferred("run")
func inspect(v)->void:
	var top:Vector3=v.stick_grip();var down:Vector3=(v.stick_heel(top)-top).normalized()
	max_shaft=maxf(max_shaft,top.distance_to(v.stick_heel(top)))
	for i in range(2):
		var glove:Node3D=v.skater_gloves[i]
		# Mesh thumb is +X on left/top, -X on right/bottom. Opposed grips.
		var thumb:Vector3=glove.basis.x*(1.0 if i==0 else -1.0)
		var expected:Vector3=down if i==0 else -down
		min_thumb=minf(min_thumb,thumb.dot(expected))
		min_cuff=minf(min_cuff,glove.basis.y.dot((v.posed_elbows[i]-v.posed_wrists[i]).normalized()))
		max_gap=maxf(max_gap,(glove.transform*v.GLOVE_HOLE-top).cross(down).length())
		max_reach=maxf(max_reach,v.shoulder_of(i).distance_to(v.posed_wrists[i]))
		check(thumb.dot(expected)>0.45,"Top thumb toward blade; lower thumb toward knob, never reversed")
func run()->void:
	var v=load("res://scripts/skater_visual.gd").new();root.add_child(v);await process_frame
	# Supplied MPP.jpg: top hand ahead of hip, elbow bent, forearm down.
	# Compare anatomical relationships in mirror for this right-shot rig.
	for f in range(120):v.animate(3,1.0/120,0,true)
	var shoulder:Vector3=v.shoulder_of(0)
	var grip:Vector3=v.stick_grip()
	var elbow:Vector3=v.posed_elbows[0]
	var wrist:Vector3=v.posed_wrists[0]
	check(shoulder.y-grip.y>0.24 and grip.x<0 and v.blade_position.x < -0.65 and absf(v.blade_position.x)>v.blade_position.z,"Strong-side stance keeps the shaft lateral rather than centered in front")
	check(elbow.y-wrist.y>0.015,"Reference top forearm angles down toward fist")
	var bend:float=rad_to_deg((shoulder-elbow).angle_to(wrist-elbow))
	check(bend>60 and bend<120,"Top arm retains natural bent-elbow grip")
	for input_ in [Vector2.ZERO,Vector2.LEFT,Vector2.RIGHT,Vector2.DOWN,Vector2.UP]:
		v.desired_stick=input_
		for f in range(100):v.animate(4,1.0/120,0,true);inspect(v)
	for kind in ["cut","toe_drag","sweep"]:
		for side in [-1.0,1.0]:
			var skills:=Skills.new();skills.request(kind,side)
			for f in range(120):
				skills.advance(1.0/120,true);v.desired_stick=skills.stick(Vector2.ZERO,4,true);v.skill_lean=skills.lean()
				v.animate(4,1.0/120,0,true);inspect(v)
	v.desired_stick=Vector2.ZERO;v.skill_lean=0
	for kind in ["pass","shot","slap"]:
		v.play_release(kind,Vector3.FORWARD)
		for f in range(120):v.animate(4,1.0/120,0,true);inspect(v)
	check(min_cuff>0.9,"Cuffs still follow forearms")
	check(max_gap<0.025,"Both closed fists remain seated on shaft")
	check(max_reach<0.62,"Wider moves stay within arm reach")
	var span:float=v.stick_home(Vector2.LEFT).distance_to(v.stick_home(Vector2.RIGHT))
	var drag:float=v.stick_home(Vector2.ZERO).distance_to(v.stick_home(Vector2.DOWN))
	check(span>1.5 and drag>0.4,"Exaggerated handling has wider cross-body reach and deeper drag")
	print("Hockey grip: ",checks," checks; ",failures," failures; thumb dot ",min_thumb," cuff dot ",min_cuff," shaft gap ",max_gap," arm reach ",max_reach," max shaft ",max_shaft," handling span ",span," drag ",drag)
	quit(failures)
