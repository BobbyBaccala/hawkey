extends Node3D
## CC0 skinned human foundation, original kit and procedural two-bone hockey posing.
const Human = preload("res://assets/player-base-v1.glb")
const Uniform = preload("res://assets/uniform.gdshader")
const Arena = preload("res://scripts/arena.gd")
var kit := Color("#116c9e")
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
var pad_size := Vector3(0.28,0.64,0.17)
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
	stick_blade_length=0.36 if goalie else 0.28
	stick_blade=build_blade()
	sticks.add_child(stick_blade)
	if goalie:
		goalie_paddle=block(sticks,Vector3(0.085,1,0.024),Vector3.ZERO,Color("#d3d9db"))
	grip_tape=block(sticks,Vector3(0.035,0.11,0.035),Vector3.ZERO,Color("#cad2d7"))
	for side in [1.0,-1.0]:
		var sleeve:=MeshInstance3D.new()
		sleeve.mesh=ArrayMesh.new()
		sleeve.material_override=material(kit,0.87)
		rig.add_child(sleeve)
		cloth_sleeves.append(sleeve)
		var skate := Node3D.new()
		rig.add_child(skate)
		build_skate(skate)
		skates.append(skate)
		if goalie:
			var pad := Node3D.new()
			rig.add_child(pad)
			build_pad(pad)
			pads.append(pad)
			var glove := Node3D.new()
			rig.add_child(glove)
			if side>0:
				ellipsoid(glove,Vector3(0.22,0.24,0.10),Vector3.ZERO,Color("#becbd3"))
				ellipsoid(glove,Vector3(0.12,0.14,0.02),Vector3(0,0,0.052),Color("#253544"))
			else:
				block(glove,Vector3(0.17,0.24,0.06),Vector3.ZERO,Color("#c6d0d8"))
			goalie_gloves.append(glove)
		else:
			var glove:=Node3D.new()
			rig.add_child(glove)
			build_player_glove(glove)
			skater_gloves.append(glove)
	blade_position=Vector3(-0.05,0.034,0.79) if goalie else Vector3(-0.20,0.029,0.83)
	if referee: sticks.visible=false
	pose(0,0)

func build_skate(parent: Node3D) -> void:
	ellipsoid(parent,Vector3(0.13,0.18,0.21),Vector3(0,0.10,0.02),Color("#18212a"))
	ellipsoid(parent,Vector3(0.12,0.10,0.31),Vector3(0,0.03,0.08),Color("#111923"))
	for side in [-1.0,1.0]:
		segment(parent,Vector3(side * 0.045,-0.015,-0.06),Vector3(side * 0.045,-0.015,0.19),0.012,Color("#c0cbd0"))
	block(parent,Vector3(0.014,0.035,0.32),Vector3(0,-0.045,0.065),Color("#91a5b2"))
	for i in range(5):
		var z := float(i) * 0.028
		segment(parent,Vector3(-0.035,0.13-z*0.3,z),Vector3(0.035,0.13-z*0.3,z+0.018),0.005,Color("#aab5bd"))

func build_pad(parent: Node3D) -> void:
	# One broad, flat pad face with a knee roll, toe taper and binding.
	build_pad_shell(parent)
	for x in [-0.126,0.126]:
		block(parent,Vector3(0.018,0.62,0.018),Vector3(x,0,0.089),Color("#253948"))
	for y in [-0.18,-0.04,0.10]:
		block(parent,Vector3(0.245,0.012,0.010),Vector3(0,y,0.091),Color("#aab8bf"))
	block(parent,Vector3(0.25,0.055,0.02),Vector3(0,0.20,0.092),kit.darkened(0.15))
	block(parent,Vector3(0.18,0.025,0.025),Vector3(0,-0.27,0.095),kit.darkened(0.1))

