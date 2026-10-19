shader_type spatial;
render_mode cull_disabled;
uniform vec4 team_color : source_color = vec4(0.06,0.23,0.36,1.0);
varying float region;
varying float rest_height;
varying float rest_x;
void vertex() {
	rest_x = VERTEX.x;
	region = COLOR.r * 8.0;
	rest_height = COLOR.g * 2.0;
}
void fragment() {
	if(region>3.5) discard; // Closed equipment gloves replace open bare-hand topology.
	if(region>0.5 && region<1.5) discard; // Continuous hockey shell and articulated sleeves cover torso/arms.
	// Retain the continuous skinned undershirt at shoulders/armpits.
	// Discarding it left visible gaps when the arms moved away from the shell.
	vec3 navy = vec3(0.018,0.032,0.052);
	vec3 white = vec3(0.62,0.68,0.72);
	vec3 color = vec3(0.34,0.22,0.16);
	if (region > 0.5 && region < 1.5) {
		color = team_color.rgb;
		if (rest_height < 1.09) color = white;
	} else if (region > 1.5 && region < 2.5) {
		color = navy;
	} else if (region > 2.5 && region < 3.5) {
		color = white;
		if (rest_height > 0.32 && rest_height < 0.41) color = team_color.rgb;
	} else if (region > 3.5) {
		color = navy;
	}
	ALBEDO = color;
	ROUGHNESS = region < 0.5 ? 0.7 : 0.85;
	SPECULAR = 0.22;
}
