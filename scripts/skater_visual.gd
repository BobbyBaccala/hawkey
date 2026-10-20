extends Node3D
## CC0 skinned human foundation, original kit and procedural two-bone hockey posing.
const Human = preload("res://assets/player-base-v1.glb")
const Uniform = preload("res://assets/uniform.gdshader")
const Arena = preload("res://scripts/arena.gd")
const Gear = preload("res://scripts/gear_builder.gd")
const Mocap = preload("res://scripts/mocap.gd")
const MOCAP_HIP_HEIGHT := 0.958
# Captured clip blended over the procedural pose (celebrations, save reactions).
var mocap := {}
var mocap_time := 0.0
var mocap_weight := 0.0
var mocap_fade := 0.0
var mocap_loop := false
var mocap_mask: Array = []
var mocap_rate := 1.0
var mocap_end := 0.0
var mocap_strength := 1.0
# Goalie layers: captured idle breathing/weight shift and lateral shuffles.
var idle_data := {}
var idle_time := 0.0
var shuffle_data: Array = [{},{}]
var shuffle_time := 0.0
var shuffle_weight := 0.0
var lateral := 0.0
var last_world := Vector3.INF
var raised_stick := 0.0
var posed_wrists: Array[Vector3] = [Vector3.ZERO,Vector3.ZERO]
var posed_elbows: Array[Vector3] = [Vector3.ZERO,Vector3.ZERO]
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
## Goalie save selection. Each save type has its own blend weight so a new
## save can interrupt the recovery from the last one. save_target is the
## puck's predicted crossing point in rig space: x across (+x = catching
## side), y height above the ice.
const SAVE_KINDS := ["glove","blocker","pad_left","pad_right"]
var save_weights := {"glove":0.0,"blocker":0.0,"pad_left":0.0,"pad_right":0.0}
var save_kind := ""
var save_target := Vector2(0,0.8)
const ARM_REACH := 0.55
## Grip-to-heel length of a goalie stick in the ready stance (metres).
const GOALIE_STICK_REACH := 0.62
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
## Player skate ankle cuffs (children of skates[i]), aligned to the shin.
var skate_cuffs: Array[MeshInstance3D] = []
var helmet: Node3D
var shirt: Node3D
var sticks: Node3D
var pads: Array[Node3D] = []
var thigh_rises: Array[Node3D] = []
var pant_legs: Array[MeshInstance3D] = []
var socks: Array[MeshInstance3D] = []
var push_blend := 0.0
var push_rate := 0.0
var posed_head := Vector3.ZERO
var bend := Basis.IDENTITY
## Per-leg stride state from stride_foot(): ankle (rig space), skate yaw/edge
## roll, and push extension 0..1. Filled each pose() for skaters.
var stride: Array = [{},{}]
## Jersey cross-sections (half-width, height, half-depth) in shirt space: the
## torso volume arms and hands are kept outside of.
var jersey_sections: Array = []
## Hip offset applied this pose (stance drop, weight shift).
var posed_drop := Vector3.ZERO
## Skating stride (one leg at a time): each leg spends STANCE of its cycle on
## the ice (glide, then a push out to the side and back) and the rest lifting
## and swinging back under the body. Legs are half a cycle apart.
const STANCE := 0.62
const PLANT := Vector3(0.10, 0.115, 0.14)     # touch-down: under the hip, ahead
const TOE_OFF := Vector3(0.56, 0.115, -0.24)  # full extension: out and back
const GLIDE_FEET := [Vector3(0.15, 0.115, 0.10), Vector3(-0.15, 0.115, -0.12)]
const LEG_REACH := 0.86
const SKATE_DROP := 0.0525                    # ankle to skate origin
const RUNNER_TOE := 0.225                     # runner tip ahead of skate origin
const RUNNER_HEEL := 0.085                    # runner heel behind skate origin
const MAX_EDGE := 0.75                        # deepest edge roll (radians)                       # max hip-to-ankle (thigh 0.44 + shin 0.45)
## Hockey stop (skaters only). A hard deceleration from speed - the brake
## button, or the AI reversing - turns the hips ~80 degrees across the line of
## travel; both blades scrape sideways (lead foot on its inside edge, trail foot
## on its outside edge), knees bend, the hips drop and sit back away from the
## travel, the stick reaches out front, and snow sprays off the blades. Detected
## here from the speed passed to animate(), so lab.gd and match.gd need no
## extra calls.
const SnowSpray = preload("res://scripts/snow_spray.gd")
const STOP_MIN_SPEED := 4.0      # m/s needed to start a stop
const STOP_DECEL := 7.0          # m/s^2 (smoothed) that counts as a hard stop
const STOP_ANGLE := 1.38         # hips turned this far from the travel (~79 deg)
var stopping := false
## 0..1 blend of the skid pose (eased in pose()).
var stop_weight := 0.0
## +1: travel runs toward the skater's right (rig -x); -1: toward the left.
var stop_side := 1.0
## Rig yaw (relative to this node) the stop turns the hips to.
var stop_yaw := 0.0
var stop_timer := 0.0
## Smoothed deceleration (m/s^2, + = slowing) and the speed it came from.
var decel := 0.0
var last_speed := -1.0
## World-space velocity of this node, smoothed (while in the tree).
var travel := Vector3.ZERO
## Smoothed low-speed brake turn of both skates (the old Ctrl brake look).
var brake_turn := 0.0
var sprays: Array = []

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
	add_to_group("skater_visuals")
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
			if not referee:
				var spray := SnowSpray.new()
				add_child(spray)
				sprays.append(spray)
	blade_position=Vector3(-0.02,0.042,0.60) if goalie else Vector3(-0.20,0.029,0.83)
	if referee: sticks.visible=false
	pose(0,0)

