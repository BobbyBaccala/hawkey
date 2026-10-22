extends Node3D
var practice_pass_actor: CharacterBody3D
var practice_input := preload("res://scripts/controller_input.gd").new()
const NetShooting = preload("res://scripts/net_shooting.gd")
const PuckControl=preload("res://scripts/puck_control.gd")
const PuckSkills=preload("res://scripts/puck_skills.gd")
const Skating = preload("res://scripts/skating.gd")
const Arena = preload("res://scripts/arena.gd")
const Skater = preload("res://scripts/skater_visual.gd")
const RenderLook = preload("res://scripts/render_look.gd")
var ice_marks
var arena: Node3D
var player: CharacterBody3D
var teammate: CharacterBody3D
var puck: RigidBody3D
var camera: Camera3D
var hud: Label
var help: Label
var status: Label
var power: ProgressBar
var player_visual: Node3D
var teammate_visual: Node3D
var goalkeepers: Array[CharacterBody3D] = []
var goalie_visuals: Array[Node3D] = []
var velocity := Vector3.ZERO
var aim := Vector3.FORWARD
var charge := 0.0
var cooldown := 0.0
var goals := 0
var away_goals := 0
var shots := 0
var passes := 0
var saves := 0
var previous_puck := Vector3.ZERO
var debug := false
var paused := false
var reduce_motion:=false
var show_puck_indicator:=false
var puck_marker: Control
var rating := 85.0
var zoom := 0.8
var arena_title := "HAWKEY PRACTICE CENTRE"
var wide_camera := false
var goal_timer := 0.0
var elapsed := 0.0
var camera_target := Vector3.ZERO
var pickup_owner := false
var audio: Node3D
var selection: MeshInstance3D

var pickup_lock_actor:CharacterBody3D
var pickup_lock_time:=0.0
var release_in_flight:=false

func lock_released_puck(actor:CharacterBody3D)->void:
	pickup_lock_actor=actor;pickup_lock_time=0.28;release_in_flight=true

func control_acquired()->void:
	if release_in_flight:cooldown=0.0
	release_in_flight=false

func pickup_blocked(actor:CharacterBody3D)->bool:
	return pickup_lock_time>0 and is_instance_valid(pickup_lock_actor) and actor==pickup_lock_actor

func advance_pickup_lock(delta:float)->void:
	pickup_lock_time=maxf(0.0,pickup_lock_time-delta)
	if pickup_lock_time<=0:pickup_lock_actor=null

func skills_for(actor:CharacterBody3D):
	if not actor.has_meta("puck_skills"):actor.set_meta("puck_skills",PuckSkills.new())
	return actor.get_meta("puck_skills")

func has_player_control()->bool:return pickup_owner

func request_player_skill(kind:String,side:float=1.0)->bool:
	return skills_for(player).request(kind,side) if has_player_control() and not paused else false

func prepare_skills(actor:CharacterBody3D,delta:float,raw:Vector2,owns:bool,protect:bool=false):
	var skills=skills_for(actor)
	skills.advance(delta,owns);skills.protecting=protect and owns
	var v=actor.get_child(1)
	v.desired_stick=skills.stick(raw,actor.velocity.length(),owns)
	v.skill_lean=skills.lean() if owns else 0.0
	return skills

func assist_carried_puck(actor:CharacterBody3D,delta:float)->void:
	var age:float=float(actor.get_meta("control_age",0.0))+delta
	actor.set_meta("control_age",age)
	var v=actor.get_child(1)
	puck.linear_velocity=PuckControl.control_velocity(puck.position,puck.linear_velocity,actor.velocity,v.get_blade_world(),delta,v.blade_velocity,age)

