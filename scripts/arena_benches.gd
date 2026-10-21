extends Node3D
## Player benches and penalty boxes, NHL layout: both team benches on the west
## side (x < 0, where match.gd sends changing skaters, BENCH_X), the two
## penalty boxes with the off-ice officials' booth between them straight across
## on the east side. The first two seating rows are cut out there
## (arena_dressing.gd reads in_zone()); the third row's riser is the back wall.
## The bench fronts have no glass above the boards (arena.gd board_segment()
## reads glass_openings()); the board/glass collider is unchanged, so a lifted
## puck still stays in play.
##
## Seated players are simple code-built figures (helmet, jersey with shoulder
## pads, pants, socks, skates, gloves, sticks), not the skinned skater: they sit
## 1-3 m behind the boards and read at gameplay-camera distance. Kit colours are
## shared materials, so set_team_colors() recolours a whole bench at once.
## set_penalty_count() seats up to two penalised players in a team's box.

const Arena = preload("res://scripts/arena.gd")

const BENCH_SIDE := -1.0
const BOX_SIDE := 1.0
## Bench zone along the west boards: |z| <= BENCH_HALF, split by a short
## glassed-in section (|z| < BENCH_GAP) between the two benches.
const BENCH_HALF := 9.8
const BENCH_GAP := 1.4
## Penalty boxes: BOX_GAP <= |z| <= BOX_HALF; the officials' booth sits between.
const BOX_HALF := 5.2
const BOX_GAP := 1.2
## Depth behind the board face to the back wall (front of seating row 2).
const DEPTH := 2.675
const BOARD_BACK := 0.12
const SEAT_TOP := 0.48
const GLASS_TOP := 2.66
const PLAYERS_PER_BENCH := 9

## Team 0 (home) bench and box at z > 0, team 1 at z < 0: each bench is at the
## end its team defends in periods 1 and 3 (long change in the 2nd), as in the NHL.
var team_kits: Array = [
	{"jersey": Color("#164a9a"), "accent": Color("#e8eef5"), "pants": Color("#0f1d36")},
	{"jersey": Color("#e9edf0"), "accent": Color("#b3162c"), "pants": Color("#7c1024")},
]
var benches: Array[Node3D] = []
var penalty_boxes: Array[Node3D] = []
## Seated figures per team on the bench, and the two penalty-box seats per team.
var seated: Array = [[], []]
var box_seats: Array = [[], []]
var _team_mats: Array = [{}, {}]
var _rng := RandomNumberGenerator.new()
var _glass_mat: StandardMaterial3D

## Whether the interval [z0, z1] on `side` (-1 west, +1 east) overlaps the cut
## out bench / penalty box zone.
static func in_zone(side: float, z0: float, z1: float) -> bool:
	var half := BENCH_HALF if side < 0 else BOX_HALF
	return z1 > -half and z0 < half

## World-z intervals along the west boards where the glass above the boards is
## left out (the bench fronts).
static func glass_openings() -> Array[Vector2]:
	return [Vector2(-BENCH_HALF, -BENCH_GAP), Vector2(BENCH_GAP, BENCH_HALF)]

func wx(side: float, depth: float) -> float:
	return side * (Arena.HALF_WIDTH + depth)

func _ready() -> void:
	_rng.seed = 4410
	_glass_mat = _mat(Color(0.58, 0.8, 0.87, 0.12), 0.1)
	for team in range(2):
		_team_mats[team] = {
			"jersey": _mat(team_kits[team].jersey, 0.85),
			"accent": _mat(team_kits[team].accent, 0.85),
			"pants": _mat(team_kits[team].pants, 0.7),
			"helmet": _mat(Color("#132434"), 0.3),   # same shell colour as the on-ice skaters
		}
	for team in range(2):
		var zsign := 1.0 if team == 0 else -1.0
		benches.append(build_bench(team, zsign))
		penalty_boxes.append(build_box(team, zsign))
	build_bench_divider()
	build_officials_booth()

