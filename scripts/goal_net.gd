extends Node3D
## Pro-style goal net, original procedural geometry. Local frame: goal mouth
## on z = 0 (the goal line), net behind it toward -z, posts at x = +-POST_X.
##
## Shape (NHL-style frame): satin red steel posts and crossbar with rounded
## elbows, a base frame that runs back from each post and rounds through the
## back (BASE_DEPTH deep), an upper back bar that rounds back from the
## crossbar (TOP_DEPTH deep), and netting hung between them: a top shelf with
## catenary droop, side panels taut by the posts, and a slack back that
## bellies out, scalloped between the ties. A flat white foam sleeve wraps the
## base frame post to post and the netting is laced down onto it. A finer,
## looser inner skirt hangs inside from the upper back bar.
##
## The netting is drawn by a shader: ~3 mm off-white nylon cords on a 2 in
## diamond mesh with knots, anti-aliased by pixel coverage (thin cords fade
## instead of breaking up) and settling to a faint grey veil at distance.
## Its vertex stage ripples outward from an impact point: impact() starts a
## ripple, and the arena calls it when the puck hits the net. A soft contact
## shadow under the net grounds it (the arena's overhead lights are shadowless).
##
## Collision: posts and crossbar are solid tubes (arena.tube); the netting is
## a set of thin convex slabs that follow the visible mesh.

const POST_X := 0.96
const BAR_Y := 1.22
const POST_R := 0.035
const BASE_DEPTH := 1.02      # 40 in at the deepest point of the base frame
const TOP_DEPTH := 0.56       # upper back bar, ~22 in behind the crossbar
const TOP_Y := 1.20
const NET_RED := Color("#94111d")
const PAD_WHITE := Color("#e9ebe8")
const MESH_CELL := 0.048      # diamond mesh pitch, metres (~2 in)
const STRAND := 0.0016        # cord half-thickness, metres (~3 mm cord)
const SKIRT_CELL := 0.034
## Netting ties along the bars: the net scallops between them.
const TIES := 26
## Top of the foam sleeve on the base frame; the netting is laced onto it.
const PAD_TOP := 0.085
## Samples around the perimeter (post -> back -> post) and down the net.
const AROUND := 72
const DOWN := 16

var net_material: ShaderMaterial
var skirt_material: ShaderMaterial
var net_mesh: MeshInstance3D
var skirt_mesh: MeshInstance3D
var frame_material: StandardMaterial3D
var collision_slabs := 0
## Ripple state, mirrored into the shaders each frame.
var ripple_point := Vector3.ZERO
var ripple_age := 99.0
var ripple_strength := 0.0
var impacts := 0

static var _net_shader: Shader
static var _shadow_shader: Shader

## Base frame outline at s in [0, 1]: left post -> back -> right post.
## A rounded "D": straight-ish sides that close through a wide back curve.
static func base_point(s: float) -> Vector3:
	return _outline(s, POST_X + 0.04, BASE_DEPTH, 2.7, 0.025)

## Upper back bar outline at the top of the net.
static func top_point(s: float) -> Vector3:
	return _outline(s, POST_X, TOP_DEPTH, 2.2, TOP_Y)

static func _outline(s: float, half_width: float, depth: float, n: float, y: float) -> Vector3:
	# Superellipse quarter on each side: angle 0 at the post, PI/2 at the back.
	var t := (s * 2.0 - 1.0)            # -1 left post, 0 back, 1 right post
	var a := (1.0 - absf(t)) * PI * 0.5
	var c := pow(cos(a), 2.0 / n)
	var sn := pow(sin(a), 2.0 / n)
	# Ease from the post's own x so the outline leaves the post square.
	var x := signf(t) * lerpf(POST_X, half_width, sn) * c if t != 0.0 else 0.0
	return Vector3(x, y, -depth * sn)

## Smooth deterministic wobble for the drape so panels are never flat.
static func _wobble(s: float, v: float) -> float:
	return sin(s * 37.0 + v * 5.3) * 0.5 + sin(s * 13.0 - v * 9.1 + 1.7) * 0.35 + sin(s * 71.0 + v * 17.0 + 0.4) * 0.15