func add_mesh(parent: Node3D, mesh: Mesh) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	parent.add_child(instance)
	return instance

func build_skate(parent: Node3D) -> void:
	add_mesh(parent,Gear.skate(goalie,goalie))
	if not goalie:
		# Ankle cuff follows the shin (posed in pose()), so the leg always
		# enters the boot.
		var cuff := add_mesh(parent,Gear.skate_cuff())
		cuff.name = "Cuff"
		skate_cuffs.append(cuff)

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
	var curve:float=-t*t*0.023
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
	jersey_sections = sections
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
	shader.code = "shader_type spatial; render_mode cull_disabled; uniform vec4 kit:source_color; uniform vec4 stripe_color:source_color=vec4(0.68,0.68,0.68,1.0); void fragment(){float stripe=(step(1.005,UV.y)-step(1.035,UV.y))+(step(1.05,UV.y)-step(1.064,UV.y));float weave=sin(UV.x*700.0)*sin(UV.y*700.0)*0.003;ALBEDO=mix(kit.rgb,stripe_color.rgb,stripe)+weave;ROUGHNESS=0.86;SPECULAR=0.18;}"
	var m := ShaderMaterial.new()
	m.shader = shader
	m.set_shader_parameter("kit",kit)
	m.set_shader_parameter("stripe_color",accent)
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

## Picks a goalie save for a shot crossing at x (rig space, + = glove side)
## and height h: butterfly for low shots in front of the pads, a pad
## extension (one leg kicked out along the ice) for low shots wide, glove or
## blocker for higher shots to either side, and a body block in the middle.
static func choose_save(x: float, h: float) -> String:
	if h < 0.45:
		if absf(x) > 0.62: return "pad_left" if x > 0 else "pad_right"
		return "butterfly"
	if x > 0.18: return "glove"
	if x < -0.18: return "blocker"
	return "glove" if h > 0.95 else "body"

## Drives the save blend: the chosen save ramps in fast (a reaction), the
## others recover more slowly, and a new choice interrupts at any point.
func set_save(kind: String, target: Vector2, delta: float) -> void:
	save_kind = kind
	save_target = save_target.lerp(target,1.0-exp(-18.0*delta))
	for k in SAVE_KINDS:
		save_weights[k] = move_toward(save_weights[k],1.0 if k==kind else 0.0,delta*(7.0 if k==kind else 3.0))

## Wrist target for a reaching save, kept within the arm's reach of its shoulder.
func reach(shoulder: Vector3, target: Vector3) -> Vector3:
	return shoulder+(target-shoulder).limit_length(ARM_REACH)

## Where one skater foot is at this point of the stride. Returns the ankle
## (rig space, before the hip-reach clamp), skate yaw, toe pitch, how much the
## boot follows the shin onto its edge, and push extension. Every curve eases
## in and out, and stance and recovery meet with matching positions, so the
## foot path has no pops at touch-down or toe-off.
func stride_foot(i: int, speed: float) -> Dictionary:
	var side := 1.0 if i==0 else -1.0
	var amount := push_blend*clampf(0.55+speed/14.0,0.55,1.0)
	var cycle := fposmod(phase/TAU+float(i)*0.5,1.0)
	var foot: Vector3
	var ext := 0.0
	var lift := 0.0
	var pitch := 0.0
	var edge := 0.0
	if cycle < STANCE:
		# Glide on the plant foot, then drive it out to the side and back.
		var u := cycle/STANCE
		ext = smoothstep(0.2,1.0,u)
		foot = PLANT.lerp(TOE_OFF,ext)
		foot.z = lerpf(PLANT.z,TOE_OFF.z,0.3*smoothstep(0.0,1.0,u)+0.7*ext)
		# Rolls onto the inside edge as the push starts; at the end of the push
		# the heel peels up and the toe flicks off the ice.
		edge = smoothstep(0.0,0.4,u)
		pitch = 0.42*smoothstep(0.72,1.0,u)
	else:
		# Recovery: toe trails low, the foot swings back in under the hip, the
		# toe comes up and the blade lands flat to glide again.
		var u := (cycle-STANCE)/(1.0-STANCE)
		var back := smoothstep(0.0,0.85,u)
		foot = TOE_OFF.lerp(PLANT,back)
		foot.z = lerpf(TOE_OFF.z,PLANT.z,smoothstep(0.1,1.0,u))
		lift = sin(PI*u)*0.05
		ext = 1.0-smoothstep(0.0,1.0,u)
		edge = 1.0-smoothstep(0.0,0.35,u)
		if u < 0.3: pitch = 0.42+0.13*smoothstep(0.0,0.3,u)
		else: pitch = lerpf(0.55,-0.06,smoothstep(0.3,0.88,u))+0.06*smoothstep(0.88,1.0,u)
	foot.x *= side
	foot.y += lift
	var glide: Vector3 = GLIDE_FEET[i]
	var ankle := glide.lerp(foot,amount)
	pitch *= amount
	# Keep the runner's toe and heel on or above the ice whatever the pitch:
	# a toe-down foot pivots on its toe, so the heel and ankle rise.
	ankle.y = soft_max(ankle.y,ankle_floor(pitch),0.012)
	return {
		"ankle": ankle,
		"ext": ext*amount,
		"lift": lift*amount,
		# Toe turns out as the leg drives.
		"yaw": side*(0.06+0.42*ext)*amount,
		"pitch": pitch,
		"edge": edge*amount,
	}

