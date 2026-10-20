extends Node3D
## Game-night arena dressing: sponsor boards, a full seating bowl with crowd,
## an LED fascia ribbon, overhead light trusses and a centre-hung scoreboard.
## All sponsor names are invented; nothing imitates a real brand or arena.

const Arena = preload("res://scripts/arena.gd")
const CROWD = preload("res://assets/crowd-spectators-v1.png")
const SPONSORS := [
	["NORTHLINE", Color("#0f2f5c"), Color("#f2f5f8")],
	["GLACIER COLA", Color("#c8102e"), Color("#ffffff")],
	["IRONWOOD BANK", Color("#f2f5f8"), Color("#183a2a")],
	["POLAR AIR", Color("#1f6fb5"), Color("#ffffff")],
	["SUMMIT TIRE", Color("#141414"), Color("#f4c20d")],
	["BLUEWATER", Color("#f2f5f8"), Color("#0a5ea8")],
	["MAPLEFIELD", Color("#e8eef2"), Color("#b3162c")],
	["RINKSIDE", Color("#ff6a13"), Color("#141414")],
]
const ROWS := 14
## First seating row sits 1.4 m behind the side boards.
const SIDE_X := Arena.HALF_WIDTH + 1.4
const ROW_RUN := 0.85
const ROW_RISE := 0.46

var helper: Arena
var jumbotron_labels: Array[Label3D] = []
## Jumbotron screen faces and LED fascia ribbons, for goal_celebration.gd.
var jumbotron_screens: Array[MeshInstance3D] = []
var led_ribbons: Array[MeshInstance3D] = []
## While a goal celebration owns the jumbotron, score updates are stored in
## scoreboard_text and shown again when it hands the board back.
var scoreboard_hold := false
var scoreboard_text: Array[String] = ["TOR  0     MTL  0", "1ST   20:00"]
var arena_name := "HAWKEY ARENA"

func _ready() -> void:
	helper = Arena.new()
	build_bowl()
	build_crowd()
	build_fascia()
	build_lights()
	build_jumbotron()
	helper.free()

