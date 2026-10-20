extends Node3D
## CC0 skinned human foundation, original kit and procedural two-bone hockey posing.
const Human = preload("res://assets/player-base-v1.glb")
const Uniform = preload("res://assets/uniform.gdshader")
const Arena = preload("res://scripts/arena.gd")
const Gear = preload("res://scripts/gear_builder.gd")
var kit := Color("#116c9e")
## Secondary team colour for pad, glove and mask graphics; derived from kit when unset.
var accent := Color(0,0,0,0)
var number := "17"
var goalie := false
var referee := false
var nameplate: Label3D
var phase := 0.0
var butterfly := 0.0
var shot_follow := 0.0
var shot_charge := 0.0
var desired_stick := Vector2.ZERO
var stick_intent := Vector2.ZERO
var goalie_save_height := 0.0
var blade_position := Vector3(-0.20,0.035,0.95)
var stick_shaft: MeshInstance3D
var stick_blade: MeshInstance3D
var grip_tape: MeshInstance3D
var goalie_paddle: MeshInstance3D
var knees: Array[Vector3] = [Vector3.ZERO,Vector3.ZERO]
var pad_size := Vector3(0.28,0.73,0.14)
var stick_blade_length := 0.28
var torso_pose := Transform3D.IDENTITY
var number_label: Label3D
var goalie_gloves: Array[Node3D] = []
var skater_gloves: Array[Node3D] = []
var cloth_sleeves: Array[MeshInstance3D] = []
var rig: Node3D
var skeleton: Skeleton3D
var rest: Dictionary = {}
var feet: Array[Vector3] = [Vector3.ZERO,Vector3.ZERO]
var skates: Array[Node3D] = []
var helmet: Node3D
var shirt: Node3D
var sticks: Node3D
var pads: Array[Node3D] = []
var thigh_rises: Array[Node3D] = []
var pant_legs: Array[MeshInstance3D] = []
var socks: Array[MeshInstance3D] = []
var push_blend := 0.0
var posed_head := Vector3.ZERO
var bend := Basis.IDENTITY

func material(color: Color, roughness: float = 0.7) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m

func ellipsoid(parent: Node3D, size: Vector3, position_: Vector3, color: Color) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1
	sphere.radial_segments = 24
	sphere.rings = 12
	instance.mesh = sphere
	instance.material_override = material(color)
	instance.scale = size
	instance.position = position_
	parent.add_child(instance)
	return instance

func block(parent: Node3D, size: Vector3, position_: Vector3, color: Color) -> MeshInstance3D:
	var helper := Arena.new()
	var result := helper.block(parent,size,position_,color)
	helper.free()
	return result

func segment(parent: Node3D, a: Vector3, b: Vector3, radius: float, color: Color) -> void:
	var helper := Arena.new()
	helper.tube(parent,a,b,radius,color)
	helper.free()

