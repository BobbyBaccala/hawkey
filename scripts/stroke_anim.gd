extends RefCounted
## Stick strokes for skaters: shots, passes, dekes, tips and poke checks.
## Each stroke is a short list of key poses (reference: EA NHL gameplay and
## broadcast footage of each move) played back on a smooth spline:
##   t     seconds from the start of the stroke
##   grip  offset of the top hand from its skating grip (rig space, m)
##   dir   direction from the top hand to the blade heel (rig space). The
##         stick keeps its length (STICK_L): a direction that points below
##         the ice puts the blade flat on the ice at the stick's full reach,
##         so only its heading matters (see ice()). Vector3.ZERO = the
##         skater's own blade (stickhandling) at that moment.
##   turn  shoulder turn (+ toward the backhand side, rad)
##   lean  sideways lean of the upper body (+ toward the backhand side, rad)
##   bend  extra forward bend of the upper body (rad)
##   hip   hip shift (weight transfer and knee drop, rig space, m)
##   stop  true where the motion comes to rest (top of the backswing, the
##         end of a drag): the spline arrives there with zero speed.
## Rig space: +z forward, -x the forehand (blade) side, +x the backhand side.
## The first and last keys are the skating pose, so a stroke starts and ends
## exactly on it; the spline (cubic Hermite with Catmull-Rom tangents over the
## real key times) is C1 continuous - no velocity jumps anywhere.

## Top hand to blade heel, as on the skater's stick in the skating stance.
const STICK_L := 1.12
## Mid-blade height above the ice (as SkaterVisual's blade_position).
const BLADE_Y := 0.029
const STICK_BLADE := 0.28

static func ice(x: float, z: float) -> Vector3:
	return Vector3(x,-4.0,z)

static func air(x: float, y: float, z: float) -> Vector3:
	return Vector3(x,y,z).normalized()

static func key(t: float, grip: Vector3, dir: Vector3, turn := 0.0, lean := 0.0, bend := 0.0, hip := Vector3.ZERO, stop := false) -> Dictionary:
	return {"t":t,"grip":grip,"dir":dir,"turn":turn,"lean":lean,"bend":bend,"hip":hip,"stop":stop}

static func rest_key(t: float) -> Dictionary:
	return key(t,Vector3.ZERO,Vector3.ZERO,0.0,0.0,0.0,Vector3.ZERO,true)

