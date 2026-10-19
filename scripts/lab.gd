extends Node3D
const Skating = preload("res://scripts/skating.gd")
var player: Node3D
var teammate: Node3D
var puck: RigidBody3D
var camera: Camera3D
var hud: Label
var help: Label
var velocity := Vector3.ZERO
var aim := Vector3.FORWARD
var charge := 0.0
var cooldown := 0.0
var goals := 0
var shots := 0
var passes := 0
var previous_puck := Vector3.ZERO
var debug := true
var paused := false
var rating := 85.0
var tone: AudioStreamPlayer
var generator: AudioStreamGenerator
var audio_playback: AudioStreamGeneratorPlayback
var sound_phase := 0.0

func material(color: Color, metallic: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = metallic
	m.roughness = 0.3
	return m

func box(size: Vector3, position_: Vector3, color: Color, solid: bool = false) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var shape := BoxMesh.new()
	shape.size = size
	mesh.mesh = shape
	mesh.material_override = material(color)
	mesh.position = position_
	add_child(mesh)
	if solid:
		var body := StaticBody3D.new()
		var collision := CollisionShape3D.new()
		var box_shape := BoxShape3D.new()
		box_shape.size = size
		collision.shape = box_shape
		body.add_child(collision)
		mesh.add_child(body)
		var physics_material := PhysicsMaterial.new()
		physics_material.bounce = 0.65
		body.physics_material_override = physics_material
	return mesh

func skater(position_: Vector3, color: Color) -> Node3D:
	var root := Node3D.new()
	add_child(root)
	root.position = position_
	var torso := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.32
	capsule.height = 1.4
	torso.mesh = capsule
	torso.material_override = material(color)
	torso.position.y = 0.9
	root.add_child(torso)
	var stick := MeshInstance3D.new()
	var stick_shape := BoxMesh.new()
	stick_shape.size = Vector3(0.07, 0.07, 1.4)
	stick.mesh = stick_shape
	stick.material_override = material(Color("#26364c"))
	stick.position = Vector3(0.4, 0.2, -0.65)
	root.add_child(stick)
	return root

func _ready() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-60, -25, 0)
	sun.light_energy = 1.5
	add_child(sun)
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color("#b9d5ec")
	world.environment.ambient_light_energy = 0.7
	add_child(world)
	box(Vector3(30, 0.3, 60), Vector3(0, -0.2, 0), Color("#dcecf2"), true)
	for x in [-15.0, 15.0]:
		box(Vector3(0.3, 1.2, 60), Vector3(x, 0.5, 0), Color("#e6f6ff"), true)
	for z in [-30.0, 30.0]:
		box(Vector3(30, 1.2, 0.3), Vector3(0, 0.5, z), Color("#e6f6ff"), true)
	for z in [-10.0, 10.0]:
		box(Vector3(29.7, 0.01, 0.22), Vector3(0, -0.035, z), Color("#2875b9"))
	for z in [-25.0, 0.0, 25.0]:
		box(Vector3(29.7, 0.01, 0.12), Vector3(0, -0.03, z), Color("#c64861"))
	# Solid side/back net stops behind-the-net entry; open front at z=-25.
	for x in [-1.06, 1.06]:
		box(Vector3(0.12, 1.22, 0.12), Vector3(x, 0.58, -25), Color("#e63e52"), true)
		box(Vector3(0.10, 1.22, 1.5), Vector3(x, 0.58, -25.75), Color("#8c9caa"), true)
	box(Vector3(2.2, 0.12, 0.12), Vector3(0, 1.16, -25), Color("#e63e52"), true)
	box(Vector3(2.2, 1.22, 0.1), Vector3(0, 0.58, -26.5), Color("#8c9caa"), true)
	player = skater(Vector3(0, 0, 3), Color("#22a9cd"))
	teammate = skater(Vector3(7, 0, -8), Color("#22a9cd"))
	puck = RigidBody3D.new()
	puck.mass = 0.17
	puck.continuous_cd = true
	puck.linear_damp = 0.22
	puck.angular_damp = 0.8
	var puck_mesh := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.15
	cylinder.bottom_radius = 0.15
	cylinder.height = 0.08
	puck_mesh.mesh = cylinder
	puck_mesh.material_override = material(Color("#101820"))
	puck.add_child(puck_mesh)
	var collision := CollisionShape3D.new()
	var puck_shape := CylinderShape3D.new()
	puck_shape.radius = 0.15
	puck_shape.height = 0.08
	collision.shape = puck_shape
	puck.add_child(collision)
	add_child(puck)
	camera = Camera3D.new()
	add_child(camera)
	camera.position = Vector3(0, 43, 27)
	camera.look_at(Vector3(0, 0, -5))
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 52
	var canvas := CanvasLayer.new()
	add_child(canvas)
	var panel := ColorRect.new()
	panel.color = Color(0.02, 0.04, 0.09, 0.94)
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	panel.offset_bottom = 94
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(panel)
	hud = Label.new()
	hud.position = Vector2(28, 16)
	hud.add_theme_font_size_override("font_size", 22)
	canvas.add_child(hud)
	help = Label.new()
	help.position = Vector2(28, 105)
	help.add_theme_font_size_override("font_size", 16)
	help.add_theme_color_override("font_color", Color("#183347"))
	canvas.add_child(help)
	tone = AudioStreamPlayer.new()
	generator = AudioStreamGenerator.new()
	generator.mix_rate = 22050
	generator.buffer_length = 0.1
	tone.stream = generator
	add_child(tone)
	tone.play()
	audio_playback = tone.get_stream_playback()
	reset_puck()

