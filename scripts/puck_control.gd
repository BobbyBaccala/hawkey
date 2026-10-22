extends RefCounted
## Shared stick-control assistance, in metres and seconds. No position teleport,
## height lock or speed-dependent change to free puck physics.
const PICKUP_REACH:=0.40
const RETAIN_REACH:=0.85
const MAX_RECEIVE_SPEED:=15.5
const MAX_CONTROL_ACCEL:=80.0
const MAX_CARRY_ACCEL:=150.0
static func can_receive(puck:Vector3,puck_velocity:Vector3,body:Vector3,body_velocity:Vector3,blade:Vector3)->bool:
	return puck.y<0.14 and puck.y>=-0.03 and body.distance_to(puck)<1.8 and blade.distance_to(puck)<PICKUP_REACH and (puck_velocity-body_velocity).length()<MAX_RECEIVE_SPEED
static func retained(puck:Vector3,body:Vector3,blade:Vector3)->bool:
	return puck.y<0.18 and body.distance_to(puck)<1.9 and blade.distance_to(puck)<RETAIN_REACH
static func control_velocity(puck:Vector3,velocity:Vector3,body_velocity:Vector3,blade:Vector3,delta:float,blade_velocity:Vector3=Vector3.INF,held_time:float=0.0)->Vector3:
	var error:=blade-puck;error.y=0
	var relative:=velocity-body_velocity;relative.y=0
	# Soft capture first. Once established, follow measured stick velocity,
	# including angular motion and dekes, instead of dragging behind the body.
	var capture_accel:Vector3=error*144-relative*24
	var blend:=smoothstep(0.08,0.24,held_time)
	var target_velocity:=body_velocity if blade_velocity==Vector3.INF else blade_velocity
	target_velocity.y=0
	var desired:Vector3=target_velocity+error*18
	var follow_change:Vector3=(desired-Vector3(velocity.x,0,velocity.z))*(1.0-exp(-32*delta))
	var change:Vector3=(capture_accel*delta).lerp(follow_change,blend).limit_length(lerpf(MAX_CONTROL_ACCEL,MAX_CARRY_ACCEL,blend)*delta)
	var result:=velocity+change
	result.y=velocity.y
	return result
static func recovery_target(puck:Vector3,puck_velocity:Vector3,blade_offset:Vector3)->Vector3:
	var prediction:=Vector3(puck_velocity.x,0,puck_velocity.z).limit_length(MAX_RECEIVE_SPEED)*0.06
	var offset:=Vector3(blade_offset.x,0,blade_offset.z).limit_length(1.25)
	var target:=puck+prediction-offset*0.9;target.y=0
	return target
static func offer(puck:Vector3,puck_velocity:Vector3,body:Vector3,body_velocity:Vector3)->bool:
	return puck.y<0.16 and body.distance_to(puck)<2.25 and (puck_velocity-body_velocity).length()<MAX_RECEIVE_SPEED