## Stroke library. release: when the puck leaves the blade (s, -1 = never);
## hold_puck: the puck stays on the ice where it was (it does not ride a
## raised blade) until the release.
static var _lib: Dictionary = {}
static func library() -> Dictionary:
	if not _lib.is_empty(): return _lib
	_lib = {
		# Wrist shot: the puck is drawn back beside the back skate, weight on the
		# back leg and shoulders coiled; it is swept forward and released off the
		# front foot, the blade following through toward the target.
		"wrist": {"release":0.26,"hold_puck":false,"keys":[
			rest_key(0.0),
			key(0.14,Vector3(-0.02,0.02,-0.07),ice(-0.86,0.34),-0.36,-0.05,0.04,Vector3(-0.06,-0.04,0),true),
			key(0.26,Vector3(0.02,0.0,0.09),ice(-0.40,0.92),0.06,0.03,0.07,Vector3(0.05,-0.06,0.03)),
			key(0.40,Vector3(0.06,0.08,0.17),air(-0.24,-0.36,0.93),0.28,0.06,0.03,Vector3(0.06,-0.03,0.04)),
			rest_key(0.66)]},
		# Snap shot: a short pull back, a quick slap down and through, a low
		# follow-through.
		"snap": {"release":0.16,"hold_puck":false,"keys":[
			rest_key(0.0),
			key(0.08,Vector3(0.0,0.05,-0.03),ice(-0.62,0.62),-0.18,-0.03,0.0,Vector3(-0.04,-0.02,0),true),
			key(0.16,Vector3(0.02,-0.02,0.08),ice(-0.38,0.96),0.06,0.02,0.08,Vector3(0.04,-0.06,0.02)),
			key(0.28,Vector3(0.04,0.04,0.14),air(-0.28,-0.55,0.85),0.22,0.04,0.05,Vector3(0.05,-0.04,0.03)),
			rest_key(0.50)]},
		# Slap shot: shoulders coil and the stick goes up and back high over the
		# forehand shoulder, weight on the back leg; it comes down hard behind
		# the puck, weight driving onto the front leg and the knees dropping,
		# and follows through up toward the target.
		"slap": {"release":0.52,"hold_puck":true,"keys":[
			rest_key(0.0),
			key(0.16,Vector3(-0.06,0.12,-0.04),air(-0.62,0.05,-0.40),-0.48,-0.06,-0.04,Vector3(-0.07,-0.02,-0.01)),
			key(0.36,Vector3(-0.10,0.22,-0.06),air(-0.55,0.55,-0.60),-0.70,-0.05,-0.08,Vector3(-0.10,-0.02,-0.02),true),
			key(0.47,Vector3(-0.04,0.06,0.02),air(-0.62,-0.20,0.35),-0.25,-0.02,0.06,Vector3(-0.01,-0.08,0.01)),
			key(0.52,Vector3(0.0,-0.06,0.08),ice(-0.50,0.86),0.02,0.04,0.13,Vector3(0.08,-0.11,0.03)),
			key(0.68,Vector3(0.04,0.10,0.14),air(-0.30,0.25,0.92),0.36,0.08,0.06,Vector3(0.10,-0.06,0.05)),
			rest_key(1.02)]},
		# One-timer: already loaded while the pass comes (load_one_timer()); a
		# short, fast swing through the puck.
		"one_timer": {"release":0.27,"hold_puck":true,"keys":[
			rest_key(0.0),
			key(0.16,Vector3(-0.08,0.16,-0.05),air(-0.64,0.22,-0.46),-0.56,-0.08,-0.05,Vector3(-0.08,-0.03,-0.01),true),
			key(0.23,Vector3(-0.03,0.04,0.02),air(-0.62,-0.25,0.35),-0.20,-0.02,0.06,Vector3(0.0,-0.08,0.01)),
			key(0.27,Vector3(0.0,-0.06,0.08),ice(-0.50,0.86),0.04,0.04,0.13,Vector3(0.08,-0.11,0.03)),
			key(0.43,Vector3(0.04,0.08,0.14),air(-0.30,0.10,0.94),0.34,0.08,0.06,Vector3(0.10,-0.06,0.05)),
			rest_key(0.76)]},
		# Backhand: top hand comes across and up, the puck is drawn back on the
		# backhand side, shoulders turned away; it is pulled across the body and
		# lifted, the blade finishing high.
		"backhand": {"release":0.28,"hold_puck":false,"keys":[
			rest_key(0.0),
			key(0.15,Vector3(-0.16,0.06,0.02),ice(0.82,0.58),0.42,0.10,0.05,Vector3(0.07,-0.04,0),true),
			key(0.28,Vector3(-0.12,0.02,0.10),ice(0.18,1.0),0.08,0.04,0.08,Vector3(-0.02,-0.06,0.03)),
			key(0.42,Vector3(-0.08,0.10,0.14),air(0.24,-0.28,0.93),-0.18,-0.04,0.03,Vector3(-0.05,-0.03,0.03)),
			rest_key(0.70)]},
		# Pass: a short sweep along the ice, the blade finishing low at the target.
		"pass": {"release":0.13,"hold_puck":false,"keys":[
			rest_key(0.0),
			key(0.07,Vector3(-0.01,0.0,-0.04),ice(-0.74,0.58),-0.16,-0.02,0.0,Vector3(-0.03,-0.01,0),true),
			key(0.13,Vector3(0.02,0.0,0.07),ice(-0.38,0.95),0.06,0.01,0.04,Vector3(0.03,-0.03,0.02)),
			key(0.24,Vector3(0.03,0.02,0.10),air(-0.22,-0.62,0.80),0.14,0.02,0.03,Vector3(0.03,-0.02,0.02)),
			rest_key(0.44)]},
		# Saucer pass: the same sweep with the blade opening and lifting through.
		"saucer": {"release":0.13,"hold_puck":false,"keys":[
			rest_key(0.0),
			key(0.07,Vector3(-0.01,0.0,-0.04),ice(-0.74,0.58),-0.16,-0.02,0.0,Vector3(-0.03,-0.01,0),true),
			key(0.13,Vector3(0.02,0.0,0.07),ice(-0.38,0.95),0.06,0.01,0.04,Vector3(0.03,-0.03,0.02)),
			key(0.26,Vector3(0.04,0.06,0.12),air(-0.22,-0.42,0.88),0.18,0.03,0.02,Vector3(0.03,-0.02,0.02)),
			rest_key(0.48)]},
		# Tip / deflection: the blade comes up to the puck's line and redirects it
		# with a short jab, then drops back to the ice.
		"tip": {"release":0.10,"hold_puck":false,"keys":[
			rest_key(0.0),
			key(0.10,Vector3(0.0,0.04,0.08),air(-0.32,-0.50,0.80),0.10,0.0,0.04,Vector3(0,-0.03,0.02)),
			key(0.20,Vector3(0.0,0.0,0.03),ice(-0.36,0.96),0.02,0.0,0.06,Vector3(0,-0.04,0.01)),
			rest_key(0.42)]},
		# Poke check: the top hand thrusts the stick out along the ice, the
		# chest dropping over it.
		"poke": {"release":0.16,"hold_puck":false,"keys":[
			rest_key(0.0),
			key(0.16,Vector3(0.0,-0.12,0.30),ice(-0.22,1.0),0.04,0.0,0.20,Vector3(0,-0.05,0.06)),
			key(0.26,Vector3(0.0,-0.10,0.26),ice(-0.24,1.0),0.04,0.0,0.18,Vector3(0,-0.05,0.05),true),
			rest_key(0.50)]},
		# Shot block: he drops low into the lane - hips down over bent knees,
		# chest up and square, stick laid flat across the ice in front - holds
		# it through the shot and gets back up.
		"block": {"release":-1.0,"hold_puck":false,"keys":[
			rest_key(0.0),
			key(0.20,Vector3(0.02,-0.22,0.02),ice(-0.95,0.30),0.0,0.0,-0.22,Vector3(0,-0.30,-0.06),true),
			key(0.70,Vector3(0.02,-0.22,0.02),ice(-0.95,0.30),0.0,0.0,-0.22,Vector3(0,-0.30,-0.06),true),
			rest_key(1.05)]},
		# Forehand-backhand deke: the puck goes wide on the forehand, then is
		# pulled across in front of the skates to the backhand, the body
		# leaning with it.
		"deke_fhbh": {"release":-1.0,"hold_puck":false,"keys":[
			rest_key(0.0),
			key(0.12,Vector3(-0.03,0.0,0.03),ice(-0.98,0.55),-0.34,-0.12,0.04,Vector3(-0.07,-0.03,0),true),
			key(0.32,Vector3(-0.13,0.04,0.05),ice(0.78,0.78),0.36,0.15,0.06,Vector3(0.09,-0.04,0.01),true),
			rest_key(0.56)]},
		# Toe drag: the stick reaches out to the forehand, the toe cups the puck
		# and drags it back in toward the skates past the defender's stick.
		"deke_toe_drag": {"release":-1.0,"hold_puck":false,"keys":[
			rest_key(0.0),
			key(0.15,Vector3(0.0,-0.05,0.13),ice(-0.62,1.0),-0.20,-0.06,0.12,Vector3(-0.03,-0.04,0.04),true),
			key(0.38,Vector3(0.02,0.04,-0.06),ice(-0.20,0.30),0.10,0.05,0.06,Vector3(0.03,-0.03,-0.01),true),
			rest_key(0.60)]},
		# Fake shot: a wrist-shot windup and a stab forward with no release, then
		# the puck is pulled across to the backhand.
		"deke_fake": {"release":-1.0,"hold_puck":false,"keys":[
			rest_key(0.0),
			key(0.12,Vector3(-0.02,0.02,-0.06),ice(-0.84,0.42),-0.30,-0.05,0.04,Vector3(-0.05,-0.03,0),true),
			key(0.24,Vector3(0.0,0.0,0.06),ice(-0.40,0.92),0.02,0.02,0.07,Vector3(0.03,-0.05,0.02),true),
			key(0.42,Vector3(-0.12,0.04,0.05),ice(0.72,0.82),0.32,0.13,0.05,Vector3(0.08,-0.04,0.01),true),
			rest_key(0.64)]},
	}
	return _lib

