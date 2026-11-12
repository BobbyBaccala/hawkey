extends RefCounted
## Board hop for line changes: the path a changing skater's visual follows
## over the dasher boards between the ice and the bench floor, and how much
## the legs tuck / the body crouches along it. Used by skater_visual.gd
## (start_hop(), pose()) and driven by match.gd's line change.
##
## The path is expressed in the skater body's (unrotated) parent space: from
## `a` to `b`, crossing the board plane x = `board_x`. It runs in three parts:
## glide/step to the boards (crouch at the end = gather), the vault itself
## (hips rise, knees tuck to the chest so the skates clear the board top,
## then extend for the landing) and a short absorb/step away on the far side.

const DURATION := 1.6
## Fractions of the hop where the vault starts and ends.
const VAULT_START := 0.32
const VAULT_END := 0.78
## Distance from the boards (either face) where the take-off and landing happen.
const TAKEOFF := 0.55
## Board (and cap) thickness behind the face: the boards fill x in
## [board_x - BOARD_DEPTH, board_x] (west boards, benches at x < board_x).
const BOARD_DEPTH := 0.27
## Peak lift of the whole body over the vault (m) and how high the tucked
## ankles come up under the hips (ankle height in figure space).
const LIFT := 0.64
const TUCK_ANKLE_Y := 0.74
## Dasher top (arena.gd board cap at 1.07 m, 0.08 m tall).
const BOARD_TOP := 1.11
## Hand plant on the board cap: when the top hand reaches / leaves the cap
## (hop fractions), how far the wrist sits above the cap (glove thickness)
## and how far to the skater's left of the crossing point.
const PLANT_START := 0.12
const PLANT_END := 0.44
const HAND_ABOVE_CAP := 0.055
const HAND_SIDE := 0.24
## Stick carry: the stick comes up off the ice in the first CARRY_IN of the hop
## (blade raised high, shaft angled up and forward to the blade side) so it is
## clear of the boards over the vault, and goes back down over the last
## CARRY_OUT as the skater steps away (skater_visual.gd stick_carry).
const CARRY_IN := 0.22
const CARRY_OUT := 0.22
## Turn: the skater turns from his heading at the start of the hop to face the
## boards over the first TURN_IN of the hop for a quarter turn, longer for a
## bigger turn (up to TURN_MAX, a half turn, still done before the vault), so
## he pivots into the gather rather than snapping round (turn_weight()).
const TURN_IN := 0.2
const TURN_MAX := 0.3

## Blend (0..1) from the starting heading to sample().facing at hop progress u
## for a turn of `angle` radians.
static func turn_weight(u: float, angle: float) -> float:
	var span := clampf(TURN_IN * absf(angle) / (PI * 0.5), TURN_IN, TURN_MAX)
	return smooth(u / span)

static func smooth(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return x * x * x * (x * (x * 6.0 - 15.0) + 10.0)

static func bump(u: float, centre: float, width: float) -> float:
	var d := absf(u - centre) / width
	if d >= 1.0: return 0.0
	var c := cos(d * PI * 0.5)
	return c * c

## Sample the hop at u in [0, 1]:
## offset - position relative to the body (parent space),
## facing - unit horizontal direction the skater faces (toward the far side),
## tuck - 0..1 knees-to-chest, crouch - 0..1 gather / landing absorb,
## lean - 0..1 extra forward lean of the upper body,
## plant/hand - top-hand weight on the board cap and the cap point,
## carry - 0..1 how far the stick is lifted into its carried pose.
static func sample(u: float, a: Vector3, b: Vector3, board_x: float) -> Dictionary:
	u = clampf(u, 0.0, 1.0)
	var mid := board_x - BOARD_DEPTH * 0.5
	var near_side := signf(a.x - mid)
	if near_side == 0.0: near_side = 1.0
	var reach := TAKEOFF + BOARD_DEPTH * 0.5
	var c_a := Vector3(mid + near_side * reach, 0.0, lerpf(a.z, b.z, 0.35))
	var c_b := Vector3(mid - near_side * reach, 0.0, lerpf(a.z, b.z, 0.65))
	var p: Vector3
	var lift := 0.0
	if u < VAULT_START:
		p = a.lerp(c_a, smooth(u / VAULT_START))
		p.y = a.y * (1.0 - smooth(u / VAULT_START))
	elif u < VAULT_END:
		var s := (u - VAULT_START) / (VAULT_END - VAULT_START)
		# Rise first, travel across over the top, then drop: the skates are only
		# above the boards' footprint while the body is high.
		p = c_a.lerp(c_b, smooth((s - 0.2) / 0.6))
		lift = LIFT * sin(PI * s)
	else:
		var s := (u - VAULT_END) / (1.0 - VAULT_END)
		p = c_b.lerp(b, smooth(s))
		p.y = b.y * smooth(s)
	p.y += lift
	# Knees come up through the gather and stay up until the skates are past.
	var tuck := smooth((u - VAULT_START + 0.05) / 0.17) * smooth((VAULT_END + 0.03 - u) / 0.17)
	var crouch := maxf(bump(u, VAULT_START, 0.12), bump(u, VAULT_END + 0.04, 0.14))
	var facing := Vector3(-near_side, 0.0, (b.z - a.z) * 0.15).normalized()
	# The top (left) hand lets go of the stick, plants on the board cap beside
	# the crossing point through the gather and push-off, and lifts off before
	# the landing. skater_visual.gd fades it further when out of arm's reach.
	var plant := smooth((u - PLANT_START) / 0.14) * smooth((PLANT_END - u) / 0.10)
	var left := Vector3.UP.cross(facing)
	var hand := Vector3(mid, BOARD_TOP + HAND_ABOVE_CAP, lerpf(a.z, b.z, 0.5) + left.z * HAND_SIDE)
	var carry := smooth(u / CARRY_IN) * smooth((1.0 - u) / CARRY_OUT)
	return {"carry": carry, "offset": p, "facing": facing, "tuck": tuck, "crouch": crouch, "lean": maxf(tuck, crouch) * 0.8, "plant": plant, "hand": hand}
