extends RefCounted
## Single-file atomic replacement. Never promote an invalid file over a good backup.
const FORMAT := "hawkey-save"
const VERSION := 2
var error := ""
var recovered := false
var migrated := false
var unsupported := false

func decode(text: String, kind: String, validator: Callable) -> Dictionary:
	unsupported=false
	var parser:=JSON.new()
	if parser.parse(text)!=OK: return {}
	var envelope: Variant=parser.data
	if not envelope is Dictionary or envelope.get("format")!=FORMAT: return {}
	if envelope.get("version")!=1 and envelope.get("version")!=VERSION:
		unsupported=true
		return {}
	if envelope.get("kind")!=kind: return {}
	var payload: Variant
	if envelope.version==1:
		payload=envelope.get("payload")
	else:
		if not envelope.get("data") is String or not envelope.get("sha256") is String: return {}
		if envelope.data.sha256_text()!=envelope.sha256: return {}
		if parser.parse(envelope.data)!=OK: return {}
		payload=parser.data
	if not payload is Dictionary or payload.is_empty() or not validator.call(payload): return {}
	migrated=envelope.version==1
	return payload

func load_file(path: String, kind: String, validator: Callable) -> Dictionary:
	error="";recovered=false;migrated=false;unsupported=false
	if FileAccess.file_exists(path):
		var value:=decode(FileAccess.get_file_as_string(path),kind,validator)
		if not value.is_empty(): return value
		if unsupported:
			error="This save uses a newer or unsupported format. It has been left untouched."
			return {}
	if FileAccess.file_exists(path+".bak"):
		var value:=decode(FileAccess.get_file_as_string(path+".bak"),kind,validator)
		if not value.is_empty():
			recovered=true
			error="Recovered the previous save from backup."
			return value
	error="No valid save found. Existing files have been left untouched."
	return {}

func write_text(path: String, text: String) -> bool:
	var file:=FileAccess.open(path,FileAccess.WRITE)
	if file==null: return false
	file.store_string(text)
	file.flush()
	var ok:=file.get_error()==OK
	file.close()
	return ok

func replace_file(from: String, to: String) -> bool:
	return DirAccess.rename_absolute(from,to)==OK

func save_file(path: String, kind: String, payload: Dictionary, validator: Callable) -> bool:
	error=""
	if payload.is_empty() or not validator.call(payload):
		error="Save validation failed; previous save retained."
		return false
	var data:=JSON.stringify(payload)
	var text:=JSON.stringify({"format":FORMAT,"version":VERSION,"kind":kind,"data":data,"sha256":data.sha256_text()})
	if DirAccess.make_dir_recursive_absolute(path.get_base_dir())!=OK:
		error="Cannot create save directory."
		return false
	var prior:=""
	if FileAccess.file_exists(path):
		prior=FileAccess.get_file_as_string(path)
		var previous:=decode(prior,kind,validator)
		if unsupported:
			error="Unsupported save format; refusing to overwrite it."
			return false
		if previous.is_empty(): prior=""
	if not write_text(path+".tmp",text):
		error="Could not write staged save; previous save retained."
		return false
	if decode(FileAccess.get_file_as_string(path+".tmp"),kind,validator).is_empty():
		error="Could not verify staged save; previous save retained."
		return false
	if not prior.is_empty():
		if not write_text(path+".bak.tmp",prior) or not replace_file(path+".bak.tmp",path+".bak"):
			error="Could not retain backup; previous save retained."
			return false
	if not replace_file(path+".tmp",path):
		error="Could not replace save; previous save retained."
		return false
	return true
