extends RefCounted
const Store=preload("res://scripts/save_store.gd")
static var path := "user://settings.json"
var values := {"schema_version":1,"camera":0,"deadzone":0.18,"sfx_volume":0.8}
var error := ""
func valid_typed(data: Dictionary) -> bool:
	if data.get("schema_version")!=1: return false
	for key in ["camera","deadzone"]:
		if not (data.get(key) is int or data.get(key) is float) or not is_finite(float(data[key])): return false
	if data.has("sfx_volume"):
		if not (data.sfx_volume is int or data.sfx_volume is float) or not is_finite(float(data.sfx_volume)) or data.sfx_volume<0 or data.sfx_volume>1: return false
	return data.camera==floor(float(data.camera)) and data.camera>=0 and data.camera<=3 and data.deadzone>=0.05 and data.deadzone<=0.4
func load_settings() -> void:
	var store:=Store.new()
	var loaded:=store.load_file(path,"settings",valid_typed)
	if not loaded.is_empty():
		values.merge(loaded,true)
	error=store.error if FileAccess.file_exists(path) or FileAccess.file_exists(path+".bak") else ""
func save_settings(camera: int, deadzone: float, sfx_volume: float=0.8) -> bool:
	var next:={"schema_version":1,"camera":camera,"deadzone":deadzone,"sfx_volume":sfx_volume}
	var store:=Store.new()
	if not store.save_file(path,"settings",next,valid_typed):
		error=store.error
		return false
	values=next;error=""
	return true
