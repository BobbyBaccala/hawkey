shader_type spatial;
// Scanned face texture with a skin-tone multiplier, reduced saturation (the
// raw scan reads very red under arena light) and a little brightness lift.
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 tone : source_color = vec4(1.0);
uniform float saturation = 0.62;
uniform float lift = 1.12;
uniform float roughness = 0.62;

void fragment() {
	vec3 c = texture(albedo_tex, UV).rgb;
	float g = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(vec3(g), c, saturation) * lift;
	ALBEDO = c * tone.rgb;
	ROUGHNESS = roughness;
	SPECULAR = 0.25;
}
