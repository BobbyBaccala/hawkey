extends SceneTree
const Visual=preload("res://scripts/skater_visual.gd")
var checks:=0
var failures:=0
func check(ok:bool,why:String)->void:
	checks+=1
	if not ok:failures+=1;push_error(why)
func _initialize()->void:call_deferred("run")
func run()->void:
	var v:=Visual.new();root.add_child(v)
	await process_frame
	# Default model faces world -Z; moving +Z must become a backward C-cut.
	for i in range(120):v.animate_motion(Vector3(0,0,5),1.0/120)
	check(v.backward_weight>0.99 and v.lateral_weight<0.001,"Backward travel selects C-cuts without turning the torso away")
	var backwards:Array=[]
	var worst_y:=INF
	var max_pitch:=0.0
	for f in range(120):
		v.animate_motion(Vector3(0,0,5),1.0/120)
		for i in range(2):
			worst_y=minf(worst_y,v.feet[i].y)
			max_pitch=maxf(max_pitch,absf(v.skates[i].rotation.x))
			check(v.feet[i].is_finite() and v.knees[i].is_finite(),"C-cut IK remains finite")
		backwards.append(v.feet[0].z)
	check(backwards.max()-backwards.min()>0.10,"Backward push moves along its own fore/aft path")
	check(worst_y>=0.114 and max_pitch<0.01,"C-cuts stay low without forward toe flick")
	for i in range(120):v.animate_motion(Vector3(5,0,0),1.0/120)
	check(v.lateral_weight>0.99 and v.backward_weight<0.001,"Lateral travel selects edge steps")
	var side_seen:={}
	for dir in [-1.0,1.0]:
		for f in range(240):
			v.animate_motion(Vector3(dir*5,0,0),1.0/120)
			if f>120:
				check(v.feet[0].x>0.08 and v.feet[1].x< -0.08,"Lateral gather never crosses the feet")
				check(v.feet[0].y>=0.114 and v.feet[1].y>=0.114,"Lateral edge steps stay above the ice")
		side_seen[dir]=v.lateral_side
	check(absf(side_seen[-1.0]-1)<0.001 and absf(side_seen[1.0]+1)<0.001,"Lateral lead changes with travel relative to the rig")
	for f in range(240):v.animate_motion(Vector3.FORWARD*5,1.0/120)
	check(v.backward_weight<0.001 and v.lateral_weight<0.001,"Forward skating retains original stride")
	for f in range(120):v.animate_motion(Vector3.BACK*5,1.0/120)
	for f in range(240):v.animate_motion(Vector3.ZERO,1.0/120,0,false)
	check(v.backward_weight<0.001 and v.lateral_weight<0.001 and v.push_blend<0.001,"Stopping settles directional blends and leg drive")
	# Reversing a lateral step must blend its leading side, not snap 30cm.
	for f in range(180):v.animate_motion(Vector3.RIGHT*5,1.0/120)
	var history:Array=[]
	var worst_jump:=0.0
	for f in range(240):
		v.animate_motion(Vector3.LEFT*5,1.0/120)
		history.append(v.feet[0])
		if history.size()>2:
			var n:=history.size()
			worst_jump=maxf(worst_jump,(history[n-1]-2*history[n-2]+history[n-3]).length())
	check(worst_jump<0.006,"Lateral reversal has no foot-position pop (second difference %.4fm)"%worst_jump)
	# An identical physical direction must classify identically after rotating
	# the actor; the camera never participates in this calculation.
	v.rotation.y=PI*0.5
	for f in range(180):v.animate_motion(Vector3.RIGHT*5,1.0/120)
	check(v.backward_weight>0.99,"Direction is relative to body, not camera or rink axis")
	# A teleport has no stride implication and must not appear as a turn step.
	v.position=Vector3(100,0,100);v.rotation.y+=PI
	v.animate(0,1.0/120,0,false)
	check(v.angular_speed==0,"Faceoff heading resets are not animated as high-rate pivots")
	v.queue_free();await process_frame
	# Goalie pivots alternate small unweighting steps; no independent pad bends.
	var g:=Visual.new();g.goalie=true;root.add_child(g);await process_frame
	var height_min:=[INF,INF];var height_max:=[0.0,0.0]
	for f in range(120):
		g.rotation.y+=2.0/120
		g.animate_motion(Vector3.ZERO,1.0/120,0,false)
		for i in range(2):
			height_min[i]=minf(height_min[i],g.feet[i].y)
			height_max[i]=maxf(height_max[i],g.feet[i].y)
			check(absf(g.feet[i].x)>0.24,"Turning goalie retains a wide stance")
	check(g.pivot_weight>0.5 and height_max[0]-height_min[0]>0.005 and height_max[1]-height_min[1]>0.005,"Turning goalie unweights both skates in alternating steps")
	g.butterfly=1
	for f in range(120):
		g.rotation.y+=2.0/120;g.animate_motion(Vector3.ZERO,1.0/120,0,false)
	check(g.pivot_weight<0.001,"Butterfly does not use standing pivot steps")
	print("Directional skating: ",checks," checks; ",failures," failures")
	quit(failures)
