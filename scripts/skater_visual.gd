extends Node3D
## CC0 skinned human foundation, original kit and procedural two-bone hockey posing.
const Human = preload("res://assets/player-base-v1.glb")
const Uniform = preload("res://assets/uniform.gdshader")
const Arena = preload("res://scripts/arena.gd")
const Gear = preload("res://scripts/gear_builder.gd")
const Mocap = preload("res://scripts/mocap.gd")
const Kit = preload("res://scripts/kit_materials.gd")
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
## Direction-aware locomotion. Explicit velocities avoid camera/teleport-driven
## guesses; legacy animate() callers retain measured-motion fallback.
var supplied_motion := Vector3.INF
var backward_weight := 0.0
var lateral_weight := 0.0
var lateral_side := 1.0
var previous_heading := INF
var angular_speed := 0.0
var pivot_weight := 0.0
var pivot_phase := 0.0
var pivot_direction := 0.0

func animate_motion(world_velocity: Vector3, delta: float, turn: float = 0.0, pushing: bool = true, braking: bool = false) -> void:
	supplied_motion=world_velocity
	animate(world_velocity.length(),delta,turn,pushing,braking)
	supplied_motion=Vector3.INF

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
## Surname sewn on the back (twill in the jersey shader).
var nameplate_text := ""
var phase := 0.0
var butterfly := 0.0 # Public drop command from rules/input; kept compatible.
var goalie_drop := 0.0 # Eased pose, shared by the visible pads and contact boxes.
var catch_hold := 0.0
var catch_close := 0.0
var shot_follow := 0.0
var shot_charge := 0.0
## Release starts at puck contact. Smooth attack, follow-through and recovery;
## skating continues underneath, and both hands remain solved onto one shaft.
var release_kind := ""
var release_age := 0.0
var release_duration := 0.6
var release_direction := Vector3.FORWARD
var release_weight := 0.0
var receive_hint:=false
var receive_target:=Vector3.ZERO
var receive_weight:=0.0
var receive_age:=-1.0
var receive_direction:=Vector3.ZERO
var receive_offset:=Vector3.ZERO
var pass_preparation:=0.0
var pass_load:=0.0

func offer_receive(world_point:Vector3)->void:
	if goalie or referee:return
	receive_hint=true;receive_target=world_point

func receive_puck(world_velocity:Vector3)->void:
	if goalie or referee:return
	receive_age=0.0
	receive_direction=(rig.global_basis.inverse()*Vector3(world_velocity.x,0,world_velocity.z)).normalized()

func update_receiving(delta:float)->void:
	receive_weight=lerpf(receive_weight,1.0 if receive_hint else 0.0,1-exp(-14*delta))
	receive_hint=false
	pass_load=lerpf(pass_load,pass_preparation,1-exp(-14*delta))
	pass_preparation=0.0
	receive_offset=Vector3.ZERO
	if receive_weight>0.001 and is_inside_tree():
		var local:=rig.to_local(receive_target)
		var desired:=Vector3(clampf(local.x,-0.75,0.35),0.029,clampf(local.z,0.65,1.35))
		receive_offset=(desired-stick_home(stick_intent)).limit_length(0.30)*receive_weight
	if receive_age>=0:
		receive_age+=delta
		var t:=clampf(receive_age/0.32,0.0,1.0)
		receive_offset+=receive_direction*0.12*sin(PI*t)
		if t>=1:receive_age=-1.0


func play_release(kind: String, world_direction: Vector3) -> void:
	if goalie or referee: return
	pass_preparation=0.0
	receive_hint=false
	release_kind=kind
	release_age=0.0
	release_duration=0.44 if kind=="pass" else (0.82 if kind=="slap" else 0.66)
	release_direction=(rig.global_basis.inverse()*Vector3(world_direction.x,0,world_direction.z)).normalized()
	release_weight=0.0

func update_release(delta: float) -> void:
	if release_kind.is_empty():
		release_weight=0.0
		return
	release_age=minf(release_age+delta,release_duration)
	var u:=release_age/release_duration
	# Contact starts from the normal stick pose, peaks early, then settles.
	var peak:=0.28
	release_weight=smoothstep(0.0,peak,u) if u<peak else 1.0-smoothstep(peak,1.0,u)
	if u>=1.0: release_kind=""

func release_blade_offset() -> Vector3:
	var pass_action:=release_kind=="pass"
	var height:=0.065 if pass_action else (0.66 if release_kind=="slap" else 0.38)
	var sweep:=0.23 if pass_action else 0.46
	return (release_direction*sweep+Vector3(0,height,0))*release_weight

var desired_stick := Vector2.ZERO
var stick_intent := Vector2.ZERO
var skill_lean:=0.0
var blade_velocity:=Vector3.ZERO
var last_blade_world:=Vector3.INF

static func stick_home(input:Vector2)->Vector3:
	# Backhand crosses the body centre; top hand repositions to keep reach.
	# Keep the blade ahead as the reference-guided top hand moves forward.
	return Vector3(-0.36-input.x*(0.94 if input.x<0 else 0.72),0.029,1.18-input.y*0.48)

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
var goalie_heel: MeshInstance3D
var heel_up:=Vector3.ZERO
var knees: Array[Vector3] = [Vector3.ZERO,Vector3.ZERO]
var pad_size := Vector3(Gear.PAD_WIDTH,Gear.PAD_LENGTH,0.14)
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
## Close-fitting cut-resistant neck fabric inside the jersey collar.
var neck_guard: MeshInstance3D
var sticks: Node3D
var pads: Array[Node3D] = []
## Legacy inspection handle; continuous pads no longer create detached rises.
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
const BoardHop = preload("res://scripts/board_hop.gd")
## Board hop (line change, board_hop.gd): progress 0..1 (-1 = not hopping),
## path in the parent's space, and the current tuck / crouch / lean weights.
var hop_u := -1.0
var hop_a := Vector3.ZERO
var hop_b := Vector3.ZERO
var hop_board_x := 0.0
var hop_state := {}
## Visual yaw when the hop started: the skater turns from it toward the hop
## facing over the first BoardHop.TURN_IN of the hop instead of snapping.
var hop_yaw0 := 0.0
## Stick lift (0..1) that keeps the blade out of the boards during a hop
## (board_clearance_carry(), rate-limited; -1 = take the first need as is).
var hop_guard := -1.0
## How firmly the top hand is planted on the board cap (0..1) this frame.
var hand_plant := 0.0
## Board hop stick carry (0..1, board_hop.gd "carry"): the stick is lifted off
## the ice with the blade up so it clears the boards; see carry_knob().
var stick_carry := 0.0
## Carried stick (rig space): the knob a little below the normal top-hand grip,
## in front of the top-hand hip, and the shaft angled up, forward and out to
## the blade side so the blade rides high over the boards.
const CARRY_KNOB := Vector3(-0.12,-0.30,0.02)
const CARRY_DIR := Vector3(-0.40,0.88,0.25)
const CARRY_LENGTH := 1.40
const PLANT_REACH_FADE := 0.10
## A planted arm may straighten fully (upper 0.28 + forearm 0.29 m).
const PLANT_REACH := 0.565
## Seated on the bench (arena_benches.gd drives these through pose_seated()):
## seat 0 = normal stance, 1 = sitting on the bench edge, thighs forward,
## skates on the floor. seat_lean leans the upper body over the knees,
## seat_yaw turns body and head toward the play (+ = rig +x), seat_slump drops
## the shoulders and head (conceded a goal), cheer stands him up with the
## arms (and the stick) raised. seat_stick: holds his stick leaning back
## against him, blade on the floor in front; otherwise the gloves rest on
## the knees.
var seat := 0.0
var seat_lean := 0.3
var seat_yaw := 0.0
var seat_slump := 0.0
var seat_stick := true
var seat_spread := 0.15
var cheer := 0.0
var cheer_pump := 0.0
## Up off the bench to go out on a line change: standing tall (less crouch
## than the skating stance), leaning a little forward, hands on the stick.
var stand_tall := 0.0
## Walking on the bench floor in skates (arena_benches.gd seat walk, needs
## stand_tall): walk_amount 0..1 blends the step in, walk_phase (radians,
## advanced by distance walked: one cycle = WALK_CYCLE metres, two steps)
## drives it, walk_dir is the direction of travel in rig space (x, z).
var walk_amount := 0.0
var walk_phase := 0.0
var walk_dir := Vector2(0,1)
const WALK_CYCLE := 0.72
## Share of the cycle each skate is planted (both down at the hand-overs).
const WALK_STANCE := 0.62
const WALK_LIFT := 0.075
const WALK_WIDTH := 0.13
## World spot each planted skate is pinned to (null in the swing), and where
## (world) it lifted off from, so a skate never glides over the floor -
## even while he turns and curves.
var walk_plants: Array = [null,null]
var walk_lift_from: Array = [Vector3.ZERO,Vector3.ZERO]
## Closing steps (0..1) once the walk has stopped (walk_phase frozen, body
## still, walk_amount still 1): each skate that is not already where it stands
## lifts and sets down in its standing spot, one after the other (a skate left
## in the air goes first), so the walk ends on two planted skates in the
## standing stance instead of sliding them there.
var walk_close := 0.0
var _close_from: Array = [Vector3.ZERO,Vector3.ZERO]
var _close_first := 0
var _closing := false
var _walk_ankle: Array = [Vector3.ZERO,Vector3.ZERO]
var _walk_fresh: Array = [true,true]

func walk_reset() -> void:
	walk_phase = 0.0
	walk_plants = [null,null]
	walk_close = 0.0
	_closing = false
	_walk_fresh = [true,true]

