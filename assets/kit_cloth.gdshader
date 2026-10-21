// Polyester hockey sweater: dimple-mesh knit normal + cavity tint, soft cloth
// folds, fabric sheen (rim) and ambient-occlusion-like darkening at the hem,
// under the arms and below the collar. Sewn-on hem/sleeve stripes and tackle
// twill numbers and nameplate are drawn in the fabric from signed distance
// fields (scripts/kit_materials.gd), so they bend, shade and wrinkle with it.
// garment: 0 plain panel, 1 jersey body, 2 sleeve, 3 referee body.
// Jersey: UV (u mirrored 0 front .. 1 back) maps the knit; UV2 (u 0..1 round
// the torso, 0.75 = centre back; v = rest height in m) places stripes and twill.
// Sleeve UVs: u around the arm, v 0 at the shoulder .. 1 at the wrist.
shader_type spatial;
render_mode cull_disabled;
#include "res://assets/kit_detail.gdshaderinc"

uniform vec4 kit : source_color = vec4(0.07, 0.36, 0.45, 1.0);
uniform vec4 stripe_color : source_color = vec4(0.03, 0.15, 0.2, 1.0);
uniform vec4 trim_color : source_color = vec4(0.91, 0.92, 0.9, 1.0);
uniform int garment = 0;
uniform bool use_uv = true;
uniform vec2 uv_metres = vec2(1.55, 1.0);
uniform sampler2D knit_tex : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D fold_tex : filter_linear_mipmap_anisotropic, repeat_enable;
uniform float knit_tiles = 42.0;
uniform float knit_strength = 0.85;
uniform float fold_tiles = 1.7;
uniform float fold_strength = 0.30;
uniform float cavity_tint = 0.16;
uniform float roughness = 0.84;
uniform float sheen = 0.35;
// Jersey layout (metres up the body).
uniform float hem_v = 0.865;
uniform float collar_v = 0.0;
// Shared jersey_profile.gd values supplied by the material factory.
uniform vec4 collar_profile = vec4(1.56,0.032,0.008,4.0);
uniform float collar_band_width = 0.012;
uniform float metres_per_u = 1.65;
uniform bool show_number = false;
uniform sampler2D number_tex : filter_linear_mipmap, repeat_disable, hint_default_black;
uniform float number_aspect = 1.6;
uniform float number_height = 0.384;
uniform float number_top = 1.432;
uniform bool show_name = false;
uniform sampler2D name_tex : filter_linear_mipmap, repeat_disable, hint_default_black;
uniform float name_aspect = 4.0;
uniform float name_height = 0.08;
uniform float name_top = 1.452;

varying vec3 obj_pos;
varying vec3 obj_n;

void vertex() {
	vec3 sc = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
	obj_pos = VERTEX * sc;
	obj_n = NORMAL;
}

float band(float x, float a, float b, float aa) {
	return smoothstep(a - aa, a + aa, x) - smoothstep(b - aa, b + aa, x);
}

// Sewn stripe stack starting at `at` along coordinate x (metres): thin trim,
// wide colour, thin trim, gap, narrow colour. Returns (trim, colour, seam).
vec3 stripes(float x, float at, float aa) {
	float t1 = band(x, at, at + 0.008, aa);
	float c1 = band(x, at + 0.008, at + 0.046, aa);
	float t2 = band(x, at + 0.046, at + 0.054, aa);
	float c2 = band(x, at + 0.070, at + 0.084, aa);
	float seam = 0.0;
	for (int k = 0; k < 6; k++) {
		float e = at + (k == 0 ? 0.0 : k == 1 ? 0.008 : k == 2 ? 0.046 : k == 3 ? 0.054 : k == 4 ? 0.070 : 0.084);
		seam = max(seam, 1.0 - smoothstep(0.0, 0.0012 + aa, abs(x - e)));
	}
	return vec3(t1 + t2, c1 + c2, seam);
}