static func has(kind: String) -> bool:
	return library().has(kind)

static func duration(kind: String) -> float:
	var keys: Array = library()[kind].keys
	return float(keys[keys.size()-1].t)

static func release_at(kind: String) -> float:
	return float(library()[kind].release)

static func holds_puck(kind: String) -> bool:
	return bool(library()[kind].hold_puck)

## Time of the windup's peak (the last resting key before the release): where
## a held shot (the user's charge) waits.
static func windup_at(kind: String) -> float:
	var r := release_at(kind)
	var best := 0.0
	for k in library()[kind].keys:
		if bool(k.stop) and float(k.t) > 0.0 and (r < 0.0 or float(k.t) < r): best = float(k.t)
	return best

static func is_shot(kind: String) -> bool:
	return kind in ["wrist","snap","slap","one_timer","backhand"]

static func is_deke(kind: String) -> bool:
	return kind.begins_with("deke_")

## Cubic Hermite through the keys of one channel. vals[i] at times ts[i];
## Catmull-Rom tangents (zero at the ends and at resting keys).
static func _tangent(ts: Array, vals: Array, stops: Array, i: int):
	if i == 0 or i == ts.size()-1 or stops[i]: return vals[i]*0.0
	return (vals[i+1]-vals[i-1])/(float(ts[i+1])-float(ts[i-1]))

