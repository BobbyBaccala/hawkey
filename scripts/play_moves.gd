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

## --- Goalie rebound control ---------------------------------------------------
## A shot the goalie gets a piece of is absorbed and steered, not left to a
## rigid-box bounce: a puck that met a pad edge used to carry on into the
## net. Like a good goalie, he kills it or sends it to the corner, away from
## the slot: off the chest or the catcher it drops dead at his feet (he then
## covers it for a whistle, match.gd), off a pad it goes wide toward the
## corner, off the blocker or stick it is kicked harder and wider. Rebounds
## into the slot kept the attackers in the zone for minutes on end (flow
## recorder, seeds 2 and 3). Only shots heading at the net (end_sign: the
## goal he defends, +1 at +z).
const REBOUND_KEEP := {"arm":0.10,"body":0.05,"catcher":0.05,"pad":0.20,"mask":0.15,"blocker":0.30,"stick":0.26}
const REBOUND_WIDE := {"arm":0.7,"body":0.15,"catcher":0.15,"pad":1.1,"mask":0.8,"blocker":1.4,"stick":1.3}
static func rebound(in_v: Vector3, zone: String, end_sign: float, roll_a: float, roll_b: float) -> Vector3:
	var speed := in_v.length()
	if speed < 2.5 or in_v.z*end_sign <= 0.0: return in_v
	var keep: float = REBOUND_KEEP.get(zone,0.2)
	var wide: float = REBOUND_WIDE.get(zone,1.0)
	var side := signf(in_v.x) if absf(in_v.x) > 0.5 else (1.0 if roll_a > 0.5 else -1.0)
	var dir := Vector3(side*(wide+roll_a*0.3),0,-end_sign).normalized()
	var out := dir*speed*keep*lerpf(0.8,1.2,roll_b)
	out.y = clampf(in_v.y*0.15,0.0,1.5)*keep*4.0 + (0.8 if zone in ["mask","blocker"] else 0.0)*roll_b
	return out

## --- Skill-stick dekes (the user's right stick) -------------------------------
## Gestures read from the last SKILL_WINDOW seconds of right-stick samples
## ([time, Vector2], newest last; x + = backhand side as the stick shows it,
## y + = pulled toward the player):
##   side to side across the stick (one side hard, then the other)  -> deke_fhbh
##   pushed forward, then pulled straight back                        -> deke_toe_drag
##   pulled back (shot windup), then flicked to the side              -> deke_fake
## Returns "" when no gesture completed in the window.
const SKILL_WINDOW := 0.35
const SKILL_HARD := 0.75
static func skill_stick_deke(history: Array) -> String:
	if history.size() < 2: return ""
	var now: float = history[history.size()-1][0]
	var last: Vector2 = history[history.size()-1][1]
	for i in range(history.size()-2,-1,-1):
		var t: float = history[i][0]
		if now-t > SKILL_WINDOW: break
		var v: Vector2 = history[i][1]
		if absf(v.x) > SKILL_HARD and absf(last.x) > SKILL_HARD and signf(v.x) != signf(last.x) and absf(v.y) < 0.6 and absf(last.y) < 0.6:
			return "deke_fhbh"
		if v.y < -SKILL_HARD and last.y > SKILL_HARD and absf(last.x) < 0.5: return "deke_toe_drag"
		if v.y > SKILL_HARD and absf(last.x) > SKILL_HARD and last.y < 0.5: return "deke_fake"
	return ""

## --- Shot blocks ---------------------------------------------------------------
## A defender gets into a shot's lane and drops to block it when he is between
## the puck and the net he defends, BLOCK_NEAR..BLOCK_FAR from the puck along
## the lane, and within BLOCK_LANE of it sideways.
const BLOCK_NEAR := 1.2
const BLOCK_FAR := 4.5
const BLOCK_LANE := 0.9
static func in_shot_lane(puck: Vector3, net: Vector3, defender: Vector3) -> bool:
	var lane := Vector3(net.x-puck.x,0,net.z-puck.z)
	var length := lane.length()
	if length < 0.1: return false
	var dir := lane/length
	var d := Vector3(defender.x-puck.x,0,defender.z-puck.z)
	var along := d.dot(dir)
	if along < BLOCK_NEAR or along > minf(BLOCK_FAR,length-1.0): return false
	return (d-dir*along).length() < BLOCK_LANE

## Whether a shot the goalie stops is frozen for a whistle: most shots into
## the chest are trapped against it and most off the catcher held, as NHL
## goalies do; the rest drop for a rebound (rebound()) - tuned on full
## simulated games (tools/sim_game.gd) toward NHL scoring. Leaving them all
## loose at his feet gave attackers 13-23 point-blank jam shots a period.
const FREEZE_CHANCE := {"body":0.75,"catcher":0.70}
static func freezes(zone: String, in_v: Vector3, end_sign: float, roll: float) -> bool:
	if in_v.length() < 10.0 or in_v.z*end_sign <= 0.0: return false
	return roll < float(FREEZE_CHANCE.get(zone,0.0))

## Whether the goalie smothers a loose puck for a whistle: slow, on the ice,
## in front of his goal line, and within his reach - wider down in the
## butterfly, where the pads lie out to either side (COVER_REACH). Covering
## only a dead puck right at his skates left scrambles at the pads that
## attackers jammed in after 2-4 saves.
const COVER_SPEED := 3.0
const COVER_REACH := Vector2(0.70, 1.10)   # standing, butterfly (m)
static func goalie_covers(goalie: Vector3, end_sign: float, puck: Vector3, puck_speed: float, butterfly: float) -> bool:
	if puck.y > 0.13 or puck_speed > COVER_SPEED: return false
	if puck.z*end_sign > goalie.z*end_sign+0.35: return false   # behind him, at the line
	var d := Vector2(puck.x-goalie.x,puck.z-goalie.z).length()
	return d < lerpf(COVER_REACH.x,COVER_REACH.y,clampf(butterfly,0.0,1.0))

## A puck the goalie touches when it is already at his goal line, behind the
## front of his body (between him and the line): he squeezes it against the
## post or his pads for a whistle most of the time instead of it squirting
## in off the back of his gear (SQUEEZE_CHANCE). depth = how far the puck is
## out from the goal line (m).
const SQUEEZE_DEPTH := 0.45
const SQUEEZE_CHANCE := 0.8
static func squeezes(depth: float, roll: float) -> bool:
	return depth >= -0.05 and depth < SQUEEZE_DEPTH and roll < SQUEEZE_CHANCE
