extends RefCounted
## Gameplay reads for the stick moves animated by stroke_anim.gd and the
## goalie's poke check / post seal (pure functions; match.gd applies them).
const Arena = preload("res://scripts/arena.gd")

## --- Deflections ------------------------------------------------------------
## A shot or pass in flight that passes within DEFLECT_REACH of a skater's
## blade (3D: a raised blade tips a high puck) is redirected. An attacker
## near the net steers it at the goal (a tip); anyone else knocks it off line.
const DEFLECT_REACH := 0.19
const DEFLECT_MIN_SPEED := 12.0
const TIP_ZONE := 7.5          # m from the goal line out, attackers' tips
const TIP_CHANCE := 0.7
const BLOCK_CHANCE := 0.5

## Closest distance from p to the segment a-b.
static func segment_distance(a: Vector3, b: Vector3, p: Vector3) -> float:
	var ab := b-a
	var l2 := ab.length_squared()
	if l2 < 1e-8: return p.distance_to(a)
	var t := clampf((p-a).dot(ab)/l2,0.0,1.0)
	return p.distance_to(a+ab*t)

## New puck velocity after a blade touches it. Attacker tip: turned most of
## the way at a spot in the net (roll_a/roll_b spread it over the mouth and up
## to the crossbar), keeping 85 % of the speed. Defender's stick: knocked
## 0.35-0.95 rad off line either way and slowed to 60 %, popping up a little.
static func deflect(vel: Vector3, at: Vector3, net_center: Vector3, attacker_tip: bool, roll_a: float, roll_b: float) -> Vector3:
	var speed := vel.length()
	if attacker_tip:
		var aim := net_center+Vector3((roll_a*2.0-1.0)*0.85,0.05+roll_b*0.9,0)
		var to_net := (aim-at).normalized()
		var dir := vel.normalized().slerp(to_net,0.75).normalized()
		return dir*speed*0.85
	var turn := lerpf(0.35,0.95,roll_a)*(1.0 if roll_b > 0.5 else -1.0)
	var flat := Vector3(vel.x,0,vel.z).rotated(Vector3.UP,turn)*0.6
	return Vector3(flat.x,maxf(vel.y*0.6,0.0)+roll_b*2.5,flat.z)

## Whether a skater standing at `pos` tips toward the net: in front of the
## net he attacks, within TIP_ZONE of the goal line.
static func in_tip_zone(pos: Vector3, attack: float) -> bool:
	var depth := Arena.GOAL_LINE-pos.z*attack
	return depth > -0.3 and depth < TIP_ZONE and absf(pos.x) < 4.0

## --- Dekes ------------------------------------------------------------------
## A CPU carrier with speed puts a deke on a defender closing from in front:
## the nearest opponent is DEKE_NEAR..DEKE_FAR ahead within DEKE_CONE of his
## line of travel. Skill decides how often (roll < chance).
const DEKE_NEAR := 1.3
const DEKE_FAR := 3.2
const DEKE_CONE := 0.75        # rad
const DEKE_MIN_SPEED := 2.5
static func wants_deke(pos: Vector3, vel: Vector3, opponents: Array, roll: float, chance: float) -> bool:
	var flat_v := Vector3(vel.x,0,vel.z)
	if flat_v.length() < DEKE_MIN_SPEED or roll >= chance: return false
	for o in opponents:
		var d: Vector3 = o-pos
		d.y = 0
		var dist := d.length()
		if dist < DEKE_NEAR or dist > DEKE_FAR: continue
		if flat_v.angle_to(d) < DEKE_CONE: return true
	return false

## Which way the deke carries him (world, sideways to travel): away from the
## defender's side, toward open ice.
static func deke_side(pos: Vector3, vel: Vector3, opponent: Vector3) -> Vector3:
	var fwd := Vector3(vel.x,0,vel.z).normalized()
	var across := Vector3(-fwd.z,0,fwd.x)
	var s := -signf(across.dot(opponent-pos))
	if s == 0.0: s = 1.0
	return across*s

## --- Goalie poke check --------------------------------------------------------
## A goalie pokes at a carrier coming in on him alone: within POKE_REACH, in
## front of the goal line and skating at the net.
const POKE_REACH := 2.1
const POKE_CHANCE := 0.4
static func goalie_pokes(goalie_pos: Vector3, end_sign: float, carrier_pos: Vector3, carrier_vel: Vector3) -> bool:
	var d := Vector3(carrier_pos.x-goalie_pos.x,0,carrier_pos.z-goalie_pos.z)
	if d.length() > POKE_REACH or d.length() < 0.5: return false
	if carrier_pos.z*end_sign > Arena.GOAL_LINE-0.3: return false
	return carrier_vel.dot(-d) > 0.5

## --- Goalie post seal (reverse VH) --------------------------------------------
## A puck below the goalie near the goal line (behind the net, or a sharp
## angle from the corner) and within POST_RANGE: he seals the near post with
## the reverse VH - post-side pad flat on the ice along the goal line, the
## other skate planted to push across. Returns "rvh_left" (glove side),
## "rvh_right" or "". local_x is the puck across the goalie (+ glove side),
## depth its distance out from the goal line (negative behind it).
const POST_RANGE := 4.2
const POST_DEPTH := 1.4
static func choose_post(local_x: float, depth: float, distance: float) -> String:
	if distance > POST_RANGE or depth > POST_DEPTH or absf(local_x) < 0.5: return ""
	return "rvh_left" if local_x > 0.0 else "rvh_right"
