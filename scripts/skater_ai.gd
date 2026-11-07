extends RefCounted
## CPU skater decisions: how a good hockey player reads the play.
##
## Pure static functions (no scene) so they can be unit-tested; match.gd
## gathers positions each tick and acts on the answers.
##
## With the puck, a CPU weighs every option the way a real player does:
## - SHOOT when the shot is worth it: distance, angle, slot, how open the net
##   is (goalie off his angle) and whether bodies are in the lane;
## - PASS to the teammate with the best next chance, only through a lane the
##   defenders can't reach in time (and lead the receiver);
## - CARRY into open ice, steering away from the nearest checker and driving
##   the net when there's room;
## - DUMP it deep when he's stuck in the neutral zone with nothing on;
## - PROTECT (cut back toward the boards) when a checker is right on him.
## Without the puck: pursue on an inside-out angle (take away the middle),
## defencemen keep a gap and back in, everyone marks goal-side in their own
## zone, forwards on offence get open off the defender's line, and anyone who
## can get to a loose or passed puck first goes for the interception.
##
## DIFFICULTY sets how fast they read (decision interval), how accurate their
## shots and passes are, how well they judge lanes and how good their stick
## checks are.
const Arena = preload("res://scripts/arena.gd")

const DIFFICULTIES := ["ROOKIE", "PRO", "ALL-STAR", "SUPERSTAR"]
const SKILL := {
	"ROOKIE":    {"react": 0.55, "shot_noise": 0.55, "pass_noise": 0.12, "read": 0.55, "check": 0.35, "shot_bar": 0.30},
	"PRO":       {"react": 0.40, "shot_noise": 0.38, "pass_noise": 0.08, "read": 0.75, "check": 0.50, "shot_bar": 0.34},
	"ALL-STAR":  {"react": 0.28, "shot_noise": 0.26, "pass_noise": 0.05, "read": 0.90, "check": 0.62, "shot_bar": 0.36},
	"SUPERSTAR": {"react": 0.20, "shot_noise": 0.18, "pass_noise": 0.03, "read": 1.00, "check": 0.72, "shot_bar": 0.38},
}
const DEFAULT_DIFFICULTY := "ALL-STAR"
const PASS_SPEED := 17.0
const STICK_REACH := 1.0          # how far a defender's stick takes a puck off a lane
const SKATE_REACH_SPEED := 2.3    # m/s a defender can close on a lane while the puck travels

static func skill(difficulty: String) -> Dictionary:
	return SKILL.get(difficulty, SKILL[DEFAULT_DIFFICULTY])

static func flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)

static func net(attack: float) -> Vector3:
	return Vector3(0.0, 0.0, attack * Arena.GOAL_LINE)

## Distance from point p to the segment a-b (on the ice plane), and how far
## along it (0..1) the closest point is.
static func segment_distance(p: Vector3, a: Vector3, b: Vector3) -> Vector2:
	var ab := flat(b - a)
	var length_sq := ab.length_squared()
	if length_sq < 1e-6:
		return Vector2(flat(p - a).length(), 0.0)
	var t := clampf(flat(p - a).dot(ab) / length_sq, 0.0, 1.0)
	return Vector2(flat(p - (a + ab * t)).length(), t)

## 0..1: how good a shot from here is. 0 from behind the goal line.
static func shot_quality(shooter: Vector3, attack: float, goalie: Vector3, blockers: Array) -> float:
	var target := net(attack)
	var depth := Arena.GOAL_LINE - shooter.z * attack     # distance out from the goal line
	if depth < 0.3:
		return 0.0
	var to_net := flat(target - shooter)
	var distance := to_net.length()
	var angle := acos(clampf(depth / maxf(distance, 0.01), 0.0, 1.0))  # 0 = straight on
	var distance_q := clampf(1.0 - (distance - 3.0) / 17.0, 0.0, 1.0)
	var angle_q := clampf(1.0 - angle / 1.3, 0.0, 1.0)
	var quality := distance_q * 0.62 + angle_q * 0.38
	quality *= clampf((22.0 - distance) / 6.0, 0.0, 1.0)    # nothing from 22 m out
	quality *= sqrt(angle_q)                               # sharp angles are poor at any range
	if absf(shooter.x) < 3.2 and distance < 10.5:
		quality += 0.12                                    # the slot
	# Goalie off his angle: the far side of the net opens up.
	var goalie_off := segment_distance(goalie, shooter, target).x
	if goalie_off > 0.55:
		quality += clampf((goalie_off - 0.55) * 0.5, 0.0, 0.3)
	# Bodies in the lane block shots.
	for b in blockers:
		var hit := segment_distance(b, shooter, target)
		if hit.y > 0.05 and hit.y < 0.95:
			if hit.x < 0.55:
				quality *= 0.45
			elif hit.x < 1.1:
				quality *= 0.75
	return clampf(quality, 0.0, 1.0)