## Closing step for skate `i`: 0..1 progress at walk_close `c` (first skate
## over the first half, the other over the second).
static func close_step(c: float, first: bool) -> float:
	return clampf(c*2.0 if first else c*2.0-1.0,0.0,1.0)
## Hip joint drop from the standing rest pose to sitting on a 0.48 m seat
## (hip ~0.58 m up, 0.17 m behind the figure origin at the seat's front edge).
const SEAT_DROP := Vector3(0,-0.38,-0.17)
const SEAT_ANKLE := Vector3(0.15,0.145,0.33)
## Seated stick, held as players do on the bench: the top hand round the
## shaft in front of the chin, the stick nearly upright (blade on the floor a
## little ahead of the skates, SEAT_BLADE_AHEAD past the hand) and the shaft
## running on past the hand so the knob stands above the helmet and shows over
## the boards. SEAT_KNOB is the hand's grip point on the shaft.
const SEAT_KNOB := Vector3(-0.17,0.06,0.30)
const SEAT_STICK_LENGTH := 1.45
const SEAT_BLADE_AHEAD := 0.36
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
	uniform.set_shader_parameter("hide_neck",not referee and not goalie)
	uniform.set_shader_parameter("skin_detail",Kit.skin_texture())
	uniform.set_shader_parameter("has_skin_detail",true)
	for child in skeleton.get_children():
		if child is MeshInstance3D:
			preload("res://scripts/player_surface_materials.gd").apply(child,uniform)
	helmet = Node3D.new()
	rig.add_child(helmet)
	build_helmet()
	shirt = Node3D.new()
	rig.add_child(shirt)
	build_jersey()
	if not goalie and not referee:
		neck_guard = MeshInstance3D.new()
		neck_guard.name = "NeckGuard"
		neck_guard.mesh = ArrayMesh.new()
		neck_guard.material_override = Kit.neck_guard()
		rig.add_child(neck_guard)
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
		goalie_heel=MeshInstance3D.new();sticks.add_child(goalie_heel)
	grip_tape=block(sticks,Vector3(0.035,0.11,0.035),Vector3.ZERO,Color("#cad2d7"))
	for side in [1.0,-1.0]:
		var sleeve:=MeshInstance3D.new()
		sleeve.mesh=ArrayMesh.new()
		sleeve.material_override=Kit.sleeve(kit,accent,referee)
		rig.add_child(sleeve)
		cloth_sleeves.append(sleeve)
		if not referee:
			var pants := add_mesh(rig,Gear.pants_leg(side,kit,Color("#151c24"),0.0 if goalie else 1.0))
			pants.material_override=Kit.breezers()
			pant_legs.append(pants)
			if not goalie:
				var sock := add_mesh(rig,Gear.sock(kit,Color("#e4e8ea")))
				sock.material_override=Kit.socks(kit,Color("#e4e8ea"))
				socks.append(sock)
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
	blade_position=Vector3(-0.02,0.042,0.60) if goalie else Vector3(-0.36,0.029,1.05)
	if referee: sticks.visible=false
	pose(0,0)

func add_mesh(parent: Node3D, mesh: Mesh) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	parent.add_child(instance)
	return instance

func build_skate(parent: Node3D) -> void:
	add_mesh(parent,Gear.skate(goalie,goalie)).material_override=Kit.skate_boot()
	if not goalie:
		# Ankle cuff follows the shin (posed in pose()), so the leg always
		# enters the boot.
		var cuff := add_mesh(parent,Gear.skate_cuff())
		cuff.material_override=Kit.skate_boot()
		cuff.name = "Cuff"
		skate_cuffs.append(cuff)

func build_pad(parent: Node3D, side: float) -> void:
	# One uninterrupted shell. A sewn flex groove is not a hinged second pad.
	add_mesh(parent,Gear.goalie_pad(side,kit,accent))

## Stretches a unit-length limb shell between two joints, facing forward.
func fit_limb(shell: MeshInstance3D, top: Vector3, bottom: Vector3, girth: float) -> void:
	var axis:=top-bottom
	var up:=axis.normalized()
	var forward:=(Vector3.BACK-up*up.dot(Vector3.BACK)).normalized()
	shell.transform=Transform3D(Basis(up.cross(forward)*girth,up*axis.length(),forward*girth),top)

func pad_box() -> Array:
	return [Transform3D.IDENTITY,Vector3(pad_size.x,Gear.PAD_LENGTH,pad_size.z)]

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
		if goalie: mesh.surface_set_color(Gear.WHITE if a<0.25 else Color("#18212a"))
		for side in range(4):
			var next_:=posmod(side+1,4)
			var normal:Vector3=(p1[side]-p0[side]).cross(p0[next_]-p0[side]).normalized()
			for v in [p0[side],p1[side],p1[next_],p0[side],p1[next_],p0[next_]]:
				mesh.surface_set_normal(normal)
				mesh.surface_add_vertex(v)
	for t in [0.0,1.0]:
		if goalie: mesh.surface_set_color(Gear.WHITE if t==0 else Color("#18212a"))
		var points:=blade_section(t,length_,height_,thickness)
		for j in [0,1,2,0,2,3]:
			mesh.surface_set_normal(Vector3.RIGHT if t>0 else Vector3.LEFT)
			mesh.surface_add_vertex(points[j])
	mesh.surface_end()
	var instance:=MeshInstance3D.new()
	instance.mesh=mesh
	instance.material_override=material(Color.WHITE if goalie else Color("#18212a"),0.7)
	if goalie:
		(instance.material_override as StandardMaterial3D).vertex_color_use_as_albedo=true
		(instance.material_override as StandardMaterial3D).vertex_color_is_srgb=true
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
	# Sculpted shell (raised crown, vents, ear pieces, occipital lock) with the
	# same glossy material as before, fittings and a curved visor.
	var shell := add_mesh(helmet,Gear.skater_helmet())
	# Painted shell with a clearcoat; plastic/webbing fittings; clear visor.
	shell.material_override = Kit.helmet_shell(Color("#132434"))
	shell.name = "Shell"
	var fittings := add_mesh(helmet,Gear.helmet_fittings())
	fittings.material_override = Kit.helmet_liner()
	var crown := add_mesh(helmet,Gear.helmet_crown_panel())
	crown.name = "CrownPanel"
	crown.material_override = Kit.helmet_crown_panel()
	var ears := add_mesh(helmet,Gear.helmet_ear_guards())
	ears.name = "EarGuards"
	ears.material_override = Kit.helmet_ears()
	ears.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var hardware := add_mesh(helmet,Gear.helmet_hardware())
	hardware.name = "RetentionHardware"
	hardware.material_override = Kit.helmet_hardware()
	var strap := add_mesh(helmet,Gear.chinstrap())
	strap.name = "Chinstrap"
	strap.material_override = Kit.chinstrap()
	var visor := add_mesh(helmet,Gear.visor())
	visor.material_override = Kit.visor()
	visor.name = "Visor"
	# Clear polycarbonate must not become an opaque shadow mask over the face.
	visor.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

## Torso of the sweater in rest (shirt) space: half-width and front/back
## half-depths by height. Shoulder pads under the sweater give the wide,
## squared shoulder line; the hem hangs and flares over the pants.
const JERSEY_HEM := 0.865
const JERSEY_COLUMNS := 56
const JERSEY_WIDTH := [[0.86,0.258],[0.95,0.240],[1.02,0.224],[1.10,0.221],[1.20,0.230],[1.28,0.246],[1.36,0.266],[1.42,0.282],[1.46,0.276],[1.49,0.250],[1.51,0.200],[1.53,0.128],[1.555,0.072]]
const JERSEY_FRONT := [[0.86,0.180],[0.97,0.160],[1.08,0.154],[1.20,0.164],[1.30,0.176],[1.38,0.166],[1.45,0.140],[1.50,0.104],[1.555,0.064]]
const JERSEY_BACK := [[0.86,0.180],[0.97,0.156],[1.08,0.150],[1.22,0.160],[1.34,0.172],[1.42,0.166],[1.48,0.140],[1.52,0.094],[1.555,0.062]]
var jersey: MeshInstance3D

## Rest-space point of the sweater surface at angle a (0 = +X, PI/2 = front)
## and height y, with static cloth folds.
func jersey_point(a: float, y: float, scale_: float = 1.0) -> Vector3:
	var Prof = Gear.GearProfiles
	var w: float = Prof.curve(JERSEY_WIDTH,y)*scale_
	var front: float = Prof.curve(JERSEY_FRONT,y)*scale_
	var back: float = Prof.curve(JERSEY_BACK,y)*scale_
	if goalie:
		w *= 1.08
		front *= 1.12
		back *= 1.10
	# Rounder at the waist, squarer across the shoulder pads.
	var square := 1.0+0.10*smoothstep(1.18,1.42,y)*pow(sin(2.0*a),2)
	var c := cos(a)
	var s := sin(a)
	var x := c*square*w
	var z := s*square*(front if s>0 else back)
	var radial := Vector2(x,z).normalized()
	var fold := 0.0
	# Hem: loose vertical folds that open up toward the bottom edge.
	var hem := smoothstep(1.06,JERSEY_HEM,y)
	fold += hem*(0.0075*sin(7.0*a+0.6)+0.0045*sin(13.0*a+2.1)+0.003*sin(19.0*a+0.3))
	# Under the arms: horizontal creases where the sweater bunches at the sides.
	var side_ := smoothstep(0.70,0.95,absf(c))
	fold -= side_*smoothstep(1.16,1.24,y)*smoothstep(1.40,1.32,y)*0.0055*(0.5+0.5*sin((y-1.16)*95.0+a*2.0))
	# Diagonal pull folds across the back from the shoulder pads.
	if s < 0:
		fold -= 0.004*smoothstep(0.2,0.8,-s)*smoothstep(1.15,1.25,y)*smoothstep(1.42,1.32,y)*(0.5+0.5*sin((y*38.0+absf(c)*14.0)))
	return Vector3(x+radial.x*fold,y,z+radial.y*fold-0.02)