static func _hermite(ts: Array, vals: Array, stops: Array, t: float):
	var n := ts.size()
	if t <= float(ts[0]): return vals[0]
	if t >= float(ts[n-1]): return vals[n-1]
	var i := 0
	while i < n-2 and t > float(ts[i+1]): i += 1
	var h := float(ts[i+1])-float(ts[i])
	var s := (t-float(ts[i]))/h
	var s2 := s*s
	var s3 := s2*s
	var m0 = _tangent(ts,vals,stops,i)*h
	var m1 = _tangent(ts,vals,stops,i+1)*h
	return vals[i]*(2*s3-3*s2+1)+m0*(s3-2*s2+s)+vals[i+1]*(-2*s3+3*s2)+m1*(s3-s2)

## Body channels of a stroke at time t (no stick: see blade()).
static func body(kind: String, t: float) -> Dictionary:
	var keys: Array = library()[kind].keys
	var ts := []
	var stops := []
	var grip := []
	var turn := []
	var lean := []
	var bend := []
	var hip := []
	for k in keys:
		ts.append(k.t); stops.append(k.stop); grip.append(k.grip)
		turn.append(k.turn); lean.append(k.lean); bend.append(k.bend); hip.append(k.hip)
	return {"grip":_hermite(ts,grip,stops,t),"turn":_hermite(ts,turn,stops,t),"lean":_hermite(ts,lean,stops,t),
		"bend":_hermite(ts,bend,stops,t),"hip":_hermite(ts,hip,stops,t)}

