extends Node3D
## Goal presentation in the arena: a red rotating goal light on the glass
## behind each net, a short warm pulse of the overhead light pools and LED
## ribbons, and an animated "GOAL" on the centre-hung scoreboard.
## One entry point: celebrate(end_sign, team_color, team_name). Add it as a
## child of the match/lab root (it finds `arena` and ArenaLighting there).
## Intensities stay broadcast-plausible: the lamp is a ~100 W class beacon, the
## arena pulse peaks at +45% on the pools and decays within ~3 s.

const Arena = preload("res://scripts/arena.gd")
const ArenaLighting = preload("res://scripts/arena_lighting.gd")

const LAMP_TIME := 4.0        # goal light spins this long
const FLASH_TIME := 3.0       # arena light pulse, decaying
const BOARD_TIME := 4.0       # jumbotron GOAL animation
const CROWD_HOLD := 3.5       # the crowd stays on its feet this long, then settles
const BOARD_NAME_AT := 2.3    # jumbotron switches from GOAL to the team name
const SPIN_RATE := TAU * 1.6  # beacon reflector, rad/s (~96 rpm, like a real beacon)
const LAMP_RED := Color("#ff1208")
const DOME_OFF := Color("#3a0a08")
## Lamp sits on a bracket just behind the end glass, centred on the net.
const LAMP_HEIGHT := 2.74
const LAMP_BEHIND := 0.38
const FLASH_WARM := Color("#ffd8a6")

class Lamp:
	var root: Node3D
	var spinner: Node3D
	var dome: StandardMaterial3D
	var reflector: StandardMaterial3D
	var glow: OmniLight3D
	var beam: SpotLight3D
	var time_left := 0.0

var lamps := {}   # end sign (-1.0 / 1.0) -> Lamp
var lighting: Node
var dressing: Node
var flash_left := 0.0
var flash_color := FLASH_WARM
var board_left := 0.0
var team_color := Color.WHITE
var team_name := ""
var _pool_base: Array = []      # [energy, color] per pool
var _ribbon_base: Array = []    # [emission, energy] per ribbon
var _screen_base: Array = []
var _label_base: Array = []     # [modulate, scale, position] per jumbotron label
var _time := 0.0

func _ready() -> void:
	name = "GoalCelebration"
	var host := get_parent()
	if host:
		lighting = host.get_node_or_null("ArenaLighting")
		var arena = host.get("arena")
		if arena: dressing = arena.get_node_or_null("Dressing")
	for end_sign in [-1.0, 1.0]:
		lamps[end_sign] = build_lamp(end_sign)
	if lighting:
		for spot in lighting.pools:
			_pool_base.append([spot.light_energy, spot.light_color])
	if dressing:
		for ribbon in dressing.led_ribbons:
			var m: StandardMaterial3D = ribbon.material_override
			_ribbon_base.append([m.emission, m.emission_energy_multiplier])
		for screen in dressing.jumbotron_screens:
			var m: StandardMaterial3D = screen.material_override
			_screen_base.append([m.emission, m.emission_energy_multiplier])
		for l in dressing.jumbotron_labels:
			_label_base.append([l.modulate, l.scale, l.position])

## Starts the goal presentation for a goal scored into the net at `end_sign`
## (-1 north, +1 south). Restarts cleanly if a celebration is still running.
func celebrate(end_sign: float, color: Color, scoring_name: String) -> void:
	var lamp: Lamp = lamps.get(signf(end_sign) if end_sign != 0.0 else 1.0)
	if lamp:
		lamp.time_left = LAMP_TIME
	flash_left = FLASH_TIME
	team_color = color
	team_name = scoring_name
	# Warm white wash with a hint of the team colour; never a coloured flood.
	flash_color = FLASH_WARM.lerp(color.lightened(0.4), 0.18)
	board_left = BOARD_TIME
	if dressing:
		dressing.scoreboard_hold = true
		# The bowl stands and roars (assets/crowd.gdshader).
		if dressing.has_method("crowd_react"): dressing.crowd_react(1.0, end_sign, CROWD_HOLD)
	advance(0.0)

