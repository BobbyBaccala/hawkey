extends SceneTree
## Genuine native UI captures using only an isolated demonstration save.
const Session=preload("res://scripts/gm_session.gd")
const Season=preload("res://scripts/gm_season.gd")
var captures: Array=[]
func _initialize() -> void: call_deferred("run")
func capture(name_: String) -> void:
	for i in range(4): await process_frame
	await RenderingServer.frame_post_draw
	var path: String="res://build/"+name_+".jpg"
	var err:=root.get_texture().get_image().save_jpg(path,0.94)
	captures.append({"path":path,"error":err,"width":root.size.x,"height":root.size.y})
	print("Captured ",path," error ",err)
func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://build")
	Session.slot_path="res://build/front-office-demo.json"
	for suffix in ["",".bak",".tmp",".bak.tmp"]:
		if FileAccess.file_exists(Session.slot_path+suffix): DirAccess.remove_absolute(Session.slot_path+suffix)
	Session.season=Season.new()
	if not Session.season.new_season(FileAccess.get_file_as_string(Season.Database.DEFAULT_PATH),"har"): quit(1);return
	var pool: Dictionary=Season.Management.Scouting.candidates(Session.season.state.world)
	var prospect: String=pool.keys()[0]
	Session.season.assign_scout(prospect)
	for day in range(10): Session.season.simulate_day()
	change_scene_to_file("res://gm_office.tscn")
	for i in range(4): await process_frame
	await capture("gm-market-20261020")
	await current_scene.sign_selected()
	current_scene.tab=1;current_scene.build()
	await capture("gm-contracts-20261020")
	current_scene.tab=2;current_scene.build()
	await capture("gm-team-stats-20261020")
	current_scene.tab=3;current_scene.build()
	await capture("gm-records-20261020")
	current_scene.tab=4;current_scene.build();current_scene.scouting_id=prospect;current_scene.show_scouting()
	await capture("gm-scouting-20261020")
	var file:=FileAccess.open("res://build/gm-office-captures.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"source":"actual Godot 4.6.3 native UI; softpipe; isolated 10-day demonstration season","captures":captures,"day":Session.season.state.day,"contracts":Session.season.state.management.contracts.size(),"transactions":Session.season.state.management.transactions.size()},"\t"));file.close()
	current_scene.queue_free();await process_frame;Session.season=null
	quit()
