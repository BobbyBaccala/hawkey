extends SceneTree
## Gameplay-camera "photo" look: skaters mirrored in the ice
## (scripts/ice_reflection.gd + the ice/paint shaders in arena.gd), overhead
## shading and specular AA on the kit shaders, minimum-width sticks
## (scripts/thin_aa.gd) and the trimmed Forward+ SSR (render_look.gd).
const IceReflection = preload("res://scripts/ice_reflection.gd")
const ThinAA = preload("res://scripts/thin_aa.gd")
const SkaterScript = preload("res://scripts/skater_visual.gd")
var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		push_error(message)
		failures += 1

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	# Mirror transform: a world point seen by the main camera lands where its
	# reflection through the ice is seen by the mirror camera, x flipped.
	var cam := Transform3D(Basis.from_euler(Vector3(-0.6, 0.4, 0.0)), Vector3(3, 9.5, 14))
	var mir := IceReflection.mirrored(cam)
	check(is_equal_approx(mir.basis.determinant(), 1.0), "Mirror camera basis is a proper rotation")
	check(is_equal_approx(mir.origin.y, -9.5) and is_equal_approx(mir.origin.x, 3.0), "Mirror camera sits below the ice")
	for p in [Vector3(1, 1.2, 2), Vector3(-4, 0.3, -8), Vector3(0, 1.9, 5)]:
		var a: Vector3 = cam.affine_inverse() * p
		var b: Vector3 = mir.affine_inverse() * Vector3(p.x, -p.y, p.z)
		check(a.distance_to(Vector3(-b.x, b.y, b.z)) < 1e-4, "Mirrored point maps to x-flipped view position %s" % p)
	var env := IceReflection.mirror_environment()
	check(not env.glow_enabled and not env.ssao_enabled and not env.ssr_enabled and not env.fog_enabled, "Mirror pass has no post effects")
	check(env.tonemap_mode == Environment.TONE_MAPPER_LINEAR, "Mirror pass is linear (added as radiance)")

	var m = load("res://main.tscn").instantiate()
	m.get_script().skip_title = true
	root.add_child(m)
	for i in range(8): await physics_frame
	await process_frame
	var refl = m.get_node_or_null("IceReflection")
	check(refl != null, "IceReflection node added by lab.gd")
	if refl:
		refl.retag()
		refl.sync_camera()
		check(refl.viewport.transparent_bg, "Mirror view is transparent outside the players")
		check(refl.viewport.msaa_3d == Viewport.MSAA_DISABLED and refl.viewport.positional_shadow_atlas_size == 0, "Mirror view is cheap (no MSAA, no positional shadows)")
		check(refl.mirror.cull_mask == IceReflection.REFLECT_LAYER, "Mirror camera renders only the reflection layer")
		var main_cam: Camera3D = m.camera
		check(refl.mirror.global_transform.origin.distance_to(IceReflection.mirrored(main_cam.global_transform).origin) < 1e-3, "Mirror camera follows the gameplay camera")
		check(is_equal_approx(refl.mirror.fov, main_cam.fov), "Mirror camera uses the gameplay fov")
		check(main_cam.cull_mask & IceReflection.REFLECT_LAYER != 0, "Gameplay camera still renders tagged skaters")
		var ice: ShaderMaterial = m.arena.ice_surface_material
		check(float(ice.get_shader_parameter("reflection_strength")) > 0.1, "Ice samples the mirror image")
		check(ice.get_shader_parameter("reflection_tex") is ViewportTexture, "Ice has the mirror texture")
		var painted := 0
		for pm in m.arena.paint_materials:
			if pm.get_shader_parameter("reflection_tex") is ViewportTexture: painted += 1
		check(painted >= 3, "Painted lines carry the reflection too (%d)" % painted)
		var on_ice := 0
		var tagged_ok := true
		var sticks_ok := true
		for v in m.get_tree().get_nodes_in_group("skater_visuals"):
			on_ice += 1
			for g in v.find_children("*", "GeometryInstance3D", true, false):
				if g is GPUParticles3D or g is CPUParticles3D: continue
				if (g as GeometryInstance3D).layers & IceReflection.REFLECT_LAYER == 0: tagged_ok = false
			if v.stick_shaft and not (v.stick_shaft.material_overlay is ShaderMaterial): sticks_ok = false
		check(on_ice >= 10, "Skaters on the ice (%d)" % on_ice)
		check(tagged_ok, "Every on-ice skater mesh is on the reflection layer")
		check(sticks_ok, "Every stick shaft has the minimum-width overlay")
		# Bench figures are not mirrored onto the sheet.
		var bench_tagged := false
		for node in m.find_children("*", "Node3D", true, false):
			if node.get_script() == SkaterScript and not node.is_in_group("skater_visuals"):
				for g in node.find_children("*", "GeometryInstance3D", true, false):
					if (g as GeometryInstance3D).layers & IceReflection.REFLECT_LAYER: bench_tagged = true
		check(not bench_tagged, "Bench figures stay off the reflection layer")
	# Thin AA coverage: the overlay alpha is the true width over the widened width.
	var shader_code: String = ThinAA.SHADER_CODE
	check(shader_code.find("coverage = half_width / (half_width + grow)") >= 0, "Stick overlay alpha is coverage")
	check(ThinAA.MIN_PIXELS >= 1.0 and ThinAA.MIN_PIXELS <= 2.5, "Minimum stick width ~1-2 px")
	# Kit shaders: overhead shading, distance detail fade, specular AA.
	var inc := FileAccess.get_file_as_string("res://assets/kit_detail.gdshaderinc")
	for fn in ["kit_overhead", "kit_detail_fade", "kit_spec_aa"]:
		check(inc.find("float %s(" % fn) >= 0, "kit_detail has %s" % fn)
	for path in ["res://assets/kit_cloth.gdshader", "res://assets/kit_gear.gdshader"]:
		var code := FileAccess.get_file_as_string(path)
		check(code.find("kit_overhead(") >= 0 and code.find("kit_spec_aa(") >= 0 and code.find("kit_detail_fade(") >= 0, "%s uses the gameplay-distance terms" % path)
	# Forward+ SSR trimmed now that the planar pass carries player reflections.
	var world_env: Environment = null
	for c in m.get_children():
		if c is WorldEnvironment: world_env = c.environment
	check(world_env != null and world_env.ssr_max_steps <= 48 and world_env.ssr_depth_tolerance <= 0.25, "SSR kept short and tight")
	m.queue_free()
	await process_frame
	print("Gameplay photo failures: %d" % failures)
	quit(failures)