func is_active() -> bool:
	return lamp_on(-1.0) or lamp_on(1.0) or flash_left > 0.0 or board_left > 0.0

func lamp_on(end_sign: float) -> bool:
	var lamp: Lamp = lamps.get(end_sign)
	return lamp != null and lamp.time_left > 0.0

func _process(delta: float) -> void:
	advance(delta)

## Steps every effect by `delta` seconds (tests and captures call it directly).
func advance(delta: float) -> void:
	_time += delta
	for end_sign in lamps:
		update_lamp(lamps[end_sign], delta)
	update_flash(delta)
	update_board(delta)

# --- Goal light --------------------------------------------------------------

func mat(color: Color, rough := 0.5, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metal
	return m

func part(parent: Node3D, mesh: Mesh, at: Vector3, material: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = at
	mi.material_override = material
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.layers = ArenaLighting.ENVIRONMENT_LAYER
	parent.add_child(mi)
	return mi

func build_lamp(end_sign: float) -> Lamp:
	var lamp := Lamp.new()
	var root := Node3D.new()
	root.name = "GoalLight%s" % ("North" if end_sign < 0 else "South")
	root.position = Vector3(0, LAMP_HEIGHT, end_sign * (Arena.HALF_LENGTH + LAMP_BEHIND))
	add_child(root)
	lamp.root = root
	var steel := mat(Color("#2b3038"), 0.45, 0.6)
	# Bracket: a short shelf back to the glass line plus a vertical strut.
	var shelf := BoxMesh.new()
	shelf.size = Vector3(0.34, 0.03, LAMP_BEHIND + 0.06)
	part(root, shelf, Vector3(0, -0.015, -end_sign * (LAMP_BEHIND * 0.5 - 0.03)), steel)
	var strut := BoxMesh.new()
	strut.size = Vector3(0.05, 0.6, 0.05)
	part(root, strut, Vector3(0, -0.32, 0.1 * end_sign), steel)
	# Base housing.
	var base := CylinderMesh.new()
	base.top_radius = 0.125
	base.bottom_radius = 0.135
	base.height = 0.09
	part(root, base, Vector3(0, 0.045, 0), mat(Color("#15181d"), 0.6, 0.3))
	# Rotating reflector and bulb inside the dome.
	var spinner := Node3D.new()
	spinner.position = Vector3(0, 0.17, 0)
	root.add_child(spinner)
	lamp.spinner = spinner
	lamp.reflector = mat(Color("#8c8f94"), 0.15, 0.9)
	lamp.reflector.emission_enabled = true
	lamp.reflector.emission = Color("#ff4a2a")
	lamp.reflector.emission_energy_multiplier = 0.0
	# Parabolic mirror behind the bulb (a shallow bowl opening along +z),
	# polished metal that catches the bulb rather than glowing itself.
	var dish := SphereMesh.new()
	dish.radius = 0.06
	dish.height = 0.035
	dish.is_hemisphere = true
	var mirror := mat(Color("#9a9ca0"), 0.12, 1.0)
	var dish_mesh := part(spinner, dish, Vector3(0, 0, -0.02), mirror)
	dish_mesh.rotation_degrees.x = 90.0
	var bulb := SphereMesh.new()
	bulb.radius = 0.022
	bulb.height = 0.044
	part(spinner, bulb, Vector3(0, 0, 0.012), lamp.reflector)
	# Red fresnel dome: dark ruby glass when off, glowing when on.
	lamp.dome = mat(DOME_OFF, 0.12)
	lamp.dome.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	lamp.dome.albedo_color = Color(DOME_OFF, 0.82)
	lamp.dome.emission_enabled = true
	lamp.dome.emission = LAMP_RED
	lamp.dome.emission_energy_multiplier = 0.0
	lamp.dome.rim_enabled = true
	lamp.dome.rim = 0.35
	var dome := CylinderMesh.new()
	dome.top_radius = 0.1
	dome.bottom_radius = 0.11
	dome.height = 0.2
	part(root, dome, Vector3(0, 0.19, 0), lamp.dome)
	var cap := SphereMesh.new()
	cap.radius = 0.1
	cap.height = 0.1
	cap.is_hemisphere = true
	part(root, cap, Vector3(0, 0.29, 0), lamp.dome)
	# Soft red spill around the lamp (glass, netting, first rows).
	var glow := OmniLight3D.new()
	glow.name = "Glow"
	glow.light_color = LAMP_RED
	glow.light_energy = 0.0
	glow.omni_range = 5.0
	glow.omni_attenuation = 1.6
	glow.shadow_enabled = false
	glow.visible = false
	glow.position = Vector3(0, 0.2, 0)
	root.add_child(glow)
	lamp.glow = glow
	# The rotating beam that sweeps the glass, ice and crowd.
	var beam := SpotLight3D.new()
	beam.name = "Beam"
	beam.light_color = LAMP_RED
	beam.light_energy = 0.0
	beam.spot_range = 20.0
	beam.spot_angle = 14.0
	beam.spot_angle_attenuation = 1.4
	beam.spot_attenuation = 1.2
	beam.shadow_enabled = false
	beam.visible = false
	beam.rotation_degrees.x = -12.0   # tipped slightly down
	spinner.add_child(beam)
	lamp.beam = beam
	return lamp

func update_lamp(lamp: Lamp, delta: float) -> void:
	lamp.time_left = maxf(0.0, lamp.time_left - delta)
	var on := lamp.time_left > 0.0
	lamp.glow.visible = on
	lamp.beam.visible = on
	if not on:
		lamp.dome.emission_energy_multiplier = 0.0
		lamp.reflector.emission_energy_multiplier = 0.0
		lamp.glow.light_energy = 0.0
		lamp.beam.light_energy = 0.0
		return
	# Quick lamp warm-up and a short fade at the end, like a real bulb.
	var age := LAMP_TIME - lamp.time_left
	var level := clampf(age / 0.12, 0.0, 1.0) * clampf(lamp.time_left / 0.35, 0.0, 1.0)
	lamp.spinner.rotation.y = wrapf(lamp.spinner.rotation.y + SPIN_RATE * delta, 0.0, TAU)
	# The dome brightens as the reflector sweeps past the viewer's side; a
	# smooth 2-per-turn pulse reads as rotation from any camera.
	var sweep := pow(0.5 + 0.5 * cos(lamp.spinner.rotation.y * 2.0), 3.0)
	lamp.dome.emission_energy_multiplier = level * (0.8 + 1.8 * sweep)
	lamp.reflector.emission_energy_multiplier = level * 3.0
	lamp.glow.light_energy = level * (0.9 + 0.8 * sweep)
	lamp.beam.light_energy = level * 8.0

# --- Arena light flash ------------------------------------------------------

func update_flash(delta: float) -> void:
	flash_left = maxf(0.0, flash_left - delta)
	var t := FLASH_TIME - flash_left
	var envelope := 0.0
	if flash_left > 0.0:
		# Fast attack, smooth decay to nothing over FLASH_TIME.
		envelope = clampf(t / 0.08, 0.0, 1.0) * pow(flash_left / FLASH_TIME, 1.4)
	if lighting:
		for i in range(mini(lighting.pools.size(), _pool_base.size())):
			var spot: SpotLight3D = lighting.pools[i]
			var base_energy: float = _pool_base[i][0]
			var base_color: Color = _pool_base[i][1]
			# Alternating banks (checkerboard) pulse in counter-phase at 2.5 Hz:
			# a restrained chase rather than a disco strobe.
			var phase := PI * float((i + i / 4) % 2)
			var pulse := 0.5 + 0.5 * cos(TAU * 2.5 * t + phase)
			spot.light_energy = base_energy * (1.0 + 0.45 * envelope * pulse)
			spot.light_color = base_color.lerp(flash_color, 0.5 * envelope)
	if dressing:
		for i in range(mini(dressing.led_ribbons.size(), _ribbon_base.size())):
			var m: StandardMaterial3D = dressing.led_ribbons[i].material_override
			var base_emission: Color = _ribbon_base[i][0]
			var base_energy: float = _ribbon_base[i][1]
			var ribbon_level := clampf(envelope * 1.6, 0.0, 1.0)
			var pulse := 0.5 + 0.5 * cos(TAU * 2.5 * t + PI * (i % 2))
			m.emission = base_emission.lerp(team_color.lightened(0.1), 0.85 * ribbon_level)
			m.albedo_color = m.emission
			m.emission_energy_multiplier = base_energy * (1.0 + ribbon_level * (0.6 + 0.6 * pulse))

# --- Jumbotron --------------------------------------------------------------

func update_board(delta: float) -> void:
	if dressing == null:
		board_left = maxf(0.0, board_left - delta)
		return
	var labels: Array = dressing.jumbotron_labels
	if board_left <= 0.0:
		return
	board_left = maxf(0.0, board_left - delta)
	if board_left <= 0.0:
		restore_board()
		return
	var t := BOARD_TIME - board_left
	# Team-colour screen with white type, as arena boards do on a goal.
	var text_color := team_color.lightened(0.55)
	var screen_color := team_color.darkened(0.3)
	var fade_out := clampf(board_left / 0.3, 0.0, 1.0)
	for i in range(dressing.jumbotron_screens.size()):
		var m: StandardMaterial3D = dressing.jumbotron_screens[i].material_override
		m.emission = screen_color
		m.albedo_color = screen_color
		m.emission_energy_multiplier = 0.85 + 0.2 * (0.5 + 0.5 * cos(TAU * 2.0 * t))
	for i in range(labels.size()):
		var l: Label3D = labels[i]
		var base: Array = _label_base[i] if i < _label_base.size() else [Color.WHITE, Vector3.ONE, l.position]
		var base_pos: Vector3 = base[2]
		if t < BOARD_NAME_AT:
			if i % 2 == 0:
				l.text = "GOAL"
				# Punch in from small, overshoot, settle, then breathe gently.
				var grow := ease_out_back(clampf(t / 0.45, 0.0, 1.0))
				var breathe := 1.0 + 0.04 * sin(TAU * 1.5 * t)
				l.scale = Vector3.ONE * lerpf(0.35, 1.75, grow) * breathe
				l.position = base_pos + Vector3(0, -0.25, 0)
				# Flash between white and a pale team tint for the first 1.4 s.
				var flash := 0.5 + 0.5 * cos(TAU * 3.0 * t) if t < 1.4 else 1.0
				l.modulate = text_color.lerp(Color.WHITE, flash)
			else:
				l.text = ""
		else:
			var u := clampf((t - BOARD_NAME_AT) / 0.25, 0.0, 1.0)
			if i % 2 == 0:
				l.text = team_name
				l.scale = Vector3.ONE * lerpf(0.8, 1.0, ease_out_back(u))
				l.position = base_pos
				l.modulate = Color(1, 1, 1, u * fade_out)
			else:
				l.text = "GOAL"
				l.scale = Vector3.ONE
				l.position = base_pos
				l.modulate = Color(text_color, u * fade_out)

func ease_out_back(x: float) -> float:
	var c := 1.70158
	return 1.0 + (c + 1.0) * pow(x - 1.0, 3.0) + c * pow(x - 1.0, 2.0)

func restore_board() -> void:
	if dressing == null: return
	for i in range(mini(dressing.jumbotron_screens.size(), _screen_base.size())):
		var m: StandardMaterial3D = dressing.jumbotron_screens[i].material_override
		m.emission = _screen_base[i][0]
		m.albedo_color = _screen_base[i][0]
		m.emission_energy_multiplier = _screen_base[i][1]
	for i in range(mini(dressing.jumbotron_labels.size(), _label_base.size())):
		var l: Label3D = dressing.jumbotron_labels[i]
		l.modulate = _label_base[i][0]
		l.scale = _label_base[i][1]
		l.position = _label_base[i][2]
	dressing.scoreboard_hold = false
	dressing.set_scoreboard(dressing.scoreboard_text[0], dressing.scoreboard_text[1])