func _ready() -> void:
	if accent.a == 0: accent = kit.darkened(0.45)
	rig = Node3D.new()
	rig.rotation.y = PI # Imported human faces +Z; game-facing direction is -Z.
	add_child(rig)
	var human := Human.instantiate()
	rig.add_child(human)
	skeleton = human.find_child("Skeleton3D",true,false)
	for i in range(skeleton.get_bone_count()):
		rest[skeleton.get_bone_name(i)] = skeleton.get_bone_global_rest(i)
	var uniform := ShaderMaterial.new()
	uniform.shader = Uniform
	uniform.set_shader_parameter("team_color",kit)
	uniform.set_shader_parameter("hide_pants",not referee)
	uniform.set_shader_parameter("hide_socks",not referee and not goalie)
	for child in skeleton.get_children():
		if child is MeshInstance3D:
			child.material_override = uniform
	helmet = Node3D.new()
	rig.add_child(helmet)
	build_helmet()
	shirt = Node3D.new()
	rig.add_child(shirt)
	build_jersey()
	sticks = Node3D.new()
	rig.add_child(sticks)
	stick_shaft=MeshInstance3D.new()
	var shaft_mesh:=BoxMesh.new()
	shaft_mesh.size=Vector3(0.018,1,0.012)
	stick_shaft.mesh=shaft_mesh
	stick_shaft.material_override=material(Color("#171f28"),0.35)
	sticks.add_child(stick_shaft)
	stick_blade_length=0.39 if goalie else 0.28
	stick_blade=build_blade()
	sticks.add_child(stick_blade)
	if goalie:
		goalie_paddle=block(sticks,Vector3(0.088,1,0.026),Vector3.ZERO,Color("#e3e7e9"))
	grip_tape=block(sticks,Vector3(0.035,0.11,0.035),Vector3.ZERO,Color("#cad2d7"))
	for side in [1.0,-1.0]:
		var sleeve:=MeshInstance3D.new()
		sleeve.mesh=ArrayMesh.new()
		sleeve.material_override=material(kit,0.87)
		rig.add_child(sleeve)
		cloth_sleeves.append(sleeve)
		if not referee:
			var pants := add_mesh(rig,Gear.pants_leg(side,kit,Color("#151c24")))
			pant_legs.append(pants)
			if not goalie:
				socks.append(add_mesh(rig,Gear.sock(kit,Color("#e4e8ea"))))
		var skate := Node3D.new()
		rig.add_child(skate)
		build_skate(skate)
		skates.append(skate)
		if goalie:
			var pad := Node3D.new()
			rig.add_child(pad)
			build_pad(pad,side)
			pads.append(pad)
			# Catcher on the left (+x) hand, blocker on the stick hand.
			var glove := Node3D.new()
			rig.add_child(glove)
			add_mesh(glove,Gear.catcher(side,kit,accent) if side>0 else Gear.blocker(side,kit,accent))
			goalie_gloves.append(glove)
		else:
			var glove:=Node3D.new()
			rig.add_child(glove)
			build_player_glove(glove)
			skater_gloves.append(glove)
	blade_position=Vector3(-0.02,0.042,0.60) if goalie else Vector3(-0.20,0.029,0.83)
	if referee: sticks.visible=false
	pose(0,0)

func add_mesh(parent: Node3D, mesh: Mesh) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	parent.add_child(instance)
	return instance

func build_skate(parent: Node3D) -> void:
	add_mesh(parent,Gear.skate(goalie))

func build_pad(parent: Node3D, side: float) -> void:
	# Sculpted box-style pad: flat face, outer roll, knee/boot breaks, toe bridge.
	add_mesh(parent,Gear.goalie_pad(side,kit,accent,-1.0,Gear.PAD_BREAK))
	# Thigh rise hinges back along the thigh at the break above the knee.
	var hinge := Node3D.new()
	hinge.position = Vector3(0,Gear.PAD_BREAK,-0.04)
	parent.add_child(hinge)
	var upper := add_mesh(hinge,Gear.goalie_pad(side,kit,accent,Gear.PAD_BREAK,1.0))
	upper.position = Vector3(0,-Gear.PAD_BREAK,0.04)
	thigh_rises.append(hinge)

## Collision box over the part of the pad that faces the shooter: the whole
## pad when standing, the shin-to-knee section once the thigh rise folds back.
## Stretches a unit-length limb shell between two joints, facing forward.
func fit_limb(shell: MeshInstance3D, top: Vector3, bottom: Vector3, girth: float) -> void:
	var axis:=top-bottom
	var up:=axis.normalized()
	var forward:=(Vector3.BACK-up*up.dot(Vector3.BACK)).normalized()
	shell.transform=Transform3D(Basis(up.cross(forward)*girth,up*axis.length(),forward*girth),top)

func pad_box() -> Array:
	var length:float=lerpf(Gear.PAD_LENGTH,Gear.PAD_BREAK+Gear.PAD_LENGTH*0.5,butterfly)
	var center:float=lerpf(0.0,Gear.PAD_BREAK-length*0.5,butterfly)
	return [Transform3D(Basis(),Vector3(0,center,0)),Vector3(pad_size.x,length,pad_size.z)]