func set_team_colors(team: int, jersey: Color, accent: Color, pants: Color = Color(0, 0, 0, 0)) -> void:
	var m: Dictionary = _team_mats[team]
	m.jersey.albedo_color = jersey
	m.accent.albedo_color = accent
	if pants.a > 0: m.pants.albedo_color = pants
	team_kits[team] = {"jersey": jersey, "accent": accent, "pants": m.pants.albedo_color}

## Seats `count` (0-2) penalised players of `team` in its penalty box.
func set_penalty_count(team: int, count: int) -> void:
	var seats: Array = box_seats[team]
	for i in range(seats.size()):
		seats[i].visible = i < count

func penalty_count(team: int) -> int:
	var n := 0
	for s in box_seats[team]:
		if s.visible: n += 1
	return n

# --- structure -------------------------------------------------------------

func build_bench(team: int, zsign: float) -> Node3D:
	var root := Node3D.new()
	root.name = "Bench%d" % team
	add_child(root)
	var s := BENCH_SIDE
	var z0 := zsign * BENCH_GAP
	var z1 := zsign * BENCH_HALF
	var zc := (z0 + z1) * 0.5
	var length := absf(z1 - z0)
	# Black rubber floor, a step up to the seat, padded bench, back panel.
	_box(root, Vector3(DEPTH - BOARD_BACK, 0.04, length), Vector3(wx(s, (BOARD_BACK + DEPTH) * 0.5), 0.02, zc), Color("#15171a"), 0.95)
	_box(root, Vector3(0.6, SEAT_TOP - 0.06, length - 0.1), Vector3(wx(s, 2.3), (SEAT_TOP - 0.06) * 0.5, zc), Color("#2b2f35"), 0.8)
	_box(root, Vector3(0.62, 0.06, length - 0.1), Vector3(wx(s, 2.3), SEAT_TOP - 0.03, zc), team_kits[team].pants.darkened(0.25), 0.6)
	_box(root, Vector3(0.05, 0.75, length - 0.1), Vector3(wx(s, DEPTH - 0.03), SEAT_TOP + 0.37, zc), Color("#1d2229"), 0.7)
	# Shelf on the back of the boards with water bottles and towels.
	_box(root, Vector3(0.22, 0.03, length - 0.2), Vector3(wx(s, BOARD_BACK + 0.11), 0.98, zc), Color("#30353c"), 0.6)
	for k in range(6):
		var bz := z0 + zsign * (0.9 + k * (length - 1.8) / 5.0)
		for j in range(2):
			var bottle := _cyl(root, 0.035, 0.24, Vector3(wx(s, BOARD_BACK + 0.07 + j * 0.09), 1.11, bz + j * 0.11), Color("#d9dde2") if (k + j) % 2 == 0 else team_kits[team].jersey)
			bottle.name = "Bottle"
		_box(root, Vector3(0.16, 0.02, 0.32), Vector3(wx(s, BOARD_BACK + 0.12), 1.005, bz + 0.38), Color("#eef0f2"), 1.0)
	# Glass end panels and the partition above the back wall (fans behind).
	for z in [z0, z1]:
		_glass(root, Vector3(DEPTH - BOARD_BACK, GLASS_TOP, 0.03), Vector3(wx(s, (BOARD_BACK + DEPTH) * 0.5), GLASS_TOP * 0.5, z))
	_glass(root, Vector3(0.03, GLASS_TOP - 1.37, length), Vector3(wx(s, DEPTH), (GLASS_TOP + 1.37) * 0.5, zc))
	# Stanchions where the front glass stops, plus the end-panel posts.
	for z in [z0, z1]:
		_post(root, Vector3(wx(s, 0.0), 1.1, z), Vector3(wx(s, 0.0), GLASS_TOP, z))
		_post(root, Vector3(wx(s, DEPTH), 0.0, z), Vector3(wx(s, DEPTH), GLASS_TOP, z))
	# Two doors in the boards, near each end of the bench.
	for zd in [z0 + zsign * 0.9, z1 - zsign * 0.9]:
		_door(root, s, zd, 0.85, false)
	# Spare sticks leaning in the rack at the bench end.
	for k in range(7):
		var sz := z1 - zsign * (0.15 + k * 0.07)
		_stick(root, Vector3(wx(s, DEPTH - 0.12), 0.02, sz), Vector3(wx(s, DEPTH - 0.32), 1.45, sz + zsign * 0.05))
	# Seated players, facing the ice, with an occasional gap.
	var spacing := (length - 0.8) / PLAYERS_PER_BENCH
	for k in range(PLAYERS_PER_BENCH):
		var pz := z0 + zsign * (0.4 + (k + 0.5) * spacing + _rng.randf_range(-0.06, 0.06))
		var figure := build_player(team, root, Vector3(wx(s, 2.05), 0.0, pz), s)
		seated[team].append(figure)
	# Coach standing behind the bench, on the riser at the gap end.
	build_coach(root, Vector3(wx(s, DEPTH - 0.25), 0.0, z0 + zsign * 0.35), s)
	return root