func make_skater(pos: Vector3, color: Color, jersey: String, is_goalie: bool = false, accent: Color = Color(0,0,0,0)) -> CharacterBody3D:
	var body := CharacterBody3D.new()
	add_child(body)
	body.position = pos
	body.motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	body.collision_layer = 2
	body.collision_mask = 19 | (32 if is_goalie else 0)
	var collision := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.34 if not is_goalie else 0.58
	shape.height = 1.7
	if is_goalie:
		var pads := BoxShape3D.new()
		pads.size = Vector3(1.0,1.3,0.45)
		collision.shape = pads
		collision.position.y = 0.66
	else:
		collision.shape = shape
		collision.position.y = 0.88
	body.add_child(collision)
	var visual := Skater.new()
	visual.kit = color
	visual.accent = accent
	visual.number = jersey
	visual.goalie = is_goalie
	body.add_child(visual)
	body.set_meta("goalie",is_goalie)
	add_puck_collision(body,is_goalie)
	return body

func _ready() -> void:
	var preferences=preload("res://scripts/game_settings.gd").new()
	preferences.load_settings()
	practice_input.deadzone=preferences.values.deadzone
	reduce_motion=preferences.values.reduce_motion
	show_puck_indicator=preferences.values.puck_indicator
	if get_script().resource_path == "res://scripts/lab.gd": Input.joy_connection_changed.connect(on_practice_connection)
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	# Tonemap, grade, glow, SSAO/SSIL/SSR, haze: scripts/render_look.gd.
	RenderLook.configure_environment(world.environment)
	add_child(world)
	var sun := DirectionalLight3D.new()
	# Arena lighting comes from overhead rigs: a steep key with soft shadows.
	sun.rotation_degrees = Vector3(-80,-20,0)
	sun.light_energy = 0.42
	RenderLook.configure_key_light(sun)   # soft PSSM shadows, tuned bias
	add_child(sun)
	# Render look extras: thin upper-bowl haze (Forward+ volumetric fog), a
	# soft vignette under the HUD, and contact shadows under every skater.
	add_child(RenderLook.make_bowl_haze())
	add_child(RenderLook.make_vignette())
	add_child(preload("res://scripts/contact_shadows.gd").new())
	# Per-zone overhead pools and side rim lights (scripts/arena_lighting.gd).
	var lighting = preload("res://scripts/arena_lighting.gd").new()
	add_child(lighting)
	arena = Arena.new()
	add_child(arena)
	lighting.tag_environment(arena)
	# Skate cuts carved into the ice behind every skater.
	ice_marks = preload("res://scripts/ice_marks.gd").new()
	ice_marks.name = "IceMarks"
	add_child(ice_marks)
	arena.set_cut_map(ice_marks.texture)   # ice plus painted lines and emblem
	# Skaters mirrored in the polished ice (scripts/ice_reflection.gd).
	var reflection = preload("res://scripts/ice_reflection.gd").new()
	add_child(reflection)
	reflection.attach(arena, world.environment)
	ice_marks.material = arena.ice_surface_material
	ice_marks.paint_materials = arena.paint_materials
	player = make_skater(Vector3(0,0,0),Color("#116c9e"),"17")
	player_visual = player.get_child(1)
	teammate = make_skater(Vector3(6,0,-7),Color("#116c9e"),"28")
	teammate_visual = teammate.get_child(1)
	for end_ in [-1.0,1.0]:
		var goalie := make_skater(Vector3(0,0,end_ * (Arena.GOAL_LINE - 1.0)),Color("#b3162c") if end_ < 0 else Color("#164a9a"),"31",true,Color("#1b2a4a") if end_ < 0 else Color("#e8eef5"))
		goalie.rotation.y = PI if end_ < 0 else 0
		goalkeepers.append(goalie)
		goalie_visuals.append(goalie.get_child(1))
	puck = preload("res://scripts/puck.gd").new()
	puck.mass = 0.17
	puck.continuous_cd = true
	puck.gravity_scale = 1
	puck.axis_lock_linear_y = false
	puck.linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	puck.linear_damp = 0
	puck.angular_damp = 0.8
	puck.axis_lock_angular_x = false
	puck.axis_lock_angular_z = false
	puck.collision_layer = 4
	arena.puck = puck
	puck.collision_mask = 9
	puck.contact_monitor = true
	puck.max_contacts_reported = 4
	var pm := PhysicsMaterial.new()
	pm.friction = 0.0
	pm.bounce = 0.12
	puck.physics_material_override = pm
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.0381
	cylinder.bottom_radius = 0.0381
	cylinder.height = 0.0254
	var mesh := MeshInstance3D.new()
	mesh.mesh = cylinder
	mesh.material_override = arena.mat(Color("#10151b"),0.4)
	puck.add_child(mesh)
	var collision := CollisionShape3D.new()
	# Convex disk avoids documented CylinderShape3D contact bugs at puck scale.
	var shape := ConvexPolygonShape3D.new()
	shape.margin=0.001
	var points:=PackedVector3Array()
	for y in [-0.0127,0.0127]:
		for i in range(32):
			var angle:=TAU*i/32
			points.append(Vector3(cos(angle)*0.0381,y,sin(angle)*0.0381))
	shape.points=points
	collision.shape = shape
	puck.add_child(collision)
	add_child(puck)
	puck.body_entered.connect(_on_puck_contact)
	selection = MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 0.43
	ring.outer_radius = 0.49
	selection.mesh = ring
	selection.material_override = arena.mat(Color("#22bcdf"))
	add_child(selection)
	camera = Camera3D.new()
	add_child(camera)
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = 48
	camera.far = 160
	camera.position = Vector3(0,23,23)
	camera.look_at(Vector3(0,0,-4))
	build_hud()
	audio = preload("res://scripts/hockey_audio.gd").new()
	add_child(audio)
	audio.level=preferences.values.get("sfx_volume",1.0)
	reset_puck()
	# Screenshot automation is opt-in and only runs in a real rendering session.
	if "--portrait" in OS.get_cmdline_user_args():
		zoom = 0.25
	if "--wide" in OS.get_cmdline_user_args():
		wide_camera = true
	if "--capture" in OS.get_cmdline_user_args():
		capture_preview()