## Smooth maximum: like maxf() but with a rounded corner of width k, so a
## curve switching from one input to the other never kinks (no visible pop).
static func soft_max(a: float, b: float, k: float) -> float:
	return (a+b+sqrt((a-b)*(a-b)+k*k))*0.5

## Lowest ankle height (rig space) that keeps the skate runner's toe and heel
## on or above the ice at this toe-down pitch (radians, + = toe down).
func ankle_floor(pitch: float) -> float:
	var toe := 0.06*cos(pitch)+RUNNER_TOE*sin(pitch)
	var heel := 0.06*cos(pitch)-RUNNER_HEEL*sin(pitch)
	return maxf(toe,heel)+SKATE_DROP+0.003

## Signed distance (metres, + outside) from a rig-space point to the torso
## surface, measured horizontally in shirt space; INF above/below the torso.
## Also returns the outward direction (rig space) via `out`.
func torso_clearance(p: Vector3, out: Array = []) -> float:
	if jersey_sections.is_empty(): return INF
	var local := shirt.transform.affine_inverse()*p
	var first: Vector3 = jersey_sections[0]
	var last: Vector3 = jersey_sections[jersey_sections.size()-1]
	# The padded pants carry the torso shape down over the hips.
	if local.y < first.y-0.22 or local.y > last.y: return INF
	var size := Vector2(first.x,first.z)
	for k in range(jersey_sections.size()-1):
		var a: Vector3 = jersey_sections[k]
		var b: Vector3 = jersey_sections[k+1]
		if local.y >= a.y and local.y <= b.y:
			var t := (local.y-a.y)/(b.y-a.y)
			size = Vector2(lerpf(a.x,b.x,t),lerpf(a.z,b.z,t))
			break
	var radial := Vector2(local.x,local.z+0.02)
	var r := radial.length()
	if r < 0.0001: return -minf(size.x,size.y)
	var n := sqrt(pow(radial.x/size.x,2)+pow(radial.y/size.y,2))
	out.clear()
	out.append(shirt.transform.basis*Vector3(radial.x/r,0,radial.y/r))
	return r*(1.0-1.0/n)

## Total depth by which a sleeve (shoulder -> elbow -> wrist, the same curve
## update_cloth_sleeve() builds) sinks into the torso, past the shoulder joint.
func sleeve_penetration(shoulder: Vector3, elbow: Vector3, wrist: Vector3) -> float:
	var control := elbow*2-(shoulder+wrist)*0.5
	var total := 0.0
	for k in range(4,11):
		var t := float(k)/10.0
		var c: Vector3 = (1-t)*(1-t)*shoulder+2*(1-t)*t*control+t*t*wrist
		var radius := lerpf(0.105,0.078,t*2) if t<=0.5 else lerpf(0.078,0.060,(t-0.5)*2)
		var d := torso_clearance(c)
		if d < radius: total += radius-d
	return total

## Elbow on the arm's IK circle that keeps the sleeve out of the torso,
## preferring the natural elbow (from `pole`) when it is already clear.
func clear_elbow(shoulder: Vector3, wrist: Vector3, pole: Vector3) -> Vector3:
	var natural := knee_position(shoulder,wrist,pole,0.28,0.29)
	var worst := sleeve_penetration(shoulder,natural,wrist)
	if worst <= 0.0: return natural
	var axis := (wrist-shoulder).normalized()
	var mid := knee_position(shoulder,wrist,pole,0.28,0.29)
	var foot := shoulder+axis*axis.dot(mid-shoulder)
	var arm := mid-foot
	var best := natural
	var best_score := worst
	for k in range(1,16):
		var angle := TAU*k/16.0
		var candidate := foot+arm.rotated(axis,angle if angle<=PI else angle-TAU)
		# Elbows don't fold up over the shoulder.
		if candidate.y > shoulder.y+0.05: continue
		var score := sleeve_penetration(shoulder,candidate,wrist)+absf(angle if angle<=PI else angle-TAU)*0.01
		if score < best_score:
			best_score = score
			best = candidate
	return best

## Shoulder joint (rig space) of arm i for the current torso pose.
func shoulder_of(i: int) -> Vector3:
	var original: Transform3D = rest["upperarm01"+(".L" if i==0 else ".R")]
	var pivot: Vector3 = rest["root"].origin
	return pivot+posed_drop+bend*(original.origin-pivot)

## Moves a hand target out of the torso so the glove sits on its surface.
func clear_hand(p: Vector3, margin: float) -> Vector3:
	var out := []
	var d := torso_clearance(p,out)
	if d < margin and not out.is_empty():
		p += out[0]*(margin-d)
	return p

