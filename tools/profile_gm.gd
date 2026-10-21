extends SceneTree
## Reproducible CPU/data baseline. Uses an isolated disposable save, not user slots.
const GM=preload("res://scripts/gm_season.gd")
const Store=preload("res://scripts/save_store.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://build")
	var path:="res://build/profile-gm-save.json"
	for suffix in ["",".bak",".tmp",".bak.tmp"]:
		if FileAccess.file_exists(path+suffix): DirAccess.remove_absolute(path+suffix)
	var world:=FileAccess.get_file_as_string(GM.Database.DEFAULT_PATH)
	var model:=GM.new();var store:=Store.new();var result:={}
	var start:=Time.get_ticks_usec()
	if not model.new_season(world,"har",20261020): push_error(model.error);quit(1);return
	result.new_season_ms=(Time.get_ticks_usec()-start)/1000.0
	start=Time.get_ticks_usec()
	for day in range(62):
		if not model.simulate_day(): push_error(model.error);quit(1);return
	result.simulate_992_fixtures_ms=(Time.get_ticks_usec()-start)/1000.0
	start=Time.get_ticks_usec()
	if not store.save_file(path,"gm-season",model.state,model.validate): push_error(store.error);quit(1);return
	result.first_snapshot_save_ms=(Time.get_ticks_usec()-start)/1000.0
	start=Time.get_ticks_usec()
	if not store.save_file(path,"gm-season",model.state,model.validate): push_error(store.error);quit(1);return
	result.snapshot_save_with_backup_ms=(Time.get_ticks_usec()-start)/1000.0
	start=Time.get_ticks_usec()
	if store.load_file(path,"gm-season",model.validate).is_empty(): push_error(store.error);quit(1);return
	result.validated_load_ms=(Time.get_ticks_usec()-start)/1000.0
	result.save_bytes=FileAccess.get_file_as_bytes(path).size()
	result.engine=Engine.get_version_info().string
	result.environment="Linux cloud headless; CPU data workflow, not gameplay FPS"
	result.processor=OS.get_processor_name();result.reported_processors=OS.get_processor_count()
	result.workload={"teams":643,"players":14745,"hl_clubs":32,"fixtures":992,"seed":20261020}
	var file:=FileAccess.open("res://build/gm-profile.json",FileAccess.WRITE);file.store_string(JSON.stringify(result,"\t"));file.close()
	print(JSON.stringify(result))
	for suffix in ["",".bak",".tmp",".bak.tmp"]:
		if FileAccess.file_exists(path+suffix): DirAccess.remove_absolute(path+suffix)
	quit()
