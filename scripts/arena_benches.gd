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
## Seated players are the same skinned skater as on the ice (skater_visual.gd)
## in its seated pose (pose_seated()): full kit, numbers on the jersey, helmet
## and neck guard, about half of them holding their stick upright. They are
## posed only when their inputs change, a few per frame (POSE_BUDGET), so a
## full bench costs little more than the on-ice skaters. set_team_colors()
## rebuilds a team's figures in the new kit.
## set_penalty_count() seats up to two penalised players in a team's box.

const Arena = preload("res://scripts/arena.gd")
const SkaterVisual = preload("res://scripts/skater_visual.gd")

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
## Most bench figures re-posed per frame (only those whose pose changed).
const POSE_BUDGET := 6
## How far the upper body / head turn to follow the puck (radians).
const BODY_TURN := 0.55
const HEAD_TURN := 0.75
## Seconds a bench stays on its feet after its team scores.
const CHEER_TIME := 4.5
## Line change: how far (m) a player steps forward off the seat as he gets up
## to go out, and how long after he leaves that his seat is taken by the
## player who came off (sitting down).
const RISE_STEP := 0.30
const SEAT_RETURN := 0.5
## The player who comes off walks from where he landed on the bench floor to
## the free seat (go_out() with a landing) at WALK_SPEED m/s, turning round to
## face the ice on the way, then sits. The one who goes out is picked about
## PASS_GAP (one seat) along the bench from the landing, so the two pass side
## by side instead of walking through each other.
const WALK_SPEED := 1.3
const WALK_MIN := 0.6
const PASS_GAP := 0.85

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
## Per-figure pose state (build_player()), the seated skater visuals per team,
## and when each team's bench cheers (it scored) or slumps (it conceded).
var _rigs: Array = []
var _numbers: Array = [[], []]
var _cheer_until := [-1.0, -1.0]
var _slump_until := [-1.0, -1.0]
var _time := 0.0
var _next_pose := 0
## World position the players watch; defaults to the arena's puck.
var watch_target: Variant = null

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
	# The skinned kit bakes its colours into several meshes: rebuild the team.
	for rig in _rigs:
		if rig.team == team: _dress(rig)

## Jersey numbers for the seated players of `team` (bench first, then the two
## penalty-box seats), e.g. the roster players who are not on the ice.
func set_bench_numbers(team: int, numbers: Array) -> void:
	if numbers.is_empty(): return
	for i in range(_numbers[team].size()):
		_numbers[team][i].set_number(str(numbers[i % numbers.size()]))

## Goal reaction: `team`'s bench jumps up and cheers, arms raised, for
## CHEER_TIME; the other bench slumps forward, heads down.
func celebrate(team: int) -> void:
	_cheer_until[team] = _time + CHEER_TIME
	_slump_until[1 - team] = _time + CHEER_TIME
	_cheer_until[1 - team] = -1.0
	_slump_until[team] = -1.0

func is_cheering(team: int) -> bool:
	return _time < _cheer_until[team]

## Line change, step 1 (match.gd, as a tired skater starts his hop onto the
## bench): the seated player nearest world z `z` on `team`'s bench gets up
## off the seat, stick raised, ready to go over the boards. Returns false if
## nobody is free to get up (everyone already up or the bench empty).
func stand_up(team: int, z: float) -> bool:
	var best = null
	var best_score := INF
	for rig in _rigs:
		if rig.team != team or String(rig.fig.name).begins_with("PenaltySeat"): continue
		if not rig.fig.visible or rig.rise_target > 0.0 or rig.return_at >= 0.0 or rig.walk_t >= 0.0: continue
		# About one seat along from where the tired player lands (PASS_GAP).
		var score := absf(absf(rig.fig.global_position.z - z) - PASS_GAP)
		if score < best_score:
			best = rig
			best_score = score
	if best == null: return false
	best.rise_target = 1.0
	best.carry_scale = 1.0
	# A whistle can call the change off: if nobody takes him out, sit back down.
	best.rise_until = _time + 3.5
	return true