func pose(speed: float, turn: float) -> void:
	skeleton.clear_bones_global_pose_override()
	var root_rest: Transform3D = rest["root"]
	# Skating stance: hips about 0.80 m, knees near 100 degrees.
	var drop := Vector3(0,-0.17,0.0)
	if goalie:
		# Sit back: hips behind the heels so the shins angle ~25 degrees and the
		# pads stay upright; in the butterfly the hips come forward over the knees.
		drop = Vector3(0,lerpf(-0.33,-0.55,butterfly),lerpf(-0.24,-0.04,butterfly))
		# Saves move the body toward the puck: hips slide toward an extended
		# pad, and the torso leans toward a glove or blocker reach.
		var pad_shift: float = save_weights.pad_left-save_weights.pad_right
		drop += Vector3(pad_shift*0.16,-absf(pad_shift)*0.04,0)
	var shoulder_turn := 0.0
	if not goalie:
		stride=[stride_foot(0,speed),stride_foot(1,speed)]
		# Weight rides over the gliding leg (away from the pushing one); the
		# hips sink as a leg drives out, and the shoulders counter-turn a touch.
		var push_side: float = stride[0].ext-stride[1].ext
		drop += Vector3(-push_side*0.075,-0.035*push_blend-0.03*soft_max(stride[0].ext,stride[1].ext,0.25),0)
		# Shoulders open toward wherever the blade is being carried, so the
		# bottom arm reaches out in front instead of across the chest.
		shoulder_turn = push_side*0.07-stick_intent.x*0.30
	# Hockey stop: blend the stride toward the skid stance (see STOP_ANGLE).
	var stop_w := stop_blend()
	if stop_w > 0.0:
		var s := stop_side
		for i in range(2):
			var side := 1.0 if i==0 else -1.0
			var lead := side == -s
			# Lead blade (on the travel side) wide and a touch ahead; trail blade
			# tucked in under the hip so both shins lean back away from travel.
			var skid := Vector3(side*(0.36 if lead else 0.10),0.115,0.07 if lead else -0.08)
			var f: Dictionary = stride[i]
			f.ankle = (f.ankle as Vector3).lerp(skid,stop_w)
			f.yaw = lerpf(f.yaw,side*0.04,stop_w)
			f.pitch = f.pitch*(1.0-stop_w)
			f.edge = lerpf(f.edge,1.0,stop_w)
			f.ext = f.ext*(1.0-stop_w)
			f.lift = f.lift*(1.0-stop_w)
		# Hips drop low and sit back away from the travel; shoulders stay
		# turned a little toward where the skater was going.
		drop = drop.lerp(Vector3(s*0.13,-0.30,-0.05),stop_w)
		shoulder_turn = lerpf(shoulder_turn,-s*0.22,stop_w)
	var cap := {}
	if mocap_weight>0 and not mocap.is_empty():
		cap = Mocap.sample(mocap,mocap_time,mocap_loop)
	var idle := {}
	if goalie and not idle_data.is_empty():
		idle = Mocap.sample(idle_data,idle_time)
		# Captured weight shift and bounce of a keeper set in his stance.
		var shift:Vector3=(idle.points.Hips-idle_data.mean.points.Hips)*MOCAP_HIP_HEIGHT*(1.0-butterfly)
		drop += Vector3(shift.x*0.25,shift.y*0.8,0)
	var capture_weight := mocap_weight*mocap_strength
	posed_drop = drop
	var root_pose := root_rest
	root_pose.origin += drop
	override_pose("root",root_pose)
	bend = Basis(Vector3.RIGHT,lerpf(0.52,0.26,butterfly) if goalie else 0.50+minf(speed/40,0.18))
	if shoulder_turn != 0.0: bend = Basis(Vector3.UP,shoulder_turn)*bend
	# Stop: the upper body leans back against the skid.
	if stop_w > 0.0: bend = Basis(Vector3.BACK,-stop_side*0.24*stop_w)*bend
	if goalie:
		var reach_lean: float = save_weights.glove*clampf(save_target.x-0.45,0.0,0.5)-save_weights.blocker*clampf(-save_target.x-0.45,0.0,0.5)
		var pad_lean: float = save_weights.pad_left-save_weights.pad_right
		if reach_lean != 0.0 or pad_lean != 0.0:
			bend = Basis(Vector3.BACK,-reach_lean*0.6-pad_lean*0.18)*bend
	if not idle.is_empty():
		var sway:=Quaternion(idle_data.mean.dirs.spine,idle.dirs.spine)
		bend = Basis(Quaternion.IDENTITY.slerp(sway,0.7*(1.0-butterfly)))*bend
	if not cap.is_empty() and "spine" in mocap_mask:
		bend = Basis(Quaternion(bend.orthonormalized()).slerp(Quaternion(Vector3.UP,cap.dirs.spine),capture_weight))
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
		var ankle := Vector3(side*0.24,0.115,0.06)
		var hip: Vector3 = rest["upperleg01"+suffix].origin+drop
		if not goalie:
			ankle = stride[i].ankle
			# Keep the foot within the leg's reach (no stretched shins).
			var reach := ankle-hip
			if reach.length() > LEG_REACH:
				ankle = hip+reach.normalized()*LEG_REACH
				ankle.y = maxf(ankle.y,0.115)
		# Goalie ready stance: feet a little wider than the shoulders, knees in.
		if goalie: ankle = Vector3(side*lerpf(0.27,0.58,butterfly),0.115,lerpf(0.0,0.10,butterfly))
		if goalie and shuffle_weight>0.01:
			# Lateral shuffle: captured strafe footwork, narrowed to stay in the stance.
			var data:Dictionary=shuffle_data[0 if lateral>0 else 1]
			if not data.is_empty():
				var step:=Mocap.sample(data,shuffle_time)
				var foot_key:="LeftFoot" if i==0 else "RightFoot"
				var off:Vector3=(step.points[foot_key]-data.mean.points[foot_key])*MOCAP_HIP_HEIGHT
				ankle += Vector3(off.x*0.3,maxf(0,off.y)*0.5,off.z*0.15)*shuffle_weight
				# Goalies shuffle without bringing the feet together.
				ankle.x=side*clampf(side*ankle.x,0.25,0.33)
		feet[i] = ankle
		var knee := knee_position(hip,ankle,Vector3(-side*0.12,0,1) if goalie else Vector3(0,0,1),0.44,0.45)
		# Pads meet edge to edge at the knees rather than crossing.
		if goalie: knee.x=side*maxf(side*knee.x,Gear.PAD_WIDTH*0.5+0.036+0.035*shuffle_weight)
		# Butterfly: knees together on the ice, shins flared out behind them.
		if goalie:
			knee=knee.lerp(Vector3(side*0.17,0.13,0.24),butterfly)
			# Shins flare as the knees drop, so the knees stay apart mid-drop.
			knee.x+=side*0.045*sin(PI*butterfly)
			# Pad extension: this leg kicks out along the ice to seal the post,
			# pad face to the shooter; the other knee stays down in the butterfly.
			var kick: float = save_weights["pad_left" if i==0 else "pad_right"]
			var other: float = save_weights["pad_right" if i==0 else "pad_left"]
			if other > 0.0:
				# The folded leg slides with the hips, staying under its pad.
				var slide := Vector3(-side*other*0.16,0,0)
				ankle += slide
				knee += slide
				feet[i] = ankle
			if kick > 0.0:
				ankle = ankle.lerp(Vector3(side*1.02,0.12,0.06),kick)
				knee = knee.lerp(Vector3(side*0.57,0.16,0.17),kick)
				feet[i] = ankle
		knees[i]=knee
		align_bone("upperleg01"+suffix,"lowerleg01"+suffix,hip,knee)
		align_bone("lowerleg01"+suffix,"foot"+suffix,knee,ankle)
		if pant_legs.size()>i:
			# Goalie pants stop short of the pads; the legs meet but don't overlap.
			var fill:=1.06 if goalie else 0.96
			var reach:=lerpf(0.68,0.52,butterfly) if goalie else 0.94
			fit_limb(pant_legs[i],hip+Vector3(side*(0.03+butterfly*0.02),0.10,0),hip.lerp(knee,reach),fill)
		var foot_pose: Transform3D = rest["foot"+suffix]
		foot_pose.origin = ankle
		var boot := Vector3.ZERO
		if not goalie:
			# The boot follows the shin: as the leg drives out to the side the
			# blade rolls onto its inside edge in line with the shin, and the toe
			# pitch comes from the stride (toe-off flick, toe-up before landing).
			var yaw: float = stride[i].yaw
			var shin_local := Basis(Vector3.UP,yaw).inverse()*(knee-ankle)
			var roll := clampf(atan2(-shin_local.x,shin_local.y),-MAX_EDGE,MAX_EDGE)*float(stride[i].edge)
			boot = Vector3(stride[i].pitch,lerpf(yaw,0.7,brake_turn*(1.0-stop_w)),roll)
		foot_pose.basis = Basis.from_euler(boot)*foot_pose.basis
		override_pose("foot"+suffix,foot_pose)
		skates[i].position = ankle+Vector3(0,-0.0525,0)
		# Butterfly: skates turn out flat so the toes clear the pad backs.
		skates[i].rotation = Vector3(0,side*lerpf(0.12,1.45,smoothstep(0.0,0.4,butterfly)),0) if goalie else boot
		if socks.size()>i:
			# Sock and shin-guard knee cap overlap the bottom of the pants.
			# The sock runs down the shin into the skate cuff (cuff top ~0.15 m).
			fit_limb(socks[i],knee.lerp(hip,0.12),ankle+cuff_axis(i,knee,ankle)*0.09,1.0)
		if skate_cuffs.size()>i:
			# Cuff: +Y up the shin, +Z toward the toe, pivoting at the ankle.
			var up_:=cuff_axis(i,knee,ankle)
			var toe_:Vector3=skates[i].basis.z
			var fwd_:=(toe_-up_*up_.dot(toe_)).normalized()
			var cuff_pose:=Transform3D(Basis(up_.cross(fwd_),up_,fwd_),ankle)
			skate_cuffs[i].transform=skates[i].transform.affine_inverse()*cuff_pose
		if goalie:
			# The pad rides the shin: +Y up the shin, face (+Z) toward the shooter.
			var shin:Vector3=(knee-ankle).normalized()
			var face:Vector3=(Vector3.BACK-shin*shin.dot(Vector3.BACK)).normalized()
			pads[i].basis=Basis(shin.cross(face),shin,face)
			# Ride a few centimetres up the shin so the skate toe cap shows below.
			# Standing, the pad is anchored to the ankle so it always clears the skate.
			pads[i].position=(ankle+shin*0.48).lerp(knee-shin*(Gear.PAD_KNEE-0.065),butterfly)+face*0.09
			# The thigh rise follows the thigh: it leans out toward the hip as it
			# rises in the stance, and folds back along the thigh in the butterfly.
			var thigh_local:Vector3=pads[i].basis.inverse()*(hip-knee).normalized()
			var roll:float=clampf(atan2(-thigh_local.x,thigh_local.y),-0.6,0.6)
			var standing:=Quaternion(Basis(Vector3.BACK,-roll*0.6-side*0.08)*Basis(Vector3.RIGHT,-0.12))
			# Butterfly: the thigh rise folds flat along the thigh and its foam
			# compresses where the two meet behind the wall of pads.
			var folded:=Quaternion(Vector3.UP,thigh_local)
			# Compress early in the drop so the halves never cross mid-transition.
			var squash:=smoothstep(0.0,0.3,butterfly)
			thigh_rises[i].position=Vector3(0,Gear.PAD_BREAK-0.08*squash,-0.04+0.05*squash)
			thigh_rises[i].basis=Basis(standing.slerp(folded,smoothstep(0.0,0.6,butterfly))).scaled_local(Vector3(lerpf(1.0,0.42,squash),1,lerpf(1.0,0.7,squash)))
			thigh_rises[i].set_meta("rest_basis",thigh_rises[i].basis)
			# Pad lower edges seal against the ice in butterfly.
			var box:Array=pad_box()
			var size_:Vector3=box[1]
			var box_center:Vector3=pads[i].transform*box[0].origin
			var extent:float=absf(pads[i].basis.x.y)*size_.x/2+absf(pads[i].basis.y.y)*size_.y/2+absf(pads[i].basis.z.y)*size_.z/2
			pads[i].position.y+=maxf(0,extent+0.012-box_center.y)
		# Elbows and wrists stay on a two-hand stick posture, never running arm swings.
		var shoulder := shoulder_of(i)
		# Right-handed shot: the blade is on the skater's right (-x), so the right
		# hand (i==1) is the bottom hand riding the shaft and the left hand holds
		# the knob in front of the body. Neither arm has to reach across the chest.
		var wrist := stick_grip().lerp(blade_position+Vector3(-stick_blade_length*0.48,0,0),0.30)+Vector3(0,0.02,0.05*maxf(0,stick_intent.y)) if i==1 else stick_grip()
		if referee: wrist=Vector3(side*0.32,0.96,0.03)
		var captured_elbow := Vector3.ZERO
		if not cap.is_empty() and "arms" in mocap_mask and not goalie:
			# Captured arm directions, scaled to this rig's segment lengths.
			captured_elbow = shoulder+cap.dirs["upper"+suffix]*0.28
			wrist = wrist.lerp(captured_elbow+cap.dirs["fore"+suffix]*0.29,capture_weight)
			# Hands at the sides hang outside the padded pants.
			if wrist.y<1.05: wrist.x=side*maxf(side*wrist.x,lerpf(0.0,0.38,capture_weight))
		if goalie:
			# Hands out in front of the body: catcher open to the shooter at the hip,
			# blocker on the stick at the top of the paddle.
			# Hands travel with the hips when a save slides the body sideways.
			wrist=Vector3(0.47+posed_drop.x,0.83-butterfly*0.16+goalie_save_height,0.42) if i==0 else stick_grip()
			var catch_w: float = save_weights.glove
			if i==0 and catch_w > 0.0:
				# Glove save: the catcher shoots out to the puck's line, pocket open.
				var aim := Vector3(clampf(save_target.x,0.22,1.0),clampf(save_target.y,0.35,1.65),0.40)
				wrist = wrist.lerp(reach(shoulder,aim),catch_w)
			if i==0:
				goalie_gloves[i].position=wrist+Vector3(0.0,0.03,0.035)
				goalie_gloves[i].rotation=Vector3(-0.12-0.35*catch_w*clampf(save_target.y-0.9,0.0,0.7),0.32+0.25*catch_w,-0.12-0.3*catch_w)
			else:
				goalie_gloves[i].position=wrist+Vector3(-0.085,0.06,0.04)
				goalie_gloves[i].rotation=Vector3(-0.10,-0.28,0.06)
		else:
			skater_gloves[i].position=wrist
			skater_gloves[i].basis=Basis(Quaternion(Vector3.UP,(stick_grip()-blade_position).normalized()))
		var pole := Vector3(side*0.6,-0.8,-0.1) if goalie else Vector3(side,0,-0.3)
		if captured_elbow != Vector3.ZERO:
			pole = pole.lerp((captured_elbow-(shoulder+wrist)*0.5).normalized(),capture_weight)
		# Bottom hand and glove stay on the outside of the jersey.
		if not goalie and not referee and captured_elbow == Vector3.ZERO: wrist = clear_hand(wrist,0.075)
		var elbow := clear_elbow(shoulder,wrist,pole)
		posed_wrists[i]=wrist
		posed_elbows[i]=elbow
		update_cloth_sleeve(cloth_sleeves[i],shoulder,elbow,wrist)
		align_bone("upperarm01"+suffix,"lowerarm01"+suffix,shoulder,elbow)
		align_bone("lowerarm01"+suffix,"wrist"+suffix,elbow,wrist)
		var wrist_pose: Transform3D = rest["wrist"+suffix]
		wrist_pose.origin = wrist
		override_pose("wrist"+suffix,wrist_pose)
	if goalie: separate_thigh_rises()
	rig.rotation.z = clampf(turn,-0.13,0.13)
	# Stop: hips (and the whole rig) turn across the line of travel.
	rig.rotation.y = PI+stop_yaw*stop_w
	update_stick()

