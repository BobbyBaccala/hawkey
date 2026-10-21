extends SceneTree
const Sound=preload("res://scripts/hockey_audio.gd")
const Settings=preload("res://scripts/game_settings.gd")
var checks:=0
var failures:=0
func check(ok: bool, why: String) -> void:
	checks+=1
	if not ok: push_error(why);failures+=1
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var sound:=Sound.new();root.add_child(sound)
	check(sound.voices.size()==12,"Audio uses bounded spatial voice pool")
	for kind in Sound.KINDS:
		check(sound.bank[kind].size()==3,"Each cue has three original variants")
		for sample in sound.bank[kind]: check(sample!=null and sample.get_length()>0,"Imported audio is playable and nonempty")
	check(sound.cue("wrist",Vector3(1,0,-2),0.7),"Cue accepts real world position")
	check(sound.last_cue.position==Vector3(1,0,-2),"Spatial position follows event")
	check(not sound.cue("wrist",Vector3.ZERO),"Repeated same-frame contacts cannot spam a cue")
	sound.clock+=0.1;sound.cue("wrist",Vector3.ZERO)
	check(sound.last_cue.variant==1,"Repeated events vary timbre")
	sound.clock+=0.1;sound.cue("wrist",Vector3.ZERO)
	check(sound.last_cue.variant==2,"Third variant selected before reuse")
	sound.set_suspended(true)
	check(not sound.cue("slap",Vector3.ZERO),"Paused soundscape emits no events")
	sound.set_suspended(false);sound.level=0
	check(not sound.cue("slap",Vector3.ZERO),"Volume zero mutes event playback")
	sound.level=1;sound.clock+=2
	check(not sound.cue("unknown",Vector3.ZERO) and not sound.cue("post",Vector3(NAN,0,0)),"Invalid sound and nonfinite coordinates rejected")
	# Fill every voice with low-priority contacts, then reserve access for a whistle.
	for i in range(Sound.VOICES): sound.voice_until[i]=sound.clock+10;sound.priorities[i]=1
	check(sound.cue("whistle",Vector3.ZERO),"Whistle can preempt lower-priority impacts")
	for i in range(Sound.VOICES): sound.priorities[i]=3
	sound.clock+=0.1
	check(not sound.cue("boards",Vector3.ZERO),"Ordinary impacts cannot steal whistle/horn voices")
	var prefs:=Settings.new()
	check(prefs.valid_typed({"schema_version":1,"camera":0,"deadzone":0.18}),"Old settings remain valid without volume")
	check(not prefs.valid_typed({"schema_version":1,"camera":0,"deadzone":0.18,"sfx_volume":2}),"Reject out-of-range audio preference")
	var old_path:=Settings.path;Settings.path="user://tests/hockey-audio-preferences.json"
	check(prefs.save_settings(2,0.22,0.0),"Audio mute saves independently with existing preferences")
	var restored:=Settings.new();restored.load_settings()
	check(restored.values.sfx_volume==0 and restored.values.camera==2,"Saved mute and camera round trip")
	for suffix in ["",".tmp",".bak",".bak.tmp"]:
		if FileAccess.file_exists(Settings.path+suffix): DirAccess.remove_absolute(Settings.path+suffix)
	Settings.path=old_path
	var floor:=StaticBody3D.new();floor.collision_layer=16;root.add_child(floor)
	var before_contacts:=sound.accepted
	sound.contact(floor,Vector3.ZERO,25)
	check(sound.accepted==before_contacts,"Ice contact is not misclassified as boards")
	floor.queue_free()
	sound.queue_free();await process_frame
	var match_scene=load("res://main.tscn").instantiate();root.add_child(match_scene);await physics_frame
	match_scene.set_physics_process(false);match_scene.in_menu=false;match_scene.paused=false
	match_scene.audio.set_suspended(false)
	match_scene.match_state.phase=match_scene.MatchState.Phase.PLAY
	match_scene.puck.position=match_scene.player.position+Vector3(0,0.03,-0.5);match_scene.puck.position.y=0.03;match_scene.cooldown=0
	check(match_scene.take_shot(true),"Actual match accepts slap shot")
	check(match_scene.audio.last_cue.kind=="slap","Slap shot routes to slap cue rather than beep")
	match_scene.audio.clock+=0.2;match_scene.cooldown=0
	match_scene.puck.position=match_scene.player.position+Vector3(0,0.03,-0.5);match_scene.puck.position.y=0.03
	check(match_scene.strike(Vector3.FORWARD,16,true),"Actual match accepts pass")
	check(match_scene.audio.last_cue.kind=="pass","Pass has separate event identity")
	match_scene.queue_free();await process_frame
	print("Hockey audio: %d checks; %d failures"%[checks,failures]);quit(failures)