func build_hud() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)
	puck_marker=preload("res://scripts/puck_indicator.gd").new();canvas.add_child(puck_marker)
	var top := PanelContainer.new()
	top.position = Vector2(30,24)
	top.size = Vector2(560,82)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#101e30")
	style.border_color = Color("#28afcf")
	style.border_width_bottom = 3
	style.content_margin_left = 22
	style.content_margin_top = 10
	style.content_margin_right = 22
	style.content_margin_bottom = 12
	style.corner_radius_bottom_right = 10
	top.add_theme_stylebox_override("panel",style)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(top)
	hud = Label.new()
	hud.add_theme_font_size_override("font_size",23)
	top.add_child(hud)
	status = Label.new()
	status.position = Vector2(32,118)
	status.add_theme_font_size_override("font_size",18)
	status.add_theme_color_override("font_color",Color("#76deef"))
	canvas.add_child(status)
	var bottom := PanelContainer.new()
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_top = -84
	var bs := StyleBoxFlat.new()
	bs.bg_color = Color(0.025,0.055,0.10,0.96)
	bs.content_margin_left = 30
	bs.content_margin_top = 15
	bottom.add_theme_stylebox_override("panel",bs)
	canvas.add_child(bottom)
	help = Label.new()
	help.add_theme_font_size_override("font_size",16)
	bottom.add_child(help)
	power = ProgressBar.new()
	power.position = Vector2(32,150)
	power.size = Vector2(180,10)
	power.show_percentage = false
	power.max_value = 1
	canvas.add_child(power)
	var menu := Button.new()
	menu.text = "Return to menu"
	menu.position = Vector2(32, 175)
	menu.pressed.connect(func():
		load("res://scripts/match.gd").return_to_title = true
		get_tree().change_scene_to_file("res://main.tscn"))
	canvas.add_child(menu)
	for item in [hud,status,help,menu]: item.add_theme_font_override("font",preload("res://scripts/interface_font.gd").get_font(false))
	menu.add_theme_font_size_override("font_size",16)