## Rolls the two thigh rises outward until their inner edges clear each other,
## whatever the knees, idle sway or shuffle footwork are doing.
func separate_thigh_rises() -> void:
	var extra := 0.0
	for iteration in range(14):
		var gap := INF
		var rise:=Gear.PAD_LENGTH*0.5-Gear.PAD_BREAK
		for height in [rise,rise*0.66,rise*0.33]:
			for depth in [-0.04,0.04,0.11]:
				var left_edge:Vector3=pads[0].transform*thigh_rises[0].transform*Vector3(-Gear.PAD_WIDTH*0.5,height,depth)
				var right_edge:Vector3=pads[1].transform*thigh_rises[1].transform*Vector3(Gear.PAD_WIDTH*0.5,height,depth)
				gap=minf(gap,left_edge.x-right_edge.x)
		if gap>=0.045 or butterfly>0.3: return
		extra+=0.05
		for i in range(2):
			var side:=1.0 if i==0 else -1.0
			var rest_basis:Basis=thigh_rises[i].get_meta("rest_basis")
			thigh_rises[i].basis=Basis(Vector3.BACK,-side*extra)*rest_basis

## Plays a captured clip over the procedural pose. Mask entries: "spine",
## "arms", "stick_up". Returns false when the clip file is not installed.
func play_mocap(clip_name: String, loop := false, mask: Array = ["spine","arms"], rate := 1.0, duration := -1.0, strength := 1.0) -> bool:
	var data := Mocap.clip(clip_name,self)
	if data.is_empty(): return false
	mocap=data
	mocap_time=0.0
	mocap_loop=loop
	mocap_mask=mask
	mocap_rate=rate
	mocap_end=duration if duration>0 else float(data.length)
	mocap_strength=strength
	mocap_fade=1.0
	return true

