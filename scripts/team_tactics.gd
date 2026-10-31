extends RefCounted
## Basic hockey positioning for AI skaters (no puck). Pure functions so the
## rules can be tested without a scene.
##
## Slots: 0 centre, 1 left wing, 2 right wing, 3 left D, 4 right D.
## Positions are worked out in "attack space": a = z * attack (positive toward
## the net the team attacks), x as on the rink. Rink landmarks come from
## arena.gd (goal line 11 ft from the boards, blue lines 25 ft from centre).
##
## Defencemen stay home: on offence they hold the opposing blue line and never
## go deeper than just inside it; when defending they keep between the puck and
## their net, never past centre, and in their own zone cover the net front and
## the strong side. Forwards don't go too deep defensively: in their own zone
## the wingers cover the points and the centre the slot, never below the top of
## the crease area; on offence they drive the net, the far circle and the high
## slot.
const Arena = preload("res://scripts/arena.gd")

const D_MAX_ATTACK := Arena.BLUE_LINE + 1.5        # D: just inside the offensive blue line
const D_MIN_CENTRE := 0.0                          # D defending: never past centre ice
const F_MIN_ATTACK := -(Arena.GOAL_LINE - 6.0)     # forwards: no deeper than the low slot
const D_PINCH_X := 7.0

static func is_defence(slot: int) -> bool:
	return slot >= 3

static func side(slot: int) -> float:
	# Slots 1 and 3 play the -x side, 2 and 4 the +x side (as at faceoffs).
	if slot == 1 or slot == 3: return -1.0
	if slot == 2 or slot == 4: return 1.0
	return 0.0

## Where a support skater (not the puck carrier, not the chaser) goes.
static func support_target(slot: int, attack: float, puck: Vector3, possession: bool) -> Vector3:
	var pa := puck.z * attack                      # puck depth in attack space
	var px := puck.x
	# Each player keeps his own side of the ice (same x as his faceoff spot).
	var s := side(slot)
	var a := 0.0
	var x := 0.0
	var goal := Arena.GOAL_LINE
	var blue := Arena.BLUE_LINE
	if possession:
		if is_defence(slot):
			if pa > blue:
				# Offensive zone: hold the point, inside the blue line.
				a = D_MAX_ATTACK - 0.5
				x = s * clampf(5.5 + absf(px) * 0.15, 4.5, D_PINCH_X)
			else:
				# Trail the play, ready to retreat.
				a = clampf(pa - 8.0, -(goal - 5.0), D_MAX_ATTACK - 0.5)
				x = s * 5.0
		else:
			if pa > blue:
				# Offensive zone: net front, far circle, high slot.
				match slot:
					0: a = goal - 10.5; x = clampf(px * 0.3, -3.0, 3.0)
					_:
						var strong := signf(px) == signf(s) or absf(px) < 1.0
						if strong:
							a = goal - 3.5; x = s * 1.6          # net front / near post
						else:
							a = goal - 8.5; x = s * 5.5          # weak-side circle for a one-timer
			else:
				# Transition: wingers wide in their lanes ahead of the puck, centre supports.
				if slot == 0:
					a = clampf(pa + 1.0, -(goal - 6.0), goal - 6.0); x = clampf(px * 0.4, -4.0, 4.0)
				else:
					a = clampf(pa + 5.0, -(goal - 6.0), goal - 4.0); x = s * 8.0
	else:
		if is_defence(slot):
			if pa < -blue:
				# Own zone: strong-side D takes the puck side low, weak-side D the net front.
				var strong := signf(px) == signf(s) or (absf(px) < 1.0 and slot == 3)
				if strong:
					a = clampf(pa, -(goal - 1.0), -(goal - 7.0)); x = clampf(px * 0.6, -7.0, 7.0)
				else:
					a = -(goal - 3.5); x = s * 1.8
			else:
				# Gap control: stay between the puck and the net, backing in.
				# With the puck loose or lost in the offensive zone the D hold
				# the blue line (keep it in) rather than chase deeper; anywhere
				# else they never push past centre ice while defending.
				var cap := D_MAX_ATTACK - 1.0 if pa > blue else D_MIN_CENTRE
				a = clampf(pa - 7.0, -(goal - 4.0), cap)
				x = s * 4.0 + clampf(px * 0.3, -2.0, 2.0)
		else:
			if pa < -blue:
				# Own zone: wingers cover the points, centre the slot (not below it).
				if slot == 0:
					a = maxf(F_MIN_ATTACK, -(goal - 7.0)); x = clampf(px * 0.3, -3.0, 3.0)
				else:
					a = -blue - 1.5; x = s * 7.5
			else:
				# Backcheck through the neutral zone in their lanes, not too deep.
				a = clampf(pa - 3.0, F_MIN_ATTACK, goal - 6.0)
				x = clampf(s * 6.5 + px * 0.25, -(Arena.HALF_WIDTH - 2.0), Arena.HALF_WIDTH - 2.0)
	x = clampf(x, -(Arena.HALF_WIDTH - 1.5), Arena.HALF_WIDTH - 1.5)
	return Vector3(x, 0, a * attack)

## May this skater chase a loose puck? Defencemen don't chase into the
## offensive zone (they hold the line); forwards don't chase behind their own
## goal line when a D is available.
static func may_chase(slot: int, attack: float, puck: Vector3) -> bool:
	var pa := puck.z * attack
	if is_defence(slot): return pa < Arena.BLUE_LINE + 1.0
	return pa > -(Arena.GOAL_LINE + 0.5)