func capture_preview() -> void:
	await get_tree().create_timer(2).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/tmp/hawkey-preview.png")
	get_tree().quit()

func reset_puck() -> void:
	pickup_lock_actor=null;pickup_lock_time=0.0;release_in_flight=false
	charge = 0
	pickup_owner = false
	puck.position = player.position + aim * 1.05 + Vector3(0,0.017,0)
	puck.linear_velocity = Vector3.ZERO
	puck.angular_velocity = Vector3.ZERO
	previous_puck = puck.position
	cooldown = 0.15

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventJoypadMotion or event is InputEventJoypadButton:
		practice_input.handle(event)
		return
	if event is InputEventMouseButton or event is InputEventKey: practice_input.active=false
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_ESCAPE:
				paused = not paused
				charge = 0
			KEY_R:
				player.position = Vector3(0,0,0)
				velocity = Vector3.ZERO
				reset_puck()
			KEY_F1: debug = not debug
			KEY_C: wide_camera = not wide_camera
			KEY_1: rating = 55
			KEY_2: rating = 85
			KEY_Z: request_player_skill("cut")
			KEY_X: request_player_skill("toe_drag")
			KEY_V: request_player_skill("sweep")
			KEY_SPACE:
				var old := player
				player = teammate
				teammate = old
				player_visual = player.get_child(1)
				teammate_visual = teammate.get_child(1)
				velocity = player.velocity
				pickup_owner = false
	if paused: return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			zoom = clampf(zoom - 0.08,0.65,1.7)
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			zoom = clampf(zoom + 0.08,0.65,1.7)
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			strike(aim,28)
			charge = 0
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			var direction := (teammate.position + teammate.velocity * 0.25 - puck.position)
			direction.y = 0
			if strike(direction.normalized(),17,true):
				passes += 1

func strike(direction: Vector3, speed: float, is_pass: bool = false, loft: float = 0.0) -> bool:
	if paused or player.position.distance_to(puck.position) > 1.8 or cooldown > 0 or puck.position.y>0.22:
		return false
	direction.y = 0
	if is_pass: speed=clampf(speed*0.75,6.0,18.0)
	puck.linear_velocity = direction.normalized() * speed + velocity * 0.25 if is_pass else NetShooting.launch(puck.position,-1,practice_input.left_stick if practice_input.active else mouse_net_placement(-1),75,practice_input.slap_requested if practice_input.active else Input.is_physical_key_pressed(KEY_ALT))
	player_visual.play_release("pass" if is_pass else ("slap" if (practice_input.slap_requested if practice_input.active else Input.is_physical_key_pressed(KEY_ALT)) else "shot"),puck.linear_velocity)
	if is_pass: puck.linear_velocity.y=speed*loft
	pickup_owner = false
	lock_released_puck(player)
	cooldown = 0.42
	if not is_pass: shots += 1
	audio.cue("pass" if is_pass else ("slap" if (practice_input.slap_requested if practice_input.active else Input.is_physical_key_pressed(KEY_ALT)) else "wrist"),puck.global_position,speed/32)
	return true

func _on_puck_contact(body: Node) -> void:
	var actor:=hit_actor(body)
	if actor is CharacterBody3D and actor in goalkeepers:
		saves += 1
		cooldown = 0.22
		audio.cue("pad",puck.global_position,clampf(puck.linear_velocity.length()/28,0.2,1))
	elif puck.linear_velocity.length() > 5:
		audio.contact(body,puck.global_position,puck.linear_velocity.length())