func build_blade() -> MeshInstance3D:
	var mesh:=ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var length_:float=stick_blade_length
	var height_:float=0.080 if goalie else 0.050
	var thickness:float=0.016 if goalie else 0.009
	for i in range(16):
		var a:=float(i)/16
		var b:=float(i+1)/16
		var p0:=blade_section(a,length_,height_,thickness)
		var p1:=blade_section(b,length_,height_,thickness)
		for side in range(4):
			var next_:=posmod(side+1,4)
			var normal:Vector3=(p1[side]-p0[side]).cross(p0[next_]-p0[side]).normalized()
			for v in [p0[side],p1[side],p1[next_],p0[side],p1[next_],p0[next_]]:
				mesh.surface_set_normal(normal)
				mesh.surface_add_vertex(v)
	for t in [0.0,1.0]:
		var points:=blade_section(t,length_,height_,thickness)
		for j in [0,1,2,0,2,3]:
			mesh.surface_set_normal(Vector3.RIGHT if t>0 else Vector3.LEFT)
			mesh.surface_add_vertex(points[j])
	mesh.surface_end()
	var instance:=MeshInstance3D.new()
	instance.mesh=mesh
	instance.material_override=material(Color("#18212a"),0.7)
	return instance

func blade_section(t: float, length_: float, height_: float, thickness: float) -> Array[Vector3]:
	var x:float=(t-0.5)*length_
	var curve:float=t*t*0.023
	var toe:float=smoothstep(0.82,1,t)*0.012
	var top:float=height_*(1.0-smoothstep(0.91,1,t)*0.22)
	return [Vector3(x,toe-height_*0.5,curve-thickness*0.5),Vector3(x,top-height_*0.5,curve-thickness*0.5),Vector3(x,top-height_*0.5,curve+thickness*0.5),Vector3(x,toe-height_*0.5,curve+thickness*0.5)]

func build_helmet() -> void:
	if goalie:
		var mask := add_mesh(helmet,Gear.goalie_mask(kit,accent))
		mask.position = Vector3(0,-0.035,0.01)
		return
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES,material(Color("#c6ced4") if goalie else Color("#132434"),0.27))
	for row in range(10):
		for column in range(32):
			var vertices: Array[Vector3] = []
			for ij in [Vector2(row,column),Vector2(row+1,column),Vector2(row+1,column+1),Vector2(row,column),Vector2(row+1,column+1),Vector2(row,column+1)]:
				var a: float = ij.x / 10 * PI * 0.59
				var b: float = ij.y / 32 * TAU
				var normal := Vector3(sin(a)*cos(b),cos(a),sin(a)*sin(b))
				mesh.surface_set_normal(normal)
				mesh.surface_add_vertex(Vector3(normal.x*0.115,normal.y*0.13,normal.z*0.135))
	mesh.surface_end()
	var shell := MeshInstance3D.new()
	shell.mesh = mesh
	helmet.add_child(shell)
	var visor := block(helmet,Vector3(0.19,0.065,0.018),Vector3(0,-0.018,0.128),Color("#91b9c7"))
	var glass := material(Color(0.55,0.75,0.82,0.25),0.15)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	visor.material_override = glass
	if goalie:
		visor.visible=false
		for x in [-0.08,0.0,0.08]:
			segment(helmet,Vector3(x,0.035,0.14),Vector3(x,-0.12,0.16),0.005,Color("#56646d"))
		for y in [0.02,-0.04,-0.10]:
			segment(helmet,Vector3(-0.10,y,0.15),Vector3(0.10,y,0.15),0.005,Color("#56646d"))
		ellipsoid(helmet,Vector3(0.14,0.075,0.06),Vector3(0,-0.12,0.13),Color("#c5cdd2"))
	for x in [-0.055,0.0,0.055]:
		block(helmet,Vector3(0.018,0.008,0.065),Vector3(x,0.123,-0.02),Color("#050d16"))
	segment(helmet,Vector3(-0.09,-0.02,0.03),Vector3(0,-0.13,0.1),0.009,Color("#adb9c4"))
	segment(helmet,Vector3(0.09,-0.02,0.03),Vector3(0,-0.13,0.1),0.009,Color("#adb9c4"))