## Netting surface. Side panels/back: v = 0 at the upper bar (or post top),
## v = 1 at the base, where it is laced onto the foam sleeve.
static func net_point(s: float, v: float) -> Vector3:
	var top := top_point(s)
	var base := base_point(s)
	base.y = PAD_TOP
	# Scallops: the cord droops between ties on the top bar and lifts between
	# lacings on the base. Zero at the posts.
	var tie := absf(sin(s * PI * TIES))
	var away := sin(clampf(s, 0.0, 1.0) * PI)
	top.y -= 0.014 * tie * away
	base.y += 0.010 * tie * away
	var p := top.lerp(base, v)
	# Slack netting: the back bellies out, the side panels stay taut by the
	# posts; a little irregular drape.
	var belly := sin(v * PI) * (0.075 * away * away + 0.012 * _wobble(s, v) * away)
	var out := Vector3(p.x, 0.0, p.z + 0.25).normalized()
	# Gravity: mid-panel sags down a touch.
	return p + out * belly + Vector3(0, -0.02 * sin(v * PI) * away, 0)

## Top shelf: w = 0 at the crossbar, w = 1 at the upper back bar.
## Catenary droop between the bars, deepest mid-span.
static func shelf_point(s: float, w: float) -> Vector3:
	var top := top_point(s)
	var front := Vector3(top.x, BAR_Y - 0.012, 0.0)
	var mid := sin(clampf(s, 0.0, 1.0) * PI)
	var sag := sin(w * PI) * (0.022 + 0.026 * mid + 0.004 * _wobble(s * 1.3, w))
	var p := front.lerp(top, w)
	p.y = minf(p.y, BAR_Y - 0.012) - sag
	return p

## Inner skirt: a loose, finer curtain hung inside from the upper back bar,
## ending about half way down. v = 0 at the bar, 1 at its hem.
static func skirt_point(s: float, v: float) -> Vector3:
	var ss := lerpf(0.07, 0.93, s)
	var top := top_point(ss)
	var inward := Vector3(-top.x, 0, -top.z - 0.15).normalized()
	var hang := 0.62 + 0.05 * sin(s * 19.0 + 0.6)   # uneven hem
	var p := top + inward * 0.05 + Vector3(0, -0.01, 0)
	p.y -= hang * v
	# Loose folds and a slight inward swing toward the hem.
	p += inward * (0.06 * v * v + 0.025 * sin(s * 41.0 + v * 2.0) * v)
	p.y -= 0.012 * absf(sin(s * PI * 18.0)) * (1.0 - v)
	return p