## Line change, step 2 (as the fresh player's hop onto the ice starts): the
## player who got up for `team` leaves his seat - he is the one going out, so
## his figure is hidden and the world position he stands at (floor level) is
## returned for the hop to start from, or null if nobody was up. His seat is
## taken SEAT_RETURN s later by the player who came off, wearing `number`,
## who sits down into it.
## With `landing` (world position where the player coming off stepped down
## onto the bench floor) and `facing` (his world facing there), he does not
## vanish: from that frame he stands at the landing, walks to the free seat
## (curving back off the boards first, turning to face the ice) and sits.
func go_out(team: int, number: String, landing: Variant = null, facing := Vector3.ZERO) -> Variant:
	for rig in _rigs:
		if rig.team != team or rig.rise_target <= 0.0 or not rig.fig.visible: continue
		var at: Vector3 = rig.visual.global_position
		at.y = rig.fig.global_position.y
		if landing is Vector3:
			_start_walk(rig, landing, facing, number)
		else:
			rig.fig.visible = false
			rig.return_at = _time + SEAT_RETURN
			rig.return_number = number
		return at
	return null

func _start_walk(rig: Dictionary, landing: Vector3, facing: Vector3, number: String) -> void:
	var fig: Node3D = rig.fig
	var from: Vector3 = fig.to_local(landing)
	from.y = 0.0
	var to := Vector3(0, 0, RISE_STEP)
	rig.walk_from = from
	# Back off the boards at the landing's spot along the bench, then across.
	rig.walk_mid = Vector3(from.x, 0, to.z)
	var mid: Vector3 = rig.walk_mid
	var length: float = from.distance_to(mid) + mid.distance_to(to)
	rig.walk_time = maxf(WALK_MIN, length * 0.85 / WALK_SPEED)
	rig.walk_t = 0.0
	var d: Vector3 = fig.global_transform.basis.inverse() * facing
	# The figure's skater faces local +Z at rotation PI (game-facing is -Z).
	rig.walk_yaw = atan2(-d.x, -d.z) if Vector2(d.x, d.z).length() > 0.01 else PI
	rig.rise = 1.0
	rig.rise_target = 0.0
	# He carries his stick as he stepped down (on the floor ahead, not raised),
	# and holds it once seated.
	rig.carry_scale = 0.0
	rig.stick = true
	rig.visual.seat_stick = true
	if number != "": rig.visual.set_number(number)
	_place_walker(rig)
	_pose_rig(rig, true)

## Where the walking player is (figure space) and which way he faces.
func _place_walker(rig: Dictionary) -> void:
	var v: Node3D = rig.visual
	var u: float = clampf(rig.walk_t / rig.walk_time, 0.0, 1.0)
	var t := smoothstep(0.0, 1.0, u)
	var a: Vector3 = rig.walk_from
	var b: Vector3 = rig.walk_mid
	var c := Vector3(0, 0, RISE_STEP)
	var p := a.lerp(b, t).lerp(b.lerp(c, t), t)
	# Small step bob while moving.
	p.y = absf(sin(rig.walk_t * 9.0)) * 0.018 * sin(PI * u)
	v.position = p
	v.rotation.y = lerp_angle(rig.walk_yaw, PI, smoothstep(0.35, 0.95, u))

func is_walking(rig: Dictionary) -> bool:
	return rig.walk_t >= 0.0

## Seated figures currently up to go out / waiting for a player to sit (tests).
func rising_count(team: int) -> int:
	var n := 0
	for rig in _rigs:
		if rig.team == team and (rig.rise_target > 0.0 or rig.return_at >= 0.0 or rig.walk_t >= 0.0): n += 1
	return n

func _process(delta: float) -> void:
	update_figures(delta)