func build_blade() -> MeshInstance3D:
	var mesh:=ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var length_:float=stick_blade_length
	var height_:float=0.062 if goalie else 0.050
	var thickness:float=0.013 if goalie else 0.009
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
	var drop := Vector3(0,(-0.32-butterfly*0.22) if goalie else -0.28,0.035)
	var root_pose := root_rest
	root_pose.origin += drop
	override_pose("root",root_pose)
	bend = Basis(Vector3.RIGHT,(0.34-butterfly*0.12) if goalie else 0.40+minf(speed/55,0.13))
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
		if goalie: ankle = Vector3(side*lerpf(0.34,0.66,butterfly),0.115,lerpf(0.04,-0.10,butterfly))
		feet[i] = ankle
		var hip: Vector3 = rest["upperleg01"+suffix].origin+drop
		var knee := knee_position(hip,ankle,Vector3(0,0,1),0.44,0.45)
		if goalie: knee=knee.lerp(Vector3(side*0.09,0.19,0.28),butterfly)
		knees[i]=knee
		align_bone("upperleg01"+suffix,"lowerleg01"+suffix,hip,knee)
		align_bone("lowerleg01"+suffix,"foot"+suffix,knee,ankle)
		var foot_pose: Transform3D = rest["foot"+suffix]
		foot_pose.origin = ankle
		foot_pose.basis = Basis(Vector3.UP,side*push*0.23*push_blend)*foot_pose.basis
		override_pose("foot"+suffix,foot_pose)
		skates[i].position = ankle+Vector3(0,-0.0525,0)
		skates[i].rotation.y = side*lerpf(0.12,1.1,butterfly) if goalie else side*push*0.23*push_blend
		if goalie:
			var shin:Vector3=(knee-ankle).normalized()
			var flare:float=atan2(-shin.x,shin.y)
			pads[i].basis=Basis(Vector3.BACK,flare)*Basis(Vector3.RIGHT,0.12*(1-butterfly))
			pads[i].position=(ankle+knee)*0.5+Vector3(-side*butterfly*0.055,0.01,0)
			pads[i].position.z=maxf(ankle.z,knee.z)+0.11
			# Pad lower edges seal against the ice in butterfly.
			var extent:float=absf(pads[i].basis.x.y)*pad_size.x/2+absf(pads[i].basis.y.y)*pad_size.y/2+absf(pads[i].basis.z.y)*pad_size.z/2
			pads[i].position.y=maxf(pads[i].position.y,extent+0.012)
		# Elbows and wrists stay on a two-hand stick posture, never running arm swings.
		var shoulder_original: Transform3D = rest["upperarm01"+suffix]
		var shoulder := pivot+drop+bend*(shoulder_original.origin-pivot)
		var wrist := stick_grip().lerp(blade_position+Vector3(-stick_blade_length*0.48,0,0),0.26) if i==0 else stick_grip()
		if referee: wrist=Vector3(side*0.32,0.96,0.03)
		if goalie:
			wrist=Vector3(0.40,0.84-butterfly*0.20+goalie_save_height,0.46) if i==0 else stick_grip()
			goalie_gloves[i].position=wrist+Vector3(0,0,0.025)
			goalie_gloves[i].rotation=Vector3(-0.15,0,0.15 if i==0 else 0)
		else:
			skater_gloves[i].position=wrist
			skater_gloves[i].basis=Basis(Quaternion(Vector3.UP,(stick_grip()-blade_position).normalized()))
		var pole := Vector3(side,0,-0.3)
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
	blade_position=Vector3(-0.05,0.034,0.79) if goalie else Vector3(-(0.20+stick_intent.x*0.55),0.029,0.83-stick_intent.y*0.26)
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
	if goalie: return Vector3(-0.30,0.66-butterfly*0.13,0.43)
	return Vector3(-0.14-stick_intent.x*0.16-shot_follow*0.12,0.93+shot_charge*0.06,0.32-stick_intent.y*0.10-shot_charge*0.18+shot_follow*0.22)