func build(arena: Node) -> void:
	frame_material = StandardMaterial3D.new()
	frame_material.albedo_color = NET_RED
	frame_material.roughness = 0.34
	frame_material.metallic_specular = 0.55
	frame_material.clearcoat_enabled = true
	frame_material.clearcoat = 0.35
	frame_material.clearcoat_roughness = 0.3
	# Posts and crossbar: unchanged solid frame (gameplay collision relies on it).
	var before := get_child_count()
	for x in [-POST_X, POST_X]:
		arena.tube(self, Vector3(x, 0.04, 0), Vector3(x, BAR_Y, 0), POST_R, NET_RED, true)
	arena.tube(self, Vector3(-POST_X, BAR_Y, 0), Vector3(POST_X, BAR_Y, 0), POST_R, NET_RED, true)
	# Smooth, satin-painted steel instead of the 8-sided default tube.
	for i in range(before, get_child_count()):
		var m := get_child(i) as MeshInstance3D
		if m and m.mesh is CylinderMesh:
			m.mesh.radial_segments = 32
			m.material_override = frame_material
			m.name = "FrameTube%d" % (i - before)
	# Rounded elbows where the crossbar meets the posts (and the back bar
	# leaves them), and at the post feet where the base frame starts.
	for x in [-POST_X, POST_X]:
		_ball("Elbow" + ("L" if x < 0 else "R"), Vector3(x, BAR_Y, 0), POST_R * 1.04)
		_ball("Foot" + ("L" if x < 0 else "R"), Vector3(x, 0.035, 0), POST_R)
		# Post runs down to the ice; a short flexible peg sits in the ice hole.
		var foot := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = POST_R
		cyl.bottom_radius = POST_R
		cyl.height = 0.04
		cyl.radial_segments = 32
		foot.mesh = cyl
		foot.position = Vector3(x, 0.02, 0)
		foot.material_override = frame_material
		foot.name = "PostFoot" + ("L" if x < 0 else "R")
		add_child(foot)
		var peg := MeshInstance3D.new()
		var pc := CylinderMesh.new()
		pc.top_radius = 0.012
		pc.bottom_radius = 0.012
		pc.height = 0.05
		pc.radial_segments = 16
		peg.mesh = pc
		peg.position = Vector3(x, -0.015, 0)
		var pm := StandardMaterial3D.new()
		pm.albedo_color = Color(0.12, 0.12, 0.13)
		pm.roughness = 0.6
		peg.material_override = pm
		peg.name = "Peg" + ("L" if x < 0 else "R")
		add_child(peg)
	var base_pts := PackedVector3Array()
	var top_pts := PackedVector3Array()
	var pad_pts := PackedVector3Array()
	for i in range(AROUND + 1):
		var s := float(i) / AROUND
		var b := base_point(s)
		base_pts.append(b)
		top_pts.append(top_point(s))
		# Sleeve centred a little inside the frame so it wraps the frame's
		# inner face and sits flat on the ice.
		var inward := Vector3(-b.x, 0, -b.z - BASE_DEPTH * 0.45).normalized()
		var fade := smoothstep(0.0, 0.02, minf(s, 1.0 - s))
		pad_pts.append(Vector3(b.x, PAD_TOP * 0.5, b.z) + inward * 0.022 * fade + Vector3(0, 0, -0.03 * (1.0 - fade)))
	add_child(sweep("BaseFrame", base_pts, 0.025, frame_material))
	add_child(sweep("UpperBackBar", top_pts, 0.018, frame_material))
	var pad_material := StandardMaterial3D.new()
	pad_material.albedo_color = PAD_WHITE
	pad_material.roughness = 0.9
	pad_material.metallic_specular = 0.25
	# Flat foam sleeve: rounded-rectangle section, 9 cm wide x 8.5 cm tall,
	# the whole way round from post to post.
	add_child(sweep("BasePadding", pad_pts, 1.0, pad_material, Vector2(0.046, PAD_TOP * 0.5), 6.0))
	_build_netting()
	_build_contact_shadow()
	_build_collision()

func _ball(node_name: String, pos: Vector3, radius: float) -> void:
	var m := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	sphere.radial_segments = 32
	sphere.rings = 16
	m.mesh = sphere
	m.position = pos
	m.material_override = frame_material
	m.name = node_name
	add_child(m)

## Smooth tube along a polyline (one mesh). With `half` set, the section is a
## superellipse of those half-extents (side, up); `power` 2 = oval, higher =
## rounded rectangle (used for the foam sleeve).
func sweep(node_name: String, pts: PackedVector3Array, radius: float, material: Material, half := Vector2.ZERO, power := 2.0) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	const SEG := 28
	var ext := half if half != Vector2.ZERO else Vector2(radius, radius)
	var e := 2.0 / power
	var rings: Array = []
	for i in range(pts.size()):
		var tangent := (pts[mini(i + 1, pts.size() - 1)] - pts[maxi(i - 1, 0)]).normalized()
		var side := tangent.cross(Vector3.UP).normalized()
		var up := side.cross(tangent).normalized()
		var r: Array = []
		for k in range(SEG + 1):
			var a := TAU * k / SEG
			var c := cos(a)
			var sn := sin(a)
			var cx := signf(c) * pow(absf(c), e)
			var sy := signf(sn) * pow(absf(sn), e)
			# Superellipse normal: gradient of |x/a|^p + |y/b|^p.
			var nx := signf(c) * pow(absf(c), 2.0 - e) / ext.x
			var ny := signf(sn) * pow(absf(sn), 2.0 - e) / ext.y
			var n := (side * nx + up * ny).normalized()
			r.append([pts[i] + side * cx * ext.x + up * sy * ext.y, n])
		rings.append(r)
	for i in range(pts.size() - 1):
		for k in range(SEG):
			var q := [rings[i][k], rings[i + 1][k], rings[i + 1][k + 1], rings[i][k], rings[i + 1][k + 1], rings[i][k + 1]]
			for v in q:
				st.set_normal(v[1])
				st.add_vertex(v[0])
	# Cap the ends.
	for end_i in [0, pts.size() - 1]:
		var centre: Vector3 = pts[end_i]
		var tangent := (pts[mini(end_i + 1, pts.size() - 1)] - pts[maxi(end_i - 1, 0)]).normalized()
		var n := -tangent if end_i == 0 else tangent
		for k in range(SEG):
			for v in [centre, rings[end_i][k][0], rings[end_i][k + 1][0]]:
				st.set_normal(n)
				st.add_vertex(v)
	var m := MeshInstance3D.new()
	m.name = node_name
	m.mesh = st.commit()
	m.material_override = material
	return m