func update_camera(delta: float) -> void:
	if reduce_motion:
		apply_comfort_camera()
		return
	var focus := player.position * 0.65 + puck.position * 0.35
	focus.x = clampf(focus.x,-7,7)
	focus.z = clampf(focus.z,-21,21)
	if wide_camera:
		focus = Vector3.ZERO
	camera_target = camera_target.lerp(focus,1 - exp(-delta * 4))
	var offset := Vector3(0,49,44) if wide_camera else Vector3(0,16,20) * zoom
	camera.position = camera.position.lerp(camera_target + offset,1 - exp(-delta * 5))
	camera.look_at(camera_target + Vector3(0,0.3,-2))
	camera.cull_mask = preload("res://scripts/arena_lighting.gd").camera_cull_mask(camera.position)
	selection.position = player.position + Vector3(0,0.025,0)
	if is_instance_valid(puck_marker): puck_marker.track(camera,puck.global_position,show_puck_indicator and not paused)

func _physics_process(delta: float) -> void:
	if practice_input.pause_pressed: paused=not paused
	audio.set_suspended(paused)
	if practice_input.active and not paused:
		practice_input.advance(delta)
		if not practice_input.deke_pressed.is_empty():request_player_skill(practice_input.deke_pressed,practice_input.deke_side)
		if practice_input.trigger_pressed:
			practice_pass_actor=player if pickup_owner else null
			if not pickup_owner: practice_input.switch_pressed=true
		if practice_input.shoot_pressed: strike(aim,28)
		if (practice_input.trigger_released and practice_pass_actor==player and pickup_owner) or (practice_input.saucer_pressed and pickup_owner):
			if strike(teammate.position+teammate.velocity*0.25-puck.position,practice_input.pass_speed() if practice_input.trigger_released else 17.0,true,0.18 if practice_input.saucer_pressed else 0): passes+=1
		if practice_input.switch_pressed:
			var old := player
			player=teammate
			teammate=old
			player_visual=player.get_child(1)
			teammate_visual=teammate.get_child(1)
			pickup_owner=false
	if practice_input.trigger_released or paused or not pickup_owner: practice_pass_actor=null
	practice_input.clear_edges()
	puck.freeze = paused
	if paused:
		if is_instance_valid(puck_marker): puck_marker.visible=false
		status.text = "PAUSED  /  Escape to resume"
		return
	elapsed += delta
	cooldown = maxf(0,cooldown - delta)
	advance_pickup_lock(delta)
	goal_timer = maxf(0,goal_timer - delta)
	var intent := Vector3(float(Input.is_physical_key_pressed(KEY_D))-float(Input.is_physical_key_pressed(KEY_A)),0,float(Input.is_physical_key_pressed(KEY_S))-float(Input.is_physical_key_pressed(KEY_W)))
	if practice_input.active: intent=Vector3(practice_input.left_stick.x,0,practice_input.left_stick.y)
	velocity = Skating.step(velocity,intent,rating,practice_input.effort if practice_input.active else Input.is_physical_key_pressed(KEY_SHIFT),delta)
	if (practice_input.active and practice_input.stop) or Input.is_physical_key_pressed(KEY_CTRL):
		velocity = velocity.move_toward(Vector3.ZERO,22 * delta)
	var raw_stick:Vector2=practice_input.right_stick if practice_input.active else Vector2(float(Input.is_physical_key_pressed(KEY_BRACKETRIGHT))-float(Input.is_physical_key_pressed(KEY_BRACKETLEFT)),0)
	var skill=prepare_skills(player,delta,raw_stick,pickup_owner,practice_input.protect_down if practice_input.active else Input.is_physical_key_pressed(KEY_G))
	var adjusted:Vector3=skill.steer(intent,player_visual.rig.global_basis.x)
	if pickup_owner:
		velocity=Skating.step(player.velocity,adjusted,rating,practice_input.effort if practice_input.active else Input.is_physical_key_pressed(KEY_SHIFT),delta)
		if (practice_input.active and practice_input.stop) or Input.is_physical_key_pressed(KEY_CTRL):velocity=velocity.move_toward(Vector3.ZERO,22*delta)
	player.velocity = velocity
	player.move_and_slide()
	velocity = player.velocity
	var intersection = Plane(Vector3.UP,0).intersects_ray(camera.project_ray_origin(get_viewport().get_mouse_position()),camera.project_ray_normal(get_viewport().get_mouse_position()))
	if practice_input.active:
		if intent.length()>0.05: aim=intent.normalized()
		# Right stick is applied by prepare_skills above.
	elif intersection != null:
		# Keyboard stick control is applied by prepare_skills above.
		var dir: Vector3 = intersection - player.position
		dir.y = 0
		if dir.length_squared() > 0.2: aim = dir.normalized()
	var target_rotation := atan2(-aim.x,-aim.z)
	var old_rotation := player_visual.rotation.y
	player_visual.rotation.y = rotate_toward(old_rotation,target_rotation,7.5 * delta)
	if not pickup_owner and not pickup_blocked(player) and PuckControl.offer(puck.position,puck.linear_velocity,player.position,player.velocity):player_visual.offer_receive(puck.position+puck.linear_velocity*0.03)
	player_visual.pass_preparation=0.4+practice_input.pass_held*0.6 if practice_input.active and practice_input.trigger_down and practice_pass_actor==player and pickup_owner else 0.0
	player_visual.animate_motion(velocity,delta,angle_difference(old_rotation,target_rotation) * velocity.length() * 0.02,intent.length_squared()>0.01,Input.is_physical_key_pressed(KEY_CTRL))
	audio.track_stop(player,player_visual.stop_weight,velocity.length())
	sync_skater_contacts(player)
	charge = 0
	var blade:Vector3=player_visual.get_blade_world()
	if not PuckControl.retained(puck.position,player.position,blade):pickup_owner=false
	if not pickup_owner and not pickup_blocked(player) and PuckControl.can_receive(puck.position,puck.linear_velocity,player.position,player.velocity,blade):
		pickup_owner=true;player.set_meta("control_age",0.0);control_acquired()
		player_visual.receive_puck(puck.linear_velocity-player.velocity)
	if pickup_owner:assist_carried_puck(player,delta)
	update_partner(delta)
	update_goalkeepers(delta)
	if goal_timer <= 0:
		for sign_ in [-1.0,1.0]:
			if Skating.goal_crossing_end(previous_puck,puck.position,sign_):
				if sign_ < 0: goals += 1
				else: away_goals += 1
				goal_timer = 2.5
				pickup_owner = false
				audio.cue("horn",puck.global_position)
	previous_puck = puck.position
	if puck.position.y < -2 or absf(puck.position.x) > 18 or absf(puck.position.z) > 33:
		reset_puck()
	update_camera(delta)
	hud.text = "HAWKEY   /   OPEN PRACTICE\nTOR   %02d     —     %02d   MTL      •      %02d:%02d" % [goals,away_goals,int(elapsed)/60,int(elapsed)%60]
	status.text = "GOAL  /  R to restart" if goal_timer > 0 else ("PUCK CONTROL  •  Click to shoot at the net · Alt + click slap shot" if pickup_owner else "FREE PUCK  •  Skate into reach to collect")
	power.value = charge
	power.visible = charge > 0
	help.text = "WASD Skate    Shift Effort    Ctrl Stop    Mouse Aim    Click LMB Wrist · Alt + click Slap    RMB Pass\nSpace Switch skater    R Reset    C Broadcast / full rink    Wheel Zoom    Esc Pause    F1 Diagnostics"
	if practice_input.active:
		help.text = "LS Skate + aim    RS Up Wrist / Down-Up Slap    R2 Hold/release Pass · Without puck Switch\nR1 Saucer    L3 Hustle    Start Pause    Shots: fixed power; passes: hold for strength"
	if debug:
		help.text = "Speed %.1f m/s   Puck %.1f m/s   Shots %d   Passes %d   Pad contacts %d   Rating %d\n1 / 2 Compare ratings    Fixed physics 120 Hz    C Camera    F1 Close diagnostics" % [velocity.length(),puck.linear_velocity.length(),shots,passes,saves,rating]

