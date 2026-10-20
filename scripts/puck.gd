extends RigidBody3D
## Free 3D rigid body: gravity, spin, grounded drag and CCD; no height lock.
var grounded := false
var ice_deceleration := 0.35
var air_drag := 0.0007
var last_velocity := Vector3.ZERO
const RADIUS := 0.0381
const HALF_HEIGHT := 0.0127
const ICE_BOUNCE := 0.12
## Inside the rink the ice is an exact plane at y = 0, handled here rather than
## by a collider (see arena.gd). Outside the boards there is no ice.
const RINK_HALF := Vector2(15.2, 30.2)

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
	var xf:=state.transform
	# Lowest point of the disk at its current tilt.
	var up:=xf.basis.y.normalized()
	var reach:=HALF_HEIGHT*absf(up.y)+RADIUS*sqrt(maxf(0.0,1.0-up.y*up.y))
	var on_rink:=absf(xf.origin.x)<RINK_HALF.x and absf(xf.origin.z)<RINK_HALF.y
	if on_rink and xf.origin.y-reach<=0.0005 and v.y<=0.05:
		grounded=true
		xf.origin.y=reach
		if v.y< -1.0:
			v.y=-v.y*ICE_BOUNCE
			if v.y<0.3: v.y=0.0
		else:
			v.y=0.0
		# Settle flat on the ice, keeping its spin about the vertical.
		var flat:=Basis(Quaternion(up,Vector3.UP))*xf.basis
		xf.basis=xf.basis.slerp(flat.orthonormalized(),minf(1.0,state.step*12.0))
		state.angular_velocity=Vector3(state.angular_velocity.x*0.9,state.angular_velocity.y,state.angular_velocity.z*0.9)
		state.transform=xf
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