func stop_mocap() -> void:
	mocap_fade=0.0

func update_layers(delta: float) -> void:
	if is_inside_tree():
		var world:=global_position
		if last_world!=Vector3.INF and delta>0:
			var local_velocity:Vector3=rig.global_basis.orthonormalized().inverse()*((world-last_world)/delta)
			lateral=lerpf(lateral,local_velocity.x,1-exp(-10*delta))
			# Direction of travel for hockey stops (ignores teleports).
			var moved:=(world-last_world)/delta
			moved.y=0
			if moved.length()<30: travel=travel.lerp(moved,1-exp(-15*delta))
		last_world=world
	if not mocap.is_empty():
		mocap_time+=delta*mocap_rate
		if not mocap_loop and mocap_time>=mocap_end-0.3: mocap_fade=0.0
		mocap_weight=move_toward(mocap_weight,mocap_fade,delta*4)
		if mocap_weight<=0 and mocap_fade==0: mocap={}
	raised_stick=mocap_weight*mocap_strength if "stick_up" in mocap_mask and not mocap.is_empty() else move_toward(raised_stick,0,delta*4)
	if goalie and is_inside_tree():
		if idle_data.is_empty() and Mocap.available("Goalkeeper_Idle"): idle_data=Mocap.clip("Goalkeeper_Idle",self)
		idle_time+=delta
		if shuffle_data[0].is_empty() and Mocap.available("Left_Strafe"):
			shuffle_data=[Mocap.clip("Left_Strafe",self),Mocap.clip("Right_Strafe",self)]
		shuffle_weight=move_toward(shuffle_weight,clampf((absf(lateral)-0.25)/1.5,0,1)*(1.0-butterfly),delta*5)
		var data:Dictionary=shuffle_data[0 if lateral>0 else 1]
		if not data.is_empty():
			# Advance the footwork by distance covered so steps match the slide.
			var stride:float=maxf(0.1,data.travel.length()*MOCAP_HIP_HEIGHT/data.length)
			shuffle_time+=delta*absf(lateral)/stride