## Builds one netting surface from a point function into `st`.
## UV is metres along the surface; UV2.x is 0 where the net is tied to a bar.
func _add_patch(st: SurfaceTool, f: Callable, cols: int, rows: int, centre: Vector3, tie_sides: bool, tie_bottom := true) -> void:
	var grid: Array = []
	for i in range(cols + 1):
		var col: Array = []
		for j in range(rows + 1):
			col.append(f.call(float(i) / cols, float(j) / rows))
		grid.append(col)
	# u: arc length around along the top row; v: arc length down each column.
	var u_len := PackedFloat32Array()
	for i in range(cols + 1):
		u_len.append(0.0 if i == 0 else u_len[i - 1] + grid[i][0].distance_to(grid[i - 1][0]))
	var uvs: Array = []
	for i in range(cols + 1):
		var col_uv: Array = []
		var acc := 0.0
		for j in range(rows + 1):
			if j > 0: acc += grid[i][j].distance_to(grid[i][j - 1])
			col_uv.append(Vector2(u_len[i], acc))
		uvs.append(col_uv)
	for i in range(cols):
		for j in range(rows):
			for c in [[i, j], [i + 1, j], [i + 1, j + 1], [i, j], [i + 1, j + 1], [i, j + 1]]:
				var p: Vector3 = grid[c[0]][c[1]]
				st.set_normal((p - centre).normalized())
				st.set_uv(uvs[c[0]][c[1]])
				var fv := float(c[1]) / rows
				var tied := minf(fv, 1.0 - fv) * 2.0 if tie_bottom else fv * 1.2
				if tie_sides:
					tied = minf(tied, minf(float(c[0]) / cols, 1.0 - float(c[0]) / cols) * 6.0)
				st.set_uv2(Vector2(clampf(tied, 0.0, 1.0), 0))
				st.add_vertex(p)

func _net_material(cell: float, strand: float, tint: Color, opacity: float, ripple_gain: float) -> ShaderMaterial:
	if _net_shader == null:
		_net_shader = Shader.new()
		_net_shader.code = NET_SHADER
	var m := ShaderMaterial.new()
	m.shader = _net_shader
	m.set_shader_parameter("cell", cell)
	m.set_shader_parameter("strand", strand)
	m.set_shader_parameter("tint", tint)
	m.set_shader_parameter("opacity", opacity)
	m.set_shader_parameter("ripple_gain", ripple_gain)
	return m

func _build_netting() -> void:
	var centre := Vector3(0, 0.55, -0.35)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_add_patch(st, func(s, v): return net_point(s, v), AROUND, DOWN, centre, true)
	_add_patch(st, func(s, v): return shelf_point(s, v), AROUND, 6, centre, true)
	net_mesh = MeshInstance3D.new()
	net_mesh.name = "Netting"
	net_mesh.mesh = st.commit()
	net_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	net_material = _net_material(MESH_CELL, STRAND, Color(0.86, 0.87, 0.85), 1.0, 1.0)
	net_mesh.material_override = net_material
	add_child(net_mesh)
	var sk := SurfaceTool.new()
	sk.begin(Mesh.PRIMITIVE_TRIANGLES)
	_add_patch(sk, func(s, v): return skirt_point(s, v), 48, 8, centre + Vector3(0, 0, -0.3), false, false)
	skirt_mesh = MeshInstance3D.new()
	skirt_mesh.name = "InnerSkirt"
	skirt_mesh.mesh = sk.commit()
	skirt_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	skirt_material = _net_material(SKIRT_CELL, STRAND * 0.75, Color(0.90, 0.91, 0.90), 0.55, 1.9)
	skirt_material.render_priority = -1   # draws before (behind) the outer net
	skirt_mesh.material_override = skirt_material
	add_child(skirt_mesh)

