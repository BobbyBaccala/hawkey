extends RefCounted
## Barlow sports typography: condensed semibold display, readable regular body.
## SIL Open Font License; loaded on the main thread without OS fallback.
static var regular: FontFile
static var bold: FontFile
static func get_font(heavy: bool = false) -> FontFile:
	if regular == null:
		regular=FontFile.new()
		regular.data=FileAccess.get_file_as_bytes("res://assets/fonts/Barlow-Regular.ttf")
		bold=FontFile.new()
		bold.data=FileAccess.get_file_as_bytes("res://assets/fonts/BarlowCondensed-SemiBold.ttf")
	return bold if heavy else regular