func build_bench_divider() -> void:
	var s := BENCH_SIDE
	_box(self, Vector3(DEPTH - BOARD_BACK, 0.04, BENCH_GAP * 2.0), Vector3(wx(s, (BOARD_BACK + DEPTH) * 0.5), 0.02, 0), Color("#15171a"), 0.95)
	_box(self, Vector3(DEPTH - BOARD_BACK - 0.2, 1.0, BENCH_GAP * 2.0 - 0.1), Vector3(wx(s, (BOARD_BACK + DEPTH) * 0.5 + 0.1), 0.5, 0), Color("#232831"), 0.8)

func build_box(team: int, zsign: float) -> Node3D:
	var root := Node3D.new()
	root.name = "PenaltyBox%d" % team
	add_child(root)
	var s := BOX_SIDE
	var z0 := zsign * BOX_GAP
	var z1 := zsign * BOX_HALF
	var zc := (z0 + z1) * 0.5
	var length := absf(z1 - z0)
	_box(root, Vector3(DEPTH - BOARD_BACK, 0.04, length), Vector3(wx(s, (BOARD_BACK + DEPTH) * 0.5), 0.02, zc), Color("#15171a"), 0.95)
	_box(root, Vector3(0.55, SEAT_TOP, length - 0.3), Vector3(wx(s, 2.3), SEAT_TOP * 0.5, zc), Color("#2b2f35"), 0.8)
	_box(root, Vector3(0.05, 0.75, length - 0.1), Vector3(wx(s, DEPTH - 0.03), SEAT_TOP + 0.37, zc), Color("#1d2229"), 0.7)
	# Fully glassed in: end panels and the back partition (front glass is the
	# rink glass above the boards).
	for z in [z0, z1]:
		_glass(root, Vector3(DEPTH - BOARD_BACK, GLASS_TOP, 0.03), Vector3(wx(s, (BOARD_BACK + DEPTH) * 0.5), GLASS_TOP * 0.5, z))
		_post(root, Vector3(wx(s, DEPTH), 0.0, z), Vector3(wx(s, DEPTH), GLASS_TOP, z))
	_glass(root, Vector3(0.03, GLASS_TOP - 1.37, length), Vector3(wx(s, DEPTH), (GLASS_TOP + 1.37) * 0.5, zc))
	_door(root, s, zc, 0.85, true)
	# Small "PENALTY" sign on the back glass, facing the ice.
	var sign_ := Label3D.new()
	sign_.text = "PENALTY"
	sign_.font_size = 64
	sign_.pixel_size = 0.16 / 64.0
	sign_.modulate = Color("#e8b33a")
	sign_.outline_size = 0
	sign_.double_sided = false
	sign_.rotation.y = -s * PI / 2
	sign_.position = Vector3(wx(s, DEPTH - 0.02), 2.25, zc)
	root.add_child(sign_)
	for k in range(2):
		var pz := zc + (k - 0.5) * 1.1
		var figure := build_player(team, root, Vector3(wx(s, 2.05), 0.0, pz), s)
		figure.name = "PenaltySeat%d" % k
		figure.visible = false
		box_seats[team].append(figure)
	return root