## Soft contact shadow on the ice in and around the net footprint, with a
## faint blurred shadow of the mesh itself.
func _build_contact_shadow() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	const N := 48
	var grow := Vector3(1.12, 0, 1.08)
	var c := Vector3(0, 0.0, -BASE_DEPTH * 0.45)
	for i in range(N):
		var a := base_point(float(i) / N) * grow
		var b := base_point(float(i + 1) / N) * grow
		for p in [c, a, b]:
			st.set_normal(Vector3.UP)
			st.add_vertex(Vector3(p.x, 0.003, minf(p.z, 0.0)))
	var l := base_point(0.0) * grow
	var r := base_point(1.0) * grow
	for p in [c, r, l]:
		st.set_normal(Vector3.UP)
		st.add_vertex(Vector3(p.x, 0.003, 0.0))
	var m := MeshInstance3D.new()
	m.name = "NetShadow"
	m.mesh = st.commit()
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if _shadow_shader == null:
		_shadow_shader = Shader.new()
		_shadow_shader.code = SHADOW_SHADER
	var sm := ShaderMaterial.new()
	sm.shader = _shadow_shader
	sm.set_shader_parameter("depth", BASE_DEPTH)
	sm.set_shader_parameter("half_w", POST_X + 0.04)
	sm.set_shader_parameter("cell", MESH_CELL)
	m.material_override = sm
	add_child(m)

const SHADOW_SHADER := """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;
uniform float depth = 1.02;
uniform float half_w = 1.0;
uniform float cell = 0.048;
varying vec3 lp;
void vertex(){ lp = VERTEX; }
void fragment(){
	// Darker toward the base frame, open at the mouth.
	vec2 q = vec2(lp.x / half_w, -lp.z / depth);
	float rim = length(vec2(q.x, q.y * 1.05 - 0.05));
	float edge = smoothstep(0.55, 1.0, rim) * (1.0 - smoothstep(1.0, 1.12, rim));
	float inside = (1.0 - smoothstep(0.85, 1.1, rim)) * smoothstep(0.0, 0.5, q.y);
	// The overhead lights throw a blurred shadow of the back netting.
	vec2 g = vec2(lp.x - lp.z, lp.x + lp.z) / (cell * 1.41421);
	vec2 f = abs(fract(g) - 0.5);
	float meshv = 1.0 - smoothstep(0.30, 0.47, max(f.x, f.y));
	float blur = clamp(fwidth(g.x) * 2.0, 0.0, 1.0);
	meshv = mix(meshv, 0.35, blur);
	float a = edge * 0.30 + inside * (0.10 + 0.07 * meshv);
	ALBEDO = vec3(0.10, 0.12, 0.16);
	ALPHA = clamp(a, 0.0, 0.4);
}"""

