shader_type spatial;
// Crowd cards (arena_dressing.gd build_crowd()): each card is a row of eight
// seated fans from assets/crowd-spectators-v1.png. During play every fan
// fidgets on their own (small, slow shifts and a faint brightness shimmer);
// on a goal or a big save (`cheer`) the cards rise as the section stands and
// each fan bounces out of phase, with the odd camera flash. Phases come from
// the card's world position and the fan's column, so no per-instance data is
// needed and it renders the same in Forward+ and gl_compatibility.
render_mode unshaded, cull_disabled, depth_draw_opaque;

uniform sampler2D crowd_tex : source_color, filter_linear_mipmap, repeat_disable;
uniform vec4 tint : source_color = vec4(0.33, 0.34, 0.36, 1.0);
// 0..1 excitement: 1 = goal roar, ~0.5 = big save.
uniform float cheer = 0.0;
// Z sign of the end where it happened (0 = whole bowl equally); the stands at
// that end react fully, the far end a little less.
uniform float cheer_end = 0.0;
// In-play fidget amount (0 = frozen photo).
uniform float shimmer = 1.0;
// Script-driven time (arena_dressing.gd) so captures and tests are repeatable.
uniform float clock = 0.0;

const float FANS = 8.0;
// How far a card rises when its section stands (m) and the bounce on top.
const float STAND_RISE = 0.16;
const float STAND_BOUNCE = 0.09;

varying flat float v_cheer;
// Flat: an interpolated seed would wobble per pixel through the hash and
// stipple the fans.
varying flat float v_seed;

float hash(float n) {
	return fract(sin(n) * 43758.5453);
}

float card_seed(vec3 origin) {
	return hash(dot(origin, vec3(12.9898, 78.233, 37.719)));
}

// Excitement at a card: full at the end where it happened, 65 % at the far end.
float card_cheer(vec3 origin) {
	float near = 1.0;
	if (cheer_end != 0.0) {
		near = mix(0.65, 1.0, clamp(0.5 + 0.5 * sign(cheer_end) * origin.z / 30.0, 0.0, 1.0));
	}
	return cheer * near;
}

void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	v_seed = card_seed(origin);
	v_cheer = card_cheer(origin);
	// The section stands: the whole card lifts, then bounces with the noise.
	float bounce = max(0.0, sin(clock * 7.0 + v_seed * 6.2832));
	VERTEX.y += v_cheer * (STAND_RISE + STAND_BOUNCE * bounce);
}

void fragment() {
	vec2 uv = UV;
	float fan = floor(clamp(uv.x, 0.0, 0.9999) * FANS);
	float ps = hash(fan * 7.31 + v_seed * 91.7);
	// In play: each fan shifts in their seat now and then (slow, ~1 cm).
	float fidget = shimmer * 0.010 * sin(clock * (0.9 + ps * 1.6) + ps * 40.0)
		* smoothstep(0.2, 0.8, sin(clock * 0.37 + ps * 17.0));
	float sway = shimmer * 0.0025 * sin(clock * (0.6 + ps) + ps * 23.0);
	// Cheering: most fans jump out of phase; about one in six stays seated.
	float jumper = step(0.17, ps);
	float jump = v_cheer * jumper * (0.035 + 0.06 * ps)
		* max(0.0, sin(clock * (6.0 + ps * 3.5) + ps * 30.0));
	uv.y += fidget + jump;
	// Keep each fan inside their own column so nobody tears at a seam.
	float lo = fan / FANS + 0.002;
	float hi = (fan + 1.0) / FANS - 0.002;
	uv.x = clamp(uv.x + sway, lo, hi);
	vec4 tex = texture(crowd_tex, uv);
	if (uv.y > 1.0) {
		tex.a = 0.0;
	}
	// Seat shimmer: a faint per-fan brightness drift (light catching people
	// as they move), a touch brighter when standing.
	float drift = 1.0 + shimmer * 0.06 * sin(clock * (0.5 + ps * 0.9) + ps * 11.0);
	float lift = 1.0 + 0.18 * v_cheer * jumper;
	vec3 col = tex.rgb * tint.rgb * drift * lift;
	// Camera flashes while the place is up (sparse, a frame or two each).
	float flash_slot = floor(clock * 14.0);
	float flash = step(0.99, hash(flash_slot * 1.37 + ps * 13.1 + v_seed * 71.3)) * step(0.35, v_cheer);
	// A small bright point held up at chest height in front of the fan (card
	// is 4.5 x 1.5 m, so measure in metres).
	vec2 bulb = vec2((fan + 0.5) / FANS + (ps - 0.5) * 0.04, 0.38);
	float r = length((UV - bulb) * vec2(4.5, 1.5));
	float spot = flash * (1.0 - smoothstep(0.008, 0.04, r));
	float alpha = max(tex.a, spot);
	col = mix(col, vec3(1.0), spot);
	ALBEDO = col;
	ALPHA = alpha;
	ALPHA_SCISSOR_THRESHOLD = 0.4;
}
