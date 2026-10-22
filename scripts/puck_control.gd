extends RefCounted
## Shared stick-control assistance, in metres and seconds. No position teleport,
## height lock or speed-dependent change to free puck physics.
const PICKUP_REACH:=0.40
const RETAIN_REACH:=0.85
const MAX_RECEIVE_SPEED:=15.5
const MAX_CONTROL_ACCEL:=80.0
static func can_receive(puck:Vector3,puck_velocity:Vector3,body:Vector3,body_velocity:Vector3,blade:Vector3)->bool:
	return puck.y<0.14 and puck.y>=-0.03 and body.distance_to(puck)<1.8 and blade.distance_to(puck)<PICKUP_REACH and (puck_velocity-body_velocity).length()<MAX_RECEIVE_SPEED
static func retained(puck:Vector3,body:Vector3,blade:Vector3)->bool:
	return puck.y<0.18 and body.distance_to(puck)<1.9 and blade.distance_to(puck)<RETAIN_REACH
static func control_velocity(puck:Vector3,velocity:Vector3,body_velocity:Vector3,blade:Vector3,delta:float)->Vector3:
	var error:=blade-puck;error.y=0
	var relative:=velocity-body_velocity;relative.y=0
	# A bounded critically damped spring; contact softens a pass over time,
	# never by multiplying velocity or snapping the puck onto a stick.
	var change:Vector3=(error*144-relative*24).limit_length(MAX_CONTROL_ACCEL)*delta
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
