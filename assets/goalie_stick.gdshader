shader_type spatial;
// Goalie stick: the baked de-branded texture (white paddle and shaft, black
// blade) plus team graphics painted on the light parts of the paddle in object
// space - a two-tone paddle: kit upper paddle under the blocker edged with an
// accent pinstripe, white below, and a kit band at the heel.
// The source mesh is modelled at 1/12 scale: the paddle runs from y 0.001 to
// 0.050, the shaft above it, the blade below 0.
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic;
uniform vec4 kit : source_color = vec4(0.7, 0.08, 0.17, 1.0);
uniform vec4 accent : source_color = vec4(0.1, 0.16, 0.29, 1.0);
uniform float roughness_v = 0.45;
varying vec3 op;

void vertex() {
	op = VERTEX;
}

float band(float x, float a, float b, float aa) {
	return smoothstep(a - aa, a + aa, x) - smoothstep(b - aa, b + aa, x);
}

void fragment() {
	vec3 base = texture(albedo_tex, UV).rgb;
	float light = smoothstep(0.35, 0.55, dot(base, vec3(0.333)));
	float y = op.y;
	float paddle = band(y, 0.0015, 0.0495, 0.0003);
	float aa = max(fwidth(y), 0.00008);
	// Two-tone paddle: kit upper paddle (under the blocker) edged with an
	// accent pinstripe, white below, and a kit band at the heel.
	float upper = band(y, 0.0330, 0.0495, aa);
	float pin = band(y, 0.0312, 0.0322, aa);
	float heel = band(y, 0.0018, 0.0048, aa);
	float k = max(upper, heel) * paddle * light;
	vec3 col = mix(base, kit.rgb, k);
	col = mix(col, accent.rgb, pin * paddle * light);
	ALBEDO = any(isnan(col)) ? base : col;
	ROUGHNESS = roughness_v;
	SPECULAR = 0.4;
}
