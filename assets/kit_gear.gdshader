// Hockey equipment surfaces (breezers, socks, gloves, skates, helmet shell).
// Colour comes from the gear_builder vertex colours (or base_color), detail
// from a procedural tiling normal map applied triplanar in metric object
// space, so it stays glued to the moving piece and needs no UVs. Clearcoat,
// rim sheen and a small fake overhead-light reflection make paint, nylon and
// leather read differently; all of it degrades gracefully in gl_compatibility.
shader_type spatial;
render_mode cull_disabled;
#include "res://assets/kit_detail.gdshaderinc"

uniform vec4 base_color : source_color = vec4(1.0);
uniform bool use_vertex_color = true;
uniform sampler2D detail_tex : filter_linear_mipmap_anisotropic, repeat_enable;
uniform float detail_tiles = 40.0;
uniform float detail_strength = 0.6;
uniform float albedo_variation = 0.1;
uniform float roughness = 0.6;
uniform float specular = 0.4;
uniform float sheen = 0.0;
uniform float clearcoat = 0.0;
// Runner steel: light-grey vertex colours on a skate become polished metal.
uniform bool metal_from_grey = false;
// Helmet: moulded panel grooves on top and a rubber edge trim at the rim.
uniform bool helmet_panels = false;

// Socks: crisp knitted-in stripes along the unit-length limb shell (t = 0 at
// the knee, 1 at the ankle), matching Gear.sock()'s bands, instead of colours
// interpolated across its coarse rings.
uniform bool sock_stripes = false;
uniform vec4 sock_color : source_color = vec4(0.1, 0.3, 0.4, 1.0);
uniform vec4 sock_stripe : source_color = vec4(0.78, 0.8, 0.81, 1.0);

varying vec3 obj_pos;
varying vec3 obj_n;
varying float limb_t;

void vertex() {
	vec3 sc = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
	obj_pos = VERTEX * sc;
	obj_n = NORMAL;
	limb_t = -VERTEX.y;
}

vec3 srgb_to_linear(vec3 c) {
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
}

void fragment() {
	vec3 col = base_color.rgb;
	if (use_vertex_color) col *= OUTPUT_IS_SRGB ? COLOR.rgb : srgb_to_linear(COLOR.rgb);
	if (sock_stripes) {
		float aa = fwidth(limb_t) * 0.7 + 0.001;
		float s = smoothstep(0.30 - aa, 0.30 + aa, limb_t) - smoothstep(0.40 - aa, 0.40 + aa, limb_t);
		s += smoothstep(0.46 - aa, 0.46 + aa, limb_t) - smoothstep(0.51 - aa, 0.51 + aa, limb_t);
		col = mix(sock_color.rgb, sock_stripe.rgb, s);
	}
	float rough = roughness;
	float metal = 0.0;
	float coat = clearcoat;
	float strength = detail_strength;
	float groove = 0.0;
	if (metal_from_grey) {
		vec3 linear_col = OUTPUT_IS_SRGB ? srgb_to_linear(col) : col;
		float hi = max(linear_col.r, max(linear_col.g, linear_col.b));
		float lo = min(linear_col.r, min(linear_col.g, linear_col.b));
		// sRGB ~0.6-0.72 neutral grey = runner steel (holder plastic is lighter).
		metal = smoothstep(0.30, 0.34, lo) * (1.0 - smoothstep(0.50, 0.56, hi));
		// Plastic holder: smooth, semi-gloss, no leather grain.
		float holder = smoothstep(0.56, 0.62, hi);
		strength *= (1.0 - metal) * (1.0 - holder * 0.8);
		rough = mix(rough, 0.3, holder);
		coat *= 1.0 - holder;
	}
	if (helmet_panels) {
		vec3 p = obj_pos;
		// Two moulded ridges/grooves front to back over the crown.
		groove = (1.0 - smoothstep(0.0015, 0.0045, abs(abs(p.x) - 0.045))) * smoothstep(0.05, 0.085, p.y);
		// Seam between the front and back shells above the ears.
		groove = max(groove, (1.0 - smoothstep(0.0015, 0.004, abs(p.z + 0.015 + 0.05 * p.y))) * smoothstep(-0.01, 0.02, p.y) * step(0.06, abs(p.x)));
		col *= 1.0 - 0.45 * groove;
		// Rubber edge trim around the bottom of the shell.
		float trim = 1.0 - smoothstep(-0.026, -0.022, p.y);
		col = mix(col, vec3(0.012), trim);
		rough = mix(rough, 0.75, trim);
		coat *= 1.0 - trim;
		strength = mix(strength, 0.5, trim);
	}
	vec3 on = normalize(obj_n);
	vec4 t = kit_triplanar(detail_tex, obj_pos * detail_tiles, on, strength * kit_detail_fade(VERTEX));
	vec3 n = normalize((VIEW_MATRIX * vec4(MODEL_NORMAL_MATRIX * t.xyz, 0.0)).xyz);
	// Supplied normals point outward; light the side facing the camera.
	n = dot(n, VIEW) < -0.15 ? -n : n;
	if (helmet_panels) n = kit_bump(n, VERTEX, -groove * 0.0015);
	NORMAL = n;
	col *= mix(1.0 - albedo_variation, 1.0, t.w);
	float ndv = clamp(dot(n, VIEW), 0.0, 1.0);
	float fres = pow(1.0 - ndv, 4.0);
	col += (col + 0.03) * fres * sheen * 0.3;
	// Overhead arena key: lit tops, darker undersides (reads at distance).
	vec3 wn = normalize((INV_VIEW_MATRIX * vec4(n, 0.0)).xyz);
	float over = kit_overhead(wn);
	ALBEDO = mix(col, col * 1.25, metal) * over;
	AO = min(over, 1.0);
	METALLIC = metal;
	ROUGHNESS = kit_spec_aa(n, mix(rough, 0.16, metal));
	SPECULAR = specular;
	RIM = sheen * 0.35;
	RIM_TINT = 0.8;
	CLEARCOAT = coat;
	CLEARCOAT_ROUGHNESS = 0.08;
	// Overhead arena lights mirrored in glossy surfaces (paint, steel, coated
	// boots): a soft band where the reflection points up, strongest at grazing.
	vec3 r = (INV_VIEW_MATRIX * vec4(reflect(-VIEW, n), 0.0)).xyz;
	float sky = smoothstep(0.35, 0.95, r.y);
	EMISSION = vec3(0.85, 0.9, 1.0) * sky * (0.02 + 0.10 * fres) * (coat * 0.8 + metal * 1.5);
	// Polished steel also mirrors the bright white ice and boards around it.
	float ice = 1.0 - smoothstep(-0.05, 0.35, r.y);
	EMISSION += vec3(0.75, 0.8, 0.85) * metal * (0.25 + 0.35 * ice);
}
