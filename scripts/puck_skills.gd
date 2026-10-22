extends RefCounted
## Original procedural skill commands. They move the real stick and skating
## intent; no puck/body teleport, collision immunity or guaranteed defender beat.
const DURATIONS:={"cut":0.62,"toe_drag":0.78,"sweep":0.82}
var move:=""
var elapsed:=0.0
var cooldown:=0.0
var side:=1.0
var phase:=0.0
var protecting:=false
var moves_started:=0
func request(kind:String,direction:float=1.0)->bool:
	if not DURATIONS.has(kind) or not move.is_empty() or cooldown>0:return false
	move=kind;elapsed=0.0;side=1.0 if direction>=0 else -1.0
	cooldown=1.65;moves_started+=1
	return true
func advance(delta:float,owns:bool)->void:
	cooldown=maxf(0.0,cooldown-delta);phase+=delta*TAU*1.05
	if not owns:move="";protecting=false;return
	if not move.is_empty():
		elapsed+=delta
		if elapsed>=float(DURATIONS[move]):move=""
func weight()->float:
	return sin(PI*clampf(elapsed/float(DURATIONS[move]),0,1)) if not move.is_empty() else 0.0
func stick(raw:Vector2,speed:float,owns:bool)->Vector2:
	if not owns:return raw.clamp(Vector2(-1,-1),Vector2(1,1))
	var result:=raw
	if raw.length()<0.12:result=Vector2(sin(phase)*0.18,cos(phase*2)*0.06)*clampf(speed/4,0,1)
	if protecting:result=Vector2(side*0.8,0.65).lerp(raw,clampf(raw.length(),0,1))
	if not move.is_empty():
		var u:=clampf(elapsed/float(DURATIONS[move]),0,1)
		var envelope:=sin(PI*u)
		match move:
			"cut":result=Vector2(side*0.95*sin(PI*u),0.15*envelope)
			"sweep":result=Vector2(side*0.95*sin(TAU*u),-0.25*envelope)
			"toe_drag":result=Vector2(side*0.8*sin(TAU*u),0.95*sin(PI*u))
	return result.clamp(Vector2(-1,-1),Vector2(1,1))
func lean()->float:
	return side*0.35 if protecting else side*weight()*(0.7 if move=="cut" else 0.3)
func steer(intent:Vector3,rig_right:Vector3)->Vector3:
	if move=="cut":return (intent*0.85-rig_right*side*0.28*weight()).limit_length(1)
	return intent*(0.82 if protecting else 1.0)