func build_jersey() -> void:
	var mesh := ImmediateMesh.new()
	var sections := [Vector3(0.24,0.98,0.16),Vector3(0.22,1.10,0.155),Vector3(0.25,1.31,0.17),Vector3(0.27,1.44,0.14),Vector3(0.11,1.50,0.09)]
	if goalie:
		# Oversized sweater over a chest protector with shoulder floaters.
		sections = [Vector3(0.255,0.95,0.17),Vector3(0.25,1.10,0.185),Vector3(0.28,1.30,0.20),Vector3(0.30,1.44,0.17),Vector3(0.13,1.53,0.10)]
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for row in range(sections.size()-1):
		for column in range(32):
			for ij in [Vector2(row,column),Vector2(row+1,column),Vector2(row+1,column+1),Vector2(row,column),Vector2(row+1,column+1),Vector2(row,column+1)]:
				var section: Vector3 = sections[int(ij.x)]
				var a: float = ij.y / 32 * TAU
				var normal := Vector3(cos(a),0,sin(a))
				mesh.surface_set_normal(normal)
				mesh.surface_set_uv(Vector2(ij.y/32,section.y))
				mesh.surface_add_vertex(Vector3(section.x*cos(a),section.y,section.z*sin(a)-0.02))
	mesh.surface_end()
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	var shader := Shader.new()
	shader.code = "shader_type spatial; render_mode cull_disabled; uniform vec4 kit:source_color; void fragment(){float stripe=step(UV.y,1.075);float weave=sin(UV.x*700.0)*sin(UV.y*700.0)*0.003;ALBEDO=mix(kit.rgb,vec3(0.68),stripe)+weave;ROUGHNESS=0.86;SPECULAR=0.18;}"
	var m := ShaderMaterial.new()
	m.shader = shader
	m.set_shader_parameter("kit",kit)
	if referee:
		var ref_shader:=Shader.new()
		ref_shader.code="shader_type spatial; render_mode cull_disabled; void fragment(){float stripe=step(0.0,sin(UV.x*62.83));ALBEDO=mix(vec3(0.015),vec3(0.7),stripe);ROUGHNESS=0.8;}"
		m.shader=ref_shader
	instance.material_override = m
	shirt.add_child(instance)
	# Shoulder pads (or a goalie's shoulder floaters) shape the sweater.
	if not referee:
		var cap:=Vector3(0.18,0.12,0.20) if goalie else Vector3(0.16,0.10,0.18)
		for x in [-1.0,1.0]:
			var shoulder_cap:=ellipsoid(shirt,cap,Vector3(x*(0.20 if goalie else 0.185),1.425,-0.01),kit)
			shoulder_cap.material_override=material(kit,0.86)
	var jersey_number := Label3D.new()
	number_label = jersey_number
	jersey_number.text = number
	jersey_number.font_size = 64
	jersey_number.pixel_size = 0.004
	jersey_number.position = Vector3(0,1.31,-0.195)
	jersey_number.rotation.y = PI
	jersey_number.modulate = Color("#d0dbe2")
	jersey_number.outline_size = 2
	jersey_number.visible = not referee
	nameplate = Label3D.new()
	nameplate.text = ""
	nameplate.font_size = 48
	nameplate.pixel_size = 0.0018
	nameplate.outline_size = 1
	nameplate.position = Vector3(0,1.44,-0.17)
	nameplate.rotation.y = PI
	nameplate.modulate = Color("#d0dbe2")
	shirt.add_child(nameplate)
	shirt.add_child(jersey_number)

func override_pose(name: String, transform_: Transform3D) -> void:
	var bone := skeleton.find_bone(name)
	if bone >= 0:
		skeleton.set_bone_global_pose_override(bone,transform_,1.0,true)

