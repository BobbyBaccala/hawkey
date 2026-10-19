extends Node3D
## CC0 skinned human foundation, original kit and procedural two-bone hockey posing.
const Human = preload("res://assets/player-base-v1.glb")
const Uniform = preload("res://assets/uniform.gdshader")
const Arena = preload("res://scripts/arena.gd")
var kit := Color("#116c9e")
var number := "17"
var goalie := false
var phase := 0.0
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
	uniform.set_shader_parameter("team_color",kit.darkened(0.35))
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
	segment(sticks,Vector3(-0.06,1.0,0.45),Vector3(0.28,0.10,1.05),0.016,Color("#171f28"))
	block(sticks,Vector3(0.28,0.055,0.045),Vector3(0.16,0.085,1.05),Color("#151c23"))
	# Tape at the top hand and blade.
	segment(sticks,Vector3(-0.06,1.0,0.45),Vector3(-0.025,0.91,0.51),0.019,Color("#cad2d7"))
	for side in [-1.0,1.0]:
		var skate := Node3D.new()
		rig.add_child(skate)
		build_skate(skate)
		skates.append(skate)
		if goalie:
			var pad := Node3D.new()
			rig.add_child(pad)
			build_pad(pad)
			pads.append(pad)
	pose(0,0)

func build_skate(parent: Node3D) -> void:
	ellipsoid(parent,Vector3(0.14,0.23,0.23),Vector3(0,0.10,0.02),Color("#18212a"))
	ellipsoid(parent,Vector3(0.14,0.13,0.32),Vector3(0,0.03,0.08),Color("#111923"))
	for side in [-1.0,1.0]:
		segment(parent,Vector3(side * 0.045,-0.015,-0.06),Vector3(side * 0.045,-0.015,0.19),0.012,Color("#c0cbd0"))
	block(parent,Vector3(0.014,0.035,0.32),Vector3(0,-0.045,0.065),Color("#91a5b2"))
	for i in range(5):
		var z := float(i) * 0.028
		segment(parent,Vector3(-0.035,0.13-z*0.3,z),Vector3(0.035,0.13-z*0.3,z+0.018),0.005,Color("#aab5bd"))

func build_pad(parent: Node3D) -> void:
	for i in range(3):
		ellipsoid(parent,Vector3(0.09,0.66,0.15),Vector3((i-1)*0.09,0.3,0.12),Color("#bfcbd2"))
	for y in [0.1,0.3,0.5]:
		block(parent,Vector3(0.27,0.018,0.012),Vector3(0,y,0.195),kit.darkened(0.4))

func build_helmet() -> void:
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES,material(Color("#132434"),0.27))
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
	shader.code = "shader_type spatial; render_mode cull_disabled; uniform vec4 kit:source_color; void fragment(){float stripe=step(UV.y,1.075);float weave=sin(UV.x*1800.0)*sin(UV.y*1800.0)*0.015;ALBEDO=mix(kit.rgb,vec3(0.68),stripe)+weave;ROUGHNESS=0.86;SPECULAR=0.18;}"
	var m := ShaderMaterial.new()
	m.shader = shader
	m.set_shader_parameter("kit",kit.darkened(0.35))
	instance.material_override = m
	shirt.add_child(instance)
	var jersey_number := Label3D.new()
	jersey_number.text = number
	jersey_number.font_size = 64
	jersey_number.pixel_size = 0.004
	jersey_number.position = Vector3(0,1.31,-0.195)
	jersey_number.rotation.y = PI
	jersey_number.modulate = Color("#d0dbe2")
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
	var drop := Vector3(0,-0.18,0.01)
	var root_pose := root_rest
	root_pose.origin += drop
	override_pose("root",root_pose)
	bend = Basis(Vector3.RIGHT,0.30 + minf(speed/40,0.17))
	var pivot := root_rest.origin
	var spine: Transform3D = rest["spine05"]
	var spine_pose := Transform3D(bend * spine.basis,pivot + drop + bend * (spine.origin-pivot))
	override_pose("spine05",spine_pose)
	shirt.transform = Transform3D(bend,pivot+drop-bend*pivot)
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
		var ankle := Vector3(side*(0.20+push*0.34*push_blend),0.115+lift*push_blend,0.06-push*0.30*push_blend)
		if goalie: ankle = Vector3(side*0.29,0.115,0.05)
		feet[i] = ankle
		var hip: Vector3 = rest["upperleg01"+suffix].origin+drop
		var knee := knee_position(hip,ankle,Vector3(0,0,1),0.44,0.45)
		align_bone("upperleg01"+suffix,"lowerleg01"+suffix,hip,knee)
		align_bone("lowerleg01"+suffix,"foot"+suffix,knee,ankle)
		var foot_pose: Transform3D = rest["foot"+suffix]
		foot_pose.origin = ankle
		foot_pose.basis = Basis(Vector3.UP,side*push*0.23*push_blend)*foot_pose.basis
		override_pose("foot"+suffix,foot_pose)
		skates[i].position = ankle
		skates[i].rotation.y = side*push*0.23*push_blend
		if goalie: pads[i].position = Vector3(ankle.x,0,ankle.z)
		# Elbows and wrists stay on a two-hand stick posture, never running arm swings.
		var shoulder_original: Transform3D = rest["upperarm01"+suffix]
		var shoulder := pivot+drop+bend*(shoulder_original.origin-pivot)
		var wrist := Vector3(0.10,0.83,0.67) if i==0 else Vector3(-0.06,1.0,0.45)
		var pole := Vector3(side,0,-0.3)
		var elbow := knee_position(shoulder,wrist,pole,0.28,0.29)
		align_bone("upperarm01"+suffix,"lowerarm01"+suffix,shoulder,elbow)
		align_bone("lowerarm01"+suffix,"wrist"+suffix,elbow,wrist)
		var wrist_pose: Transform3D = rest["wrist"+suffix]
		wrist_pose.origin = wrist
		override_pose("wrist"+suffix,wrist_pose)
	rig.rotation.z = clampf(turn,-0.13,0.13)

func animate(speed: float, delta: float, turn: float = 0, pushing: bool = true, braking: bool = false) -> void:
	var target := clampf(speed/5.0,0,1) if pushing and not braking and not goalie else 0.0
	push_blend = move_toward(push_blend,target,delta*4)
	if push_blend > 0.01:
		phase += delta * TAU * lerpf(0.7,1.25,clampf(speed/10,0,1))
	pose(speed,turn)
	if braking:
		skates[0].rotation.y = 0.7
		skates[1].rotation.y = 0.7
