extends SceneTree
## Skater kit materials: fabric/gear surfaces carry procedural detail maps,
## numbers are sewn into the jersey shader (no floating text), and generated
## textures/materials are cached and shared between skaters of one kit.
const Kit = preload("res://scripts/kit_materials.gd")
var failures := 0

func check(condition: bool, label: String) -> void:
	if condition:
		print("PASS ", label)
	else:
		failures += 1
		print("FAIL ", label)

func _initialize() -> void:
	call_deferred("run")

func param(mi: GeometryInstance3D, name: String) -> Variant:
	var m := mi.material_override as ShaderMaterial
	return m.get_shader_parameter(name) if m else null

func mipmapped(tex: Variant) -> bool:
	return tex is Texture2D and (tex as Texture2D).get_image() != null and (tex as Texture2D).get_image().has_mipmaps()

func labels(node: Node) -> int:
	var count := 1 if node is Label3D else 0
	for child in node.get_children():
		count += labels(child)
	return count

func run() -> void:
	var Visual = load("res://scripts/skater_visual.gd")
	var a = Visual.new()
	a.kit = Color("#185c73")
	a.number = "17"
	root.add_child(a)
	var b = Visual.new()
	b.kit = Color("#185c73")
	b.number = "9"
	root.add_child(b)
	var keeper = Visual.new()
	keeper.goalie = true
	keeper.kit = Color("#7a1f2b")
	root.add_child(keeper)
	var ref = Visual.new()
	ref.referee = true
	root.add_child(ref)
	await process_frame

	# Jersey: knit normal + folds, twill number, sheen.
	var jersey: MeshInstance3D = a.jersey
	check(jersey.skin != null, "Kit shader is applied to the skinned jersey")
	check(jersey.material_override is ShaderMaterial and (jersey.material_override as ShaderMaterial).shader == Kit.CLOTH, "Jersey uses the knit cloth shader")
	check(mipmapped(param(jersey, "knit_tex")), "Jersey has a mipmapped knit normal map")
	check(mipmapped(param(jersey, "fold_tex")), "Jersey has a cloth-fold normal map")
	check(float(param(jersey, "sheen")) > 0.0, "Jersey has fabric sheen")
	check(param(jersey, "show_number") == true and param(jersey, "number_tex") is Texture2D, "Number is sewn into the jersey shader")
	check(labels(a) == 0, "No floating Label3D text on the skater")
	a.set_nameplate("Larsen")
	check(param(a.jersey, "show_name") == true and param(a.jersey, "name_tex") is Texture2D, "Nameplate is twill in the jersey shader")
	a.set_number("44")
	check(param(a.jersey, "number_tex") == Kit.text_texture("44", 0.92), "set_number() updates the sewn number")
	# The number SDF has a solid inside and a clear outside.
	var img := Kit.text_texture("17", 0.92).get_image()
	var lo := 255
	var hi := 0
	for x in range(img.get_width()):
		var v := int(img.get_pixel(x, 32).r8)
		lo = mini(lo, v)
		hi = maxi(hi, v)
	check(lo < 40 and hi > 180, "Number SDF has inside and outside (%d..%d)" % [lo, hi])

	# Sleeves: UV-mapped knit with stripes.
	var sleeve: MeshInstance3D = a.cloth_sleeves[0]
	check(param(sleeve, "knit_tex") is Texture2D and int(param(sleeve, "garment")) == 2, "Sleeves use striped knit cloth")
	var arrays: Array = (sleeve.mesh as ArrayMesh).surface_get_arrays(0)
	check(arrays[Mesh.ARRAY_TEX_UV] != null and (arrays[Mesh.ARRAY_TEX_UV] as PackedVector2Array).size() > 0, "Sleeve cloth has UVs for stripes and knit")

	# Breezers, socks, gloves, skates, helmet.
	check(mipmapped(param(a.pant_legs[0], "detail_tex")) and float(param(a.pant_legs[0], "sheen")) > 0.0, "Breezers have nylon detail and sheen")
	check(param(a.socks[0], "detail_tex") == Kit.rib_texture() and param(a.socks[0], "sock_stripes") == true, "Socks have a ribbed knit normal and crisp stripes")
	var glove: MeshInstance3D = a.skater_gloves[0].get_child(0)
	check(param(glove, "detail_tex") == Kit.leather_texture(), "Gloves have a leather grain normal")
	var skate: MeshInstance3D = a.skates[0].get_child(0)
	check(param(skate, "detail_tex") is Texture2D and param(skate, "metal_from_grey") == true, "Skates have boot grain and steel runner")
	var shell: MeshInstance3D = a.helmet.get_node("Shell")
	check(float(param(shell, "clearcoat")) > 0.5 and param(shell, "detail_tex") is Texture2D, "Helmet shell has a clearcoat over painted detail")
	check(a.helmet.get_node("Visor").material_override == Kit.visor(), "Visor uses the clear Fresnel visor shader")

	# Skin keeps garment hiding and gains detail.
	var body: MeshInstance3D = null
	for child in a.skeleton.get_children():
		if child is MeshInstance3D and child != a.jersey: body = child
	check(param(body, "has_skin_detail") == true and param(body, "skin_detail") is Texture2D, "Skin has pore detail")
	check(param(body, "hide_pants") == true and param(body, "hide_socks") == true, "Skin shader still hides the body's pants and socks")

	# Caching: textures generated once, materials shared within a colourway.
	check(param(a.jersey, "knit_tex") == param(b.jersey, "knit_tex"), "Two skaters share the knit texture")
	check(a.cloth_sleeves[0].material_override == b.cloth_sleeves[0].material_override, "Same kit shares the sleeve material")
	check(a.pant_legs[0].material_override == b.pant_legs[0].material_override, "Same kit shares the breezer material")
	check(a.socks[1].material_override == b.socks[0].material_override, "Same kit shares the sock material")
	check(param(a.jersey, "number_tex") != param(b.jersey, "number_tex"), "Different numbers get different twill")
	check(Kit.text_texture("17", 0.92) == Kit.text_texture("17", 0.92), "Number textures are cached")

	# Goalie and referee variants build.
	check(keeper.jersey.material_override is ShaderMaterial and float(param(keeper.jersey, "hem_v")) < float(param(a.jersey, "hem_v")), "Goalie sweater gets its own hem height")
	check(int(param(ref.jersey, "garment")) == 3, "Referee keeps the striped sweater")

	print("Kit material failures: %d" % failures)
	quit(failures)