func reset_puck() -> void:
	puck.position = player.position + Vector3(0, 0.15, -1)
	puck.linear_velocity = Vector3.ZERO
	puck.angular_velocity = Vector3.ZERO
	previous_puck = puck.position
	cooldown = 0.3

func beep(frequency: float) -> void:
	# Original synthetic placeholder; replace with licensed/original hockey recordings.
	for i in range(mini(audio_playback.get_frames_available(), 1700)):
		var value := sin(float(i) * frequency * TAU / 22050.0) * 0.12 * (1.0 - float(i) / 1700.0)
		audio_playback.push_frame(Vector2(value, value))

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_ESCAPE:
				paused = not paused
			KEY_R:
				reset_puck()
			KEY_F1:
				debug = not debug
			KEY_1:
				rating = 55.0
			KEY_2:
				rating = 85.0
	if paused:
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			camera.size = maxf(25, camera.size - 2)
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			camera.size = minf(75, camera.size + 2)
		if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			strike(aim, lerpf(12, 34, charge))
			charge = 0.0
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			strike((teammate.position - puck.position).normalized(), 15)
			passes += 1

func strike(direction: Vector3, speed: float) -> void:
	if player.position.distance_to(puck.position) > 1.7:
		return
	puck.linear_velocity = direction * speed
	cooldown = 0.45
	shots += 1
	beep(180)

func _physics_process(delta: float) -> void:
	puck.freeze = paused
	if paused:
		hud.text = "HAWKEY / LABORATORY     PAUSED — Esc to resume"
		return
	cooldown = maxf(0, cooldown - delta)
	var intent := Vector3(float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)), 0, float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W)))
	velocity = Skating.step(velocity, intent, rating, Input.is_physical_key_pressed(KEY_SHIFT), delta)
	player.position += velocity * delta
	player.position.x = clampf(player.position.x, -14.2, 14.2)
	player.position.z = clampf(player.position.z, -29.2, 29.2)
	var mouse := get_viewport().get_mouse_position()
	var intersection = Plane(Vector3.UP, 0).intersects_ray(camera.project_ray_origin(mouse), camera.project_ray_normal(mouse))
	if intersection != null:
		var direction: Vector3 = intersection - player.position
		direction.y = 0
		if direction.length_squared() > 0.01:
			aim = direction.normalized()
	player.rotation.y = atan2(-aim.x, -aim.z)
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		charge = minf(1, charge + delta)
	# Assisted stick constraint: velocity spring, never teleport attachment.
	if cooldown <= 0 and player.position.distance_to(puck.position) < 1.6 and puck.linear_velocity.length() < 13:
		var target := player.position + aim * 0.95 + Vector3(0, 0.1, 0)
		puck.linear_velocity += ((target - puck.position) * 45 - (puck.linear_velocity - velocity) * 8) * delta
	if cooldown <= 0 and teammate.position.distance_to(puck.position) < 1.5:
		puck.linear_velocity = (player.position - puck.position).normalized() * 12
		cooldown = 0.6
		beep(280)
	if Skating.goal_crossing(previous_puck, puck.position):
		goals += 1
		beep(540)
	previous_puck = puck.position
	if puck.position.y < -3:
		reset_puck()
	hud.text = "HAWKEY  /  PRACTICE LAB     GOALS %02d     RELEASES %02d     PASSES %02d\nPlaceholder 3D assets • Native PC prototype • Rating %d • Charge %d%%" % [goals, shots, passes, rating, charge * 100]
	help.text = "WASD Skate   Shift Effort   Mouse Aim   Hold / release LMB Shoot   RMB Pass to partner\nR Reset puck   Esc Pause   Wheel Zoom   1 / 2 Compare skating ratings   F1 Debug"
	if debug:
		help.text += "\nSpeed %.2f m/s   Puck %.2f m/s   Aim %.2f, %.2f   Fixed simulation 120 Hz" % [velocity.length(), puck.linear_velocity.length(), aim.x, aim.z]

func _exit_tree() -> void:
	audio_playback = null
	if is_instance_valid(tone):
		tone.stop()
