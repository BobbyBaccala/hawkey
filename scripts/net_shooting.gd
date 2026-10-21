extends RefCounted
## Original net-target assist. Aim selects a point inside the mouth, not facing.
const Arena = preload("res://scripts/arena.gd")
const Puck = preload("res://scripts/puck.gd")

static func target(end_: float, placement: Vector2) -> Vector3:
	var p := placement.clamp(Vector2(-1,-1),Vector2(1,1))
	return Vector3(-end_*p.x*0.78,0.59-p.y*0.47,end_*Arena.GOAL_LINE)

static func launch(origin: Vector3, end_: float, placement: Vector2, power: float = 75.0, slap: bool = false) -> Vector3:
	var destination := target(end_,placement)
	var flat := Vector3(destination.x-origin.x,0,destination.z-origin.z)
	var speed := lerpf(25.0,31.0,clampf(power/100.0,0,1)) if slap else lerpf(18.0,24.0,clampf(power/100.0,0,1))
	var elevation := Puck.solve_elevation(flat.length(),speed,destination.y,origin.y)
	return Puck.launch(flat,speed,elevation)
