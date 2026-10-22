// Shared surface-detail helpers for the skater kit shaders (kit_cloth,
// kit_gear). Detail textures are generated in scripts/kit_materials.gd:
// rgb = tangent-space normal, a = height / cavity. All of this is plain GLSL
// ES 3.0, so it behaves the same in gl_compatibility and Forward+.

// Perturbs a view-space normal with a tangent-space normal for a surface
// whose UVs (in metres) are `uv`: tangent frame from screen derivatives, so
// meshes need no tangent arrays.
vec3 kit_perturb_uv(vec3 n, vec3 pos, vec2 uv, vec3 tn) {
	vec3 dp1 = dFdx(pos);
	vec3 dp2 = dFdy(pos);
	vec2 duv1 = dFdx(uv);
	vec2 duv2 = dFdy(uv);
	vec3 dp2perp = cross(dp2, n);
	vec3 dp1perp = cross(n, dp1);
	vec3 t = dp2perp * duv1.x + dp1perp * duv2.x;
	vec3 b = dp2perp * duv1.y + dp1perp * duv2.y;
	float inv = inversesqrt(max(max(dot(t, t), dot(b, b)), 1e-20));
	return normalize(t * inv * tn.x + b * inv * tn.y + n * tn.z);
}

// Bump from a scalar height (metres) using screen derivatives.
vec3 kit_bump(vec3 n, vec3 pos, float h) {
	vec3 sx = dFdx(pos);
	vec3 sy = dFdy(pos);
	vec3 r1 = cross(sy, n);
	vec3 r2 = cross(n, sx);
	float det = dot(sx, r1);
	vec3 grad = sign(det) * (dFdx(h) * r1 + dFdy(h) * r2);
	vec3 perturbed = abs(det) * n - grad;
	// Degenerate screen derivatives must preserve the valid input normal.
	return dot(perturbed, perturbed) > 1e-16 ? normalize(perturbed) : n;
}

// Triplanar weights from an object-space normal.
vec3 kit_tri_weights(vec3 n) {
	vec3 w = pow(abs(n), vec3(4.0));
	return w / max(w.x + w.y + w.z, 1e-5);
}

// Triplanar detail in object space (metres): returns the perturbed object
// normal in xyz and the blended height in w.
vec4 kit_triplanar(sampler2D tex, vec3 p, vec3 n, float strength) {
	vec3 w = kit_tri_weights(n);
	vec4 tx = texture(tex, p.zy);
	vec4 ty = texture(tex, p.xz);
	vec4 tz = texture(tex, p.xy);
	vec2 nx = (tx.rg * 2.0 - 1.0) * strength;
	vec2 ny = (ty.rg * 2.0 - 1.0) * strength;
	vec2 nz = (tz.rg * 2.0 - 1.0) * strength;
	vec3 s = sign(n);
	vec3 r = n + vec3(0.0, nx.y, nx.x * s.x) * w.x + vec3(ny.x * s.y, 0.0, ny.y) * w.y + vec3(nz.x * s.z, nz.y, 0.0) * w.z;
	return vec4(normalize(r), tx.a * w.x + ty.a * w.y + tz.a * w.z);
}

// --- Gameplay-distance look (5-25 m from the camera) ---------------------
// Arena light comes from straight overhead: shoulders, helmet tops and the
// tops of the gloves catch it, undersides (under the arms, below the pants,
// the inside of the legs) fall off. `wn` is the world-space normal. Returns a
// multiplier for albedo/AO: < 1 facing down, a touch > 1 facing up.
float kit_overhead(vec3 wn) {
	float down = 1.0 - smoothstep(-0.75, 0.35, wn.y);
	float up = smoothstep(0.45, 0.95, wn.y);
	return 1.0 - 0.30 * down + 0.10 * up;
}

// Fine knit/grain normal detail aliases into sparkle once a texel is smaller
// than a pixel; fade it with view distance (VERTEX is view space).
float kit_detail_fade(vec3 view_pos) {
	return 1.0 - 0.75 * smoothstep(7.0, 20.0, length(view_pos));
}

// Specular anti-aliasing (Kaplanyan/Tokuyoshi style): widen roughness by the
// screen-space variance of the normal, so curved shells, thin sticks and
// knit bumps do not flicker with single-pixel highlights in motion.
float kit_spec_aa(vec3 n, float rough) {
	vec3 dx = dFdx(n);
	vec3 dy = dFdy(n);
	float variance = 0.5 * (dot(dx, dx) + dot(dy, dy));
	float a2 = rough * rough * rough * rough + min(2.0 * variance, 0.25);
	return sqrt(sqrt(clamp(a2, 0.0, 1.0)));
}