func build_officials_booth() -> void:
	var s := BOX_SIDE
	_box(self, Vector3(DEPTH - BOARD_BACK, 0.04, BOX_GAP * 2.0), Vector3(wx(s, (BOARD_BACK + DEPTH) * 0.5), 0.02, 0), Color("#15171a"), 0.95)
	# Desk with the game-clock console, two off-ice officials behind it.
	_box(self, Vector3(0.5, 0.9, BOX_GAP * 2.0 - 0.2), Vector3(wx(s, 0.75), 0.45, 0), Color("#262b33"), 0.6)
	var screen := _box(self, Vector3(0.04, 0.22, 0.5), Vector3(wx(s, 0.62), 1.02, 0), Color("#0b0f14"), 0.3)
	var lit := StandardMaterial3D.new()
	lit.albedo_color = Color("#d0352b")
	lit.emission_enabled = true
	lit.emission = Color("#d0352b")
	lit.emission_energy_multiplier = 1.2
	screen.material_override = lit
	for z in [-0.5, 0.5]:
		build_official(self, Vector3(wx(s, 1.45), 0.0, z), s)

# --- figures ---------------------------------------------------------------

## Seated skater, origin on the floor under the front edge of his seat; faces
## the ice (local +Z towards -side in world x).
func build_player(team: int, parent: Node3D, pos: Vector3, side: float) -> Node3D:
	var m: Dictionary = _team_mats[team]
	var fig := Node3D.new()
	fig.name = "Seated"
	parent.add_child(fig)
	fig.position = pos
	fig.rotation.y = -side * PI / 2 + _rng.randf_range(-0.12, 0.12)
	var skin := _mat(Color.from_hsv(0.07, _rng.randf_range(0.25, 0.45), _rng.randf_range(0.55, 0.85)), 0.6)
	var black := _mat(Color("#121417"), 0.5)
	var glove := _mat(team_kits[team].pants.darkened(0.2), 0.7)
	var spread := _rng.randf_range(0.10, 0.15)
	# Legs: thighs out over the seat edge, shins down to skates on the floor.
	for x in [-spread, spread]:
		var hip := Vector3(x * 0.8, 0.55, -0.18)
		var knee := Vector3(x, 0.56, 0.24 + _rng.randf_range(-0.03, 0.03))
		var ankle := Vector3(x * 1.05, 0.13, knee.z + _rng.randf_range(0.02, 0.12))
		_limb(fig, hip, knee, 0.105, m.pants)
		_limb(fig, knee, ankle, 0.065, m.jersey)          # sock
		_limb(fig, knee.lerp(ankle, 0.35) + Vector3(0, 0, 0.004), knee.lerp(ankle, 0.5), 0.068, m.accent)
		_part(fig, BoxMesh.new(), Vector3(0.1, 0.13, 0.29), ankle + Vector3(0, -0.05, 0.06), black)
		_part(fig, BoxMesh.new(), Vector3(0.012, 0.03, 0.27), ankle + Vector3(0, -0.12, 0.06), _mat(Color("#b9c2ca"), 0.2))
	# Upper body on a pivot at the hips so it can lean forward over the knees.
	var upper := Node3D.new()
	fig.add_child(upper)
	upper.position = Vector3(0, 0.56, -0.16)
	upper.rotation.x = _rng.randf_range(0.12, 0.45)   # forward lean
	upper.rotation.z = _rng.randf_range(-0.05, 0.05)
	upper.rotation.y = _rng.randf_range(-0.3, 0.3)     # watching the play
	_part(upper, CapsuleMesh.new(), Vector3(0.21, 0.62, 0.0), Vector3(0, 0.3, 0), m.jersey)            # torso
	_part(upper, BoxMesh.new(), Vector3(0.43, 0.08, 0.27), Vector3(0, 0.08, 0), m.accent)               # hem stripe
	var shoulders := _part(upper, CapsuleMesh.new(), Vector3(0.13, 0.56, 0.0), Vector3(0, 0.53, 0), m.jersey)
	shoulders.rotation.z = PI / 2
	_part(upper, SphereMesh.new(), Vector3(0.1, 0.0, 0.0), Vector3(0, 0.76, 0.03), skin)                 # face/head
	var helmet := _part(upper, SphereMesh.new(), Vector3(0.122, 0.0, 0.0), Vector3(0, 0.79, -0.01), m.helmet)
	helmet.scale = Vector3(1.0, 0.9, 1.1)
	_part(upper, BoxMesh.new(), Vector3(0.2, 0.05, 0.03), Vector3(0, 0.78, 0.115), _mat(Color(0.1, 0.12, 0.14, 0.55), 0.05))  # visor
	# Arms resting on the knees, gloves at the knees or holding the stick.
	var hold_stick := _rng.randf() < 0.55
	var hands: Array[Vector3] = []
	for x in [-1.0, 1.0]:
		var shoulder := Vector3(x * 0.25, 0.5, 0.0)
		var elbow := Vector3(x * 0.27, 0.24, 0.2)
		var hand := Vector3(x * (0.06 if hold_stick else 0.17), 0.18 + (0.12 if hold_stick and x > 0 else 0.0), 0.38)
		_limb(upper, shoulder, elbow, 0.07, m.jersey)
		_limb(upper, shoulder.lerp(elbow, 0.55), shoulder.lerp(elbow, 0.75), 0.073, m.accent)   # sleeve stripe
		_limb(upper, elbow, hand, 0.062, glove)
		_part(upper, BoxMesh.new(), Vector3(0.1, 0.1, 0.14), hand, glove)
		hands.append(hand)
	if hold_stick:
		# Stick held upright between the knees, knob up near the chin.
		var top := fig.to_global(Vector3(0.06, 1.3, 0.3))
		var blade := fig.to_global(Vector3(0.03, 0.03, 0.6))
		_stick(parent, parent.to_local(blade), parent.to_local(top))
	return fig

