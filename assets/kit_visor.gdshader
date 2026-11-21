// Clear polycarbonate visor: nearly invisible face-on, mirror-like at grazing
// angles (Fresnel), with a soft reflection of the overhead arena lights and
// a faint blue-grey tint. No screen texture reads, so it works the same in
// gl_compatibility and Forward+.
shader_type spatial;
render_mode cull_disabled, depth_draw_opaque, blend_mix;

uniform vec4 tint : source_color = vec4(0.62, 0.74, 0.8, 1.0);

void fragment() {
	// Clamped: |dot| can land a hair above 1.0, and pow() of the resulting
	// negative base is NaN on some Vulkan drivers - a NaN pixel blooms into a
	// white blob over the whole helmet in Forward+.
	float ndv = clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0);
	float fres = 0.04 + 0.96 * pow(1.0 - ndv, 5.0);
	vec3 r = (INV_VIEW_MATRIX * vec4(reflect(-VIEW, NORMAL), 0.0)).xyz;
	float lights = smoothstep(0.25, 0.9, r.y);
	float hy = r.y / 0.12;
	float horizon = exp(-hy * hy);
	ALBEDO = tint.rgb * 0.15;
	ROUGHNESS = 0.04;
	SPECULAR = 0.9;
	vec3 e = (vec3(0.9, 0.95, 1.0) * lights * 0.6 + vec3(0.35, 0.4, 0.5) * horizon * 0.3) * fres + tint.rgb * 0.01;
	EMISSION = any(isnan(e)) ? vec3(0.0) : e;
	float a = 0.10 + fres * 0.9 + lights * 0.06;
	ALPHA = isnan(a) ? 0.1 : clamp(a, 0.0, 0.85);
}
