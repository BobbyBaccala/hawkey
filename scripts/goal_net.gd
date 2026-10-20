extends Node3D
## Pro-style goal net, original procedural geometry. Local frame: goal mouth
## on z = 0 (the goal line), net behind it toward -z, posts at x = +-POST_X.
##
## Shape (NHL-style frame): a red base frame that runs back from each post and
## rounds through the back (BASE_DEPTH deep), an upper back bar that rounds back
## from the crossbar (TOP_DEPTH deep), and netting hung between them: a flat
## top shelf, side panels down the posts, and a back that slopes from the
## upper bar out to the base. White foam padding covers the inside of the base
## frame. The netting is one mesh with a knotted diamond mesh shader
## (anti-aliased, fading to a soft veil at distance) whose vertex stage
## ripples outward from an impact point: impact() starts a ripple, and the
## arena calls it when the puck hits the net.
##
## Collision: posts and crossbar are solid tubes (arena.tube); the netting is
## a set of thin convex slabs that follow the visible mesh.

const POST_X := 0.96
const BAR_Y := 1.22
const POST_R := 0.035
const BASE_DEPTH := 1.02      # 40 in at the deepest point of the base frame
const TOP_DEPTH := 0.56       # upper back bar, ~22 in behind the crossbar
const TOP_Y := 1.20
const NET_RED := Color("#b0182c")
const PAD_WHITE := Color("#f2f4f6")
const MESH_CELL := 0.058      # diamond mesh pitch, metres
## Samples around the perimeter (post -> back -> post) and down the net.
const AROUND := 28
const DOWN := 10

var net_material: ShaderMaterial
var net_mesh: MeshInstance3D
var collision_slabs := 0
## Ripple state, mirrored into the shader each frame.
var ripple_point := Vector3.ZERO
var ripple_age := 99.0
var ripple_strength := 0.0
var impacts := 0

static var _net_shader: Shader

## Base frame outline (y = 0) at s in [0, 1]: left post -> back -> right post.
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

## Netting surface. side panels/back: v = 0 at the upper bar (or post top),
## v = 1 at the base frame; a slight sag inward at mid-height.
static func net_point(s: float, v: float) -> Vector3:
	var top := top_point(s)
	var base := base_point(s)
	base.y = 0.03
	var p := top.lerp(base, v)
	# Hanging netting bellies a little outward (back) between its two bars.
	var belly := sin(v * PI) * 0.05 * sin(clampf(s, 0.0, 1.0) * PI)
	var out := Vector3(p.x, 0.0, p.z + 0.25).normalized()
	return p + out * belly

## Top shelf: w = 0 at the crossbar, w = 1 at the upper back bar.
static func shelf_point(s: float, w: float) -> Vector3:
	var top := top_point(s)
	var front := Vector3(top.x, BAR_Y - 0.01, 0.0)
	return front.lerp(top, w) + Vector3(0, -sin(w * PI) * 0.025, 0)

func build(arena: Node) -> void:
	# Posts and crossbar: unchanged solid frame (gameplay collision relies on it).
	for x in [-POST_X, POST_X]:
		arena.tube(self, Vector3(x, 0.04, 0), Vector3(x, BAR_Y, 0), POST_R, NET_RED, true)
	arena.tube(self, Vector3(-POST_X, BAR_Y, 0), Vector3(POST_X, BAR_Y, 0), POST_R, NET_RED, true)
	var base_pts := PackedVector3Array()
	var top_pts := PackedVector3Array()
	var pad_pts := PackedVector3Array()
	for i in range(AROUND + 1):
		var s := float(i) / AROUND
		base_pts.append(base_point(s))
		top_pts.append(top_point(s))
		var b := base_point(s)
		var inward := Vector3(-b.x, 0, -b.z - BASE_DEPTH * 0.45).normalized()
		pad_pts.append(Vector3(b.x, 0.055, b.z) + inward * 0.03)
	add_child(sweep("BaseFrame", base_pts, 0.025, NET_RED, 0.35))
	add_child(sweep("UpperBackBar", top_pts, 0.018, NET_RED, 0.35))
	# Foam padding on the inside of the base frame (skips the post feet).
	var pad := PackedVector3Array()
	for i in range(1, pad_pts.size() - 1): pad.append(pad_pts[i])
	add_child(sweep("BasePadding", pad, 0.055, PAD_WHITE, 0.85, Vector3(1.0, 0.85, 1.0)))
	_build_netting()
	_build_collision()

## Smooth tube along a polyline (one mesh). `squash` scales the ring's
## local (side, up, -) axes so padding can be an oval rather than a round tube.
func sweep(node_name: String, pts: PackedVector3Array, radius: float, color: Color, roughness: float, squash := Vector3.ONE) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	const SEG := 10
	var rings: Array = []
	for i in range(pts.size()):
		var tangent := (pts[mini(i + 1, pts.size() - 1)] - pts[maxi(i - 1, 0)]).normalized()
		var side := tangent.cross(Vector3.UP).normalized()
		var up := side.cross(tangent).normalized()
		var r: Array = []
		for k in range(SEG + 1):
			var a := TAU * k / SEG
			var n := (side * cos(a) * squash.x + up * sin(a) * squash.y).normalized()
			r.append([pts[i] + side * cos(a) * radius * squash.x + up * sin(a) * radius * squash.y, n])
		rings.append(r)
	for i in range(pts.size() - 1):
		for k in range(SEG):
			var q := [rings[i][k], rings[i + 1][k], rings[i + 1][k + 1], rings[i][k], rings[i + 1][k + 1], rings[i][k + 1]]
			for v in q:
				st.set_normal(v[1])
				st.add_vertex(v[0])
	var m := MeshInstance3D.new()
	m.name = node_name
	m.mesh = st.commit()
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	m.material_override = material
	return m