func update_partner(delta: float) -> void:
	var target := Vector3(clampf(player.position.x + (6 if player.position.x < 0 else -6),-(Arena.HALF_WIDTH-2.0),Arena.HALF_WIDTH-2.0),0,clampf(player.position.z - 5,-21,21))
	# Receiver moves to the pass, otherwise holds a supporting lane.
	if not pickup_owner and passes>0 and teammate.position.distance_to(puck.position)<5:
		target=PuckControl.recovery_target(puck.position,puck.linear_velocity,teammate_visual.get_blade_world()-teammate.position)
	var dir := target - teammate.position
	teammate.velocity = teammate.velocity.move_toward(dir.limit_length(1) * 5,9 * delta)
	teammate.move_and_slide()
	if dir.length() > 0.4:
		teammate_visual.rotation.y = rotate_toward(teammate_visual.rotation.y,atan2(-dir.x,-dir.z),5 * delta)
	if not pickup_owner and not pickup_blocked(teammate) and PuckControl.offer(puck.position,puck.linear_velocity,teammate.position,teammate.velocity):teammate_visual.offer_receive(puck.position+puck.linear_velocity*0.03)
	teammate_visual.animate_motion(teammate.velocity,delta,0,dir.length()>0.4)
	sync_skater_contacts(teammate)
	if not pickup_blocked(teammate) and not pickup_owner and PuckControl.can_receive(puck.position,puck.linear_velocity,teammate.position,teammate.velocity,teammate_visual.get_blade_world()):
		teammate_visual.receive_puck(puck.linear_velocity-teammate.velocity)
		status.text="PASS RECEIVED  /  Space to switch"
		var old:=player;player=teammate;teammate=old
		player_visual=player.get_child(1);teammate_visual=teammate.get_child(1)
		velocity=player.velocity;pickup_owner=true;player.set_meta("control_age",0.0);control_acquired()
		assist_carried_puck(player,delta)