func animate(speed: float, delta: float, turn: float = 0, pushing: bool = true, braking: bool = false) -> void:
	update_layers(delta)
	update_stop(speed,delta,braking)
	brake_turn = move_toward(brake_turn,1.0 if braking and not goalie else 0.0,delta*6)
	shot_follow = maxf(0,shot_follow-delta*3)
	stick_intent=stick_intent.lerp(desired_stick,1-exp(-14*delta))
	blade_position=Vector3(-0.02+butterfly*0.05,0.042,0.60-butterfly*0.04) if goalie else Vector3(-(0.20+stick_intent.x*0.55),0.029,0.83-stick_intent.y*0.26)
	# Stop: the stick reaches out in front for balance.
	if not goalie: blade_position += Vector3(-0.04,0,0.16)*stop_blend()
	var target := clampf(speed/5.0,0,1) if pushing and not braking and not goalie else 0.0
	# Critically damped spring (not a linear ramp) so starting or easing off a
	# push - including into a hockey stop - never kinks the foot path.
	var substeps := clampi(ceili(delta*120.0),1,24)
	var h := delta/substeps
	for k in range(substeps):
		push_rate += (81.0*(target-push_blend)-18.0*push_rate)*h
		push_blend = clampf(push_blend+push_rate*h,0.0,1.0)
	if push_blend > 0.01:
		phase += delta * TAU * lerpf(0.7,1.25,clampf(speed/10,0,1))
	pose(speed,turn)
	update_spray(speed)

## Eased 0..1 weight of the hockey-stop pose (smootherstep: no velocity or
## acceleration jump as the blend starts or ends).
func stop_blend() -> float:
	if goalie: return 0.0
	var x := clampf(stop_weight,0.0,1.0)
	return x*x*x*(x*(x*6.0-15.0)+10.0)

## Heading of the direction of travel relative to this node's facing
## (radians, 0 = skating forward); 0 when not moving or not in the tree.
func travel_heading() -> float:
	if travel.length() < 0.5 or not is_inside_tree(): return 0.0
	var local:Vector3=global_basis.orthonormalized().inverse()*travel
	return atan2(-local.x,-local.z)

## Starts a hockey stop on a hard deceleration from speed and ends it once the
## skater has (nearly) stopped or eased off; the pose blends in fast and out
## more slowly so the recovery to the normal stance has no pop.
func update_stop(speed: float, delta: float, braking: bool) -> void:
	if delta <= 0.0: return
	var raw := 0.0
	# Clamped so a one-frame impact (boards, a hit) doesn't read as a stop.
	if last_speed >= 0.0: raw = clampf((last_speed-speed)/delta,-30.0,30.0)
	last_speed = speed
	decel = lerpf(decel,raw,1.0-exp(-20.0*delta))
	if goalie or referee:
		stopping = false
		stop_weight = 0.0
		return
	var heading := travel_heading()
	if not stopping and speed > STOP_MIN_SPEED and (braking or decel > STOP_DECEL):
		stopping = true
		stop_timer = 0.0
		# Turn whichever way is shorter from where the body faces now.
		stop_side = 1.0 if absf(wrapf(heading+STOP_ANGLE,-PI,PI)) <= absf(wrapf(heading-STOP_ANGLE,-PI,PI)) else -1.0
		if stop_weight < 0.05: stop_yaw = wrapf(heading+stop_side*STOP_ANGLE,-PI,PI)
	if stopping:
		stop_timer += delta
		stop_yaw = lerp_angle(stop_yaw,heading+stop_side*STOP_ANGLE,1.0-exp(-8.0*delta))
		if speed < 0.6 or (stop_timer > 0.3 and not braking and decel < 2.5):
			stopping = false
	stop_weight = move_toward(stop_weight,1.0 if stopping else 0.0,delta*(3.5 if stopping else 2.5))