func align_bone(name: String, end_name: String, start: Vector3, end_: Vector3) -> void:
	var original: Transform3D = rest[name]
	var original_end: Transform3D = rest[end_name]
	var old_direction := (original_end.origin-original.origin).normalized()
	var new_direction := (end_-start).normalized()
	var rotation := Basis(Quaternion(old_direction,new_direction))
	override_pose(name,Transform3D(rotation * original.basis,start))

func knee_position(hip: Vector3, ankle: Vector3, pole: Vector3, upper: float, lower: float) -> Vector3:
	var axis := ankle-hip
	var distance_ := clampf(axis.length(),0.1,upper+lower-0.005)
	axis = axis.normalized()
	var along := (upper*upper-lower*lower+distance_*distance_)/(2*distance_)
	var height := sqrt(maxf(0,upper*upper-along*along))
	var perpendicular := (pole-axis*pole.dot(axis)).normalized()
	return hip+axis*along+perpendicular*height

func pose(speed: float, turn: float) -> void:
	skeleton.clear_bones_global_pose_override()
	var root_rest: Transform3D = rest["root"]
	# Skating stance: hips about 0.80 m, knees near 100 degrees.
	var drop := Vector3(0,-0.17,0.0)
	if goalie:
		# Sit back: hips behind the heels so the shins angle ~25 degrees and the
		# pads stay upright; in the butterfly the hips come forward over the knees.
		drop = Vector3(0,lerpf(-0.33,-0.55,butterfly),lerpf(-0.24,-0.04,butterfly))
	var root_pose := root_rest
	root_pose.origin += drop
	override_pose("root",root_pose)
	bend = Basis(Vector3.RIGHT,lerpf(0.52,0.26,butterfly) if goalie else 0.50+minf(speed/40,0.18))
	var pivot := root_rest.origin
	var spine: Transform3D = rest["spine05"]
	var spine_pose := Transform3D(bend * spine.basis,pivot + drop + bend * (spine.origin-pivot))
	override_pose("spine05",spine_pose)
	shirt.transform = Transform3D(bend,pivot+drop-bend*pivot)
	torso_pose=Transform3D(bend,shirt.transform*Vector3(0,1.23,-0.02))
	var head: Transform3D = rest["head"]
	posed_head = pivot+drop+bend*(head.origin-pivot)
	var head_pose := head
	head_pose.origin = posed_head
	override_pose("head",head_pose)
	helmet.position = posed_head+Vector3(0,0.095,0.015)
	for i in range(2):
		var side := 1.0 if i==0 else -1.0
		var suffix := ".L" if i==0 else ".R"
		var cycle := fposmod(phase+float(i)*PI,TAU)/TAU
		var push := smoothstep(0,0.55,cycle) if cycle < 0.55 else 1-smoothstep(0.55,1,cycle)
		var lift := sin((cycle-0.55)/0.45*PI)*0.045 if cycle > 0.55 else 0.0
		var ankle := Vector3(side*(0.24+push*0.22*push_blend),0.115+lift*push_blend,0.06-push*0.30*push_blend)
		# Goalie ready stance: feet a little wider than the shoulders, knees in.
		if goalie: ankle = Vector3(side*lerpf(0.27,0.58,butterfly),0.115,lerpf(0.0,0.10,butterfly))
		feet[i] = ankle
		var hip: Vector3 = rest["upperleg01"+suffix].origin+drop
		var knee := knee_position(hip,ankle,Vector3(-side*0.12,0,1) if goalie else Vector3(0,0,1),0.44,0.45)
		# Pads meet edge to edge at the knees rather than crossing.
		if goalie: knee.x=side*maxf(side*knee.x,Gear.PAD_WIDTH*0.5+0.024)
		# Butterfly: knees together on the ice, shins flared out behind them.
		if goalie:
			knee=knee.lerp(Vector3(side*0.17,0.13,0.24),butterfly)
			# Shins flare as the knees drop, so the knees stay apart mid-drop.
			knee.x+=side*0.035*sin(PI*butterfly)
		knees[i]=knee
		align_bone("upperleg01"+suffix,"lowerleg01"+suffix,hip,knee)
		align_bone("lowerleg01"+suffix,"foot"+suffix,knee,ankle)
		if pant_legs.size()>i:
			# Goalie pants stop short of the pads; the legs meet but don't overlap.
			var fill:=1.06 if goalie else 0.96
			var reach:=lerpf(0.68,0.52,butterfly) if goalie else 0.94
			fit_limb(pant_legs[i],hip+Vector3(side*(0.03+butterfly*0.02),0.10,0),hip.lerp(knee,reach),fill)
		if socks.size()>i:
			# Sock and shin-guard knee cap overlap the bottom of the pants.
			fit_limb(socks[i],knee.lerp(hip,0.12),ankle+Vector3(0,0.12,0.01),1.0)
		var foot_pose: Transform3D = rest["foot"+suffix]
		foot_pose.origin = ankle
		foot_pose.basis = Basis(Vector3.UP,side*push*0.23*push_blend)*foot_pose.basis
		override_pose("foot"+suffix,foot_pose)
		skates[i].position = ankle+Vector3(0,-0.0525,0)
		# Butterfly: skates turn out flat so the toes clear the pad backs.
		skates[i].rotation.y = side*lerpf(0.12,1.45,smoothstep(0.0,0.4,butterfly)) if goalie else side*push*0.23*push_blend
		if goalie:
			# The pad rides the shin: +Y up the shin, face (+Z) toward the shooter.
			var shin:Vector3=(knee-ankle).normalized()
			var face:Vector3=(Vector3.BACK-shin*shin.dot(Vector3.BACK)).normalized()
			pads[i].basis=Basis(shin.cross(face),shin,face)
			# Ride a few centimetres up the shin so the skate toe cap shows below.
			pads[i].position=knee-shin*(Gear.PAD_KNEE-0.065)+face*0.09
			# The thigh rise follows the thigh: it leans out toward the hip as it
			# rises in the stance, and folds back along the thigh in the butterfly.
			var thigh_local:Vector3=pads[i].basis.inverse()*(hip-knee).normalized()
			var roll:float=clampf(atan2(-thigh_local.x,thigh_local.y),-0.6,0.6)
			var standing:=Quaternion(Basis(Vector3.BACK,-roll*0.6)*Basis(Vector3.RIGHT,-0.12))
			# Butterfly: the thigh rise folds flat along the thigh and its foam
			# compresses where the two meet behind the wall of pads.
			var folded:=Quaternion(Vector3.UP,thigh_local)
			# Compress early in the drop so the halves never cross mid-transition.
			var squash:=smoothstep(0.0,0.3,butterfly)
			thigh_rises[i].position=Vector3(0,Gear.PAD_BREAK-0.08*squash,-0.04+0.05*squash)
			thigh_rises[i].basis=Basis(standing.slerp(folded,smoothstep(0.0,0.6,butterfly))).scaled_local(Vector3(lerpf(1.0,0.42,squash),1,lerpf(1.0,0.7,squash)))
			# Pad lower edges seal against the ice in butterfly.
			var box:Array=pad_box()
			var size_:Vector3=box[1]
			var box_center:Vector3=pads[i].transform*box[0].origin
			var extent:float=absf(pads[i].basis.x.y)*size_.x/2+absf(pads[i].basis.y.y)*size_.y/2+absf(pads[i].basis.z.y)*size_.z/2
			pads[i].position.y+=maxf(0,extent+0.012-box_center.y)
		# Elbows and wrists stay on a two-hand stick posture, never running arm swings.
		var shoulder_original: Transform3D = rest["upperarm01"+suffix]
		var shoulder := pivot+drop+bend*(shoulder_original.origin-pivot)
		# Bottom hand rides the shaft, kept clear of the pants.
		var wrist := stick_grip().lerp(blade_position+Vector3(-stick_blade_length*0.48,0,0),0.26)+Vector3(0,0.02,0.05*maxf(0,stick_intent.y)) if i==0 else stick_grip()
		if referee: wrist=Vector3(side*0.32,0.96,0.03)
		if goalie:
			# Hands out in front of the body: catcher open to the shooter at the hip,
			# blocker on the stick at the top of the paddle.
			wrist=Vector3(0.38,0.81-butterfly*0.16+goalie_save_height,0.40) if i==0 else stick_grip()
			if i==0:
				goalie_gloves[i].position=wrist+Vector3(0.0,0.03,0.035)
				goalie_gloves[i].rotation=Vector3(-0.12,0.32,-0.12)
			else:
				goalie_gloves[i].position=wrist+Vector3(-0.085,0.06,0.04)
				goalie_gloves[i].rotation=Vector3(-0.10,-0.28,0.06)
		else:
			skater_gloves[i].position=wrist
			skater_gloves[i].basis=Basis(Quaternion(Vector3.UP,(stick_grip()-blade_position).normalized()))
		var pole := Vector3(side*0.6,-0.8,-0.1) if goalie else Vector3(side,0,-0.3)
		var elbow := knee_position(shoulder,wrist,pole,0.28,0.29)
		update_cloth_sleeve(cloth_sleeves[i],shoulder,elbow,wrist)
		align_bone("upperarm01"+suffix,"lowerarm01"+suffix,shoulder,elbow)
		align_bone("lowerarm01"+suffix,"wrist"+suffix,elbow,wrist)
		var wrist_pose: Transform3D = rest["wrist"+suffix]
		wrist_pose.origin = wrist
		override_pose("wrist"+suffix,wrist_pose)
	rig.rotation.z = clampf(turn,-0.13,0.13)
	update_stick()