func update_goalkeepers(delta: float) -> void:
	for i in range(goalkeepers.size()):
		var goalie := goalkeepers[i]
		var end_ := -1.0 if i == 0 else 1.0
		var depth := clampf(absf(puck.position.z - end_ * Arena.GOAL_LINE) * 0.05,1.18,1.4)
		var target := Vector3(clampf(puck.position.x * 0.13,-0.75,0.75),0,end_ * (Arena.GOAL_LINE - depth))
		goalie.velocity = (target - goalie.position).limit_length(1) * 3.8
		goalie.move_and_slide()
		var facing:=Vector3(puck.position.x,0,puck.position.z-end_*Arena.GOAL_LINE)
		if facing.length_squared()<0.0001: facing=Vector3(0,0,-end_)
		goalie_visuals[i].rotation.y=rotate_toward(goalie_visuals[i].rotation.y,atan2(-facing.x,-facing.z)-goalie.rotation.y,delta*9)
		goalie_visuals[i].animate_motion(goalie.velocity,delta)
		sync_goalie_contacts(goalie)

func add_puck_collision(actor: CharacterBody3D, is_goalie: bool) -> void:
	if is_goalie:
		build_goalie_contacts(actor)
		return
	var contact:=AnimatableBody3D.new()
	contact.sync_to_physics=false
	contact.name="PuckContact"
	contact.collision_layer=8
	contact.collision_mask=4
	contact.set_meta("actor",actor)
	contact.set_meta("zone","pads" if is_goalie else "body")
	actor.add_child(contact)
	var pm:=PhysicsMaterial.new()
	pm.bounce=0.22 if is_goalie else 0.12
	pm.friction=0.15
	contact.physics_material_override=pm
	var boxes: Array[Dictionary]=[
		{"size":Vector3(0.48,0.65,0.30),"pos":Vector3(0,1.14,0),"name":"Torso"},
		{"size":Vector3(0.16,0.12,0.30),"pos":Vector3(-0.18,0.065,-0.02),"name":"LeftSkate"},
		{"size":Vector3(0.16,0.12,0.30),"pos":Vector3(0.18,0.065,-0.02),"name":"RightSkate"}]
	for entry in boxes:
		var collision:=CollisionShape3D.new()
		var box_shape:=BoxShape3D.new()
		box_shape.size=entry.size
		collision.shape=box_shape
		collision.position=entry.pos
		collision.name=entry.name
		contact.add_child(collision)

