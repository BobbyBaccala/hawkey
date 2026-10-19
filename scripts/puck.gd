extends RigidBody3D
## Free 3D rigid body: gravity, spin, grounded drag and CCD; no height lock.
var grounded := false
var ice_deceleration := 0.35
var air_drag := 0.0007
var last_velocity := Vector3.ZERO

static func launch(direction: Vector3, speed: float, elevation: float) -> Vector3:
	var horizontal:=Vector3(direction.x,0,direction.z).normalized()
	var angle:=clampf(elevation,0,0.65)
	return horizontal*cos(angle)*speed+Vector3.UP*sin(angle)*speed

static func ballistic_height(start_y: float, vertical_speed: float, time: float) -> float:
	return start_y+vertical_speed*time-0.5*9.8*time*time

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	grounded=false
	for i in range(state.get_contact_count()):
		var local_normal:=state.get_contact_local_normal(i)
		var normal:Vector3=state.transform.basis*local_normal
		if normal.y>0.65:
			grounded=true
			break
	var v:=state.linear_velocity
	if grounded:
		var horizontal:=Vector3(v.x,0,v.z).move_toward(Vector3.ZERO,ice_deceleration*state.step)
		v.x=horizontal.x
		v.z=horizontal.z
	else:
		v-=v*minf(0.05,air_drag*v.length()*state.step)
	state.linear_velocity=v
	last_velocity=v

static func solve_elevation(distance_: float, speed: float, target_y: float, start_y: float) -> float:
	if distance_<0.05: return 0
	var gravity:=9.8
	var square:=speed*speed
	var discriminant:=square*square-gravity*(gravity*distance_*distance_+2*(target_y-start_y)*square)
	if discriminant<0: return 0.35
	return clampf(atan((square-sqrt(discriminant))/(gravity*distance_)),0,0.60)
