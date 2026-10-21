extends Node3D
## Original precomputed cues; bounded spatial voices, no per-event synthesis.
const KINDS: Array[String]=["wrist","slap","pass","boards","pad","post","net","whistle","horn","check","stop"]
const VOICES:=12
var bank: Dictionary={}
var voices: Array[AudioStreamPlayer3D]=[]
var voice_until: Array[float]=[]
var priorities: Array[int]=[]
var cursors: Dictionary={}
var last_event: Dictionary={}
var stop_states: Dictionary={}
var clock:=0.0
var suspended:=false
var level:=1.0
var last_cue: Dictionary={}
var accepted:=0

func _ready() -> void:
	for kind in KINDS:
		var variants: Array=[]
		for variant in range(3):
			# Normal Godot resources retain the import/export path and are cached once.
			variants.append(load("res://assets/audio/%s-%d.wav"%[kind,variant]))
		bank[kind]=variants;cursors[kind]=0
	for i in range(VOICES):
		var voice:=AudioStreamPlayer3D.new()
		voice.max_distance=120;voice.unit_size=20
		voice.attenuation_filter_cutoff_hz=12000
		add_child(voice);voices.append(voice);voice_until.append(0);priorities.append(0)

func _process(delta: float) -> void:
	if not suspended: clock+=delta

func set_suspended(value: bool) -> void:
	suspended=value
	for voice in voices: voice.stream_paused=value

func priority(kind: String) -> int:
	return 3 if kind in ["whistle","horn"] else (2 if kind in ["wrist","slap","pass"] else 1)

func cue(kind: String, where: Vector3, strength: float=1.0) -> bool:
	if suspended or level<=0 or not bank.has(kind) or not where.is_finite() or not is_finite(strength): return false
	var gap: float=0.3 if kind in ["whistle","horn","stop"] else 0.045
	if clock-float(last_event.get(kind,-10.0))<gap: return false
	var importance:=priority(kind)
	var slot:=-1
	for i in range(VOICES):
		if voice_until[i]<=clock: slot=i;break
	if slot<0:
		for i in range(VOICES):
			if priorities[i]<importance and (slot<0 or voice_until[i]<voice_until[slot]): slot=i
	if slot<0: return false
	var variant: int=int(cursors[kind])%3
	var stream: AudioStreamWAV=bank[kind][variant]
	if stream==null: return false
	var voice:=voices[slot]
	voice.stop();voice.stream=stream;voice.global_position=where
	voice.unit_size=55 if importance==3 else 20
	voice.volume_db=linear_to_db(clampf(level,0,1)*clampf(strength,0.15,1.0))-8
	voice.pitch_scale=1.0+float(variant-1)*0.018
	voice_until[slot]=clock+stream.get_length()/voice.pitch_scale;priorities[slot]=importance
	last_event[kind]=clock;cursors[kind]+=1
	last_cue={"kind":kind,"position":where,"variant":variant,"strength":clampf(strength,0.15,1.0),"slot":slot}
	accepted+=1
	if DisplayServer.get_name()!="headless": voice.play()
	return true

func contact(body: Node, where: Vector3, speed: float) -> void:
	if speed<2.5: return
	if body is CollisionObject3D and (body.collision_layer & 16)!=0: return
	var cursor:=body
	var kind: String="pad" if body.has_meta("actor") else "boards"
	for depth in range(6):
		if cursor==null: break
		if cursor.name=="NetCollision": kind="net";break
		if cursor.name in ["NorthGoal","SouthGoal"]: kind="post";break
		cursor=cursor.get_parent()
	cue(kind,where,clampf(speed/28,0.2,1))

func track_stop(actor: Node3D, weight: float, speed: float) -> void:
	var id_:=actor.get_instance_id()
	var stopping:=weight>0.15
	if stopping and not bool(stop_states.get(id_,false)): cue("stop",actor.global_position,clampf(speed/8,0.3,1))
	stop_states[id_]=stopping
