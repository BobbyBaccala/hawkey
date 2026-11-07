extends SceneTree
## Goalie gear graphics are painted textures (crisp edges), not colours stepped
## across triangles: each piece carries UVs and a texture whose face holds the
## kit colour and whose reserved strip is white for untextured geometry.
const Gear = preload("res://scripts/gear_builder.gd")
var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		push_error(message)
		failures += 1

func _initialize() -> void:
	call_deferred("run")

func near(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) < 0.08 and absf(a.g - b.g) < 0.08 and absf(a.b - b.b) < 0.08

func run() -> void:
	var kit := Color("#b3162c")
	var accent := Color("#1b2a4a")
	var pieces := {
		"pad": Gear.goalie_pad(1, kit, accent),
		"blocker": Gear.blocker(-1, kit, accent),
		"catcher": Gear.catcher(1, kit, accent),
	}
	for name in pieces:
		var mesh: ArrayMesh = pieces[name]
		var arrays := mesh.surface_get_arrays(0)
		var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		check(uv.size() == (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size(), "%s has a UV per vertex" % name)
		var material := mesh.surface_get_material(0) as StandardMaterial3D
		check(material != null and material.albedo_texture != null, "%s carries a painted graphic" % name)
		if material == null or material.albedo_texture == null:
			continue
		var image: Image = material.albedo_texture.get_image()
		check(image.has_mipmaps(), "%s graphic is mipmapped (no shimmer at distance)" % name)
		var blank := image.get_pixelv(Vector2i(Gear.BLANK_UV * Vector2(image.get_size())))
		check(near(blank, Color.WHITE), "%s blank strip is white (%s)" % [name, blank])
		var kit_pixels := 0
		var white_pixels := 0
		for y in range(0, int(image.get_height() * Gear.FACE_V), 4):
			for x in range(0, image.get_width(), 4):
				var c := image.get_pixel(x, y)
				if near(c, kit): kit_pixels += 1
				elif near(c, Gear.WHITE): white_pixels += 1
		check(kit_pixels > 50 and white_pixels > 50, "%s face mixes kit panels and white (%d kit, %d white samples)" % [name, kit_pixels, white_pixels])
		# Textured face vertices exist (not every vertex on the blank strip).
		var face := 0
		for q in uv:
			if q != Gear.BLANK_UV: face += 1
		# The catcher paints only its cuff/cheater panel; the pocket is leather.
		check(face > (40 if name == "catcher" else 100), "%s maps its face into the graphic (%d vertices)" % [name, face])
	# Graphics are cached per colourway, so a second goalie reuses the texture.
	var again: ArrayMesh = Gear.goalie_pad(-1, kit, accent)
	check((again.surface_get_material(0) as StandardMaterial3D).albedo_texture == (pieces.pad.surface_get_material(0) as StandardMaterial3D).albedo_texture, "Pad graphic is shared between pads of one colourway")
	print("Gear graphic failures: ", failures)
	quit(failures)
