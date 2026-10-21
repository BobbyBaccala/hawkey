// Original eye material for the existing CC0 eye meshes; no likeness/texture imported.
shader_type spatial;
render_mode cull_disabled;
uniform vec4 sclera : source_color = vec4(0.50, 0.48, 0.45, 1.0);
uniform vec4 iris_color : source_color = vec4(0.17, 0.12, 0.08, 1.0);
varying vec2 eye_uv;
varying float eye_depth;
void vertex() { eye_uv = UV; eye_depth = UV2.x; }
void fragment() {
	vec2 p = eye_uv;
	float r = length(p);
	float aa = max(fwidth(r), 0.00008);
	float front = smoothstep(0.134, 0.140, eye_depth);
	float iris = (1.0 - smoothstep(0.0055 - aa, 0.0055 + aa, r)) * front;
	float pupil = (1.0 - smoothstep(0.0022 - aa, 0.0022 + aa, r)) * front;
	float fibres = 0.85 + 0.15 * sin(atan(p.y, p.x) * 43.0 + r * 1400.0);
	float limbal = smoothstep(0.0044, 0.0055, r);
	vec3 color = mix(sclera.rgb, iris_color.rgb * fibres * mix(1.0, 0.45, limbal), iris);
	ALBEDO = mix(color, vec3(0.008), pupil);
	ROUGHNESS = 0.19;
	SPECULAR = 0.5;
	CLEARCOAT = 0.35;
	CLEARCOAT_ROUGHNESS = 0.1;
}