## Top edge of the sweater: a V-neck at the front, a round collar elsewhere.
func jersey_neck(a: float) -> float:
	return preload("res://scripts/jersey_profile.gd").neck(a)

## Skin weights for a rest-space point: the hem follows the hips, the body
## the spine chain up to the chest, the shoulder pads partly the upper arms.
func jersey_weights(p: Vector3) -> Array:
	var root_w := 0.45*smoothstep(1.10,0.90,p.y)
	var chain := [[1.0,"spine05"],[1.10,"spine04"],[1.18,"spine03"],[1.26,"spine02"],[1.34,"spine01"]]
	var lower: String = chain[0][1]
	var upper: String = chain[0][1]
	var t := 0.0
	if p.y >= chain[-1][0]:
		lower = chain[-1][1]
		upper = lower
	elif p.y > chain[0][0]:
		for k in range(chain.size()-1):
			if p.y <= chain[k+1][0]:
				lower = chain[k][1]
				upper = chain[k+1][1]
				t = (p.y-chain[k][0])/(chain[k+1][0]-chain[k][0])
				break
	var arm_w := 0.35*smoothstep(0.17,0.28,absf(p.x))*smoothstep(1.37,1.45,p.y)
	var rest_w := 1.0-root_w-arm_w
	var out := {"root":root_w}
	out[lower] = out.get(lower,0.0)+rest_w*(1.0-t)
	out[upper] = out.get(upper,0.0)+rest_w*t
	if arm_w > 0.0: out["upperarm01.L" if p.x>0 else "upperarm01.R"] = arm_w
	return [out.keys(),out.values()]

func build_jersey() -> void:
	var sections := [Vector3(0.24,0.98,0.16),Vector3(0.22,1.10,0.155),Vector3(0.25,1.31,0.17),Vector3(0.27,1.44,0.14),Vector3(0.11,1.50,0.09)]
	if goalie:
		# Oversized sweater over a chest protector with shoulder floaters.
		sections = [Vector3(0.255,0.95,0.17),Vector3(0.25,1.10,0.185),Vector3(0.28,1.30,0.20),Vector3(0.30,1.44,0.17),Vector3(0.13,1.53,0.10)]
	jersey_sections = sections
	# One continuous sweater: rolled hem inside, hem, body, shoulders, V-neck
	# and a rolled collar, as rings of JERSEY_COLUMNS points.
	var b = Gear.MeshBuilder.new()
	var rings := []
	var ring_colors := []
	var ring_uvs := []
	var levels := []  # [y or -1 for neck rows, v along the neck rise, scale, dy, uv_y]
	var hem := JERSEY_HEM-(0.03 if goalie else 0.0)
	levels.append([hem+0.03,0.0,0.965,0.0,0.97])
	levels.append([hem-0.004,0.0,1.004,0.0,0.975])
	var body_rows := 24
	for k in range(body_rows+1):
		var y := lerpf(hem,1.40,float(k)/body_rows)
		levels.append([y,0.0,1.0,0.0,0.98+(y-hem)])
	for k in range(1,7):
		levels.append([-1.0,float(k)/6.0,1.0,0.0,0.0])
	levels.append([-1.0,1.0,1.025,0.003,1.02])
	levels.append([-1.0,1.0,1.04,-0.003,1.02])
	levels.append([-1.0,1.0,0.98,-0.009,1.02])
	for level: Array in levels:
		var ring := PackedVector3Array()
		var uv_ring := PackedVector2Array()
		var cols := PackedColorArray()
		for j in range(JERSEY_COLUMNS):
			var a := TAU*j/JERSEY_COLUMNS
			var y: float = level[0]
			if y < 0.0: y = lerpf(1.40,jersey_neck(a),level[1])
			var p := jersey_point(a,y)
			var centre := Vector3(0,p.y,-0.02)
			p = centre+(p-centre)*float(level[2])+Vector3(0,level[3],0)
			ring.append(p)
			# Symmetric u so the referee's vertical stripes have no seam.
			var u := absf(wrapf(a-PI*0.5,-PI,PI))/PI
			uv_ring.append(Vector2(0.075 if level[4]>=1.02 and referee else u,(0.98+(y-hem)) if level[0] < 0.0 and level[4]==0.0 else level[4]))
			cols.append(Color.WHITE)
		rings.append(ring)
		ring_uvs.append(uv_ring)
		ring_colors.append(cols)
	b.add_loft(rings,ring_colors,false,false,ring_uvs)
	var bones := PackedInt32Array()
	var weights := PackedFloat32Array()
	var skin := Skin.new()
	var bind_names: Array[String] = ["root","spine05","spine04","spine03","spine02","spine01","upperarm01.L","upperarm01.R"]
	for bone_name in bind_names:
		skin.add_named_bind(bone_name,(rest[bone_name] as Transform3D).affine_inverse())
	for v: Vector3 in b.vertices:
		var bw := jersey_weights(v)
		for k in range(4):
			if k < bw[0].size():
				bones.append(bind_names.find(bw[0][k]))
				weights.append(bw[1][k])
			else:
				bones.append(0)
				weights.append(0.0)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = b.vertices
	arrays[Mesh.ARRAY_NORMAL] = b.normals
	arrays[Mesh.ARRAY_TEX_UV] = b.uvs
	# UV2 for the kit shader's layout: u = angle round the body (0.75 = centre
	# back, unmirrored so numbers read correctly), v = rest height in metres.
	var uv2 := PackedVector2Array()
	for v: Vector3 in b.vertices:
		uv2.append(Vector2(fposmod(atan2(v.z+0.02,v.x),TAU)/TAU,v.y))
	arrays[Mesh.ARRAY_TEX_UV2] = uv2
	arrays[Mesh.ARRAY_BONES] = bones
	arrays[Mesh.ARRAY_WEIGHTS] = weights
	arrays[Mesh.ARRAY_INDEX] = b.indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var instance := MeshInstance3D.new()
	instance.name = "Jersey"
	instance.mesh = mesh
	instance.skin = skin
	instance.skeleton = NodePath("..")
	jersey = instance
	# Knit polyester sweater: sewn hem/sleeve stripes, collar and twill
	# number/nameplate drawn in the fabric (scripts/kit_materials.gd).
	apply_jersey_material()
	# Skinned to the rig's skeleton: bends and twists with the posed torso.
	skeleton.add_child(instance)

## Jersey material for the current number and nameplate (shared per colourway,
## number and name; the generated textures are shared by everyone).
func apply_jersey_material() -> void:
	if not is_instance_valid(jersey): return
	var hem := JERSEY_HEM-(0.03 if goalie else 0.0)
	jersey.material_override = Kit.jersey(kit,accent,number,nameplate_text,referee,hem,0.0)

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
		save_weights[k] = lerpf(save_weights[k],1.0 if k==kind else 0.0,1.0-exp(-maxf(0,delta)*(18.0 if k==kind else 6.0)))

## Called only by a confirmed front-pocket puck contact, not by save selection.
func secure_catch() -> void:
	catch_hold=2.5