## Idle motion: upper body and head turning (with a little per-player lag)
## to follow the puck, standing up and cheering on goals, slumping after a
## goal against. Pose inputs update every frame; the skinned figures are
## re-posed round-robin, at most POSE_BUDGET per frame, and only when their
## inputs moved.
func update_figures(delta: float) -> void:
	_time += delta
	var target := Vector3.ZERO
	if watch_target is Vector3:
		target = watch_target
	else:
		var puck = get_parent().get("puck") if get_parent() != null else null
		if puck != null and is_instance_valid(puck): target = puck.global_position
	var k := 1.0 - exp(-delta * 3.0)
	for rig in _rigs:
		var fig: Node3D = rig.fig
		if rig.return_at >= 0.0 and _time >= rig.return_at:
			# The player who came off takes the free seat: he appears on his
			# feet (stick up, as he stepped off the boards) and sits down.
			rig.return_at = -1.0
			rig.rise_target = 0.0
			rig.rise = 1.0
			fig.visible = true
			if rig.return_number != "": rig.visual.set_number(rig.return_number)
			_pose_rig(rig, true)
		if not fig.is_visible_in_tree(): continue
		var team: int = rig.team
		if rig.walk_t >= 0.0:
			# Walking from the landing to his seat: on his feet until he gets there.
			rig.walk_t += delta
			_place_walker(rig)
			if rig.walk_t >= rig.walk_time:
				rig.walk_t = -1.0
				rig.visual.rotation.y = PI
			else:
				continue
		if rig.rise_target > 0.0 and _time > rig.rise_until: rig.rise_target = 0.0
		rig.rise = move_toward(rig.rise, rig.rise_target, delta * 1.6)
		var on_bench := not String(fig.name).begins_with("PenaltySeat")
		var cheer: bool = on_bench and _time + rig.lag < _cheer_until[team] and _time > _cheer_until[team] - CHEER_TIME + rig.lag
		var slump: bool = on_bench and _time < _slump_until[team]
		rig.stand = lerpf(rig.stand, 1.0 if cheer else 0.0, 1.0 - exp(-delta * 5.0))
		rig.slump = lerpf(rig.slump, 1.0 if slump else 0.0, 1.0 - exp(-delta * 2.0))
		var lp := fig.to_local(target)
		var want := clampf(atan2(lp.x, lp.z), -1.3, 1.3)
		# Lagged reaction: each player re-aims at a slightly different rate.
		rig.yaw = lerpf(rig.yaw, want, k * (0.55 + rig.lag))
	var n := _rigs.size()
	var posed := 0
	for step in range(n):
		if posed >= POSE_BUDGET: break
		var rig: Dictionary = _rigs[(_next_pose + step) % n]
		if not rig.fig.is_visible_in_tree(): continue
		if _pose_rig(rig): posed += 1
	_next_pose = (_next_pose + maxi(posed, 1)) % maxi(n, 1)

## Feeds the rig's state to its skater visual; re-poses it (returns true) only
## if something visible changed since the last pose.
func _pose_rig(rig: Dictionary, force := false) -> bool:
	var v = rig.visual
	var st: float = smoothstep(0.0, 1.0, rig.stand)
	# Up to go out on a line change (stand_up()): off the seat, not cheering.
	var up: float = smoothstep(0.0, 1.0, rig.rise)
	st *= 1.0 - up
	var state := [(1.0 - st) * (1.0 - up), (rig.yaw_bias * (1.0 - st) + rig.yaw) * (1.0 - up), rig.slump * (1.0 - up), st,
		_time * 7.0 + rig.cheer_phase if st > 0.01 else 0.0, up * rig.carry_scale, up]
	var last: Array = rig.get("posed", [])
	if not force and last.size() == state.size():
		var moved := 0.0
		for i in range(state.size()): moved = maxf(moved, absf(state[i] - last[i]))
		if moved < 0.004: return false
	rig.posed = state
	v.seat = state[0]
	v.seat_yaw = state[1]
	v.seat_slump = state[2]
	v.cheer = state[3]
	v.cheer_pump = state[4]
	v.seat_lean = rig.lean
	v.stick_carry = state[5]
	v.stand_tall = state[6]
	v.sticks.visible = rig.stick or state[6] > 0.01
	v.pose_seated()
	if rig.walk_t >= 0.0: return true
	# Cheering bounce on the toes; stepping forward off the seat to go out.
	v.position = Vector3(0, absf(sin(_time * 9.0 + rig.cheer_phase)) * 0.03 * st, RISE_STEP * state[6])
	return true

