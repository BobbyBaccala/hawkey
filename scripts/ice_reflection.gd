extends Node3D
## Players mirrored in the polished ice, as in broadcast hockey photos: a
## soft, darker, slightly blurred copy of each skater directly under him.
##
## A low-resolution SubViewport shares the game world and renders only the
## skaters (render layer REFLECT_LAYER) from the main camera mirrored through
## the ice plane, with a stripped-down environment (no glow, fog, SSAO/SSIL/
## SSR, no positional shadows) and no MSAA. The ice shader (arena.gd) samples
## it by screen position, blurs it vertically and blends it in as a Fresnel-
## weighted reflection that fades where the ice is cut up.
##
## Works in both renderers. In Forward+ SSR also reflects players on the ice,
## so the planar term is weaker there (FORWARD_PLUS_STRENGTH) to avoid a
## doubled-up mirror image; in gl_compatibility (no SSR) it is the only one.
##
## Skater visuals are picked up from the "skater_visuals" group (bench
## figures leave it, so they are never mirrored onto the sheet).

## Render layer 20: only the mirror camera filters on it; the gameplay cameras
## render all 20 layers, so tagging changes nothing for them.
const REFLECT_LAYER := 1 << 19
const ThinAA = preload("res://scripts/thin_aa.gd")
## Mirror image resolution relative to the main viewport. The image is blurred
## anyway, so a third of the size is plenty and keeps the cost low.
const RESOLUTION_SCALE := 0.4
## Reflection strength on clean ice (multiplied by Fresnel and ice wear).
const STRENGTH := 0.42
const FORWARD_PLUS_STRENGTH := 0.26
## Vertical blur (fraction of screen height per tap) - reflections in real
## ice smear along the view direction.
const BLUR := 0.0028
const RETAG_INTERVAL := 0.5
## Ambient boost in the mirror pass standing in for light bounced off the ice.
const UNDERSIDE_BOUNCE := 6.0
## Mirror pass exposure: undersides seen in the ice keep their kit colour (a
## blue sweater leaves a blue smear) rather than a neutral grey ghost.
const MIRROR_EXPOSURE := 2.2

var viewport: SubViewport
var mirror: Camera3D
var ice_material: ShaderMaterial
var tagged: Array[Node3D] = []
var _retag_timer := 0.0

func _init() -> void:
	name = "IceReflection"
	process_priority = 1000   # after cameras have moved this frame

func _ready() -> void:
	viewport = SubViewport.new()
	viewport.name = "MirrorView"
	viewport.transparent_bg = true
	viewport.msaa_3d = Viewport.MSAA_DISABLED
	viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	viewport.use_taa = false
	viewport.positional_shadow_atlas_size = 0
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.audio_listener_enable_3d = false
	viewport.size = Vector2i(64, 64)
	add_child(viewport)
	mirror = Camera3D.new()
	mirror.name = "MirrorCamera"
	mirror.cull_mask = REFLECT_LAYER
	mirror.environment = mirror_environment()
	viewport.add_child(mirror)
	mirror.current = true

## Lean environment for the mirror pass: same ambient as the arena, linear
## tonemap (the ice shader adds the result as radiance), nothing screen-space.
static func mirror_environment(source: Environment = null) -> Environment:
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = source.ambient_light_color if source else Color("#cad8e6")
	# The undersides the ice sees are lit by bounce off the white sheet itself:
	# lift the ambient so the mirrored kit keeps its colours instead of going
	# a flat grey.
	env.ambient_light_energy = (source.ambient_light_energy if source else 0.3) * UNDERSIDE_BOUNCE
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.tonemap_exposure = MIRROR_EXPOSURE
	env.glow_enabled = false
	env.fog_enabled = false
	env.volumetric_fog_enabled = false
	env.ssao_enabled = false
	env.ssil_enabled = false
	env.ssr_enabled = false
	env.sdfgi_enabled = false
	env.adjustment_enabled = false
	return env

## Hands the mirror image to the ice sheet and painted markings (called by
## lab.gd once the arena exists). `target` is the Arena (set_reflection()) or
## a single ShaderMaterial.
func attach(target: Object, world_env: Environment = null) -> void:
	if world_env: mirror.environment = mirror_environment(world_env)
	if target is ShaderMaterial:
		ice_material = target
		ice_material.set_shader_parameter("reflection_tex", viewport.get_texture())
		ice_material.set_shader_parameter("reflection_strength", strength())
		ice_material.set_shader_parameter("reflection_blur", BLUR)
	elif target != null and target.has_method("set_reflection"):
		ice_material = target.ice_surface_material
		target.set_reflection(viewport.get_texture(), strength(), BLUR)

static func strength() -> float:
	return FORWARD_PLUS_STRENGTH if RenderingServer.get_current_rendering_method() == "forward_plus" else STRENGTH

## The camera mirrored through the ice plane (y = 0). A true mirror is an
## improper transform; flipping the camera's own x axis keeps it a rotation,
## and the ice shader undoes that flip by sampling at 1 - SCREEN_UV.x.
static func mirrored(t: Transform3D) -> Transform3D:
	var m := Basis(Vector3(1, 0, 0), Vector3(0, -1, 0), Vector3(0, 0, 1))
	var b := m * t.basis
	b.x = -b.x
	return Transform3D(b, Vector3(t.origin.x, -t.origin.y, t.origin.z))

func _process(delta: float) -> void:
	_retag_timer -= delta
	if _retag_timer <= 0.0:
		_retag_timer = RETAG_INTERVAL
		retag()
	sync_camera()

func sync_camera() -> void:
	var main_vp := get_viewport()
	var cam := main_vp.get_camera_3d() if main_vp else null
	if cam == null or cam == mirror: return
	var size := Vector2i((Vector2(main_vp.get_visible_rect().size) * RESOLUTION_SCALE).round())
	size = size.max(Vector2i(16, 16))
	if viewport.size != size: viewport.size = size
	mirror.projection = cam.projection
	mirror.fov = cam.fov
	mirror.size = cam.size
	mirror.keep_aspect = cam.keep_aspect
	mirror.near = cam.near
	mirror.far = cam.far
	mirror.h_offset = -cam.h_offset
	mirror.v_offset = cam.v_offset
	mirror.global_transform = mirrored(cam.global_transform)

## Puts every on-ice skater's meshes (body, kit, gear, stick) on the mirror
## layer and takes bench figures off it.
func retag() -> void:
	var live: Array[Node3D] = []
	for v in get_tree().get_nodes_in_group("skater_visuals"):
		if v is Node3D and v.is_inside_tree():
			live.append(v)
			_set_layer(v, true)
			# Sticks: minimum-width coverage overlay (scripts/thin_aa.gd).
			ThinAA.apply(v)
	for v in tagged:
		if is_instance_valid(v) and not live.has(v):
			_set_layer(v, false)
	tagged = live

static func _set_layer(root: Node, on: bool) -> void:
	for g in root.find_children("*", "GeometryInstance3D", true, false):
		var gi := g as GeometryInstance3D
		# Contact-shadow style decals and particles stay out of the mirror.
		if gi is GPUParticles3D or gi is CPUParticles3D: continue
		gi.layers = (gi.layers | REFLECT_LAYER) if on else (gi.layers & ~REFLECT_LAYER)
