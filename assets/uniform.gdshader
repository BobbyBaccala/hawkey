shader_type spatial;
render_mode cull_disabled;
uniform vec4 team_color : source_color = vec4(0.06,0.23,0.36,1.0);
// Sculpted pant and sock shells replace the base body's leg garments.
uniform bool hide_pants = false;
uniform bool hide_socks = false;
// Skin: fine pore/mottle detail (scripts/kit_materials.gd skin_texture) and
// a faked subsurface look - wrap diffuse with a warm, reddish terminator -
// since screen-space SSS is not available in gl_compatibility.
uniform sampler2D skin_detail : filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool has_skin_detail = false;
uniform bool lip_surface = false;
uniform bool hide_neck = false;
uniform float skin_detail_tiles = 24.0;
uniform float skin_wrap = 0.45;
uniform vec3 scatter_color = vec3(0.75, 0.2, 0.1);
varying float region;
varying float rest_height;
varying float rest_x;
varying float skin;
void vertex() {
	rest_x = VERTEX.x;
	region = COLOR.r * 8.0;
	rest_height = COLOR.g * 2.0;
}
void fragment() {
	if(region>3.5) discard; // Closed equipment gloves replace open bare-hand topology.
	if(region>0.5 && region<1.5) discard; // Continuous hockey shell and articulated sleeves cover torso/arms.
	if(hide_pants && region>1.5 && region<2.5) discard;
	if(hide_socks && region>2.5 && region<3.5) discard;
	// Skaters wear a neck guard (skater_visual.gd): the base mesh's neck and
	// upper chest skin under it would only poke through as jagged edges.
	if(hide_neck && region<0.5 && rest_height<1.545) discard;
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
	skin = region < 0.5 ? 1.0 : 0.0;
	if (skin > 0.5) {
		if (lip_surface) color *= vec3(1.02, 0.93, 0.92);
		// Original subtle facial albedo, located in stable bind-pose UV space.
		// Distinguish lips/brows without painting lighting into the skin.
		float face_u = UV.x - 0.5;
		float lip = exp(-pow(abs(rest_height - 1.601) / 0.008, 2.0) - pow(abs(face_u) / 0.029, 4.0));
		color = mix(color, color * vec3(1.08, 0.72, 0.73), lip * 0.15);
		float brow_u = (abs(face_u) - 0.036) / 0.020;
		float brow_y = 1.703 + 0.004 * (1.0 - brow_u * brow_u);
		float brow = exp(-pow(abs(rest_height - brow_y) / 0.0028, 2.0) - pow(abs(brow_u), 6.0));
		color *= 1.0 - 0.65 * brow;
	}
	if (skin > 0.5 && has_skin_detail) {
		vec4 d = texture(skin_detail, UV * skin_detail_tiles);
		// Mottled, slightly uneven skin tone; redder in the low spots.
		color *= mix(0.86, 1.06, d.a);
		color = mix(color, color * vec3(1.08, 0.92, 0.9), (1.0 - d.a) * 0.35);
		vec2 dn = (d.rg * 2.0 - 1.0) * 0.35;
		vec3 dp1 = dFdx(VERTEX);
		vec3 dp2 = dFdy(VERTEX);
		vec2 duv1 = dFdx(UV * skin_detail_tiles);
		vec2 duv2 = dFdy(UV * skin_detail_tiles);
		vec3 t = cross(dp2, NORMAL) * duv1.x + cross(NORMAL, dp1) * duv2.x;
		vec3 b = cross(dp2, NORMAL) * duv1.y + cross(NORMAL, dp1) * duv2.y;
		float inv = inversesqrt(max(max(dot(t, t), dot(b, b)), 1e-20));
		vec3 bumped = t * inv * dn.x + b * inv * dn.y + NORMAL;
		// Degenerate screen derivatives (tiny or flat UVs) must not poison the
		// normal: a NaN here rendered whole faces black.
		if (!(dot(bumped, bumped) > 1e-6) || any(isnan(bumped)) || any(isinf(bumped))) bumped = NORMAL;
		NORMAL = normalize(bumped);
	}
	ALBEDO = color;
	// Light scattered inside the skin keeps shadowed skin warm, not grey.
	// Bounce from the bright ice and bowl: faces under a helmet brim are lit
	// from below and the sides on a broadcast, never pitch black.
	if (skin > 0.5) {
		vec3 wn = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
		float from_ice = 0.5 - 0.5 * wn.y;
		EMISSION = color * (scatter_color * 0.035 + vec3(0.04 + 0.12 * from_ice));
	}
	ROUGHNESS = region < 0.5 ? 0.68 : 0.85;
	SPECULAR = region < 0.5 ? 0.28 : 0.22;
}
void light() {
	float ndl = dot(NORMAL, LIGHT);
	vec3 diffuse;
	if (skin > 0.5) {
		// Wrap lighting: light bleeds past the terminator like it does through
		// skin, and the band around the terminator picks up a warm red.
		float wrap = max((ndl + skin_wrap) / (1.0 + skin_wrap), 0.0);
		float band = smoothstep(-skin_wrap, 0.0, ndl) * (1.0 - smoothstep(0.0, skin_wrap, ndl));
		diffuse = vec3(wrap) + scatter_color * band * 0.35;
	} else {
		diffuse = vec3(max(ndl, 0.0));
	}
	DIFFUSE_LIGHT += diffuse * ATTENUATION * LIGHT_COLOR / PI;
	// Soft, broad skin/cloth highlight (normalised Blinn-Phong).
	vec3 h = normalize(VIEW + LIGHT);
	float r = skin > 0.5 ? 0.68 : 0.8;
	float shin = 2.0 / max(r * r * r * r, 0.002) - 2.0;
	float fres = 0.04 + 0.96 * pow(1.0 - max(dot(h, VIEW), 0.0), 5.0);
	float spec = pow(max(dot(NORMAL, h), 0.0), shin) * (shin + 8.0) / (8.0 * PI) * fres * max(ndl, 0.0);
	SPECULAR_LIGHT += spec * ATTENUATION * LIGHT_COLOR * (skin > 0.5 ? 0.45 : 0.3);
}