## Two-bone solve: knee for a hip and ankle with fixed thigh/shin lengths,
## bending towards `forward`.
static func solve_knee(hip: Vector3, ankle: Vector3, l1: float, l2: float, forward: Vector3) -> Vector3:
	var d := clampf(hip.distance_to(ankle), absf(l1 - l2) + 0.001, l1 + l2 - 0.001)
	var axis := (ankle - hip).normalized()
	var a := (l1 * l1 - l2 * l2 + d * d) / (2.0 * d)
	var h := sqrt(maxf(l1 * l1 - a * a, 0.0))
	var bend := (forward - axis * forward.dot(axis)).normalized()
	return hip + axis * a + bend * h

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
## the ice (local +Z towards -side in world x). The body is a skinned skater
## (skater_visual.gd, _dress()) in its seated pose, driven by update_figures().
func build_player(team: int, parent: Node3D, pos: Vector3, side: float) -> Node3D:
	var fig := Node3D.new()
	fig.name = "Seated"
	parent.add_child(fig)
	fig.position = pos
	fig.rotation.y = -side * PI / 2 + _rng.randf_range(-0.12, 0.12)
	var rig := {"team": team, "fig": fig, "phase": _rng.randf_range(0.0, TAU),
		"lag": _rng.randf_range(0.0, 0.45), "stand": 0.0, "slump": 0.0, "yaw": 0.0, "cheer_phase": _rng.randf_range(0.0, TAU),
		"lean": _rng.randf_range(0.12, 0.42), "yaw_bias": _rng.randf_range(-0.15, 0.15),
		"spread": _rng.randf_range(0.12, 0.18), "stick": _rng.randf() < 0.55,
		"number": str(_rng.randi_range(2, 98)), "index": _numbers[team].size(), "visual": null,
		"rise": 0.0, "rise_target": 0.0, "rise_until": 0.0, "return_at": -1.0, "return_number": "",
		"carry_scale": 1.0, "walk_t": -1.0, "walk_time": 1.0, "walk_from": Vector3.ZERO, "walk_mid": Vector3.ZERO, "walk_yaw": PI}
	fig.set_meta("rig", rig)
	_rigs.append(rig)
	_numbers[team].append(null)
	_dress(rig)
	return fig

## (Re)builds the rig's skinned skater in its team's current kit.
func _dress(rig: Dictionary) -> void:
	var team: int = rig.team
	var number: String = rig.number
	var old = rig.visual
	if old != null:
		number = old.number
		old.get_parent().remove_child(old)
		old.queue_free()
	var v = SkaterVisual.new()
	v.name = "Skater"
	v.kit = team_kits[team].jersey
	v.accent = team_kits[team].accent
	v.number = number
	v.seat_stick = rig.stick
	v.seat_spread = rig.spread
	v.seat_lean = rig.lean
	v.seat = 1.0
	# Game-facing is -Z; the figure faces +Z (the ice).
	v.rotation.y = PI
	rig.fig.add_child(v)
	# Not a skater on the ice: no skate cuts (ice_marks.gd) for bench figures.
	v.remove_from_group("skater_visuals")
	v.sticks.visible = rig.stick
	for sp in v.sprays: sp.visible = false
	rig.visual = v
	_numbers[team][rig.index] = v
	rig.erase("posed")
	_pose_rig(rig, true)

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
