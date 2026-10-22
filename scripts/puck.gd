extends RigidBody3D
## Free 3D rigid body: gravity, spin, grounded drag and CCD; no height lock.
const BLADE_LAYER:=1<<6 # Layers 5/6 are ice support / goalie-only net guard.
var moving_contacts:=0
var sweep_contacts:=0
var blade_probe:=SphereShape3D.new()
var contact_shape:Shape3D
var grounded := false
var ice_deceleration := 0.35
var air_drag := 0.0007
var last_velocity := Vector3.ZERO
const RADIUS := 0.0381
const HALF_HEIGHT := 0.0127
const ICE_BOUNCE := 0.12
## Inside the rink the ice is an exact plane at y = 0, handled here rather than
## by a collider (see arena.gd). Outside the boards there is no ice.
const RINK_HALF := Vector2(preload("res://scripts/arena.gd").HALF_WIDTH + 0.2, 30.2)

static func launch(direction: Vector3, speed: float, elevation: float) -> Vector3:
	var horizontal:=Vector3(direction.x,0,direction.z).normalized()
	var angle:=clampf(elevation,0,0.65)
	return horizontal*cos(angle)*speed+Vector3.UP*sin(angle)*speed

static func ballistic_height(start_y: float, vertical_speed: float, time: float) -> float:
	return start_y+vertical_speed*time-0.5*9.8*time*time

func _init()->void:
	blade_probe.radius=0.25

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
	var integration_start:=state.transform
	# Sweep the posed blade as well as the disk. A blade that changes side
	# between ticks must push the disk ahead of its original face, not emerge
	# through it and let discrete collision select the opposite face.
	var nearby:=PhysicsShapeQueryParameters3D.new()
	nearby.shape=blade_probe;nearby.transform=Transform3D(Basis.IDENTITY,state.transform.origin)
	nearby.collision_mask=BLADE_LAYER
	for candidate in state.get_space_state().intersect_shape(nearby,16):
		var blade:StaticBody3D=candidate.collider
		if not blade.has_meta("previous_world") or Engine.get_physics_frames()-int(blade.get_meta("pose_tick",0))>1:continue
		var old:Transform3D=blade.get_meta("previous_world")
		var current:Transform3D=blade.global_transform
		if old.origin.distance_to(current.origin)>0.15:continue # Spawn/reset, not a physical stroke.
		var was:=old.affine_inverse()*state.transform.origin
		var now:=current.affine_inverse()*state.transform.origin
		if absf(now.x)>0.14 or absf(now.y)>0.038:continue
		var t:=clampf(was.x/0.28+0.5,0,1)
		var face:=signf(was.z+0.023*t*t)
		if face==0:continue
		t=clampf(now.x/0.28+0.5,0,1)
		var curve:float=-0.023*(t*t if face>0 else t)
		var distance_:float=(now.z-curve)*face
		var depth:=RADIUS+0.0045+0.012-distance_
		if depth>0 and depth<0.16:
			moving_contacts+=1
			var normal:=current.basis.z*face
			var contact:=state.transform;contact.origin+=normal*depth;state.transform=contact
			var surface:Vector3=(current*was-old*was)/state.step
			var into:float=(v-surface).dot(normal)
			if into<0:v-=normal*into
	# At puck scale the native CCD can miss a 9 mm blade. Sweep the actual
	# disk against the dedicated blade layer before integration, preserving
	# free flight/ice/goalie physics and resolving the remaining tick as a bounce.
	if contact_shape!=null:
		# A posed blade can move into a stationary disk between ticks. Resolve
		# that existing contact too; a forward sweep alone ignores overlaps.
		var overlap:=PhysicsShapeQueryParameters3D.new()
		overlap.shape=contact_shape;overlap.transform=state.transform
		overlap.collision_mask=BLADE_LAYER;overlap.margin=0.012
		var rest:=state.get_space_state().get_rest_info(overlap)
		if not rest.is_empty():
			var normal:Vector3=rest.normal
			var axis:Vector3=state.transform.basis.y.normalized()
			var nd:=absf(normal.dot(axis))
			var support:=HALF_HEIGHT*nd+RADIUS*sqrt(maxf(0,1-nd*nd))
			var depth:=support-normal.dot(state.transform.origin-rest.point)
			if depth>0 and depth<0.075:
				var contact:=state.transform
				contact.origin+=normal*(depth+0.012)
				state.transform=contact
				var into:float=(v-rest.linear_velocity).dot(normal)
				if into<0:v-=normal*into
	var motion:=v*state.step
	if motion.length_squared()>0.000001 and contact_shape!=null:
		var query:=PhysicsShapeQueryParameters3D.new()
		query.shape=contact_shape
		query.transform=state.transform
		query.motion=motion;query.collision_mask=BLADE_LAYER;query.margin=0.012
		var space:=state.get_space_state()
		var sweep:=space.cast_motion(query)
		if sweep.size()==2 and sweep[0]<1.0:
			sweep_contacts+=1
			query.transform.origin+=motion*minf(1.0,sweep[1]+0.001)
			query.motion=Vector3.ZERO
			var hit:=space.get_rest_info(query)
			if not hit.is_empty():
				var normal:Vector3=hit.normal
				var surface:Vector3=hit.linear_velocity
				var into:=(v-surface).dot(normal)
				if into<0:
					v-=normal*into*1.12
					# Physics will integrate the new velocity for this step. Offset
					# to the time of impact first, then leave only the remainder.
					var contact:=state.transform
					contact.origin+=motion*sweep[0]-v*state.step*sweep[0]
					state.transform=contact
	# Curved-face and heel/toe contacts can leave the tangential remainder
	# inside the hull after the first impact. Resolve the predicted endpoint,
	# then compensate for the velocity integration so the endpoint is exact.
	if contact_shape!=null:
		var endpoint:=PhysicsShapeQueryParameters3D.new()
		endpoint.shape=contact_shape;endpoint.collision_mask=BLADE_LAYER;endpoint.margin=0.001
		for iteration in range(2):
			endpoint.transform=state.transform
			endpoint.transform.origin+=v*state.step
			var hit:=state.get_space_state().get_rest_info(endpoint)
			if hit.is_empty():break
			var normal:Vector3=hit.normal
			var nd:=absf(normal.dot(endpoint.transform.basis.y.normalized()))
			var support:=HALF_HEIGHT*nd+RADIUS*sqrt(maxf(0,1-nd*nd))
			var depth:=support-normal.dot(endpoint.transform.origin-hit.point)
			if depth<=0 or depth>0.075:break
			var target:=endpoint.transform.origin+normal*(depth+0.012)
			var into:float=(v-hit.linear_velocity).dot(normal)
			if into<0:v-=normal*into
			var contact:=state.transform;contact.origin=target-v*state.step;state.transform=contact
	# Apply contact separation through velocity over this tick. Native CCD
	# can overwrite a custom horizontal transform correction during motion;
	# leaving the start transform intact also avoids double separation.
	v+=(state.transform.origin-integration_start.origin)/state.step
	state.transform=integration_start
	state.linear_velocity=v
	last_velocity=v

static func solve_elevation(distance_: float, speed: float, target_y: float, start_y: float) -> float:
	if distance_<0.05: return 0
	var gravity:=9.8
	var square:=speed*speed
	var discriminant:=square*square-gravity*(gravity*distance_*distance_+2*(target_y-start_y)*square)
	if discriminant<0: return 0.35
	return clampf(atan((square-sqrt(discriminant))/(gravity*distance_)),0,0.60)
