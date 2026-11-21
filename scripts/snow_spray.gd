extends Node3D
## Hockey-stop snow spray from one skate blade: a quick, low fan of fine ice
## shavings thrown ahead along the direction of travel, plus a faint haze of
## finer snow that hangs a moment longer. Particles live in world space so the
## spray stays where it was thrown while the skater slides on. CPU particles
## so it renders the same on the gl_compatibility renderer.
## The node is top-level: skater_visual.gd places it on the blade each frame
## with -Z pointing along the direction of travel.

var shavings: CPUParticles3D
var haze: CPUParticles3D
## 0..1 strength (speed of the stop); scales throw speed and opacity.
var strength := 1.0

static var dot_texture: Texture2D

static func soft_dot() -> Texture2D:
	if dot_texture == null:
		var gradient := Gradient.new()
		gradient.set_color(0, Color(1, 1, 1, 1))
		gradient.set_color(1, Color(1, 1, 1, 0))
		gradient.add_point(0.45, Color(1, 1, 1, 0.75))
		var texture := GradientTexture2D.new()
		texture.gradient = gradient
		texture.fill = GradientTexture2D.FILL_RADIAL
		texture.fill_from = Vector2(0.5, 0.5)
		texture.fill_to = Vector2(1.0, 0.5)
		texture.width = 32
		texture.height = 32
		dot_texture = texture
	return dot_texture

static func particle_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	# Plain billboard keeping the particle scale (BILLBOARD_PARTICLES draws
	# not-yet-born particles as black discs on the compatibility renderer).
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.billboard_keep_scale = true
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = soft_dot()
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.disable_receive_shadows = true
	return m

static func tint(a: Color, b: Color) -> Gradient:
	var g := Gradient.new()
	g.set_color(0, a)
	g.set_color(1, b)
	return g

static func fade(peak: float) -> Gradient:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 0))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.08, Color(1, 1, 1, peak))
	g.add_point(0.55, Color(1, 1, 1, peak * 0.7))
	return g

func make(amount: int, size: float, lifetime_: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(size, size)
	quad.material = particle_material()
	p.mesh = quad
	p.amount = amount
	p.lifetime = lifetime_
	p.lifetime_randomness = 0.45
	p.local_coords = false
	p.emitting = false
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# The blade lies across the direction of travel (emitter X).
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(0.12, 0.005, 0.02)
	p.direction = Vector3(0, 0.26, -1)
	p.custom_aabb = AABB(Vector3(-3, -1, -4), Vector3(6, 3, 6))
	add_child(p)
	return p

func _ready() -> void:
	top_level = true
	# Fine shavings: tiny, many, fast, low; they skid to a stop and fade.
	shavings = make(900, 0.026, 0.5)
	shavings.spread = 40.0
	shavings.flatness = 0.62
	shavings.initial_velocity_min = 1.6
	shavings.initial_velocity_max = 5.2
	shavings.damping_min = 9.0
	shavings.damping_max = 14.0
	shavings.gravity = Vector3(0, -7.5, 0)
	shavings.scale_amount_min = 0.45
	shavings.scale_amount_max = 1.5
	shavings.color = Color(1, 1, 1, 1)
	shavings.color_ramp = fade(0.9)
	# Some shavings catch the light, others read slightly blue-grey against
	# the white sheet.
	shavings.color_initial_ramp = tint(Color(0.62, 0.68, 0.78), Color(1, 1, 1))
	# Haze of finer snow: a few soft, faint puffs that drift and settle.
	haze = make(56, 0.2, 0.8)
	haze.spread = 40.0
	haze.flatness = 0.85
	haze.initial_velocity_min = 0.6
	haze.initial_velocity_max = 2.2
	haze.damping_min = 5.0
	haze.damping_max = 8.0
	haze.gravity = Vector3(0, -0.6, 0)
	haze.scale_amount_min = 0.6
	haze.scale_amount_max = 1.6
	haze.color = Color(1, 1, 1, 1)
	haze.color_ramp = fade(0.45)
	haze.color_initial_ramp = tint(Color(0.74, 0.80, 0.88), Color(0.93, 0.96, 1.0))

## Starts or stops throwing snow; strength 0..1 (how hard the stop is) and
## the skater's speed: shavings leave the blade carrying the skater's own
## momentum plus the throw, so the fan lands ahead of him, not behind.
func spray(on: bool, strength_: float, skater_speed := 0.0) -> void:
	strength = clampf(strength_, 0.0, 1.0)
	if on:
		shavings.initial_velocity_min = skater_speed * 0.8 + 0.4
		shavings.initial_velocity_max = skater_speed * 1.2 + lerpf(1.5, 3.5, strength)
		haze.initial_velocity_min = skater_speed * 0.6 + 0.2
		haze.initial_velocity_max = skater_speed * 0.9 + 1.0
		shavings.color.a = lerpf(0.45, 1.0, strength)
		haze.color.a = lerpf(0.4, 1.0, strength)
	shavings.emitting = on
	haze.emitting = on

func is_spraying() -> bool:
	return shavings.emitting