const NET_SHADER := """shader_type spatial;
render_mode cull_disabled, depth_draw_always, diffuse_lambert_wrap, specular_schlick_ggx;
uniform float cell = 0.048;
uniform float strand = 0.0016;
uniform vec4 tint : source_color = vec4(0.86, 0.87, 0.85, 1.0);
uniform float opacity = 1.0;
uniform float ripple_gain = 1.0;
uniform vec3 ripple_point = vec3(0.0);
uniform float ripple_age = 99.0;
uniform float ripple_strength = 0.0;
varying float height;
float hash(vec2 p){ return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void vertex(){
	float tied = UV2.x;
	float d = distance(VERTEX, ripple_point);
	float env = exp(-ripple_age * 3.0) * ripple_strength * ripple_gain;
	// Bulge where the puck hit, then a ring wave running out across the mesh.
	float bulge = exp(-d * d / 0.08) * exp(-ripple_age * 4.5);
	float wave = sin(ripple_age * 28.0 - d * 15.0) * exp(-d * 1.6);
	VERTEX += NORMAL * env * tied * (0.14 * bulge + 0.035 * wave);
	height = VERTEX.y;
}
// Anti-aliased cord coverage: a cord thinner than a pixel fades by its
// width instead of breaking into dashes.
float cord(float dist, float half_w, float px){
	float hw = max(half_w, px * 0.5);
	return clamp((hw - dist) / px + 0.5, 0.0, 1.0) * (half_w / hw);
}
void fragment(){
	// Diamond mesh: two families of cords at +-45 degrees, `cell` apart.
	vec2 g = vec2(UV.x + UV.y, UV.x - UV.y) / (cell * 1.41421);
	vec2 cellid = floor(g + 0.5);
	vec2 dist = abs(g - cellid);             // in cells, 0 on a cord
	vec2 px = max(fwidth(g), vec2(1e-4));
	float hw = strand / cell;
	float ca = cord(dist.x, hw, px.x);
	float cb = cord(dist.y, hw * 0.92, px.y);
	// Knots at the crossings.
	float pxk = max(px.x, px.y);
	float kn = cord(length(dist), hw * 1.9, pxk);
	float cover = max(max(ca, cb), kn);
	// Average coverage once a cell is only a few pixels: a faint grey veil.
	float avg = 4.0 * hw * 1.25;
	cover = mix(cover, avg, smoothstep(0.25, 0.7, pxk));
	if (cover < 0.015) discard;
	// Per-cord brightness and a little grime low on the net.
	float va = hash(vec2(cellid.x, 1.0)) * 0.12;
	float vb = hash(vec2(cellid.y, 7.0)) * 0.12;
	float tone = 0.9 + (ca >= cb ? va : vb);
	float grime = mix(0.86, 1.0, smoothstep(0.05, 0.5, height));
	ALBEDO = tint.rgb * tone * grime;
	ROUGHNESS = 0.88;
	SPECULAR = 0.18;
	BACKLIGHT = vec3(0.22);
	ALPHA = clamp(cover * opacity, 0.0, 1.0);
}"""

## Thin convex slabs following the netting: puck and sticks stop on the net.
## Built from the undraped frame-to-frame surface (gameplay unchanged).
func _build_collision() -> void:
	var body := StaticBody3D.new()
	body.name = "NetCollision"
	var pm := PhysicsMaterial.new()
	pm.friction = 0.6
	pm.bounce = 0.12
	# Flexible netting absorbs the puck material restitution instead of adding it.
	pm.absorbent = true
	body.physics_material_override = pm
	add_child(body)
	const STEPS := 8
	var centre := Vector3(0, 0.55, -0.35)
	for i in range(STEPS):
		var s0 := float(i) / STEPS
		var s1 := float(i + 1) / STEPS
		var quads := [
			[net_point(s0, 0), net_point(s1, 0), net_point(s1, 1), net_point(s0, 1)],
			[shelf_point(s0, 0), shelf_point(s1, 0), shelf_point(s1, 1), shelf_point(s0, 1)],
		]
		for q in quads:
			var pts := PackedVector3Array()
			var mid: Vector3 = (q[0] + q[1] + q[2] + q[3]) * 0.25
			var out: Vector3 = (mid - centre).normalized()
			for p in q:
				pts.append(p + out * 0.04)
				pts.append(p - out * 0.02)
			# Keep the slab clear of the goal mouth plane.
			for k in range(pts.size()): pts[k].z = minf(pts[k].z, -0.005)
			var shape := ConvexPolygonShape3D.new()
			shape.points = pts
			var cs := CollisionShape3D.new()
			cs.shape = shape
			body.add_child(cs)
			collision_slabs += 1

## Puck (or anything) hit the netting at `local_point` with `speed` m/s.
func impact(local_point: Vector3, speed: float) -> void:
	ripple_point = local_point
	ripple_age = 0.0
	ripple_strength = clampf(speed / 18.0, 0.25, 1.4)
	impacts += 1
	_push()

func _process(delta: float) -> void:
	if ripple_age < 3.0:
		ripple_age += delta
		_push()

func _push() -> void:
	for m in [net_material, skirt_material]:
		if m == null: continue
		m.set_shader_parameter("ripple_point", ripple_point)
		m.set_shader_parameter("ripple_age", ripple_age)
		m.set_shader_parameter("ripple_strength", ripple_strength)

## Is a local point in or right against the net (behind the goal line)?
static func near_net(local_point: Vector3) -> bool:
	if local_point.z > 0.0 or local_point.y < -0.05 or local_point.y > BAR_Y + 0.15: return false
	if local_point.z < -BASE_DEPTH - 0.2: return false
	return absf(local_point.x) < POST_X + 0.2
