shader_type spatial;
// Scanned face texture with a skin-tone multiplier, reduced saturation (the
// raw scan reads very red under arena light) and a little brightness lift.
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 tone : source_color = vec4(1.0);
uniform float saturation = 0.62;
uniform float lift = 1.12;
uniform float roughness = 0.62;
uniform vec4 hair_color : source_color = vec4(0.06, 0.045, 0.035, 1.0);


// Goalies: the ears would poke through the mask's back plate.
uniform bool hide_ears = false;

void fragment() {
	if (hide_ears && COLOR.a < 0.5) discard;
	vec3 c = texture(albedo_tex, UV).rgb;
	float g = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(vec3(g), c, saturation) * lift;
	// Hair: vertex colour red marks the crown/back/sides of the skull (the
	// scan texture itself is bald).
	float hair = COLOR.r;
	// Green: hair that sits under the helmet reads as a dark liner.
	vec3 hc = mix(hair_color.rgb, vec3(0.012, 0.012, 0.014), COLOR.g * 0.94);
	ALBEDO = mix(c * tone.rgb, hc, hair * 0.95);
	// Blue: under-helmet skin (top of the forehead) is in the liner's shadow.
	ALBEDO = mix(ALBEDO, vec3(0.012, 0.012, 0.014), COLOR.b * 0.94);
	ROUGHNESS = mix(roughness, 0.8, hair);
	SPECULAR = 0.25;
}