func hit_actor(body: Node) -> Node:
	if body.has_meta("actor"): return body.get_meta("actor")
	return body

func set_puck_contacts_enabled(actor: CharacterBody3D, enabled: bool) -> void:
	for child in actor.get_children():
		if child is AnimatableBody3D:
			child.collision_layer=8 if enabled else 0

func build_goalie_contacts(actor: CharacterBody3D) -> void:
	var visual:=actor.get_child(1)
	var equipment:Dictionary=visual.get_goalie_gear()
	# Empty compatibility node; it has no broad pad wall and no puck collision.
	var root_contact:=AnimatableBody3D.new()
	root_contact.name="PuckContact"
	root_contact.collision_layer=0
	root_contact.collision_mask=0
	actor.add_child(root_contact)
	for name_ in equipment:
		var spec:Dictionary=equipment[name_]
		var body:=AnimatableBody3D.new()
		body.sync_to_physics=false # Updated explicitly from the same physics-tick pose as the mesh.
		body.name=name_
		body.collision_layer=8
		body.collision_mask=4
		body.set_meta("actor",actor)
		body.set_meta("zone",spec.zone)
		var material_:=PhysicsMaterial.new()
		material_.bounce=spec.bounce
		material_.friction=0.12
		body.physics_material_override=material_
		var collision:=CollisionShape3D.new()
		var box:=BoxShape3D.new()
		box.size=spec.size
		box.margin=0.002
		collision.shape=box
		body.add_child(collision)
		actor.add_child(body)
		body.transform=spec.transform

func sync_goalie_contacts(actor: CharacterBody3D) -> void:
	var equipment:Dictionary=actor.get_child(1).get_goalie_gear()
	for name_ in equipment:
		var body:AnimatableBody3D=actor.get_node(name_)
		var spec:Dictionary=equipment[name_]
		body.transform=spec.transform
		var box:BoxShape3D=body.get_child(0).shape
		box.size=spec.size

func sync_skater_contacts(actor: CharacterBody3D) -> void:
	var visual:=actor.get_child(1)
	var contact:=actor.get_node("PuckContact")
	contact.transform=Transform3D.IDENTITY
	var frame:Transform3D=visual.transform*visual.rig.transform
	contact.get_node("Torso").transform=frame*visual.torso_pose
	for i in range(2):
		var name_:String="LeftSkate" if i==0 else "RightSkate"
		contact.get_node(name_).transform=frame*visual.skates[i].transform*Transform3D(Basis.IDENTITY,Vector3(0,-0.0025,0.06))

func mouse_net_placement(end_: float) -> Vector2:
	var cursor := get_viewport().get_mouse_position()
	var hit: Variant = Plane(Vector3(0,0,1),end_*Arena.GOAL_LINE).intersects_ray(camera.project_ray_origin(cursor),camera.project_ray_normal(cursor))
	if hit == null: return Vector2.ZERO
	return Vector2(hit.x/(-end_*0.78),(0.59-hit.y)/0.47).clamp(Vector2(-1,-1),Vector2(1,1))

func on_practice_connection(device: int, connected: bool) -> void:
	if not connected and practice_input.disconnected(device):
		practice_pass_actor=null
		paused=true
		charge=0

func apply_comfort_camera() -> void:
	camera.position=Vector3(0,51,35)
	camera.look_at(Vector3(0,0.4,0),Vector3.UP)
	camera.cull_mask=0xFFFFF & ~preload("res://scripts/arena_lighting.gd").RIGGING_LAYER
	selection.position=player.position+Vector3(0,0.025,0)
	if is_instance_valid(puck_marker): puck_marker.track(camera,puck.global_position,show_puck_indicator and not paused)