func update_stick() -> void:
	var top:=stick_grip()
	var bottom:=blade_position+Vector3(-stick_blade_length*0.48,0,0)
	var axis:=top-bottom
	stick_shaft.position=(top+bottom)*0.5
	stick_shaft.basis=Basis(Quaternion(Vector3.UP,axis.normalized()))
	stick_shaft.scale=Vector3(1,axis.length()+0.11,1)
	stick_shaft.position+=axis.normalized()*0.055
	if goalie:
		var paddle_top:Vector3=bottom.lerp(top,0.88)
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
		"Mask":{"transform":frame*helmet.transform,"size":Vector3(0.23,0.27,0.29),"zone":"mask","bounce":0.30},
		"Torso":{"transform":frame*torso_pose,"size":Vector3(0.56,0.59,0.33),"zone":"body","bounce":0.08},
		"PadLeft":{"transform":frame*pads[0].transform,"size":pad_size,"zone":"pad","bounce":0.20},
		"PadRight":{"transform":frame*pads[1].transform,"size":pad_size,"zone":"pad","bounce":0.20},
		"Catcher":{"transform":frame*goalie_gloves[0].transform,"size":Vector3(0.22,0.24,0.10),"zone":"catcher","bounce":0.02},
		"Blocker":{"transform":frame*goalie_gloves[1].transform,"size":Vector3(0.17,0.24,0.06),"zone":"blocker","bounce":0.48},
		"GoalieBlade":{"transform":frame*stick_blade.transform,"size":Vector3(0.36,0.062,0.036),"zone":"stick","bounce":0.40},
		"Paddle":{"transform":frame*Transform3D(goalie_paddle.basis.orthonormalized(),goalie_paddle.position),"size":Vector3(0.085,goalie_paddle.scale.y,0.024),"zone":"stick","bounce":0.35}
	}

func build_player_glove(parent: Node3D) -> void:
	var dark:=Color("#172b38")
	ellipsoid(parent,Vector3(0.13,0.15,0.12),Vector3.ZERO,dark)
	block(parent,Vector3(0.145,0.045,0.125),Vector3(0,0.065,0),kit.lightened(0.15))
	ellipsoid(parent,Vector3(0.052,0.085,0.065),Vector3(0.052,-0.012,0.025),dark)
	for i in range(4):
		block(parent,Vector3(0.023,0.048,0.028),Vector3(-0.043+i*0.028,-0.015,0.055),kit.darkened(0.2))

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

func build_pad_shell(parent: Node3D) -> void:
	var mesh:=ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var outline:Array[Vector2]=[Vector2(-0.112,-0.32),Vector2(0.112,-0.32),Vector2(0.14,-0.27),Vector2(0.14,0.29),Vector2(0.115,0.32),Vector2(-0.115,0.32),Vector2(-0.14,0.29),Vector2(-0.14,-0.27)]
	for i in range(outline.size()):
		var a:Vector2=outline[i]
		var b:Vector2=outline[posmod(i+1,outline.size())]
		for ring in range(2):
			var z0:float=-0.085 if ring==0 else 0.073
			var z1:float=0.073 if ring==0 else 0.085
			var scale0:float=1
			var scale1:float=1 if ring==0 else 0.94
			var normal:=Vector3(b.y-a.y,a.x-b.x,0.3 if ring==1 else 0.0).normalized()
			for v in [Vector3(a.x*scale0,a.y*scale0,z0),Vector3(b.x*scale0,b.y*scale0,z0),Vector3(b.x*scale1,b.y*scale1,z1),Vector3(a.x*scale0,a.y*scale0,z0),Vector3(b.x*scale1,b.y*scale1,z1),Vector3(a.x*scale1,a.y*scale1,z1)]:
				mesh.surface_set_normal(normal)
				mesh.surface_add_vertex(v)
		for z in [-0.085,0.085]:
			var scale_:float=0.94 if z>0 else 1
			for v in [Vector3(0,0,z),Vector3(a.x*scale_,a.y*scale_,z),Vector3(b.x*scale_,b.y*scale_,z)]:
				mesh.surface_set_normal(Vector3(0,0,signf(z)))
				mesh.surface_add_vertex(v)
	mesh.surface_end()
	var instance:=MeshInstance3D.new()
	instance.mesh=mesh
	instance.material_override=material(Color("#dce1e1"),0.62)
	parent.add_child(instance)