func _build_netting() -> void:
	# UVs are in metres along the surface so the diamond pitch is constant.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var centre := Vector3(0, 0.55, -0.35)
	var patches := [
		[func(s, v): return net_point(s, v), DOWN],
		[func(s, v): return shelf_point(s, v), 4],
	]
	for patch in patches:
		var f: Callable = patch[0]
		var rows: int = patch[1]
		var grid: Array = []
		var u_len := PackedFloat32Array()
		# Arc length around the perimeter for u; down each column for v.
		for i in range(AROUND + 1):
			var col: Array = []
			for j in range(rows + 1):
				col.append(f.call(float(i) / AROUND, float(j) / rows))
			grid.append(col)
		for i in range(AROUND + 1):
			u_len.append(0.0 if i == 0 else u_len[i - 1] + grid[i][0].distance_to(grid[i - 1][0]))
		var uvs: Array = []
		for i in range(AROUND + 1):
			var col_uv: Array = []
			var acc := 0.0
			for j in range(rows + 1):
				if j > 0: acc += grid[i][j].distance_to(grid[i][j - 1])
				col_uv.append(Vector2(u_len[i], acc))
			uvs.append(col_uv)
		for i in range(AROUND):
			for j in range(rows):
				for c in [[i, j], [i + 1, j], [i + 1, j + 1], [i, j], [i + 1, j + 1], [i, j + 1]]:
					var p: Vector3 = grid[c[0]][c[1]]
					var out := (p - centre)
					out = out.normalized()
					st.set_normal(out)
					st.set_uv(uvs[c[0]][c[1]])
					# UV2.x carries the rim weight: 0 where netting is tied to a bar.
					var tied := minf(float(c[1]) / rows, 1.0 - float(c[1]) / rows) * 2.0
					tied = minf(tied, minf(float(c[0]) / AROUND, 1.0 - float(c[0]) / AROUND) * 6.0)
					st.set_uv2(Vector2(clampf(tied, 0.0, 1.0), 0))
					st.add_vertex(p)
	net_mesh = MeshInstance3D.new()
	net_mesh.name = "Netting"
	net_mesh.mesh = st.commit()
	net_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if _net_shader == null:
		_net_shader = Shader.new()
		_net_shader.code = NET_SHADER
	net_material = ShaderMaterial.new()
	net_material.shader = _net_shader
	net_material.set_shader_parameter("cell", MESH_CELL)
	net_mesh.material_override = net_material
	add_child(net_mesh)

const NET_SHADER := """shader_type spatial;
render_mode cull_disabled, depth_draw_always, specular_schlick_ggx;
uniform float cell = 0.058;
uniform vec3 ripple_point = vec3(0.0);
uniform float ripple_age = 99.0;
uniform float ripple_strength = 0.0;
void vertex(){
	float tied = UV2.x;
	float d = distance(VERTEX, ripple_point);
	float env = exp(-ripple_age * 3.2) * ripple_strength;
	// Bulge where the puck hit, then a ring wave running out across the mesh.
	float bulge = exp(-d * d / 0.08) * exp(-ripple_age * 5.0);
	float wave = sin(ripple_age * 30.0 - d * 16.0) * exp(-d * 1.8);
	VERTEX += NORMAL * env * tied * (0.16 * bulge + 0.04 * wave);
}
void fragment(){
	// Diamond mesh: two families of strands at +-45 degrees.
	vec2 g = vec2(UV.x + UV.y, UV.x - UV.y) / (cell * 1.41421);
	vec2 f = abs(fract(g) - 0.5);
	vec2 w = fwidth(g);
	float strand = 0.05;
	vec2 line = 1.0 - smoothstep(vec2(strand) - w, vec2(strand) + w, 0.5 - f);
	float cover = max(line.x, line.y);
	// Knots where strands cross read slightly heavier.
	float knot = (1.0 - smoothstep(0.0, 0.16 + w.x, length(0.5 - f))) * 0.6;
	cover = max(cover, knot);
	// When a cell is smaller than a pixel, settle to the average coverage.
	float far = smoothstep(0.35, 0.9, max(w.x, w.y));
	cover = mix(cover, 0.30, far);
	if (cover < 0.02) discard;
	ALBEDO = vec3(0.93, 0.94, 0.95);
	ROUGHNESS = 0.8;
	SPECULAR = 0.2;
	ALPHA = clamp(cover * 0.92, 0.0, 1.0);
	BACKLIGHT = vec3(0.35);
}"""

## Thin convex slabs following the netting: puck and sticks stop on the net.
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
	if net_material == null: return
	net_material.set_shader_parameter("ripple_point", ripple_point)
	net_material.set_shader_parameter("ripple_age", ripple_age)
	net_material.set_shader_parameter("ripple_strength", ripple_strength)

## Is a local point in or right against the net (behind the goal line)?
static func near_net(local_point: Vector3) -> bool:
	if local_point.z > 0.0 or local_point.y < -0.05 or local_point.y > BAR_Y + 0.15: return false
	if local_point.z < -BASE_DEPTH - 0.2: return false
	return absf(local_point.x) < POST_X + 0.2