## 0..1: how safe a pass from a to b is against these opponents (a defender
## can reach the lane with his stick plus whatever he skates while the puck
## travels; `read` < 1 makes the passer misjudge lanes a little).
static func pass_safety(a: Vector3, b: Vector3, opponents: Array, read := 1.0, speed := PASS_SPEED) -> float:
	var length := flat(b - a).length()
	if length < 1.5:
		return 0.0
	var safety := 1.0
	for o in opponents:
		var hit := segment_distance(o, a, b)
		var travel := hit.y * length / speed
		var reach := STICK_REACH + SKATE_REACH_SPEED * travel * read
		var margin := (hit.x - reach) / 1.5
		safety = minf(safety, clampf(margin + 0.5, 0.0, 1.0))
	if length > 22.0:
		safety *= 0.7                                       # long stretch passes are risky
	return safety

## Where to send the puck so it meets a moving receiver.
static func lead_point(from: Vector3, receiver: Vector3, receiver_velocity: Vector3, speed := PASS_SPEED) -> Vector3:
	var travel := flat(receiver - from).length() / speed
	return flat(receiver + receiver_velocity * clampf(travel, 0.0, 1.2) * 0.85)

static func nearest_distance(p: Vector3, others: Array) -> float:
	var best := INF
	for o in others:
		best = minf(best, flat(p - o).length())
	return best

## Space ahead: distance from the nearest opponent to the spot `ahead`
## metres in front of the carrier (toward the net he attacks).
static func open_ice(pos: Vector3, attack: float, opponents: Array, ahead := 3.0) -> float:
	var forward := flat(net(attack) - pos).normalized() if absf(pos.z * attack) < Arena.GOAL_LINE - 1.0 else Vector3(0, 0, attack)
	return nearest_distance(pos + forward * ahead, opponents)

