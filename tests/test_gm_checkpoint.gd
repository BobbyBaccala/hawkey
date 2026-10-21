extends SceneTree
const Session=preload("res://scripts/gm_session.gd")
const Season=preload("res://scripts/gm_season.gd")
var failures:=0
var checks:=0
func check(ok: bool, why: String) -> void:
	checks+=1
	if not ok: push_error(why);failures+=1
func _initialize() -> void: call_deferred("run")
func settle() -> void:
	for i in range(4): await process_frame
func run() -> void:
	var original:=Session.slot_path;Session.slot_path="user://tests/async-gm.json"
	Session.season=Season.new()
	check(Session.season.new_season(FileAccess.get_file_as_string(Season.Database.DEFAULT_PATH),"har"),"Create test season")
	change_scene_to_file("res://gm.tscn");await settle()
	var screen=current_scene
	var launch_start:=Time.get_ticks_usec()
	screen.advance_day()
	var launch_ms: float=(Time.get_ticks_usec()-launch_start)/1000.0
	check(screen.checkpoint_job!=null and screen.sim_button.disabled and screen.play_button.disabled,"Save job starts with duplicate actions disabled")
	check(Session.season.state.day==0,"Live season remains unchanged until successful checkpoint")
	check(not Session.advance_day() and not Session.resume(),"Session API also rejects changes/resume during checkpoint")
	var frames:=0
	while screen.checkpoint_job!=null:
		await process_frame;frames+=1
	check(frames>2,"UI process frames continue during real snapshot save")
	check(Session.season.state.day==1,"Completed worker publishes exactly one new league day")
	check(not screen.sim_button.disabled,"Controls return after save completion")
	check(Session.resume() and Session.season.state.day==1,"Background checkpoint survives resume")
	var good_path:=Session.slot_path;Session.slot_path="/proc/hawkey-async-no-write/slot.json"
	await screen.advance_day()
	check(Session.season.state.day==1 and not Session.error.is_empty(),"Failed background checkpoint retains live day and reports error")
	Session.slot_path=good_path
	check(Session.resume() and Session.season.state.day==1,"Failed worker cannot corrupt valid prior checkpoint")
	current_scene.queue_free();await process_frame;Session.season=null
	for suffix in ["",".bak",".tmp",".bak.tmp"]:
		if FileAccess.file_exists(Session.slot_path+suffix): DirAccess.remove_absolute(Session.slot_path+suffix)
	Session.slot_path=original
	print("GM checkpoint: %d checks; %d failures; %d process callbacks during save; %.2f ms main-thread launch"%[checks,failures,frames,launch_ms]);quit(failures)
