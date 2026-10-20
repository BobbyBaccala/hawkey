extends SceneTree
const Store=preload("res://scripts/save_store.gd")
const Settings=preload("res://scripts/game_settings.gd")
class FailStore:
	extends Store
	var fail_suffix:=".tmp"
	func replace_file(from: String, to: String) -> bool:
		if from.ends_with(fail_suffix) and (fail_suffix!=".tmp" or not from.ends_with(".bak.tmp")): return false
		return super.replace_file(from,to)
var failures:=0
var checks:=0
var path:="user://tests/atomic-save.json"
func check(ok: bool, why: String) -> void:
	checks+=1
	if not ok: push_error(why);failures+=1
func valid(data: Dictionary) -> bool:
	return data.get("value") is float or data.get("value") is int
func clean(target: String) -> void:
	for suffix in ["",".bak",".tmp",".bak.tmp"]:
		if FileAccess.file_exists(target+suffix): DirAccess.remove_absolute(target+suffix)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	clean(path)
	var store:=Store.new()
	var first:=store.save_file(path,"test",{"value":1},valid)
	check(first,"Initial atomic save: "+store.error)
	if not first: quit(1);return
	check(store.save_file(path,"test",{"value":2},valid),"Next save keeps backup")
	check(store.load_file(path,"test",valid).value==2,"Latest value round trip")
	var original:=FileAccess.get_file_as_string(path)
	check(not store.save_file(path,"test",{"bad":3},valid),"Reject invalid payload")
	check(FileAccess.get_file_as_string(path)==original,"Invalid writes preserve existing bytes")
	var fault:=FailStore.new()
	check(not fault.save_file(path,"test",{"value":3},valid),"Interrupted replacement reports failure")
	check(store.load_file(path,"test",valid).value==2,"Interrupted final replacement preserves primary")
	fault.fail_suffix=".bak.tmp"
	check(not fault.save_file(path,"test",{"value":4},valid),"Backup failure stops commit")
	check(store.load_file(path,"test",valid).value==2,"Backup failure preserves primary")
	store.write_text(path+".tmp","partial orphan")
	check(store.load_file(path,"test",valid).value==2,"Interrupted staged writes are never promoted on load")
	store.write_text(path,"truncated")
	check(store.load_file(path,"test",valid).value==2 and store.recovered,"Corrupt primary recovers latest valid backup")
	var backup:=FileAccess.get_file_as_string(path+".bak")
	check(store.save_file(path,"test",{"value":5},valid),"Save after recovery")
	check(FileAccess.get_file_as_string(path+".bak")==backup,"Recovered save does not replace backup with corrupt primary")
	var envelope: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
	envelope.data=JSON.stringify({"value":999})
	store.write_text(path,JSON.stringify(envelope))
	check(store.load_file(path,"test",valid).value==2 and store.recovered,"Checksum detects valid-JSON payload corruption")
	store.write_text(path,JSON.stringify({"format":Store.FORMAT,"version":999,"kind":"test"}))
	check(store.load_file(path,"test",valid).is_empty() and store.unsupported,"Future version blocks stale backup fallback")
	check(not store.save_file(path,"test",{"value":6},valid),"Future version is never overwritten")
	store.write_text(path,JSON.stringify({"format":Store.FORMAT,"version":1,"kind":"test","payload":{"value":7}}))
	check(store.load_file(path,"test",valid).value==7 and store.migrated,"Legacy envelope migration")
	check(store.save_file(path,"test",{"value":8},valid),"Migrated save writes current envelope")
	check(JSON.parse_string(FileAccess.get_file_as_string(path)).version==Store.VERSION,"Current format persisted")
	check(store.load_file(path,"different-kind",valid).is_empty(),"Wrong-kind saves rejected")
	var settings:=Settings.new()
	check(not settings.valid_typed({"schema_version":1,"camera":1.5,"deadzone":0.2}),"Camera must be integral")
	check(not settings.valid_typed({"schema_version":1,"camera":0,"deadzone":0.9}),"Deadzone must be bounded")
	var previous_path:=Settings.path;Settings.path="user://tests/preferences.json";clean(Settings.path)
	check(settings.save_settings(2,0.26),"Settings save independently")
	var restored:=Settings.new();restored.load_settings()
	check(restored.values.camera==2 and is_equal_approx(restored.values.deadzone,0.26),"Settings round trip")
	check(FileAccess.get_file_as_string(path).contains('"kind":"test"'),"Settings do not mutate other save")
	clean(Settings.path);Settings.path=previous_path;clean(path)
	print("Save/recovery: %d checks; %d failures"%[checks,failures]);quit(failures)