func animate(speed: float, delta: float, turn: float = 0, pushing: bool = true, braking: bool = false) -> void:
	shot_follow = maxf(0,shot_follow-delta*3)
	stick_intent=stick_intent.lerp(desired_stick,1-exp(-14*delta))
	blade_position=Vector3(-0.02+butterfly*0.05,0.042,0.60-butterfly*0.04) if goalie else Vector3(-(0.20+stick_intent.x*0.55),0.029,0.83-stick_intent.y*0.26)
	var target := clampf(speed/5.0,0,1) if pushing and not braking and not goalie else 0.0
	push_blend = move_toward(push_blend,target,delta*4)
	if push_blend > 0.01:
		phase += delta * TAU * lerpf(0.7,1.25,clampf(speed/10,0,1))
	pose(speed,turn)
	if braking:
		skates[0].rotation.y = 0.7
		skates[1].rotation.y = 0.7

func set_number(value: String) -> void:
	number=value
	if is_instance_valid(number_label): number_label.text=value

func set_nameplate(value: String) -> void:
	if is_instance_valid(nameplate): nameplate.text=value.to_upper()

func stick_grip() -> Vector3:
	if goalie: return Vector3(lerpf(-0.36,-0.24,butterfly),0.60-butterfly*0.12,0.49)
	return Vector3(-0.14-stick_intent.x*0.16-shot_follow*0.12,0.93+shot_charge*0.06,0.32-stick_intent.y*0.06-shot_charge*0.18+shot_follow*0.22)