func build_coach(parent: Node3D, pos: Vector3, side: float) -> void:
	var suit := _mat(Color("#1b1e24"), 0.7)
	var fig := Node3D.new()
	fig.name = "Coach"
	parent.add_child(fig)
	fig.position = pos
	fig.rotation.y = -side * PI / 2
	for x in [-0.1, 0.1]:
		_limb(fig, Vector3(x, 0.9, 0), Vector3(x, 0.08, 0.02), 0.075, suit)
	_part(fig, CapsuleMesh.new(), Vector3(0.2, 0.68, 0.0), Vector3(0, 1.22, 0), suit)
	_part(fig, BoxMesh.new(), Vector3(0.1, 0.3, 0.02), Vector3(0, 1.38, 0.17), _mat(Color("#e9ecef"), 0.6))
	_part(fig, SphereMesh.new(), Vector3(0.105, 0.0, 0.0), Vector3(0, 1.7, 0.01), _mat(Color("#d8a888"), 0.6))
	_part(fig, SphereMesh.new(), Vector3(0.108, 0.0, 0.0), Vector3(0, 1.73, -0.02), _mat(Color("#4a3a2c"), 0.9))

func build_official(parent: Node3D, pos: Vector3, side: float) -> void:
	var shirt := _mat(Color("#2a3140"), 0.8)
	var fig := Node3D.new()
	fig.name = "OffIceOfficial"
	parent.add_child(fig)
	fig.position = pos
	fig.rotation.y = -side * PI / 2
	_part(fig, BoxMesh.new(), Vector3(0.45, 0.5, 0.45), Vector3(0, 0.25, 0), _mat(Color("#202329"), 0.8))
	_part(fig, CapsuleMesh.new(), Vector3(0.19, 0.6, 0.0), Vector3(0, 0.82, 0), shirt)
	_part(fig, SphereMesh.new(), Vector3(0.1, 0.0, 0.0), Vector3(0, 1.22, 0.02), _mat(Color("#c99a7a"), 0.6))

# --- primitives ------------------------------------------------------------