## Blade heel for a top hand at `top` pointing along `dir`, stick length kept:
## a heel that would go below the ice lies on it at the full reach instead.
static func heel_for(top: Vector3, dir: Vector3) -> Vector3:
	var d := dir.normalized()
	var heel := top+d*STICK_L
	if heel.y < BLADE_Y:
		var drop := top.y-BLADE_Y
		var flat := Vector3(d.x,0,d.z)
		if flat.length() < 0.01: flat = Vector3(-0.3,0,1)
		var h := sqrt(maxf(STICK_L*STICK_L-drop*drop,0.0))
		heel = Vector3(top.x,BLADE_Y,top.z)+flat.normalized()*h
	return heel

## Mid-blade (the puck pocket) for a heel: the blade runs on from the heel in
## the direction the shaft leans, as SkaterVisual.stick_heel_at() assumes.
static func mid_blade(top: Vector3, heel: Vector3) -> Vector3:
	var flat := Vector3(heel.x-top.x,0,heel.z-top.z)
	if flat.length() < 0.05: flat = Vector3(-1,0,0.4)
	return heel+flat.normalized()*STICK_BLADE*0.48

## Mid-blade target at time t for a top hand at `top` (already including the
## stroke's grip offset). base_dir replaces the Vector3.ZERO (skating) keys.
static func blade(kind: String, t: float, top: Vector3, base_dir: Vector3) -> Vector3:
	var keys: Array = library()[kind].keys
	var ts := []
	var stops := []
	var dirs := []
	for k in keys:
		ts.append(k.t); stops.append(k.stop)
		var d: Vector3 = k.dir
		# Ice keys are steered by heading only: put them on the unit sphere at
		# the heading they give and the drop the stick needs to reach the ice,
		# so the spline between an ice key and an air key passes through real
		# stick angles.
		if d == Vector3.ZERO: d = base_dir
		elif d.y < -1.5:
			var drop := clampf((top.y-BLADE_Y)/STICK_L,0.0,0.999)
			var flat := Vector3(d.x,0,d.z).normalized()*sqrt(1.0-drop*drop)
			d = Vector3(flat.x,-drop,flat.z)
		dirs.append(d.normalized())
	var dir: Vector3 = _hermite(ts,dirs,stops,t)
	return mid_blade(top,heel_for(top,dir))

## CPU shot selection (and the user's, from the same reads): a defenceman far
## out with time winds up a slap shot; a puck taken on the backhand side
## (net to the skater's backhand, rig +x) goes off the backhand; a shooter
## with a checker on him (< 1.5 m) or in tight (< 7 m) snaps it; otherwise a
## wrister.
## A one-timer is always a one-timer.
static func shot_kind(is_d: bool, distance: float, pressure: float, net_side: float, one_timer: bool) -> String:
	if one_timer: return "one_timer"
	if is_d and distance > 14.0 and pressure > 3.0: return "slap"
	if net_side > 0.3 and distance < 9.0: return "backhand"
	# Snap shot: a checker on him or in tight, where the quick release counts.
	if pressure < 1.5 or distance < 7.0: return "snap"
	return "wrist"

## Puck speed (m/s) for each shot type: slap and one-timer hardest, the
## backhand much softer. Kept on the game's existing balance (forwards
## 27-30, a point slapper 33-36): faster one-timers beat the goalie's
## reaction from the slot far more often than real ones do.
static func shot_speed(kind: String, roll: float) -> float:
	match kind:
		"slap": return 33.0+roll*3.0
		"one_timer": return 28.0+roll*3.0
		"snap": return 27.0+roll*3.0
		"backhand": return 21.0+roll*3.0
	return 26.0+roll*3.0

## CPU deke choice: which move to put on a defender closing from in front.
static func deke_kind(roll: float) -> String:
	if roll < 0.40: return "deke_fhbh"
	if roll < 0.72: return "deke_toe_drag"
	return "deke_fake"
