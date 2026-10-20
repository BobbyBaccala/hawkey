extends RefCounted
## Shared licensed fonts loaded on the main thread; no OS font fallback.
static var regular: FontFile
static var bold: FontFile
static func get_font(heavy: bool = false) -> FontFile:
	if regular == null:
		regular=FontFile.new()
		regular.data=FileAccess.get_file_as_bytes("res://assets/fonts/Interface-Regular.ttf")
		bold=FontFile.new()
		bold.data=FileAccess.get_file_as_bytes("res://assets/fonts/Interface-Bold.ttf")
	return bold if heavy else regular