func release_catch() -> void:
	catch_hold=0.0

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
	# Backward C-cuts stay low: the push sweeps outward and forward rather
	# than playing the forward toe-off in reverse. One leg recovers at a time.
	if backward_weight>0.001:
		var u:=cycle/STANCE if cycle<STANCE else (cycle-STANCE)/(1.0-STANCE)
		var drive:=smoothstep(0.0,1.0,u) if cycle<STANCE else 1.0-smoothstep(0.0,1.0,u)
		var back:=Vector3(side*lerpf(0.14,0.46,drive),0.115,lerpf(-0.12,0.20,drive))
		ankle=ankle.lerp(glide.lerp(back,amount),backward_weight)
		pitch=lerpf(pitch,0.0,backward_weight)
	# Lateral edge steps: lead foot opens, trailing foot gathers. No crossing
	# or airborne running pose is substituted for a shuffle.
	if lateral_weight>0.001:
		var open:=sin(PI*cycle)*sin(PI*cycle)
		var lead:=side*lateral_side>0.0
		var shift:=lateral_side*(0.18 if lead else 0.08)*open
		var lateral_foot:=Vector3(side*0.18+shift,0.115+0.018*maxf(0.0,sin(TAU*cycle)),glide.z*0.5)
		lateral_foot.x=side*maxf(0.085,side*lateral_foot.x)
		ankle=ankle.lerp(glide.lerp(lateral_foot,amount),lateral_weight)
		pitch=lerpf(pitch,0.0,lateral_weight)
	# Keep the runner's toe and heel on or above the ice whatever the pitch:
	# a toe-down foot pivots on its toe, so the heel and ankle rise.
	ankle.y = soft_max(ankle.y,ankle_floor(pitch),0.012)
	return {
		"ankle": ankle,
		"ext": ext*amount,
		"lift": lift*amount,
		# Toe turns out as the leg drives.
		"yaw": lerpf(lerpf(side*(0.06+0.42*ext)*amount,-side*(0.08+0.30*ext)*amount,backward_weight),lateral_side*0.42*amount,lateral_weight),
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
		drop = Vector3(0,lerpf(-0.33,-0.55,goalie_drop),lerpf(-0.24,-0.04,goalie_drop))
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
		drop.x+=skill_lean*0.075
		drop.y-=absf(skill_lean)*0.09
		drop.y+=0.035*backward_weight
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
	# Board hop: gather low, then knees tuck to the chest over the boards and
	# the legs extend again for the landing (board_hop.gd sample()).
	if not goalie and not hop_state.is_empty():
		var tuck: float = hop_state.tuck
		var crouch: float = hop_state.crouch
		for i in range(2):
			var side := 1.0 if i==0 else -1.0
			var f: Dictionary = stride[i]
			var base := Vector3(side*0.15,0.115,0.02)
			f.ankle = (f.ankle as Vector3).lerp(base,maxf(crouch,tuck))
			f.ankle = (f.ankle as Vector3).lerp(Vector3(side*0.13,BoardHop.TUCK_ANKLE_Y,0.20),tuck)
			f.yaw = f.yaw*(1.0-tuck)
			f.pitch = lerpf(f.pitch,-0.35,tuck)
			f.edge = f.edge*(1.0-maxf(crouch,tuck))
			f.ext = f.ext*(1.0-maxf(crouch,tuck))
			f.lift = f.lift*(1.0-maxf(crouch,tuck))
		drop = drop.lerp(Vector3(0,-0.31,-0.04),crouch)
		drop = drop.lerp(Vector3(0,-0.10,-0.06),tuck)
		shoulder_turn = shoulder_turn*(1.0-maxf(crouch,tuck))
	# Bench: sit on the seat edge, feet forward on the floor; or stand tall to cheer.
	if not goalie and (seat > 0.0 or cheer > 0.0 or stand_tall > 0.0):
		for i in range(2):
			var side := 1.0 if i==0 else -1.0
			var f: Dictionary = stride[i]
			f.ankle = (f.ankle as Vector3).lerp(Vector3(side*seat_spread,SEAT_ANKLE.y,SEAT_ANKLE.z+0.03*side),seat)
			for key in ["yaw","pitch","edge","ext","lift"]: f[key] = float(f[key])*(1.0-seat)
		drop = drop.lerp(Vector3(0,-0.05,0),maxf(cheer,stand_tall)*(1.0-seat)).lerp(SEAT_DROP,seat)
		shoulder_turn = shoulder_turn*(1.0-maxf(seat,maxf(cheer,stand_tall)))
		# Walking on the bench floor: alternate skate lifts and plants, the
		# hips riding over the planted skate and highest as it passes under.
		var walk := walk_amount*stand_tall*(1.0-seat)
		if walk > 0.0:
			var dir := Vector3(walk_dir.x,0,walk_dir.y).normalized()
			# Smooth sway and bob, in step with the plants: over the left
			# skate at its mid-stance, over the right half a cycle later; up
			# at each mid-stance, down through the hand-overs.
			var mid := fposmod(walk_phase/TAU-WALK_STANCE*0.5,1.0)*TAU
			var shift := cos(mid)
			var rise := cos(2.0*mid)
			var close := clampf(walk_close,0.0,1.0)
			var to_rig := rig.global_transform.affine_inverse()
			if close > 0.0 and not _closing:
				# Walk over: note where each skate is; one in the air (or else
				# the one further from where it stands) steps in first.
				_closing = true
				var far := [0.0,0.0]
				for i in range(2):
					var st := walk_step(walk_phase,i)
					_close_from[i] = _walk_ankle[i]
					far[i] = Vector2(_walk_ankle[i].x-stride[i].ankle.x,_walk_ankle[i].z-stride[i].ankle.z).length()+(10.0 if float(st.lift) > 0.0 else 0.0)
				_close_first = 0 if far[0] >= far[1] else 1
			if _closing:
				for i in range(2):
					var f: Dictionary = stride[i]
					var stance: Vector3 = f.ankle
					var from: Vector3 = _close_from[i]
					var s := close_step(close,i == _close_first)
					var gap := Vector2(from.x-stance.x,from.z-stance.z).length()
					var e := smoothstep(0.0,1.0,s)
					# Up before it moves over, over before it comes down.
					f.ankle = from.lerp(stance,smoothstep(0.12,0.85,s))
					f.ankle.y = lerpf(from.y,stance.y,e)
					# Lifted over the step (lower for a short one); one that is
					# already in place just settles.
					if gap > 0.01: f.ankle.y += WALK_LIFT*clampf(gap/0.12,0.4,1.0)*sin(PI*e)
					for key in ["yaw","pitch","edge","ext","lift"]: f[key] = float(f[key])*(1.0-walk*(1.0-e))
				var settle := 1.0-smoothstep(0.0,1.0,close)
				drop += Vector3(shift*0.035,0.01*rise-0.01,0)*walk*settle
			else:
				for i in range(2):
					var side := 1.0 if i==0 else -1.0
					var st := walk_step(walk_phase,i)
					var f: Dictionary = stride[i]
					var at := Vector3(side*WALK_WIDTH,0.115+float(st.lift),0.02)+dir*float(st.along)
					var target := (f.ankle as Vector3).lerp(at,walk)
					if float(st.lift) == 0.0:
						# His first step leaves from where the skate stood.
						if walk_plants[i] == null and _walk_fresh[i]: walk_plants[i] = rig.global_transform*(f.ankle as Vector3)
						# Planted: pinned where it touched down - from the very
						# first step (it starts planted where he stood).
						if walk_plants[i] == null: walk_plants[i] = rig.global_transform*target
						var pinned: Vector3 = to_rig*(walk_plants[i] as Vector3)
						pinned.y = target.y
						f.ankle = pinned
						walk_lift_from[i] = walk_plants[i]
					else:
						# Swing: from where it lifted to its next landing spot.
						walk_plants[i] = null
						_walk_fresh[i] = false
						var w := float(st.swing)
						# (Leaves from where it was planted in the world, so it does
						# not drag along the floor with the body as it lifts.)
						var from: Vector3 = to_rig*(walk_lift_from[i] as Vector3)
						f.ankle = from.lerp(target,smoothstep(0.0,1.0,w))
						f.ankle.y = target.y
					for key in ["yaw","pitch","edge","ext","lift"]: f[key] = float(f[key])*(1.0-walk)
					_walk_ankle[i] = f.ankle
				drop += Vector3(shift*0.035,0.01*rise-0.01,0)*walk
	var cap := {}
	if mocap_weight>0 and not mocap.is_empty():
		cap = Mocap.sample(mocap,mocap_time,mocap_loop)
	var idle := {}
	if goalie and not idle_data.is_empty():
		idle = Mocap.sample(idle_data,idle_time)
		# Captured weight shift and bounce of a keeper set in his stance.
		var shift:Vector3=(idle.points.Hips-idle_data.mean.points.Hips)*MOCAP_HIP_HEIGHT*(1.0-goalie_drop)
		drop += Vector3(shift.x*0.25,shift.y*0.8,0)
	var capture_weight := mocap_weight*mocap_strength
	posed_drop = drop
	var root_pose := root_rest
	root_pose.origin += drop
	override_pose("root",root_pose)
	bend = Basis(Vector3.RIGHT,lerpf(0.52,0.26,goalie_drop) if goalie else 0.50+minf(speed/40,0.18))
	if not goalie and not referee:
		bend=Basis(Vector3.BACK,-skill_lean*0.23)*bend
		bend=Basis(Vector3.UP,(0.12 if release_kind=="pass" else 0.32)*release_weight)*bend
	if shoulder_turn != 0.0: bend = Basis(Vector3.UP,shoulder_turn)*bend
	# Stop: the upper body leans back against the skid.
	if stop_w > 0.0: bend = Basis(Vector3.BACK,-stop_side*0.24*stop_w)*bend
	if not hop_state.is_empty(): bend = Basis(Vector3.RIGHT,0.38*float(hop_state.lean))*bend
	if not goalie and (seat > 0.0 or cheer > 0.0 or stand_tall > 0.0):
		var tall := maxf(cheer,stand_tall)
		var upright := lerpf(0.22,0.06,cheer/maxf(tall,0.001))
		var lean := lerpf(seat_lean+0.3*seat_slump,upright,tall*(1.0-seat))
		bend = Basis(Vector3.UP,seat_yaw*0.55*(1.0-0.6*seat_slump))*Basis(Vector3.RIGHT,lerpf(0.5,lean,maxf(seat,tall)))
	if goalie:
		var reach_lean: float = save_weights.glove*clampf(save_target.x-0.45,0.0,0.5)-save_weights.blocker*clampf(-save_target.x-0.45,0.0,0.5)
		var pad_lean: float = save_weights.pad_left-save_weights.pad_right
		if reach_lean != 0.0 or pad_lean != 0.0:
			bend = Basis(Vector3.BACK,-reach_lean*0.6-pad_lean*0.18)*bend
	if not idle.is_empty():
		var sway:=Quaternion(idle_data.mean.dirs.spine,idle.dirs.spine)
		bend = Basis(Quaternion.IDENTITY.slerp(sway,0.7*(1.0-goalie_drop)))*bend
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
	# Bench: the head turns to follow the play and drops when slumped.
	var look := Basis.IDENTITY
	if not goalie and (seat > 0.0 or cheer > 0.0 or stand_tall > 0.0):
		look = Basis(Vector3.UP,seat_yaw*(1.0-0.6*seat_slump))*Basis(Vector3.RIGHT,lerpf(-0.08*seat,0.55,seat_slump)-0.2*cheer)
		head_pose.basis = look*head.basis
	override_pose("head",head_pose)
	helmet.position = posed_head+look*(Vector3(0,0.095,0.015) if goalie else Gear.HELMET_OFFSET)
	helmet.basis = look
	if neck_guard: update_neck_guard()
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
		if goalie: ankle = Vector3(side*lerpf(0.27,0.64,goalie_drop),0.115,lerpf(0.0,0.03,goalie_drop))
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
			else:
				# No optional strafe clip installed: a short alternating recovery
				# step, driven by measured lateral distance, never crossing feet.
				var cycle:=fposmod(shuffle_time+float(i)*0.5,1.0)
				var swing:=smoothstep(0.58,0.98,cycle)
				var offset:=lerpf(0.05,-0.05,minf(cycle/0.58,1.0)) if cycle<0.58 else lerpf(-0.05,0.05,swing)
				ankle.x+=signf(lateral)*offset*shuffle_weight
				ankle.y+=0.025*sin(PI*swing)*shuffle_weight
		if goalie and pivot_weight>0.001:
			# Alternate unweighting a skate through the turn. The stance stays
			# wide; pivoting does not rotate the pads independently or detach them.
			var swivel:=TAU*pivot_phase+float(i)*PI
			ankle.y+=0.018*maxf(0.0,sin(swivel))*pivot_weight*(1.0-goalie_drop)
		feet[i] = ankle
		var knee := knee_position(hip,ankle,Vector3(-side*0.12,0,1) if goalie else Vector3(0,0,1),0.44,0.45)
		# Pads meet edge to edge at the knees rather than crossing.
		if goalie: knee.x=side*maxf(side*knee.x,Gear.PAD_WIDTH*0.5+0.036+0.035*shuffle_weight)
		# Butterfly: knees together on the ice, shins flared out behind them.
		if goalie:
			knee=knee.lerp(Vector3(side*0.30,0.13,0.22),goalie_drop)
			# Shins flare as the knees drop, so the knees stay apart mid-drop.
			knee.x+=side*0.045*sin(PI*goalie_drop)
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
			var reach:=lerpf(0.68,0.52,goalie_drop) if goalie else 0.94
			fit_limb(pant_legs[i],hip+Vector3(side*(0.03+goalie_drop*0.02),0.10,0),hip.lerp(knee,reach),fill)
		var foot_pose: Transform3D = rest["foot"+suffix]
		foot_pose.origin = ankle
		var pivot_yaw:=pivot_direction*0.14*cos(TAU*pivot_phase+float(i)*PI)*pivot_weight*(1.0-goalie_drop) if goalie else 0.0
		var boot := Vector3(0,pivot_yaw,0)
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
		skates[i].rotation = Vector3(0,side*lerpf(0.12,2.65,smoothstep(0.0,0.6,goalie_drop))+pivot_yaw,0) if goalie else boot
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
			# Standing shell follows the shin; in butterfly it rolls as one piece,
			# face (+Z) toward the shooter and inner edge flat on the ice.
			var shin:Vector3=(knee-ankle).normalized()
			var pad_up:=shin.slerp(Vector3(signf(shin.x),0,0),smoothstep(0.15,0.85,goalie_drop)).normalized()
			var face:Vector3=(Vector3.BACK-pad_up*pad_up.dot(Vector3.BACK)).normalized()
			pads[i].basis=Basis(pad_up.cross(face),pad_up,face)
			# Ankle/boot-channel anchor, with room for the skate behind the face.
			pads[i].position=ankle-shin*Gear.PAD_ANKLE+face*0.13
			# Keep complete thigh rises side by side. Move the entire shell;
			# never rotate or shrink a detached upper section to hide overlap.
			var bounds: AABB=pads[i].get_child(0).mesh.get_aabb()
			var inner:=INF
			for c in range(8): inner=minf(inner,side*(pads[i].transform*bounds.get_endpoint(c)).x)
			pads[i].position.x+=side*maxf(0,0.018-inner)
			# In a wide extension the boot stays behind the pad toe instead of
			# protruding past its end. Fit the shell, not a hidden/shortened skate.
			var boot_end:=0.0
			for foot_point in [Vector3(-0.045,0.04,0.21),Vector3(0.045,0.04,0.21)]:
				var in_pad: Vector3=pads[i].transform.affine_inverse()*(skates[i].transform*foot_point)
				boot_end=maxf(boot_end,-Gear.PAD_LENGTH*0.5+0.012-in_pad.y)
			pads[i].position-=pad_up*boot_end*smoothstep(0.6,1.0,goalie_drop)
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
		var wrist := bottom_grip(shoulder) if i==1 else stick_grip()
		var grip_point := wrist
		if not goalie and not referee:
			# The shaft runs through the closed fist, which sits 3.5 cm past the
			# wrist joint (the glove origin): put the wrist on the elbow side of
			# the grip point, within the arm's reach.
			# Offset across the shaft (toward the arm), so the shaft crosses the palm.
			var shaft_dir:=(stick_heel(stick_grip())-stick_grip()).normalized()
			var to_arm:=shoulder-wrist
			to_arm-=shaft_dir*shaft_dir.dot(to_arm)
			wrist = wrist+to_arm.normalized()*GLOVE_FIST
			if shoulder.distance_to(wrist)>STICK_ARM_REACH:
				wrist = shoulder+(wrist-shoulder).normalized()*STICK_ARM_REACH
		if referee: wrist=Vector3(side*0.32,0.96,0.03)
		if not goalie and not referee and (seat > 0.0 or cheer > 0.0):
			# Bench: gloves rest on top of the knees (no stick), and go up to cheer.
			var w := 0.0
			if not seat_stick:
				var rest_ := knees[i]+Vector3(-side*0.02,0.085,-0.06)
				wrist = wrist.lerp(rest_,seat)
				w = seat
			var pump := sin(cheer_pump+i*1.3)*0.08
			var up_ := shoulder+Vector3(side*0.14,0.50+pump,0.10)
			wrist = wrist.lerp(shoulder+(up_-shoulder).limit_length(STICK_ARM_REACH),cheer)
			w = maxf(w,cheer)
			grip_point = grip_point.lerp(wrist,w)
		if i==0: hand_plant=plant_weight(shoulder)
		if i==0 and hand_plant>0.0:
			# Board hop: the top hand lets go of the stick and plants on the cap.
			# The fist rests on the cap; the wrist sits a fist's length up the arm.
			var planted:=shoulder+(hop_hand_target()-shoulder).limit_length(PLANT_REACH)
			grip_point=grip_point.lerp(planted,hand_plant)
			wrist=wrist.lerp(planted+(shoulder-planted).normalized()*GLOVE_FIST,hand_plant)
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
			wrist=Vector3(0.58+posed_drop.x,0.83-goalie_drop*0.16+0.10*sin(PI*goalie_drop)+goalie_save_height,0.62) if i==0 else stick_grip()
			var catch_w: float = save_weights.glove
			if i==0 and catch_w > 0.0:
				# Glove save: the catcher shoots out to the puck's line, pocket open.
				var aim := Vector3(clampf(save_target.x,0.22,1.0),clampf(save_target.y,0.35,1.65),0.62)
				wrist = wrist.lerp(reach(shoulder,aim),catch_w)
			if i==0:
				goalie_gloves[i].position=wrist+Vector3(0.0,0.03,0.035)
				goalie_gloves[i].rotation=Vector3(-0.12-0.35*catch_w*clampf(save_target.y-0.9,0.0,0.7),0.32+0.25*catch_w,-0.12-0.3*catch_w)
			else:
				goalie_gloves[i].position=wrist+Vector3(-0.085,0.06,0.04)
				goalie_gloves[i].rotation=Vector3(-0.10,-0.28,0.06)
		# Elbows: the top-hand elbow points out and back a little; the bottom
		# arm hangs nearly straight, elbow tucked in toward the body.
		var top_elbow_y:=lerpf(0.20,-0.25,maxf(seat,stick_carry))
		var pole := Vector3(side*0.6,-0.8,-0.1) if goalie else (Vector3(side*0.45,top_elbow_y,-1.0) if i==0 else Vector3(side*0.5,-0.2,-0.8))
		if referee: pole = Vector3(side,0,-0.3)
		if captured_elbow != Vector3.ZERO:
			pole = pole.lerp((captured_elbow-(shoulder+wrist)*0.5).normalized(),capture_weight)
		# Bottom hand and glove stay on the outside of the jersey.
		if not goalie and not referee and captured_elbow == Vector3.ZERO and i==0: wrist = clear_hand(wrist,0.075)
		var elbow := clear_elbow(shoulder,wrist,pole)
		posed_wrists[i]=wrist
		posed_elbows[i]=elbow
		if not goalie: fit_glove(i,wrist,elbow,grip_point if not referee and captured_elbow==Vector3.ZERO else Vector3.INF)
		update_cloth_sleeve(cloth_sleeves[i],shoulder,elbow,wrist)
		align_bone("upperarm01"+suffix,"lowerarm01"+suffix,shoulder,elbow)
		align_bone("lowerarm01"+suffix,"wrist"+suffix,elbow,wrist)
		var wrist_pose: Transform3D = rest["wrist"+suffix]
		wrist_pose.origin = wrist
		override_pose("wrist"+suffix,wrist_pose)
	rig.rotation.z = clampf(turn,-0.13,0.13)
	# Stop: hips (and the whole rig) turn across the line of travel.
	rig.rotation.y = PI+stop_yaw*stop_w
	update_stick()

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
		var moved:=Vector3.ZERO
		if supplied_motion!=Vector3.INF: moved=supplied_motion
		elif last_world!=Vector3.INF and delta>0: moved=(world-last_world)/delta
		moved.y=0
		# Teleports/faceoff resets never create a fictitious stride or pivot.
		if moved.length()>=30: moved=Vector3.ZERO
		travel=travel.lerp(moved,1-exp(-15*delta))
		var body_frame:=Basis(Vector3.UP,global_rotation.y+PI)
		var local_velocity:Vector3=body_frame.inverse()*moved
		lateral=lerpf(lateral,local_velocity.x,1-exp(-10*delta))
		var direction:=local_velocity.normalized()
		var moving:=smoothstep(0.15,0.8,local_velocity.length())
		backward_weight=lerpf(backward_weight,smoothstep(0.15,0.8,-direction.z)*moving,1-exp(-9*delta))
		lateral_weight=lerpf(lateral_weight,smoothstep(0.45,0.9,absf(direction.x))*moving,1-exp(-9*delta))
		if absf(local_velocity.x)>0.1:lateral_side=lerpf(lateral_side,signf(local_velocity.x),1-exp(-10*delta))
		var heading:=global_rotation.y
		var angle:=angle_difference(previous_heading,heading) if previous_heading!=INF else 0.0
		angular_speed=angle/maxf(delta,0.0001) if absf(angle)<0.9 else 0.0
		if absf(angular_speed)>0.1:pivot_direction=lerpf(pivot_direction,signf(angular_speed),1-exp(-12*delta))
		previous_heading=heading
		pivot_weight=lerpf(pivot_weight,smoothstep(0.5,3.0,absf(angular_speed))*(1.0-goalie_drop),1-exp(-12*delta))
		pivot_phase+=absf(angular_speed)*delta/0.65
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
		shuffle_weight=move_toward(shuffle_weight,clampf((absf(lateral)-0.25)/1.5,0,1)*(1.0-goalie_drop),delta*5)
		var data:Dictionary=shuffle_data[0 if lateral>0 else 1]
		if not data.is_empty():
			# Advance the footwork by distance covered so steps match the slide.
			var stride:float=maxf(0.1,data.travel.length()*MOCAP_HIP_HEIGHT/data.length)
			shuffle_time+=delta*absf(lateral)/stride
		else: shuffle_time+=delta*absf(lateral)/0.28

## Starts a board hop from `a` to `b` (parent space, see board_hop.gd) over the
## board plane x = board_x; the body stays put while this visual travels.
## `carried`: the stick is already up (a fresh player getting off the bench).
func start_hop(a: Vector3, b: Vector3, board_x: float, carried := false) -> void:
	hop_a = a
	hop_b = b
	hop_board_x = board_x
	hop_u = 0.0
	hop_yaw0 = rotation.y
	hop_guard = 1.0 if carried else -1.0
	hop_state = BoardHop.sample(0.0,a,b,board_x)
	position = a

## Board hop hand plant: the board-cap point (rig space) the top hand presses
## on, and how much it is planted (the hop's plant curve, faded to nothing as
## the cap passes out of arm's reach so the hand never floats above it).
func hop_hand_target() -> Vector3:
	return (transform*rig.transform).affine_inverse()*(hop_state.hand as Vector3)

func plant_weight(shoulder: Vector3) -> float:
	if goalie or referee or hop_state.is_empty(): return 0.0
	var w: float = hop_state.get("plant",0.0)
	if w <= 0.0: return 0.0
	var d := shoulder.distance_to(hop_hand_target())
	return w*clampf((PLANT_REACH-d)/PLANT_REACH_FADE,0.0,1.0)

func hopping() -> bool:
	return hop_u >= 0.0 and hop_u < 1.0

## True once a started hop has reached its end (until cancel_hop()).
func hop_finished() -> bool:
	return hop_u >= 1.0

## Ends any hop and puts the visual back on its body.
func cancel_hop() -> void:
	hop_u = -1.0
	hop_state = {}
	position = Vector3.ZERO

func update_hop(delta: float) -> void:
	if hop_u < 0.0: return
	hop_u = minf(hop_u+delta/BoardHop.DURATION,1.0)
	hop_state = BoardHop.sample(hop_u,hop_a,hop_b,hop_board_x)
	position = hop_state.offset
	var f: Vector3 = hop_state.facing
	var yaw := atan2(-f.x,-f.z)
	rotation.y = lerp_angle(hop_yaw0,yaw,BoardHop.turn_weight(hop_u,angle_difference(hop_yaw0,yaw)))
	if hop_u >= 1.0:
		# Landed: stand normally where the hop ended.
		hop_state = {}

func animate(speed: float, delta: float, turn: float = 0, pushing: bool = true, braking: bool = false) -> void:
	if goalie:
		goalie_drop=smoothstep(0.0,1.0,clampf(butterfly,0,1))
		catch_hold=maxf(0,catch_hold-delta)
		catch_close=lerpf(catch_close,1.0 if catch_hold>0 else 0.0,1.0-exp(-delta*(22 if catch_hold>0 else 7)))
		if not goalie_gloves.is_empty():
			(goalie_gloves[0].get_child(0) as MeshInstance3D).set_blend_shape_value(0,catch_close)
	update_hop(delta)
	if hop_u >= 0.0:
		speed = 0.0
		pushing = false
		braking = false
	update_layers(delta)
	update_stop(speed,delta,braking)
	brake_turn = move_toward(brake_turn,1.0 if braking and not goalie else 0.0,delta*6)
	update_release(delta)
	update_receiving(delta)
	shot_follow = release_weight
	stick_intent=stick_intent.lerp(desired_stick,1-exp(-14*delta))
	blade_position=Vector3(-0.02+goalie_drop*0.05,0.042,0.76-goalie_drop*0.04+0.035*sin(PI*goalie_drop)) if goalie else stick_home(stick_intent)
	if not goalie and not referee: blade_position+=release_blade_offset()+receive_offset+Vector3(0,0,-0.18)*pass_load
	# Stop: the stick reaches out in front for balance.
	if not goalie: blade_position += Vector3(-0.04,0,0.16)*stop_blend()
	# Board hop: lift the stick clear of the boards (blade rises first, so it
	# never sweeps through the dasher on the way up or down).
	stick_carry = float(hop_state.get("carry",0.0)) if not goalie and not referee and not hop_state.is_empty() else 0.0
	# Stood close to the boards (or facing them as the hop starts) the stick on
	# the ice would reach into them: lift it at least as far as that needs.
	if not goalie and not referee and not hop_state.is_empty():
		var need := board_clearance_carry()
		hop_guard = need if hop_guard < 0.0 else move_toward(hop_guard,need,STICK_GUARD_RATE*delta)
		stick_carry = maxf(stick_carry,hop_guard)
	if stick_carry>0.0:
		var up := 1.0-pow(1.0-stick_carry,3.0)
		var carried := carry_blade()
		blade_position = Vector3(lerpf(blade_position.x,carried.x,stick_carry),lerpf(blade_position.y,carried.y,up),lerpf(blade_position.z,carried.z,stick_carry))
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
	if is_inside_tree() and delta>0:
		var point:=get_blade_world()
		var diff:=point-last_blade_world if last_blade_world!=Vector3.INF else Vector3.ZERO
		blade_velocity=(diff/delta).limit_length(20.0) if last_blade_world!=Vector3.INF and diff.length()<1.5 else (supplied_motion if supplied_motion!=Vector3.INF else Vector3.ZERO)
		last_blade_world=point
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
	apply_jersey_material()

func set_nameplate(value: String) -> void:
	nameplate_text=value.to_upper()
	apply_jersey_material()

func stick_grip() -> Vector3:
	if goalie:
		# Mid-drop the stick is pushed out ahead of the closing pads.
		var grip := Vector3(lerpf(-0.36,-0.24,goalie_drop)+posed_drop.x,0.60-goalie_drop*0.12,0.65+0.035*sin(PI*goalie_drop))
		var block_w: float = save_weights.blocker
		if block_w > 0.0:
			# Blocker save: the stick hand punches out to the puck's line and the
			# paddle follows it.
			var aim := Vector3(clampf(save_target.x,-1.0,-0.28),clampf(save_target.y,0.45,1.45),0.50)
			grip = grip.lerp(reach(shoulder_of(1),aim),block_w)
		return grip
	# Top hand on the knob in front of the top-hand hip: upper arm down, elbow
	# back beside the body, forearm angled down to the fist so the shaft crosses the palm
	# (not held end-on like a torch). Rides with the shoulders as the skater
	# crouches, and moves with stickhandling and shots.
	var grip := shoulder_of(0)+Vector3(-0.11-stick_intent.x*0.20-shot_follow*0.12,-0.30+shot_charge*0.06,0.23-stick_intent.y*0.05-shot_charge*0.12+shot_follow*0.22)
	grip.x-=0.18*maxf(0.0,-stick_intent.x)
	# Pull the top hand back/up during a deep drag, keeping the two cuffs
	# separated as the blade returns toward the skates.
	grip+=Vector3(0,0.065,-0.08)*maxf(0.0,stick_intent.y)
	# Stop: hands come down with the hips and push the stick out front.
	grip += receive_offset*0.25+Vector3(0,0,-0.055)*pass_load
	grip += Vector3(0,-0.10,0.06)*stop_blend()
	# Board hop: the knob comes down to the hip as the stick is carried.
	if stick_carry>0.0: grip = grip.lerp(carry_knob(),stick_carry)
	# Bench: knob held up in front of the chin, stick leaning back against him.
	if seat>0.0: grip = grip.lerp(seat_knob(),seat)
	# Pulling the stick in never drives the top hand into the hip pads.
	grip.z = maxf(grip.z,shoulder_of(0).z+0.15)
	# The top hand holds the stick in front of the jersey, never inside it.
	return clear_hand(grip,0.075)

func seat_knob() -> Vector3:
	return shoulder_of(0)+SEAT_KNOB

## Bench stick: blade on the floor (local y 0.07: the rubber floor is 4 cm
## up) straight in front, one stick length from the knob.
func seat_blade() -> Vector3:
	var knob := seat_knob()
	return Vector3(knob.x+0.04,0.07,knob.z+SEAT_BLADE_AHEAD)

## Knob end of the stick shaft (past the top hand), in the shaft's parent
## space: lets tests check the seated stick stands above the helmet.
func stick_knob_end() -> Vector3:
	return stick_shaft.position+stick_shaft.basis.y.normalized()*stick_shaft.scale.y*0.5

## Bench figures (arena_benches.gd): pose the seated/cheering stance without
## the skating layers. Cheap enough to call only when the inputs change.
func pose_seated() -> void:
	stick_intent = Vector2.ZERO
	desired_stick = Vector2.ZERO
	blade_position = Vector3(-0.36,0.029,1.05).lerp(seat_blade(),seat)
	# Getting up to go out on a line change: stick comes up as for the hop.
	if stick_carry>0.0: blade_position = blade_position.lerp(carry_blade(),stick_carry)
	raised_stick = cheer if seat_stick else 0.0
	pose(0,0)

## One skate's place in the bench walk cycle: `along` (metres along the
## direction of travel from under the hip), `lift` (blade height above the
## floor) and `load` (1 while it carries the weight, eased at the hand-overs).
## Planted, it slides back exactly as fast as the body moves forward, so it
## stays put on the floor; in the swing it comes through low and lands ahead.
static func walk_step(phase: float, i: int) -> Dictionary:
	var c := fposmod(phase/TAU+float(i)*0.5,1.0)
	var half := WALK_CYCLE*WALK_STANCE*0.5
	if c < WALK_STANCE:
		var u := c/WALK_STANCE
		# Weight comes on just after the plant and goes as the other lands.
		var load := smoothstep(0.0,0.2,u)*(1.0-smoothstep(0.8,1.0,u))
		return {"along":lerpf(half,-half,u),"lift":0.0,"load":load,"swing":0.0}
	var w := (c-WALK_STANCE)/(1.0-WALK_STANCE)
	# Swing: the skate leaves and lands at rest on the floor (in the world),
	# so along the body it starts and ends moving back at walking speed.
	var body := WALK_CYCLE*(1.0-WALK_STANCE)
	var along := -half+(2.0*half+body)*smoothstep(0.0,1.0,w)-body*w
	return {"along":along,"lift":WALK_LIFT*sin(PI*w),"load":0.0,"swing":w}

## Board hop: how far the stick must be carried (0..1) so a blade left on the
## ice does not reach into the dasher - the blade's distance past the face of
## the boards on the side the skater is on, with a STICK_BOARD_MARGIN lead-in.
## Checked at the current heading and, ahead of the turn into the boards, at
## the hop's facing (lifted over STICK_LEAD_IN of the hop) so the stick is
## already coming up as the turn swings the blade toward the boards.
const STICK_BOARD_MARGIN := 0.35
const STICK_LEAD_IN := 0.02
const STICK_GUARD_RATE := 3.5
func board_clearance_carry() -> float:
	var need := blade_board_need(transform)
	if hop_u < BoardHop.VAULT_START:
		var f: Vector3 = hop_state.facing
		var ahead := Transform3D(Basis(Vector3.UP,atan2(-f.x,-f.z)),position)
		need = maxf(need,blade_board_need(ahead)*BoardHop.smooth(hop_u/STICK_LEAD_IN))
	return need

func blade_board_need(xf: Transform3D) -> float:
	var mid := hop_board_x-BoardHop.BOARD_DEPTH*0.5
	var side := signf(position.x-mid)
	if side == 0.0: side = 1.0
	var face := mid+side*BoardHop.BOARD_DEPTH*0.5
	var reach := -INF
	# Toe and heel of the blade on the ice, in the body's (parent) space.
	var to_parent := xf*rig.transform
	for k in [-0.5,0.5]:
		var p: Vector3 = to_parent*(blade_position+Vector3(stick_blade_length*k,0,0))
		reach = maxf(reach,(face-p.x)*side)
	return BoardHop.smooth((reach+STICK_BOARD_MARGIN)/STICK_BOARD_MARGIN)

## Board hop carried stick: knob and mid-blade points (rig space).
func carry_knob() -> Vector3:
	return shoulder_of(0)+CARRY_KNOB

func carry_blade() -> Vector3:
	var d := CARRY_DIR.normalized()
	var toe := Vector3(d.x,0,d.z).normalized()
	return carry_knob()+d*CARRY_LENGTH+toe*stick_blade_length*0.48

## Heel of the blade (where the shaft meets it) for a top-hand position.
func stick_heel(top: Vector3) -> Vector3:
	var toe_dir:=stick_toe_dir(top,blade_position)
	toe_dir=stick_toe_dir(top,blade_position-toe_dir*stick_blade_length*0.48)
	return blade_position-toe_dir*stick_blade_length*0.48

## Bottom hand: a point ON the shaft, 27-42 % of the way from the knob to the
## heel (a real grip is two to three hand-widths apart), as low as the arm
## comfortably reaches from this shoulder. The fist closes round the shaft.
const GLOVE_FIST := 0.035
## Shoulder to wrist joint with the elbow just short of locked.
const STICK_ARM_REACH := 0.565
const BOTTOM_REACH := STICK_ARM_REACH+GLOVE_FIST
func bottom_grip(shoulder: Vector3) -> Vector3:
	var top:=stick_grip()
	var heel:=stick_heel(top)
	var best:=top.lerp(heel,0.27)
	for k in range(21):
		var t:=lerpf(0.27,0.42,k/20.0)
		var p:=top.lerp(heel,t)
		if shoulder.distance_to(p)<=BOTTOM_REACH: best=p
	return best

func update_stick() -> void:
	var top:=stick_grip()
	# The blade lies flat on the ice in the shaft's plane: it runs on from the
	# heel in the direction the shaft leans (away from the hands), as on a
	# real stick, instead of folding back under the shaft. blade_position (the
	# puck pocket, used by gameplay) stays mid-blade.
	var toe_dir:=stick_toe_dir(top,blade_position)
	toe_dir=stick_toe_dir(top,blade_position-toe_dir*stick_blade_length*0.48)
	var heel_fraction:=0.5 if goalie else 0.48
	var bottom:=blade_position-toe_dir*stick_blade_length*heel_fraction
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
	var beyond:=0.42 if goalie else 0.06
	if not goalie and seat>0.0:
		# Bench: the hand is round the shaft, the rest of the stick runs on
		# past it to the knob (full stick length from the heel).
		var held:=seat*(1.0-raised_stick)*(1.0-stick_carry)
		beyond=lerpf(beyond,maxf(beyond,SEAT_STICK_LENGTH-axis.length()),held)
	stick_shaft.scale=Vector3(1,axis.length()+beyond,1)
	stick_shaft.position+=axis.normalized()*beyond*0.5
	if goalie:
		var paddle_top:Vector3=bottom.lerp(top,0.97)
		goalie_paddle.position=(bottom+paddle_top)*0.5
		goalie_paddle.basis=stick_shaft.basis
		goalie_paddle.scale=Vector3(1,bottom.distance_to(paddle_top),1)
	var flat:=Basis(toe_dir,Vector3.UP,toe_dir.cross(Vector3.UP))
	stick_blade.basis=flat.slerp(stick_shaft.basis.orthonormalized(),maxf(raised_stick,stick_carry))
	stick_blade.position=bottom+stick_blade.basis*Vector3(stick_blade_length*heel_fraction,0,0)
	if goalie:
		goalie_heel.position=bottom
		var up:=axis.normalized()
		if heel_up.distance_to(up)>0.002 or goalie_heel.mesh==null:
			goalie_heel.mesh=Gear.goalie_stick_heel(up,toe_dir)
			heel_up=up
	grip_tape.position=top+axis.normalized()*maxf(beyond-0.06,0.0)
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

func get_catch_pocket_world() -> Vector3:
	return goalie_gloves[0].to_global(Gear.CATCHER_POCKET_POINT)

func catch_contact_offset() -> Vector3:
	return Gear.CATCHER_POCKET_POINT-Gear.CATCHER_CONTACT_CENTER

func get_goalie_gear() -> Dictionary:
	# Actor-local transforms: the physical and visible gear share one source.
	var frame:=transform*rig.transform
	return {
		"Mask":{"transform":frame*helmet.transform,"size":Vector3(0.24,0.30,0.29),"zone":"mask","bounce":0.30},
		"Torso":{"transform":frame*torso_pose,"size":Vector3(0.56,0.59,0.33),"zone":"body","bounce":0.08},
		"PadLeft":{"transform":frame*pads[0].transform*pad_box()[0],"size":pad_box()[1],"zone":"pad","bounce":0.20},
		"PadRight":{"transform":frame*pads[1].transform*pad_box()[0],"size":pad_box()[1],"zone":"pad","bounce":0.20},
		"Catcher":{"transform":frame*goalie_gloves[0].transform*Transform3D(Basis(),Gear.CATCHER_CONTACT_CENTER),"size":Gear.CATCHER_SIZE,"zone":"catcher","bounce":0.02},
		"Blocker":{"transform":frame*goalie_gloves[1].transform,"size":Vector3(0.205,0.385,0.05),"zone":"blocker","bounce":0.48},
		"GoalieBlade":{"transform":frame*stick_blade.transform,"size":Vector3(0.39,0.08,0.036),"zone":"stick","bounce":0.40},
		"Paddle":{"transform":frame*Transform3D(goalie_paddle.basis.orthonormalized(),goalie_paddle.position),"size":Vector3(0.088,goalie_paddle.scale.y,0.026),"zone":"stick","bounce":0.35}
	}

func build_player_glove(parent: Node3D) -> void:
	# Thumbs on opposite sides so each hand is a mirror of the other.
	add_mesh(parent,Gear.skater_glove(kit,1.0 if skater_gloves.size()==0 else -1.0)).material_override=Kit.gloves()

## Closes glove i round the stick at the wrist: cuff (+Y) back along the
## forearm toward the elbow, shaft through the fist along local X, back of
## the hand (+Z) facing away from the body.
## Hole through the closed fist (glove space): the shaft runs through it.
const GLOVE_HOLE := Vector3(0,-0.035,-0.005)
func fit_glove(i: int, wrist: Vector3, elbow: Vector3, grip_point := Vector3.INF) -> void:
	var up := (elbow-wrist).normalized()
	var shaft := (stick_grip()-stick_heel(stick_grip())).normalized()
	# A hand planted on the board cap (board hop) lies along the boards.
	if i==0 and hand_plant>0.0: shaft=shaft.lerp(Vector3.RIGHT if shaft.x>=0.0 else Vector3.LEFT,hand_plant).normalized()
	var x: Vector3
	if grip_point==Vector3.INF:
		x = shaft-up*up.dot(shaft)
		if x.length_squared() < 0.0001: x = up.cross(Vector3.BACK)
		x = x.normalized()
	else:
		# The shaft runs diagonally across the palm (real grips are not square
		# to the forearm): split the difference between the forearm-square
		# fist and the shaft (35 % of the way), so the cuff stays on the forearm and the stick
		# still lies in the fingers.
		var square := shaft-up*up.dot(shaft)
		square = square.normalized() if square.length_squared()>0.0001 else up.cross(Vector3.BACK).normalized()
		var across:=shaft if shaft.dot(square)>0.0 else -shaft
		# Limit wrist cock at extreme drags instead of pulling the cuff off
		# the forearm to force an arbitrary percentage of shaft alignment.
		var cock:=minf(0.35,0.42/maxf(square.angle_to(across),0.001))
		x = square.slerp(across,cock).normalized()
		up = (up-x*x.dot(up))
		up = up.normalized() if up.length_squared()>0.0001 else x.cross(Vector3.BACK).normalized()
	var z := x.cross(up)
	var away := wrist-torso_pose.origin
	# Attached hockey grip: top-hand thumb points toward the blade; the
	# mirrored bottom-hand thumb points back toward the top hand. Choosing
	# palm roll from body distance alone can reverse the top hand like a putter.
	var reverse := x.dot(-shaft)<0.0 if grip_point!=Vector3.INF and hand_plant<0.01 else z.dot(away)<0.0
	if reverse:
		x = -x
		z = -z
	var basis_ := Basis(x,up,z)
	# Seat the fist on the shaft: the hole through the fingers is on the grip point.
	var origin := wrist if grip_point==Vector3.INF else grip_point-basis_*GLOVE_HOLE
	skater_gloves[i].transform = Transform3D(basis_,origin)

const SLEEVE_ROWS := 14
const SLEEVE_SIDES := 22
## Short fabric neck guard, with both ends attached in the posed bind frame.
## A world-up offset from the head stretched the old guard during a skating lean.
func update_neck_guard() -> void:
	var bottom: Vector3 = shirt.transform*Vector3(0,1.505,0.006)
	var top: Vector3 = posed_head+shirt.transform.basis*(Vector3(0,1.575,0.006)-(rest["head"] as Transform3D).origin)
	var old:Array=neck_guard.get_meta("pose",[])
	if old.size()==2 and bottom.is_equal_approx(old[0]) and top.is_equal_approx(old[1]):return
	neck_guard.set_meta("pose",[bottom,top])
	var axis:=(top-bottom).normalized()
	var across:=axis.cross(Vector3.FORWARD).normalized()
	if across.length_squared()<0.01: across=Vector3.RIGHT
	var depth:=axis.cross(across).normalized()
	var st:=SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	const SIDES:=20
	const ROWS:=6
	# Radius: flares into the collar, snug round the neck, rolled top edge.
	var radii:=[0.067,0.063,0.060,0.057,0.056,0.056,0.055]
	var rings:=[]
	for r in range(ROWS+1):
		var t:=float(r)/ROWS
		var c:=bottom.lerp(top,t)
		var ring:=[]
		for k in range(SIDES+1):
			var a:=TAU*k/SIDES
			var radial:=across*cos(a)+depth*sin(a)*0.92
			ring.append([c+radial*float(radii[r]),radial.normalized()])
		rings.append(ring)
	for r in range(ROWS):
		for k in range(SIDES):
			for v in [rings[r][k],rings[r+1][k],rings[r+1][k+1],rings[r][k],rings[r+1][k+1],rings[r][k+1]]:
				st.set_normal(v[1])
				st.add_vertex(v[0])
	var mesh:ArrayMesh=neck_guard.mesh
	mesh.clear_surfaces()
	st.commit(mesh)

func update_cloth_sleeve(instance: MeshInstance3D, shoulder: Vector3, elbow: Vector3, wrist: Vector3) -> void:
	# A continuous curved cloth envelope follows the exact arm IK targets.
	var old:Array=instance.get_meta("arm_pose",[])
	if old.size()==3 and shoulder.is_equal_approx(old[0]) and elbow.is_equal_approx(old[1]) and wrist.is_equal_approx(old[2]):return
	instance.set_meta("arm_pose",[shoulder,elbow,wrist])
	var vertices:=PackedVector3Array()
	var normals:=PackedVector3Array()
	var uvs:=PackedVector2Array()
	var indices:=PackedInt32Array()
	var rows:=SLEEVE_ROWS
	var cols:=SLEEVE_SIDES
	# Bend direction at the elbow: the sleeve bunches on the inside of the bend.
	var bend_dir:=(elbow-(shoulder+wrist)*0.5)
	var bent:=clampf(bend_dir.length()/0.12,0.0,1.0)
	bend_dir=bend_dir.normalized() if bend_dir.length()>0.001 else Vector3.ZERO
	var across:=Vector3.ZERO
	var tuck:=(torso_pose.origin+Vector3(0,0.20,0)-shoulder)
	tuck=tuck.normalized()*0.035 if tuck.length()>0.001 else Vector3.ZERO
	# Path: straight upper arm and forearm joined by a short rounded elbow
	# (not one long curve, which read as a bent noodle).
	var l1:=shoulder.distance_to(elbow)
	var l2:=elbow.distance_to(wrist)
	var d1:=(elbow-shoulder)/maxf(l1,0.001)
	var d2:=(wrist-elbow)/maxf(l2,0.001)
	var fillet:=minf(0.055,minf(l1,l2)*0.4)
	var total:=l1+l2
	var elbow_t:=l1/maxf(total,0.001)
	for row in range(rows+1):
		var t:=float(row)/rows
		var arc:=t*total
		var center:Vector3
		var axis:Vector3
		if arc<l1-fillet:
			center=shoulder+d1*arc
			axis=d1
		elif arc>l1+fillet:
			center=elbow+d2*(arc-l1)
			axis=d2
		else:
			var q:=(arc-(l1-fillet))/(2.0*fillet)
			var p0:=elbow-d1*fillet
			var p2:=elbow+d2*fillet
			center=(1-q)*(1-q)*p0+2*(1-q)*q*elbow+q*q*p2
			axis=(2*(1-q)*(elbow-p0)+2*q*(p2-elbow)).normalized()
		# The armhole starts in under the shoulder pad, so the sleeve grows out
		# of the sweater instead of butting against it.
		center+=tuck*(1.0-smoothstep(0.0,0.16,t))
		# Parallel-transport the ring frame so the sleeve never twists.
		if row==0:
			across=axis.cross(Vector3.FORWARD).normalized()
			if across.length_squared()<0.01:across=axis.cross(Vector3.RIGHT).normalized()
		else:
			across=(across-axis*across.dot(axis)).normalized()
		var depth:=axis.cross(across).normalized()
		# Sleeve over shoulder cap, upper arm, elbow pad and forearm: it flares
		# into the armhole, follows the arm and ends loose inside the glove cuff.
		var u:=t/maxf(elbow_t,0.01) if t<=elbow_t else 1.0+(t-elbow_t)/maxf(1.0-elbow_t,0.01)
		var radius_:float
		if u<=1.0: radius_=lerpf(0.074,0.060,smoothstep(0.0,0.45,u))
		else: radius_=lerpf(0.058,0.050,u-1.0)
		# Elbow pad under the sleeve.
		radius_+=0.008*exp(-pow((u-1.0)/0.16,2))
		if goalie: radius_*=1.2
		for column in range(cols+1):
			var angle:=TAU*column/cols
			var radial:Vector3=across*cos(angle)+depth*sin(angle)
			var r:=radius_
			# Folds: rings of creases on the inside of the elbow bend, light
			# lengthwise drape folds elsewhere.
			var inner:=maxf(0.0,-radial.dot(bend_dir))
			r-=0.006*bent*inner*exp(-pow((t-0.5)/0.12,2))*(0.5+0.5*sin(t*70.0))
			r+=0.0025*sin(angle*5.0+t*3.0)*(1.0-exp(-pow((t-0.5)/0.1,2)))
			vertices.append(center+radial*r)
			normals.append(radial)
			uvs.append(Vector2(float(column)/cols,t))
			if row<rows and column<cols:
				var a:=row*(cols+1)+column
				indices.append_array(PackedInt32Array([a,a+cols+1,a+cols+2,a,a+cols+2,a+1]))
	var arrays:=[]
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=vertices
	arrays[Mesh.ARRAY_NORMAL]=normals
	arrays[Mesh.ARRAY_TEX_UV]=uvs
	arrays[Mesh.ARRAY_INDEX]=indices
	var mesh:ArrayMesh=instance.mesh
	mesh.clear_surfaces()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
