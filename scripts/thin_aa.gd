extends RefCounted
## Thin-geometry anti-aliasing for sticks at gameplay distance.
##
## A 1.8 cm shaft or 9 mm blade is under a pixel wide from 15-25 m, so MSAA
## alone draws it as a dotted, crawling line in motion. A material_overlay
## pass re-draws the piece pushed out along its normals to a minimum on-screen
## width, with alpha = how much of that widened pixel strip the real stick
## would cover. The result is a continuous, soft, correctly weighted line, as
## a camera lens would record it. Up close (wider than the minimum) the pass
## adds nothing visible.
##
## It is an overlay, so it never touches the stick's own material or mesh
## (skater_visual.gd / gear_builder.gd own those); apply() is idempotent.

## Minimum on-screen width of a stick, in pixels.
const MIN_PIXELS := 1.6
const SHAFT_HALF_WIDTH := 0.0065
const BLADE_HALF_WIDTH := 0.0045

const SHADER_CODE := """shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back, skip_vertex_transform, shadows_disabled;
uniform vec4 color : source_color = vec4(0.09, 0.12, 0.16, 1.0);
uniform float half_width = 0.0065;
uniform float min_pixels = 1.6;
uniform float roughness = 0.5;
varying float coverage;
void vertex() {
	vec3 v = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 n = normalize((MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	// World size of one pixel at this depth (perspective projection).
	float px = max(-v.z, 0.05) * 2.0 / (PROJECTION_MATRIX[1][1] * VIEWPORT_SIZE.y);
	float grow = max(0.0, 0.5 * min_pixels * px - half_width);
	VERTEX = v + n * grow;
	NORMAL = n;
	coverage = half_width / (half_width + grow);
}
void fragment() {
	ALBEDO = color.rgb;
	ROUGHNESS = roughness;
	SPECULAR = 0.3;
	ALPHA = coverage;
}
"""

static var _shader: Shader

static func shader() -> Shader:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER_CODE
	return _shader

static func overlay_for(piece: GeometryInstance3D, half_width: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = shader()
	var c := Color(0.09, 0.12, 0.16)
	var src: Material = piece.material_override
	if src == null and piece is MeshInstance3D and (piece as MeshInstance3D).mesh and (piece as MeshInstance3D).mesh.get_surface_count() > 0:
		src = (piece as MeshInstance3D).mesh.surface_get_material(0)
	if src is BaseMaterial3D:
		c = (src as BaseMaterial3D).albedo_color
		m.set_shader_parameter("roughness", (src as BaseMaterial3D).roughness)
	m.set_shader_parameter("color", c)
	m.set_shader_parameter("half_width", half_width)
	m.set_shader_parameter("min_pixels", MIN_PIXELS)
	return m

## Gives a skater visual's stick shaft and blade the minimum-width overlay.
static func apply(visual: Node) -> void:
	for pair in [["stick_shaft", SHAFT_HALF_WIDTH], ["stick_blade", BLADE_HALF_WIDTH]]:
		var piece = visual.get(pair[0])
		if is_instance_valid(piece) and piece is GeometryInstance3D and not piece.has_meta("thin_aa") and piece.material_overlay == null:
			piece.material_overlay = overlay_for(piece, pair[1])
			piece.set_meta("thin_aa", true)
