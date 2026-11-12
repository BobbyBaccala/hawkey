extends RefCounted
## Offside and icing, as pure logic (no scene): match.gd feeds it one
## snapshot per physics tick and acts on the call it returns.
##
## Coordinates: the rink runs along z; a team attacks towards z = +1 or -1
## (attack[team]). "s" below is a position measured along a team's attack
## direction (s = z * attack), so s > blue_line is that team's attacking zone.
##
## Offside: when the attacking team sends or carries the puck over the blue
## line while a team-mate (not the carrier) is already fully across it.
##  - carried in: whistle at once;
##  - shot/passed in: DELAYED offside. It clears when every attacker has
##    tagged up (back to the line) or the puck leaves the zone, and becomes a
##    whistle when an attacker plays the puck.
##  Faceoff: the neutral-zone dot just outside that blue line, on the puck's side.
##
## Icing: puck released from the shooter's own side of the centre red line
## crosses the far goal line untouched and wide of the net. Not called on a
## shorthanded team. Hybrid race, judged once when the puck crosses the
## end-zone faceoff-dot line: waved off if an attacker (icing team) is nearer
## the puck than every defender, or a defender is close enough to have
## clearly played it. Faceoff: the icing team's own end dot, on the side the
## puck was shot from.

const NONE := ""
const OFFSIDE := "OFFSIDE"
const ICING := "ICING"

## Rink geometry (defaults mirror arena.gd; tests may override).
var blue_line := 7.62
var goal_line := 26.647
var end_dot_z := 20.551
var neutral_dot_z := 6.096
var dot_x := 6.706

## A skater is across the line when his centre is this far past it (both
## skates over), and has tagged up when his centre is back within TAG_MARGIN.
const SKATER_MARGIN := 0.30
const TAG_MARGIN := 0.10
## Puck must be fully over a line (radius 38 mm).
const PUCK_MARGIN := 0.04
## Icing is not called for pucks crossing the goal line this close to the
## net's centre (on net: a shot, a save or a goal).
const NET_HALF_WIDTH := 1.25
## A defender this close to the puck at the dot line could clearly have
## played it: no icing.
const PLAYABLE := 1.6

var enabled := true
## Per team: delayed offside flagged, and the x the puck entered at.
var delayed := [false, false]
var entry_x := [0.0, 0.0]
## Last team to play the puck (carrier or deflection) and where it left him.
var touch_team := -1
var touch_pos := Vector3.ZERO
## True from a release until someone else touches the puck.
var loose := false
var icing_live := false
var icing_judged := false
var icing_waved := false
var previous_puck := Vector3.ZERO
var has_previous := false
## Counters for the stats/tuning sims.
var calls := {OFFSIDE: 0, ICING: 0}
var waved_icings := 0
var delayed_cleared := 0

func reset() -> void:
	delayed = [false, false]
	touch_team = -1
	loose = false
	icing_live = false
	icing_judged = false
	icing_waved = false
	has_previous = false

## Any attacker of `team` (except `skip` index) fully inside his attacking zone.
func attackers_inside(team: int, attack: float, skaters: Array, margin: float, skip := -1) -> bool:
	for i in range(skaters.size()):
		if i == skip: continue
		var sk: Dictionary = skaters[i]
		if int(sk.team) != team: continue
		if float((sk.pos as Vector3).z) * attack > blue_line + margin: return true
	return false

## A goalkeeper or a skater's body/stick deflects the puck: no icing after that.
func note_touch(team: int, at: Vector3) -> void:
	# The shooter's own stick/team-mates don't change who played it last.
	if team == touch_team: return
	touch_team = team
	touch_pos = at
	loose = true
	icing_live = false

func goalie_touch() -> void:
	icing_live = false

func offside_spot(team: int, attack: float) -> Vector3:
	return Vector3(signf(entry_x[team]) * dot_x if entry_x[team] != 0.0 else dot_x, 0, attack * neutral_dot_z)

func icing_spot(attack: float) -> Vector3:
	return Vector3((-dot_x if touch_pos.x < 0 else dot_x), 0, -attack * end_dot_z)

## One tick. input:
##  puck: Vector3, carrier: index into skaters or -1,
##  skaters: [{team:int, pos:Vector3}], attack: [float, float],
##  shorthanded: [bool, bool] (optional).
## Returns {call: "", ...} or {call: OFFSIDE|ICING, team: offender, spot: Vector3}.
func step(input: Dictionary) -> Dictionary:
	var result := {"call": NONE}
	if not enabled: return result
	var puck: Vector3 = input.puck
	var skaters: Array = input.skaters
	var attack: Array = input.attack
	var carrier := int(input.get("carrier", -1))
	var carrier_team := int(skaters[carrier].team) if carrier >= 0 else -1
	if not has_previous:
		previous_puck = puck
		has_previous = true
	# --- who last played it -------------------------------------------------
	if carrier_team >= 0:
		touch_team = carrier_team
		touch_pos = puck
		loose = false
		icing_live = false
	elif not loose and touch_team >= 0:
		# Just released: an icing is possible if it left from behind centre.
		loose = true
		var a_release := float(attack[touch_team])
		var short: Array = input.get("shorthanded", [false, false])
		icing_live = touch_pos.z * a_release < 0.0 and not bool(short[touch_team])
		icing_judged = false
		icing_waved = false
	# --- offside ------------------------------------------------------------
	for team in range(2):
		var a := float(attack[team])
		var s := puck.z * a
		var s_prev := previous_puck.z * a
		var line := blue_line + PUCK_MARGIN
		if delayed[team]:
			if s <= line:
				delayed[team] = false
				delayed_cleared += 1
			elif carrier_team == team:
				result = _call(OFFSIDE, team, offside_spot(team, a))
			elif not attackers_inside(team, a, skaters, TAG_MARGIN):
				delayed[team] = false
				delayed_cleared += 1
		elif s > line and s_prev <= line and touch_team == team:
			# The attacking team just put the puck over the blue line.
			if attackers_inside(team, a, skaters, SKATER_MARGIN, carrier if carrier_team == team else -1):
				entry_x[team] = puck.x
				if carrier_team == team:
					result = _call(OFFSIDE, team, offside_spot(team, a))
				else:
					delayed[team] = true
		if result.call != NONE: break
	# --- icing --------------------------------------------------------------
	if result.call == NONE and icing_live and touch_team >= 0:
		var a_ice := float(attack[touch_team])
		var s_ice := puck.z * a_ice
		if not icing_judged and s_ice > end_dot_z:
			icing_judged = true
			var best_attacker := INF
			var best_defender := INF
			for sk in skaters:
				var d := Vector2(sk.pos.x - puck.x, sk.pos.z - puck.z).length()
				if int(sk.team) == touch_team: best_attacker = minf(best_attacker, d)
				else: best_defender = minf(best_defender, d)
			icing_waved = best_attacker < best_defender or best_defender < PLAYABLE
			if icing_waved:
				waved_icings += 1
				icing_live = false
		if icing_live and s_ice > goal_line + PUCK_MARGIN:
			if absf(puck.x) > NET_HALF_WIDTH:
				result = _call(ICING, touch_team, icing_spot(a_ice))
			icing_live = false
	previous_puck = puck
	return result

func delayed_offside(team: int) -> bool:
	return enabled and bool(delayed[team])

func _call(kind: String, team: int, spot: Vector3) -> Dictionary:
	calls[kind] = int(calls[kind]) + 1
	delayed = [false, false]
	icing_live = false
	return {"call": kind, "team": team, "spot": spot}