func _mat(color: Color, roughness: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	if color.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m

func _shadowless(mi: MeshInstance3D) -> MeshInstance3D:
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi

func _box(parent: Node3D, size: Vector3, pos: Vector3, color: Color, roughness := 0.6) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = _mat(color, roughness)
	mi.position = pos
	parent.add_child(mi)
	return _shadowless(mi)

func _glass(parent: Node3D, size: Vector3, pos: Vector3) -> MeshInstance3D:
	var mi := _box(parent, size, pos, Color.WHITE)
	mi.material_override = _glass_mat
	mi.name = "Glass"
	return mi

func _cyl(parent: Node3D, radius: float, height: float, pos: Vector3, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = radius * 0.8
	c.bottom_radius = radius
	c.height = height
	c.radial_segments = 10
	c.rings = 1
	mi.mesh = c
	mi.material_override = _mat(color, 0.4)
	mi.position = pos
	parent.add_child(mi)
	return _shadowless(mi)

func _post(parent: Node3D, a: Vector3, b: Vector3) -> void:
	_rod(parent, a, b, 0.025, _mat(Color("#8a9fac"), 0.3))

func _stick(parent: Node3D, blade: Vector3, top: Vector3) -> void:
	_rod(parent, blade, top, 0.014, _mat(Color("#16181b"), 0.4))
	var b := _part(parent, BoxMesh.new(), Vector3(0.012, 0.07, 0.28), blade + Vector3(0, 0.035, 0), _mat(Color("#101113"), 0.4))
	var along := Vector3(top.x - blade.x, 0, top.z - blade.z)
	if along.length() > 0.01: b.rotation.y = atan2(along.x, along.z)

func _rod(parent: Node3D, a: Vector3, b: Vector3, radius: float, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = radius
	c.bottom_radius = radius
	c.height = a.distance_to(b)
	c.radial_segments = 6
	c.rings = 1
	mi.mesh = c
	mi.material_override = m
	parent.add_child(mi)
	mi.position = (a + b) * 0.5
	mi.quaternion = Quaternion(Vector3.UP, (b - a).normalized())
	return _shadowless(mi)

## Capsule between two points (local to `parent`).
func _limb(parent: Node3D, a: Vector3, b: Vector3, radius: float, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var c := CapsuleMesh.new()
	c.radius = radius
	c.height = maxf(a.distance_to(b) + radius * 2.0, radius * 2.0 + 0.001)
	c.radial_segments = 10
	c.rings = 3
	mi.mesh = c
	mi.material_override = m
	parent.add_child(mi)
	mi.position = (a + b) * 0.5
	if a.distance_to(b) > 0.001:
		mi.quaternion = Quaternion(Vector3.UP, (b - a).normalized())
	return _shadowless(mi)

## Generic part: size.x is the radius for spheres/capsules (size.y = capsule
## height), a box's full size otherwise.
func _part(parent: Node3D, mesh: PrimitiveMesh, size: Vector3, pos: Vector3, m: Material) -> MeshInstance3D:
	if mesh is BoxMesh:
		(mesh as BoxMesh).size = size
	elif mesh is SphereMesh:
		(mesh as SphereMesh).radius = size.x
		(mesh as SphereMesh).height = size.x * 2.0
		(mesh as SphereMesh).radial_segments = 14
		(mesh as SphereMesh).rings = 8
	elif mesh is CapsuleMesh:
		(mesh as CapsuleMesh).radius = size.x
		(mesh as CapsuleMesh).height = size.y
		(mesh as CapsuleMesh).radial_segments = 12
		(mesh as CapsuleMesh).rings = 3
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.position = pos
	parent.add_child(mi)
	return _shadowless(mi)

## Door in the boards: dark seams and a latch on the ice side; a penalty-box
## door also gets a framed glass door above the boards.
func _door(parent: Node3D, side: float, zc: float, width: float, glass_door: bool) -> void:
	var seam := _mat(Color("#2a3038"), 0.5)
	var face := side * (Arena.HALF_WIDTH - 0.128)
	for z in [zc - width * 0.5, zc + width * 0.5]:
		var mi := _part(parent, BoxMesh.new(), Vector3(0.006, 1.0, 0.018), Vector3(face, 0.52, z), seam)
		mi.name = "DoorSeam"
	_part(parent, BoxMesh.new(), Vector3(0.012, 0.05, 0.12), Vector3(face, 0.9, zc + width * 0.5 - 0.1), _mat(Color("#9aa6b0"), 0.25))
	if glass_door:
		for z in [zc - width * 0.5, zc + width * 0.5]:
			_post(parent, Vector3(side * Arena.HALF_WIDTH, 1.1, z), Vector3(side * Arena.HALF_WIDTH, GLASS_TOP, z))