// Twill letter from an SDF texture: returns (fill, outline, stitch) masks.
vec3 twill(sampler2D tex, vec2 t, float bold, float outline) {
	float inside = step(0.0, t.x) * step(t.x, 1.0) * step(0.0, t.y) * step(t.y, 1.0);
	float s = texture(tex, clamp(t, vec2(0.001), vec2(0.999))).r;
	float d = (0.5 - s) * 16.0; // pixels of the 64 px glyph cell, + outside
	float aa = clamp(fwidth(d), 0.05, 4.0) * 0.75;
	// bold > 0 grows the letter (the SDF is of the font's own weight).
	float fill = 1.0 - smoothstep(-aa, aa, d - bold);
	float outl = outline > 0.0 ? 1.0 - smoothstep(-aa, aa, d - bold - outline) : fill;
	float edge = outline > 0.0 ? bold + outline - 1.0 : bold - 1.0;
	float stitch = 1.0 - smoothstep(0.25, 0.25 + aa, abs(d - edge));
	return vec3(fill, outl, stitch) * inside;
}

void fragment() {
	vec3 col = kit.rgb;
	vec2 m = UV * uv_metres;
	float ao = 1.0;
	float rough = roughness;
	float height = 0.0;
	float twill_mask = 0.0;
	float fold_amt = fold_strength;
	float aa_v = fwidth(UV.y) * 0.6;
	// Recover the mesh's own (outward) normal whatever the triangle winding,
	// then tell the outside of the garment from the inside (seen through the
	// collar or hem) by which way it faces the camera.
	vec3 n0 = FRONT_FACING ? NORMAL : -NORMAL;
	bool outside = dot(n0, VIEW) > -0.15;
	vec3 base_n = outside ? n0 : -n0;
	if (garment == 1) {
		// Layout in UV2: u = angle round the body (0.75 = centre back), v = rest
		// height (m). UV (mirrored front/back) only drives the knit detail.
		vec2 L = UV2;
		float aa_l = fwidth(L.y) * 0.6;
		// Hem: double-stitched turn-up, then the sewn stripe stack.
		vec3 s = stripes(L.y, hem_v + 0.06, aa_l);
		col = mix(col, trim_color.rgb, s.x);
		col = mix(col, stripe_color.rgb, s.y);
		height += (s.x + s.y) * 0.0005 - s.z * 0.0006;
		col *= 1.0 - 0.25 * (1.0 - smoothstep(0.0012, 0.0025 + aa_l, abs(L.y - hem_v - 0.014)));
		ao *= mix(0.72, 1.0, smoothstep(hem_v, hem_v + 0.05, L.y));
		// Collar: trim band along the neckline (V at the front, as
		// skater_visual.gd jersey_neck(); collar_v > 0 gives a flat collar).
		// Mirrored UV.x is the original mesh angle (front=0, back=1),
		// unlike UV2.x, whose atan2 is distorted by the torso ellipse.
		float front = max(0.0, cos(PI * UV.x));
		float edge = collar_profile.x - collar_profile.y * pow(front,collar_profile.w) - collar_profile.z * front;
		float neck = (collar_v > 0.0 ? collar_v : edge) - collar_band_width;
		float collar = smoothstep(neck - aa_l, neck + aa_l, L.y);
		col = mix(col, stripe_color.rgb, collar);
		ao *= mix(1.0, 0.85, smoothstep(neck - 0.04, neck + 0.02, L.y));
		// Under the arms: the sides of the upper torso sit in shadow.
		float side = pow(abs(cos(TAU * L.x)), 6.0);
		ao *= 1.0 - 0.30 * side * smoothstep(1.16, 1.30, L.y) * (1.0 - smoothstep(1.40, 1.46, L.y));
		// The sweater bunches over the pants at the waist.
		fold_amt *= 1.0 + 1.4 * (1.0 - smoothstep(hem_v + 0.05, hem_v + 0.2, L.y));
		// The inside of the sweater: no twill, and in shadow.
		if (!outside) ao *= 0.45;
		// Number and nameplate: tackle twill sewn on the back.
		if (show_number && outside) {
			vec2 t = vec2(0.5 - (L.x - 0.75) * metres_per_u / (number_height * number_aspect), (number_top - L.y) / number_height);
			vec3 n = twill(number_tex, t, 1.2, 2.6);
			col = mix(col, stripe_color.rgb * 0.8, n.y);
			col = mix(col, trim_color.rgb, n.x);
			col *= 1.0 - 0.22 * n.z;
			height += (n.y * 0.5 + n.x * 0.6) * 0.0015 - n.z * 0.0005;
			twill_mask = max(twill_mask, n.y);
		}
		if (show_name && outside) {
			vec2 t = vec2(0.5 - (L.x - 0.75) * metres_per_u / (name_height * name_aspect), (name_top - L.y) / name_height);
			vec3 n = twill(name_tex, t, 0.5, 0.0);
			col = mix(col, trim_color.rgb, n.x);
			height += n.x * 0.0009;
			twill_mask = max(twill_mask, n.x);
		}
	} else if (garment == 2) {
		float aa_t = fwidth(UV.y) * 0.6;
		vec3 s = stripes(UV.y * 0.58, 0.58 * 0.60, aa_t * 0.58);
		col = mix(col, trim_color.rgb, s.x);
		col = mix(col, stripe_color.rgb, s.y);
		height += (s.x + s.y) * 0.0005 - s.z * 0.0006;
		// Ribbed cuff at the wrist.
		float cuff = smoothstep(0.93, 0.935, UV.y);
		col = mix(col, col * 0.82, cuff);
		ao *= mix(0.78, 1.0, smoothstep(0.0, 0.12, UV.y));
		ao *= mix(1.0, 0.8, smoothstep(0.95, 1.0, UV.y));
		// Wrinkles gather at the elbow.
		fold_amt *= 1.0 + 1.6 * exp(-pow((UV.y - 0.5) / 0.12, 2.0));
	} else if (garment == 3) {
		float x = sin(UV.x * 62.83);
		float w = fwidth(x) + 0.001;
		col = mix(vec3(0.015), vec3(0.7), smoothstep(-w, w, x));
	}
	vec3 n;
	float cavity;
	if (use_uv) {
		vec4 k = texture(knit_tex, m * knit_tiles);
		vec4 f = texture(fold_tex, m * fold_tiles);
		float ks = knit_strength * (1.0 - 0.7 * twill_mask);
		vec2 d = (k.rg * 2.0 - 1.0) * ks + (f.rg * 2.0 - 1.0) * fold_amt;
		n = kit_perturb_uv(base_n, VERTEX, m, normalize(vec3(d, 1.0)));
		cavity = mix(k.a, 1.0, twill_mask * 0.7);
		ao *= mix(0.86, 1.0, f.a);
		n = kit_bump(n, VERTEX, height);
	} else {
		vec4 t = kit_triplanar(knit_tex, obj_pos * knit_tiles, normalize(obj_n), knit_strength);
		n = normalize((VIEW_MATRIX * vec4(MODEL_NORMAL_MATRIX * t.xyz, 0.0)).xyz);
		n = dot(n, VIEW) < -0.15 ? -n : n;
		cavity = t.w;
	}
	NORMAL = n;
	col *= mix(1.0 - cavity_tint, 1.0, cavity);
	// Velvet-like fabric sheen at grazing angles (ambient part; RIM below
	// adds the light-driven part).
	float fres = pow(1.0 - clamp(dot(n, VIEW), 0.0, 1.0), 3.0);
	col += (col + 0.03) * fres * sheen * 0.3;
	ALBEDO = col * ao;
	AO = ao;
	ROUGHNESS = mix(rough, 0.62, twill_mask);
	SPECULAR = mix(0.22, 0.35, twill_mask);
	RIM = sheen * 0.3;
	RIM_TINT = 0.8;
	BACKLIGHT = vec3(0.04) * kit.rgb;
}