## Snow spray off both blades while a stop is scraping, thrown along the
## direction of travel; the lead (travel-side) blade throws the most.
func update_spray(speed: float) -> void:
	if sprays.is_empty() or not is_inside_tree(): return
	var on := stopping and stop_weight > 0.35 and speed > 1.5
	var dir := travel if travel.length() > 0.5 else -global_basis.z
	dir.y = 0
	if dir.length_squared() < 0.0001: dir = Vector3.FORWARD
	dir = dir.normalized()
	var amount := clampf((speed-1.5)/7.0,0.0,1.0)
	for i in range(sprays.size()):
		var lead := (1.0 if i==0 else -1.0) == -stop_side
		sprays[i].global_transform = Transform3D(Basis.looking_at(dir,Vector3.UP),skates[i].global_position+Vector3(0,0.012,0)+dir*0.05)
		sprays[i].spray(on,amount*(1.0 if lead else 0.55),speed)

func set_number(value: String) -> void:
	number=value
	if is_instance_valid(number_label): number_label.text=value

func set_nameplate(value: String) -> void:
	if is_instance_valid(nameplate): nameplate.text=value.to_upper()

func stick_grip() -> Vector3:
	if goalie:
		var grip := Vector3(lerpf(-0.36,-0.24,butterfly)+posed_drop.x,0.60-butterfly*0.12,0.49)
		var block_w: float = save_weights.blocker
		if block_w > 0.0:
			# Blocker save: the stick hand punches out to the puck's line and the
			# paddle follows it.
			var aim := Vector3(clampf(save_target.x,-1.0,-0.28),clampf(save_target.y,0.45,1.45),0.50)
			grip = grip.lerp(reach(shoulder_of(1),aim),block_w)
		return grip
	var grip := Vector3(0.06-stick_intent.x*0.16-shot_follow*0.12,0.93+shot_charge*0.06,0.32-stick_intent.y*0.06-shot_charge*0.18+shot_follow*0.22)
	# Stop: hands come down with the hips and push the stick out front.
	grip += Vector3(0,-0.10,0.06)*stop_blend()
	# The top hand holds the stick in front of the jersey, never inside it.
	return clear_hand(grip,0.075)

func update_stick() -> void:
	var top:=stick_grip()
	# The blade lies flat on the ice in the shaft's plane: it runs on from the
	# heel in the direction the shaft leans (away from the hands), as on a
	# real stick, instead of folding back under the shaft. blade_position (the
	# puck pocket, used by gameplay) stays mid-blade.
	var toe_dir:=stick_toe_dir(top,blade_position)
	toe_dir=stick_toe_dir(top,blade_position-toe_dir*stick_blade_length*0.48)
	var bottom:=blade_position-toe_dir*stick_blade_length*0.48
	if goalie:
		# The stick is rigid: a blocker punched up lifts the paddle off the ice
		# instead of stretching the shaft.
		bottom = top+(bottom-top).limit_length(GOALIE_STICK_REACH)
	if raised_stick>0.01:
		# Celebration: the stick goes up with the top hand, blade high.
		var hand:Vector3=posed_wrists[1]
		var lift:=((hand-posed_elbows[1]).normalized()+Vector3(0,1.6,0)).normalized()
		top=top.lerp(hand-lift*0.12,raised_stick)
		bottom=bottom.lerp(hand+lift*1.30,raised_stick)
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
	var flat:=Basis(toe_dir,Vector3.UP,toe_dir.cross(Vector3.UP))
	stick_blade.basis=flat.slerp(stick_shaft.basis.orthonormalized(),raised_stick)
	stick_blade.position=bottom+stick_blade.basis*Vector3(stick_blade_length*0.48,0,0)
	grip_tape.position=top
	grip_tape.basis=stick_shaft.basis

## Axis of a skate's ankle cuff: the shin direction, but a stiff boot only
## flexes so far from the foot's own up axis (CUFF_FLEX), like a real skate.
const CUFF_FLEX := 0.52
func cuff_axis(i: int, knee: Vector3, ankle: Vector3) -> Vector3:
	var shin:=(knee-ankle).normalized()
	if skates.size()<=i: return shin
	var foot_up:Vector3=Basis.from_euler(skates[i].rotation).y
	var angle:=foot_up.angle_to(shin)
	if angle<=CUFF_FLEX: return shin
	return foot_up.slerp(shin,CUFF_FLEX/angle).normalized()

## Horizontal direction from the shaft's heel to the toe: the shaft's lean,
## projected on the ice. Falls back to the player's side if the shaft is upright.
func stick_toe_dir(top: Vector3, heel: Vector3) -> Vector3:
	# A goalie's stick lies across the crease in front of the skates.
	if goalie: return Vector3.RIGHT
	var d:=heel-top
	d.y=0
	if d.length()<0.05:
		d=Vector3(-1,0,0.4)
	return d.normalized()

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
