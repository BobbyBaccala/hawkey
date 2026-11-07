extends SceneTree
## Render look: anti-aliasing, filmic tonemap/grade, soft key-light shadows,
## Forward+ screen-space effects, and a contact shadow under every skater,
## goalie and official (scripts/render_look.gd, scripts/contact_shadows.gd).
const RenderLook = preload("res://scripts/render_look.gd")
var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		push_error(message)
		failures += 1

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	# Anti-aliasing (project.godot): MSAA 4x for both renderers, SMAA in
	# Forward+, no TAA (smears the puck), 16x anisotropic for the markings.
	check(int(ProjectSettings.get_setting("rendering/anti_aliasing/quality/msaa_3d")) == Viewport.MSAA_4X, "MSAA 3D is 4x")
	check(int(ProjectSettings.get_setting("rendering/anti_aliasing/quality/screen_space_aa")) != Viewport.SCREEN_SPACE_AA_DISABLED, "Screen-space AA on")
	check(not bool(ProjectSettings.get_setting("rendering/anti_aliasing/quality/use_taa")), "TAA off")
	check(int(ProjectSettings.get_setting("rendering/textures/default_filters/anisotropic_filtering_level")) >= 3, "Anisotropic filtering at least 8x")
	check(int(ProjectSettings.get_setting("rendering/lights_and_shadows/directional_shadow/size")) >= 4096, "Directional shadow map >= 4096")
	check(int(ProjectSettings.get_setting("rendering/lights_and_shadows/directional_shadow/soft_shadow_filter_quality")) >= 2, "Soft shadow filter quality high")

	var m = load("res://main.tscn").instantiate()
	m.get_script().skip_title = true
	root.add_child(m)
	for i in range(4): await physics_frame
	await process_frame

	var world: WorldEnvironment = null
	var sun: DirectionalLight3D = null
	for c in m.get_children():
		if c is WorldEnvironment: world = c
		if c is DirectionalLight3D and sun == null: sun = c
	check(world != null and world.environment != null, "WorldEnvironment present")
	if world:
		var env := world.environment
		check(env.tonemap_mode in [Environment.TONE_MAPPER_AGX, Environment.TONE_MAPPER_ACES], "Filmic tonemapper (AgX/ACES)")
		check(env.tonemap_exposure > 1.0 and env.tonemap_exposure < 2.5, "Exposure tuned (%.2f)" % env.tonemap_exposure)
		check(env.glow_enabled and env.glow_hdr_threshold >= 1.0, "Glow only on highlights")
		check(env.ssao_enabled and env.ssil_enabled and env.ssr_enabled, "SSAO/SSIL/SSR on (Forward+)")
		check(not env.sdfgi_enabled, "SDFGI off")
		check(env.fog_enabled and env.fog_density < 0.01, "Light depth haze")
		check(env.adjustment_enabled and env.adjustment_color_correction != null, "Colour grade LUT set")
	# Grade: highlights cool (ice), mids warm (arena), and gentle.
	var ice := RenderLook.grade(Color(0.85, 0.86, 0.87))
	check(ice.b > ice.r, "Grade cools the ice")
	var mid := RenderLook.grade(Color(0.35, 0.35, 0.35))
	check(mid.r > mid.b, "Grade warms the mids")
	check(absf(mid.r - 0.35) < 0.05 and absf(ice.b - 0.87) < 0.05, "Grade is subtle")

	check(sun != null and sun.shadow_enabled, "Key light casts shadows")
	if sun:
		check(sun.shadow_opacity >= 0.7, "Shadows dark enough to ground players (%.2f)" % sun.shadow_opacity)
		check(sun.shadow_blur >= 1.0, "Soft shadow blur")
		check(sun.shadow_bias > 0.0 and sun.shadow_bias <= 0.06, "Shadow bias small (no peter-panning)")
		check(sun.shadow_normal_bias > 0.0 and sun.shadow_normal_bias <= 1.5, "Normal bias set (no acne)")
		check(sun.directional_shadow_mode == DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS, "4 PSSM splits")
		check(sun.directional_shadow_max_distance <= 80.0, "Shadow distance kept close for resolution")

	# Gameplay camera has no depth of field.
	var cam: Camera3D = m.camera
	var attr = cam.attributes
	check(attr == null or not (attr is CameraAttributesPractical and (attr.dof_blur_far_enabled or attr.dof_blur_near_enabled)), "No DOF on the gameplay camera")

	# Contact shadows: every skater visual in the match is tracked and drawn.
	var cs = m.get_node_or_null("ContactShadows")
	check(cs != null, "ContactShadows node exists")
	if cs:
		var visuals: Array = []
		for actor in m.skaters + m.goalkeepers: visuals.append(actor.get_child(1))
		visuals.append_array(m.referee_nodes)
		check(visuals.size() == 14, "10 skaters + 2 goalies + 2 officials (%d)" % visuals.size())
		var expected := 0
		for v in visuals:
			check(cs.tracked.has(v), "%s has a contact shadow" % v.get_parent().name)
			check(v.skates.size() == 2, "%s has two skates to ground" % v.get_parent().name)
			expected += cs.shadows_for(v)
		cs.refresh()
		check(cs.instance_count() == expected, "Body + skate shadows drawn for all (%d of %d)" % [cs.instance_count(), expected])
		# Each shadow sits just above the markings and under the player.
		var t: Transform3D = cs.blobs[0].xform
		check(t.origin.y > 0.027 and t.origin.y < 0.04, "Shadow just above the paint (%.3f)" % t.origin.y)
		check(cs.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "Contact shadows cast no shadows")
		# A skater added later (e.g. a capture tool) is picked up too.
		var extra = load("res://scripts/skater_visual.gd").new()
		m.add_child(extra)
		await process_frame
		check(cs.tracked.has(extra), "Late-added skater gets a contact shadow")
		# A lifted skate's streak fades.
		extra.skates[0].global_position.y = 0.4
		cs.refresh()
		var lifted := -1.0
		var planted := -1.0
		for b in cs.blobs:
			if b.visual == extra and b.hardness < 0.5: lifted = b.strength
			if b.visual == extra and b.hardness > 0.5: planted = b.strength
		check(lifted >= 0.0 and lifted < 0.1, "Lifted skate shadow fades (%.2f)" % lifted)
		check(planted > 0.5, "Planted skate shadow is dark (%.2f)" % planted)
		var before: int = cs.tracked.size()
		extra.queue_free()
		await process_frame
		check(cs.tracked.size() == before - 1, "Freed skater is dropped")
	print("Render settings failures: ", failures)
	quit(failures)