## Decide what the carrier does. ctx keys:
##   pos, vel, attack, is_d, goalie (Vector3), opponents (Array[Vector3]),
##   teammates (Array of {pos, vel, index}), skill (Dictionary), roll (0..1 random)
## Returns {kind: "shoot"|"pass"|"carry"|"dump"|"protect", target: Vector3,
##   receiver: int (teammate index or -1), value: float}.
static func carrier_decision(ctx: Dictionary) -> Dictionary:
	var pos: Vector3 = ctx.pos
	var attack: float = ctx.attack
	var opponents: Array = ctx.opponents
	var sk: Dictionary = ctx.get("skill", skill(DEFAULT_DIFFICULTY))
	var read: float = sk.read
	var pressure := nearest_distance(pos, opponents)
	var depth := pos.z * attack                              # + toward the net he attacks
	# Shoot
	var shoot_q := shot_quality(pos, attack, ctx.goalie, opponents)
	if ctx.get("is_d", false) and depth > Arena.BLUE_LINE:
		shoot_q = maxf(shoot_q, 0.30 if absf(pos.x) < 8.0 else 0.0)   # point shot for a tip/rebound
	var best := {"kind": "carry", "target": carry_target(pos, attack, opponents), "receiver": -1, "value": 0.0}
	var shoot_value := shoot_q
	if shoot_q < sk.shot_bar and pressure > 1.6:
		shoot_value *= 0.6                                   # no rush: look for better
	best = _better(best, {"kind": "shoot", "target": net(attack), "receiver": -1, "value": shoot_value})
	# Pass
	for mate in ctx.get("teammates", []):
		var mate_pos: Vector3 = mate.pos
		var lead := lead_point(pos, mate_pos, mate.get("vel", Vector3.ZERO))
		var safety := pass_safety(pos, lead, opponents, read)
		if safety < 0.45:
			continue
		var their_q := shot_quality(lead, attack, ctx.goalie, opponents)
		var advance := clampf((lead.z - pos.z) * attack / 25.0, -0.4, 0.5)
		var open := clampf(nearest_distance(lead, opponents) / 5.0, 0.0, 1.0)
		var value := (their_q * 0.85 + advance * 0.35 + open * 0.2) * safety
		# Under pressure, moving it to an open man is the play.
		value += clampf((2.6 - pressure) / 2.6, 0.0, 1.0) * 0.22 * safety
		# A pass across the slot to a shooter beats a contested shot.
		if their_q > shoot_q + 0.12:
			value += 0.08
		best = _better(best, {"kind": "pass", "target": lead, "receiver": int(mate.index), "value": value})
	# Carry: worth more with space ahead and outside shooting range.
	var space := open_ice(pos, attack, opponents)
	var carry_value := clampf(space / 7.0, 0.0, 1.0) * (0.42 if shoot_q < 0.35 else 0.22)
	carry_value *= clampf(pressure / 2.0, 0.35, 1.0)        # hard to carry with a man on you
	if best.kind == "carry":
		best.value = carry_value
	else:
		best = _better(best, {"kind": "carry", "target": carry_target(pos, attack, opponents), "receiver": -1, "value": carry_value})
	# Dump it in: stuck at the red line / blue line with nothing on.
	if depth > -Arena.BLUE_LINE and depth < Arena.BLUE_LINE + 1.0 and pressure < 2.2 and space < 3.0:
		var corner := Vector3(-signf(pos.x if absf(pos.x) > 0.5 else 1.0) * (Arena.HALF_WIDTH - 2.5), 0.0, attack * (Arena.GOAL_LINE + 1.5))
		best = _better(best, {"kind": "dump", "target": corner, "receiver": -1, "value": 0.26})
	# Protect: a checker on top of him and nothing better than a weak option.
	if pressure < 1.0 and best.value < 0.2:
		var away := flat(pos - _nearest(pos, opponents)).normalized()
		var back := Vector3(0.0, 0.0, -attack)
		var shield := pos + (away + back * 0.4).normalized() * 3.0
		shield.x = clampf(shield.x, -(Arena.HALF_WIDTH - 2.0), Arena.HALF_WIDTH - 2.0)
		shield.z = clampf(shield.z, -(Arena.GOAL_LINE + 1.0), Arena.GOAL_LINE + 1.0)
		best = {"kind": "protect", "target": shield, "receiver": -1, "value": 0.2}
	# Hard minimums: a great look is always shot, a breakaway is always carried in.
	if shoot_q >= 0.62:
		best = {"kind": "shoot", "target": net(attack), "receiver": -1, "value": shoot_q}
	return best

static func _better(a: Dictionary, b: Dictionary) -> Dictionary:
	return b if float(b.value) > float(a.value) else a

static func _nearest(p: Vector3, others: Array) -> Vector3:
	var best := p + Vector3(0, 0, 1)
	var best_d := INF
	for o in others:
		var d := flat(p - o).length()
		if d < best_d:
			best_d = d
			best = o
	return best

## Where the carrier skates: toward the slot, bent away from the nearest
## checker; along the wall before the zone so he isn't stripped in the middle.
static func carry_target(pos: Vector3, attack: float, opponents: Array) -> Vector3:
	var depth := pos.z * attack
	var goal := Vector3(clampf(pos.x * 0.5, -3.0, 3.0), 0.0, attack * (Arena.GOAL_LINE - 4.5))
	if depth < Arena.BLUE_LINE - 2.0:
		goal = Vector3(clampf(pos.x, -7.0, 7.0), 0.0, pos.z + attack * 8.0)
	var drive := flat(goal - pos).normalized()
	var threat := _nearest(pos, opponents)
	var threat_d := flat(threat - pos).length()
	if threat_d < 5.0:
		var away := flat(pos - threat).normalized()
		var side := Vector3(-drive.z, 0.0, drive.x)
		if side.dot(away) < 0.0:
			side = -side
		drive = (drive + side * (5.0 - threat_d) / 5.0 * 0.9).normalized()
	var target := pos + drive * 4.0
	# Stay off the wall unless he's protecting it there (boards kill the play).
	target.x = clampf(target.x, -(Arena.HALF_WIDTH - 3.0), Arena.HALF_WIDTH - 3.0)
	target.z = clampf(target.z, -(Arena.GOAL_LINE + 1.0), Arena.GOAL_LINE + 1.0)
	return target