func emissive(color: Color, energy := 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m

func box(size: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
	# Stands, fascia and rigging are lit, but never shadow the ice.
	var m := helper.block(self, size, pos, color)
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return m

func text(words: String, pos: Vector3, facing: Vector3, height: float, color: Color, parent: Node3D = self) -> Label3D:
	var l := Label3D.new()
	l.font = preload("res://scripts/interface_font.gd").get_font(true)
	l.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	l.text = words
	l.font_size = 96
	l.pixel_size = height / 96.0
	l.modulate = color
	l.outline_size = 0
	l.double_sided = false
	l.shaded = false
	var forward := facing.normalized()
	var right := Vector3.UP.cross(forward).normalized()
	l.basis = Basis(right, Vector3.UP, forward)
	l.position = pos
	parent.add_child(l)
	return l

## Sponsor panels along the inside face of every long board segment.
func add_board_ads(points: Array) -> void:
	helper = Arena.new()
	var index := 0
	for i in range(points.size()):
		var a: Vector3 = points[i]
		var b: Vector3 = points[(i + 1) % points.size()]
		var length := a.distance_to(b)
		if length < 6.0:
			continue
		var along := (b - a).normalized()
		var mid := (a + b) * 0.5
		var inward := -Vector3(mid.x, 0, mid.z)
		inward = (inward - along * inward.dot(along)).normalized()
		var count := int(length / 5.6)
		for k in range(count):
			var t := (k + 0.5) / count
			var center := a.lerp(b, t) + inward * 0.126
			var sponsor: Array = SPONSORS[index % SPONSORS.size()]
			index += 1
			var panel := MeshInstance3D.new()
			var quad := QuadMesh.new()
			quad.size = Vector2(length / count - 0.35, 0.6)
			panel.mesh = quad
			var m := StandardMaterial3D.new()
			m.albedo_color = sponsor[1]
			m.roughness = 0.55
			panel.material_override = m
			var right := Vector3.UP.cross(inward).normalized()
			panel.basis = Basis(right, Vector3.UP, inward)
			panel.position = center + Vector3(0, 0.6, 0)
			add_child(panel)
			text(sponsor[0], center + Vector3(0, 0.6, 0) + inward * 0.004, inward, 0.34, sponsor[2])
	helper.free()

func build_bowl() -> void:
	var seat := [Color("#0e1724"), Color("#121d2c")]
	for r in range(ROWS):
		var y := r * ROW_RISE
		var color: Color = seat[r % 2]
		for side in [-1.0, 1.0]:
			box(Vector3(ROW_RUN, 0.45 + y, 62 + r * 2 * ROW_RUN), Vector3(side * (SIDE_X + r * ROW_RUN), (0.45 + y) * 0.5, 0), color)
			box(Vector3(Arena.HALF_WIDTH * 2.0 + 2.0 + r * 2 * ROW_RUN, 0.45 + y, ROW_RUN), Vector3(0, (0.45 + y) * 0.5, side * (31.4 + r * ROW_RUN)), color)
	# Aisles: lighter stair strips that break up the rows.
	for side in [-1.0, 1.0]:
		for z in [-20.0, -6.0, 6.0, 20.0]:
			for r in range(ROWS):
				box(Vector3(ROW_RUN, 0.02, 0.9), Vector3(side * (SIDE_X + r * ROW_RUN), 0.46 + r * ROW_RISE, z), Color("#2a3746"))

func build_crowd() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2207
	var shared: Array[StandardMaterial3D] = []
	for i in range(6):
		var m := StandardMaterial3D.new()
		m.albedo_texture = CROWD
		var v := rng.randf_range(0.24, 0.42)
		m.albedo_color = Color(v, v * 1.02, v * 1.1)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		m.alpha_scissor_threshold = 0.4
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		shared.append(m)
	var quad := QuadMesh.new()
	quad.size = Vector2(4.5, 1.5)
	for r in range(ROWS):
		var y := 0.9 + r * ROW_RISE + 0.42
		for side in [-1.0, 1.0]:
			# Sides: cards run along the rink, facing the ice.
			var count := int((60.0 + r * 2 * ROW_RUN) / 4.5)
			for k in range(count):
				var card := MeshInstance3D.new()
				card.mesh = quad
				card.material_override = shared[rng.randi() % shared.size()]
				card.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				card.position = Vector3(side * (SIDE_X + r * ROW_RUN), y, -count * 2.25 + 2.25 + k * 4.5)
				card.rotation.y = -side * PI / 2
				card.scale.x = -1 if rng.randf() > 0.5 else 1
				add_child(card)
			# Ends.
			var end_count := int((Arena.HALF_WIDTH * 2.0 + r * 2 * ROW_RUN) / 4.5)
			for k in range(end_count):
				var card := MeshInstance3D.new()
				card.mesh = quad
				card.material_override = shared[rng.randi() % shared.size()]
				card.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				card.position = Vector3(-end_count * 2.25 + 2.25 + k * 4.5, y, side * (31.4 + r * ROW_RUN))
				card.rotation.y = 0.0 if side < 0 else PI
				card.scale.x = -1 if rng.randf() > 0.5 else 1
				add_child(card)

func build_fascia() -> void:
	var top := ROWS * ROW_RISE + 1.2
	var out_x := SIDE_X + ROWS * ROW_RUN
	var out_z := 31.4 + ROWS * ROW_RUN
	var blue := Color("#164a9a")
	for side in [-1.0, 1.0]:
		var ribbon := box(Vector3(0.2, 1.1, out_z * 2 + 1), Vector3(side * (out_x + 0.1), top, 0), blue)
		ribbon.material_override = emissive(blue.lightened(0.05), 1.2)
		led_ribbons.append(ribbon)
		var end_ribbon := box(Vector3(out_x * 2 + 1, 1.1, 0.2), Vector3(0, top, side * (out_z + 0.1)), blue)
		end_ribbon.material_override = emissive(blue.lightened(0.05), 1.2)
		led_ribbons.append(end_ribbon)
		for z in [-18.0, 0.0, 18.0]:
			text(arena_name, Vector3(side * out_x, top, z), Vector3(-side, 0, 0), 0.62, Color(1, 1, 1))
		text(arena_name, Vector3(0, top, side * out_z), Vector3(0, 0, -side), 0.62, Color(1, 1, 1))
		# Upper bowl wall above the ribbon disappears into the dark.
		box(Vector3(0.3, 8, out_z * 2 + 2), Vector3(side * (out_x + 0.6), top + 4.5, 0), Color("#070b11"))
		box(Vector3(out_x * 2 + 2, 8, 0.3), Vector3(0, top + 4.5, side * (out_z + 0.6)), Color("#070b11"))

func build_lights() -> void:
	# Light trusses above the ice: bright fixtures seen from low cameras.
	for x in [-9.0, -3.0, 3.0, 9.0]:
		var truss := box(Vector3(0.25, 0.25, 50), Vector3(x, 19.5, 0), Color("#1a2330"))
		truss.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		truss.set_meta("rigging", true)
		for z in range(-22, 23, 4):
			var lamp := box(Vector3(0.7, 0.12, 0.7), Vector3(x, 19.3, z), Color.WHITE)
			lamp.material_override = emissive(Color("#f4f7ff"), 3.0)
			lamp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			lamp.set_meta("rigging", true)
	# Ceiling: one downward-facing, back-culled plane. It darkens the view up
	# from low cameras but is invisible from above, so the full-rink camera
	# (high over the roof line) still sees the ice.
	var ceiling := MeshInstance3D.new()
	ceiling.name = "Ceiling"
	var plane := PlaneMesh.new()
	plane.size = Vector2(80, 100)
	plane.flip_faces = true
	ceiling.mesh = plane
	var ceiling_mat := StandardMaterial3D.new()
	ceiling_mat.albedo_color = Color("#06090e")
	ceiling_mat.cull_mode = BaseMaterial3D.CULL_BACK
	ceiling.material_override = ceiling_mat
	ceiling.position = Vector3(0, 23, 0)
	ceiling.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ceiling)

func build_jumbotron() -> void:
	var core := Node3D.new()
	core.position = Vector3(0, 13.5, 0)
	core.name = "Jumbotron"
	add_child(core)
	var body := helper.block(core, Vector3(6.4, 3.6, 6.4), Vector3.ZERO, Color("#0b0f15"))
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for y in [-2.05, 2.05]:
		var ring := helper.block(core, Vector3(6.6, 0.4, 6.6), Vector3(0, y, 0), Color("#164a9a"))
		ring.material_override = emissive(Color("#1f5fbf"), 1.4)
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for i in range(4):
		var facing := Vector3(sin(i * PI / 2), 0, cos(i * PI / 2))
		var screen := MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = Vector2(5.8, 3.1)
		screen.mesh = quad
		screen.material_override = emissive(Color("#0a1a33"), 1.0)
		screen.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var right := Vector3.UP.cross(facing).normalized()
		screen.basis = Basis(right, Vector3.UP, facing)
		screen.position = facing * 3.21
		core.add_child(screen)
		jumbotron_screens.append(screen)
		var l := text("TOR  0     MTL  0", facing * 3.23 + Vector3(0, 0.45, 0), facing, 0.9, Color(1, 1, 1), core)
		jumbotron_labels.append(l)
		var sub := text("1ST   20:00", facing * 3.23 + Vector3(0, -0.75, 0), facing, 0.6, Color("#e8b83a"), core)
		jumbotron_labels.append(sub)
	for x in [-2.0, 2.0]:
		var cable := box(Vector3(0.05, 4.0, 0.05), Vector3(x * 1.25, 17.4, 0), Color("#2a3440"))
		cable.rotation.z = -x * 0.12
		cable.set_meta("rigging", true)
	for g in core.find_children("*", "GeometryInstance3D", true, false):
		g.set_meta("rigging", true)

func set_scoreboard(line: String, sub: String) -> void:
	scoreboard_text.assign([line, sub])
	if scoreboard_hold:
		return
	for i in range(jumbotron_labels.size()):
		jumbotron_labels[i].text = line if i % 2 == 0 else sub