func update_stick() -> void:
	var top:=stick_grip()
	var bottom:=blade_position+Vector3(-stick_blade_length*0.48,0,0)
	var axis:=top-bottom
	stick_shaft.position=(top+bottom)*0.5
	stick_shaft.basis=Basis(Quaternion(Vector3.UP,axis.normalized()))
	# A goalie's hand sits at the top of the paddle; the shaft runs on past it.
	var beyond:=0.42 if goalie else 0.11
	stick_shaft.scale=Vector3(1,axis.length()+beyond,1)
	stick_shaft.position+=axis.normalized()*beyond*0.5
	if goalie:
		var paddle_top:Vector3=bottom.lerp(top,0.97)
		goalie_paddle.position=(bottom+paddle_top)*0.5
		goalie_paddle.basis=stick_shaft.basis
		goalie_paddle.scale=Vector3(1,bottom.distance_to(paddle_top),1)
	stick_blade.position=blade_position
	grip_tape.position=top
	grip_tape.basis=stick_shaft.basis

func get_blade_world() -> Vector3:
	return rig.to_global(blade_position)

func get_goalie_gear() -> Dictionary:
	# Actor-local transforms: the physical and visible gear share one source.
	var frame:=transform*rig.transform
	return {
		"Mask":{"transform":frame*helmet.transform,"size":Vector3(0.24,0.30,0.29),"zone":"mask","bounce":0.30},
		"Torso":{"transform":frame*torso_pose,"size":Vector3(0.56,0.59,0.33),"zone":"body","bounce":0.08},
		"PadLeft":{"transform":frame*pads[0].transform*pad_box()[0],"size":pad_box()[1],"zone":"pad","bounce":0.20},
		"PadRight":{"transform":frame*pads[1].transform*pad_box()[0],"size":pad_box()[1],"zone":"pad","bounce":0.20},
		"Catcher":{"transform":frame*goalie_gloves[0].transform,"size":Vector3(0.26,0.40,0.10),"zone":"catcher","bounce":0.02},
		"Blocker":{"transform":frame*goalie_gloves[1].transform,"size":Vector3(0.205,0.385,0.05),"zone":"blocker","bounce":0.48},
		"GoalieBlade":{"transform":frame*stick_blade.transform,"size":Vector3(0.39,0.08,0.036),"zone":"stick","bounce":0.40},
		"Paddle":{"transform":frame*Transform3D(goalie_paddle.basis.orthonormalized(),goalie_paddle.position),"size":Vector3(0.088,goalie_paddle.scale.y,0.026),"zone":"stick","bounce":0.35}
	}

