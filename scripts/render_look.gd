extends RefCounted
## Broadcast "look": tonemapping, colour grade, glow, screen-space effects,
## haze and the key-light shadow setup, in one place so lab.gd/match.gd only
## call configure_environment() / configure_key_light().
##
## Two renderers are targeted:
##  - Forward+ (what the game ships with): everything below applies, including
##    SSAO, SSIL, SSR on the ice and a thin volumetric haze in the upper bowl.
##  - gl_compatibility (OpenGL fallback): SSAO/SSIL/SSR/volumetric fog are
##    ignored by the renderer, so grounding there comes from contact_shadows.gd
##    and the depth/height fog, tonemap, glow and grade still apply.
## Anti-aliasing (MSAA 4x + SMAA, 16x anisotropic) lives in project.godot.

## AgX keeps saturated kit colours from skewing (ACES pushes reds to orange and
## blues to purple) and rolls bright ice off smoothly instead of clipping.
const TONEMAP := Environment.TONE_MAPPER_AGX
const EXPOSURE := 1.85
const AGX_WHITE := 6.0
const AGX_CONTRAST := 1.45

## Key light shadows: soft and close-range so the 4096 map gives players crisp
## contact under the skates. Bias values were tuned on the skater close-up: no
## acne on the jersey, no gap between skate and shadow.
const SHADOW_MAX_DISTANCE := 70.0
const SHADOW_BIAS := 0.03
const SHADOW_NORMAL_BIAS := 0.6
const SHADOW_BLUR := 1.6
const SHADOW_OPACITY := 0.85

static func configure_environment(env: Environment) -> void:
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#04070b")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	# Slightly warmer, lower ambient than before: the key light and pools carry
	# the image so shadows and form read instead of a flat, even wash.
	env.ambient_light_color = Color("#cad8e6")
	env.ambient_light_energy = 0.3
	env.tonemap_mode = TONEMAP
	env.tonemap_exposure = EXPOSURE
	env.tonemap_white = AGX_WHITE
	env.set("tonemap_agx_white", AGX_WHITE)
	env.set("tonemap_agx_contrast", AGX_CONTRAST)
	# Bloom: only true highlights (lamps, LED ribbons, specular on fresh ice)
	# bleed, softly; the ice body itself stays below the threshold.
	env.glow_enabled = true
	env.glow_normalized = false
	env.glow_intensity = 0.45
	env.glow_strength = 0.9
	env.glow_bloom = 0.02
	env.glow_hdr_threshold = 1.15
	env.glow_hdr_scale = 1.6
	for level in range(7):
		env.set_glow_level(level, [0.0, 0.0, 1.0, 0.8, 0.6, 0.3, 0.0][level])
	# Forward+ only: contact shading under players, bounce light from the
	# bright ice onto pants/gloves, and faint reflections in the polished ice.
	env.ssao_enabled = true
	env.ssao_radius = 0.7
	env.ssao_intensity = 1.6
	env.ssao_power = 1.4
	env.ssao_detail = 0.6
	env.ssao_light_affect = 0.15
	env.ssil_enabled = true
	env.ssil_radius = 2.0
	env.ssil_intensity = 0.6
	env.ssr_enabled = true
	env.ssr_max_steps = 56
	env.ssr_fade_in = 0.25
	env.ssr_fade_out = 2.5
	env.ssr_depth_tolerance = 0.25
	env.sdfgi_enabled = false   # costly; the arena is lit by analytic lights
	# Depth + height haze (both renderers): a breath of aerial perspective that
	# thickens up into the bowl so the far stands and rafters sit back.
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_light_color = Color("#1d2633")
	env.fog_light_energy = 1.0
	env.fog_density = 0.0045
	env.fog_aerial_perspective = 0.2
	env.fog_sky_affect = 0.0
	env.fog_height = 3.0
	env.fog_height_density = -0.03   # negative: denser with height
	# Forward+ volumetric fog: very thin, so the overhead pools show faint
	# shafts in the upper bowl. 64^3 froxels (default) is cheap.
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.0025
	env.volumetric_fog_albedo = Color("#d9e2ee")
	env.volumetric_fog_length = 70.0
	env.volumetric_fog_detail_spread = 2.0
	env.volumetric_fog_ambient_inject = 0.0
	env.volumetric_fog_sky_affect = 0.0
	# Colour grade: gentle contrast, a little extra saturation, and a split
	# tone LUT (cool highlights for the ice, warm mids/shadows for the bowl).
	env.adjustment_enabled = true
	env.adjustment_brightness = 1.0
	env.adjustment_contrast = 1.05
	env.adjustment_saturation = 1.08
	env.adjustment_color_correction = grade_lut()

