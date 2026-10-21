extends RefCounted
## Only isolated data enters this worker. No scene tree, rendering or live session access.
const Season=preload("res://scripts/gm_season.gd")
const Store=preload("res://scripts/save_store.gd")
var thread:=Thread.new()
var snapshot: Dictionary={}
var strengths: Dictionary={}
var path:=""
var outcome: Dictionary={}
func start(state: Dictionary, cached_strengths: Dictionary, target: String) -> Error:
	if thread.is_started(): return ERR_BUSY
	snapshot=state.duplicate(true)
	strengths=cached_strengths.duplicate(true)
	path=target
	return thread.start(_run)
func completed() -> bool:
	return thread.is_started() and not thread.is_alive()
func finish() -> Dictionary:
	if thread.is_started():
		var value: Variant=thread.wait_to_finish()
		outcome=value if value is Dictionary else {"ok":false,"error":"Checkpoint worker stopped unexpectedly; previous save retained."}
	return outcome
func _run() -> Dictionary:
	var model:=Season.new()
	model.state=snapshot;model.strengths=strengths
	if not model.simulate_day(): return {"ok":false,"error":model.error}
	var store:=Store.new()
	if not store.save_file(path,"gm-season",model.state,model.validate): return {"ok":false,"error":store.error}
	return {"ok":true,"state":model.state,"error":""}