func build_player_glove(parent: Node3D) -> void:
	add_mesh(parent,Gear.skater_glove(kit))

func update_cloth_sleeve(instance: MeshInstance3D, shoulder: Vector3, elbow: Vector3, wrist: Vector3) -> void:
	# A continuous curved cloth envelope follows the exact arm IK targets.
	var old:Array=instance.get_meta("arm_pose",[])
	if old.size()==3 and shoulder.is_equal_approx(old[0]) and elbow.is_equal_approx(old[1]) and wrist.is_equal_approx(old[2]):return
	instance.set_meta("arm_pose",[shoulder,elbow,wrist])
	var control:=elbow*2-(shoulder+wrist)*0.5
	var vertices:=PackedVector3Array()
	var normals:=PackedVector3Array()
	var indices:=PackedInt32Array()
	for row in range(9):
		var t:=float(row)/8
		var center:Vector3=(1-t)*(1-t)*shoulder+2*(1-t)*t*control+t*t*wrist
		var axis:Vector3=(2*(1-t)*(control-shoulder)+2*t*(wrist-control)).normalized()
		var across:=axis.cross(Vector3.FORWARD).normalized()
		if across.length_squared()<0.01:across=axis.cross(Vector3.RIGHT).normalized()
		var depth:=axis.cross(across).normalized()
		var radius_:float=lerpf(0.105,0.078,t*2) if t<=0.5 else lerpf(0.078,0.060,(t-0.5)*2)
		if goalie: radius_*=1.2
		for column in range(17):
			var angle:=TAU*column/16
			var radial:Vector3=across*cos(angle)+depth*sin(angle)
			vertices.append(center+radial*radius_)
			normals.append(radial)
			if row<8 and column<16:
				var a:=row*17+column
				indices.append_array(PackedInt32Array([a,a+17,a+18,a,a+18,a+1]))
	var arrays:=[]
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=vertices
	arrays[Mesh.ARRAY_NORMAL]=normals
	arrays[Mesh.ARRAY_INDEX]=indices
	var mesh:ArrayMesh=instance.mesh
	mesh.clear_surfaces()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