## 17^3 3D LUT built in code (no asset): luminance-weighted split toning.
static func grade_lut(size: int = 17) -> ImageTexture3D:
	var images: Array[Image] = []
	for b in range(size):
		var img := Image.create(size, size, false, Image.FORMAT_RGB8)
		for g in range(size):
			for r in range(size):
				var c := Color(float(r) / (size - 1), float(g) / (size - 1), float(b) / (size - 1))
				img.set_pixel(r, g, grade(c))
		images.append(img)
	var tex := ImageTexture3D.new()
	tex.create(Image.FORMAT_RGB8, size, size, size, false, images)
	return tex

## The grade applied to one display-space colour (also used by tests).
static func grade(c: Color) -> Color:
	var l := c.r * 0.2126 + c.g * 0.7152 + c.b * 0.0722
	var high := smoothstep(0.55, 1.0, l)
	var low := 1.0 - smoothstep(0.05, 0.5, l)
	var mid := clampf(1.0 - high - low, 0.0, 1.0)
	# Warm the mids/shadows a touch, cool the highlights a touch.
	var warm := Vector3(0.018, 0.006, -0.016) * (mid + low * 0.6)
	var cool := Vector3(-0.03, -0.006, 0.026) * high
	return Color(clampf(c.r + warm.x + cool.x, 0, 1), clampf(c.g + warm.y + cool.y, 0, 1), clampf(c.b + warm.z + cool.z, 0, 1))

## Overhead key light: soft, close-range PSSM shadows.
static func configure_key_light(sun: DirectionalLight3D) -> void:
	sun.shadow_enabled = true
	sun.shadow_opacity = SHADOW_OPACITY
	sun.shadow_blur = SHADOW_BLUR
	sun.shadow_bias = SHADOW_BIAS
	sun.shadow_normal_bias = SHADOW_NORMAL_BIAS
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_blend_splits = true
	sun.directional_shadow_max_distance = SHADOW_MAX_DISTANCE
	sun.directional_shadow_fade_start = 0.85
	sun.light_angular_distance = 1.2   # penumbra widens away from contact (Forward+)

## True when running on the Forward+ (RenderingDevice) renderer.
static func is_forward_plus() -> bool:
	return RenderingServer.get_current_rendering_method() == "forward_plus"

## Upper-bowl haze volume for Forward+ volumetric fog. The OpenGL renderer
## rejects fog shaders, so there it returns a plain empty node.
static func make_bowl_haze() -> Node3D:
	if not is_forward_plus():
		var none := Node3D.new()
		none.name = "BowlHaze"
		return none
	var fog := FogVolume.new()
	fog.name = "BowlHaze"
	fog.shape = RenderingServer.FOG_VOLUME_SHAPE_BOX
	fog.size = Vector3(90, 18, 110)
	fog.position = Vector3(0, 16, 0)
	var mat := FogMaterial.new()
	mat.density = 0.02
	mat.albedo = Color("#dfe6f0")
	mat.height_falloff = 0.08
	mat.edge_fade = 0.4
	fog.material = mat
	return fog

## Optional camera attributes for replay/close cameras only (never gameplay):
## shallow far-field blur so the stands fall away behind a close subject.
static func close_camera_attributes(focus_distance: float) -> CameraAttributesPractical:
	var attr := CameraAttributesPractical.new()
	attr.dof_blur_far_enabled = true
	attr.dof_blur_far_distance = focus_distance + 6.0
	attr.dof_blur_far_transition = 12.0
	attr.dof_blur_amount = 0.06
	return attr

## Full-screen vignette below the HUD (layer 0; the broadcast HUD is layer 5).
static func make_vignette() -> CanvasLayer:
	var layer := CanvasLayer.new()
	layer.name = "Vignette"
	layer.layer = 0
	var rect := ColorRect.new()
	rect.name = "VignetteRect"
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = """shader_type canvas_item;
uniform float strength = 0.22;
void fragment(){
	vec2 p = UV * 2.0 - 1.0;
	p.x *= 1.25;
	float v = smoothstep(0.75, 1.75, length(p));
	COLOR = vec4(0.0, 0.01, 0.02, v * strength);
}"""
	var mat := ShaderMaterial.new()
	mat.shader = shader
	rect.material = mat
	layer.add_child(rect)
	return layer