## Chase the carrier on an inside-out angle: aim between him and the net,
## a little ahead of where he's going, so he's pushed to the outside.
static func pursue_target(carrier: Vector3, carrier_velocity: Vector3, own_attack: float, chaser: Vector3) -> Vector3:
	var own_net := net(-own_attack)
	var ahead := flat(carrier + carrier_velocity * clampf(flat(chaser - carrier).length() / 9.0, 0.1, 0.6))
	var inside := flat(own_net - ahead).normalized()
	return ahead + inside * 0.9

## Defenceman gap control against a rush: stay goal-side of the carrier at
## a gap that closes as he gets nearer the blue line.
static func gap_target(carrier: Vector3, own_attack: float, side: float) -> Vector3:
	var own_net := net(-own_attack)
	var toward := flat(own_net - carrier)
	var gap := clampf(toward.length() * 0.22, 2.5, 6.0)
	var spot := carrier + toward.normalized() * gap
	spot.x += side * 1.4
	return spot

## Goal-side coverage of a man in the defensive zone.
static func mark_target(attacker: Vector3, own_attack: float) -> Vector3:
	var own_net := net(-own_attack)
	return flat(attacker + flat(own_net - attacker).normalized() * 1.2)

## Get open on offence: shift the support spot sideways until the lane from
## the carrier is clear (or give up and keep the spot).
static func open_spot(spot: Vector3, carrier: Vector3, opponents: Array) -> Vector3:
	if carrier == Vector3.INF or pass_safety(carrier, spot, opponents) >= 0.6:
		return spot
	var best := spot
	var best_safety := pass_safety(carrier, spot, opponents)
	for shift in [-2.5, 2.5, -4.5, 4.5]:
		var candidate := spot + Vector3(shift, 0.0, 0.0)
		candidate.x = clampf(candidate.x, -(Arena.HALF_WIDTH - 1.5), Arena.HALF_WIDTH - 1.5)
		var s := pass_safety(carrier, candidate, opponents)
		if s > best_safety + 0.1:
			best_safety = s
			best = candidate
	return best

## Where a skater at `skater` (top speed `speed`) can first reach a moving
## puck, or Vector3.INF if he can't within `horizon` seconds.
static func intercept_point(puck: Vector3, puck_velocity: Vector3, skater: Vector3, speed := 8.5, horizon := 1.5) -> Vector3:
	var v := flat(puck_velocity)
	var t := 0.0
	while t <= horizon:
		var p := flat(puck) + v * t * (1.0 - t * 0.08)   # friction slows it a little
		if flat(p - skater).length() - STICK_REACH <= speed * t:
			return p
		t += 0.1
	return Vector3.INF

## Greedy man-to-man assignment in the defensive zone: each defender takes
## the most dangerous (closest to his net) attacker nobody has yet. Returns
## a dictionary defender index -> attacker index.
static func assign_coverage(defenders: Array, attackers: Array, own_attack: float) -> Dictionary:
	var own_net := net(-own_attack)
	var order := range(attackers.size())
	order.sort_custom(func(i, j): return flat(attackers[i] - own_net).length() < flat(attackers[j] - own_net).length())
	var taken := {}
	var result := {}
	for ai in order:
		var best := -1
		var best_d := INF
		for di in range(defenders.size()):
			if taken.has(di):
				continue
			var d := flat(defenders[di] - attackers[ai]).length()
			if d < best_d:
				best_d = d
				best = di
		if best >= 0:
			taken[best] = true
			result[best] = ai
	return result

## Shot aim: the corner away from the goalie, missed by up to `noise`
## metres (difficulty); low or high by distance.
static func shot_aim(shooter: Vector3, attack: float, goalie: Vector3, noise: float, roll_x: float, roll_y: float) -> Vector3:
	var side := -1.0 if goalie.x >= 0.0 else 1.0
	var x := side * 0.62 + (roll_x * 2.0 - 1.0) * noise
	var height := 0.12 if flat(net(attack) - shooter).length() > 12.0 else 0.55
	height += (roll_y * 2.0 - 1.0) * noise * 0.5
	return Vector3(x, clampf(height, 0.05, 1.0), attack * Arena.GOAL_LINE)

## One-timer: a pass received where the shot is clearly on (a bit better than
## the player's usual shooting bar) is fired first time, before the goalie
## can get across.
static func one_timer(quality: float, shot_bar: float) -> bool:
	return quality >= shot_bar + 0.08
