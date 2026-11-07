shader_type spatial;
// Scanned face texture with a skin-tone multiplier, reduced saturation (the
// raw scan reads very red under arena light) and a little brightness lift.
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 tone : source_color = vec4(1.0);
uniform float saturation = 0.62;
uniform float lift = 1.12;
uniform float roughness = 0.62;
uniform vec4 hair_color : source_color = vec4(0.06, 0.045, 0.035, 1.0);


void fragment() {
	vec3 c = texture(albedo_tex, UV).rgb;
	float g = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(vec3(g), c, saturation) * lift;
	// Hair: vertex colour red marks the crown/back/sides of the skull (the
	// scan texture itself is bald).
	float hair = COLOR.r;
	ALBEDO = mix(c * tone.rgb, hair_color.rgb, hair * 0.92);
	ROUGHNESS = mix(roughness, 0.8, hair);
	SPECULAR = 0.25;
}
