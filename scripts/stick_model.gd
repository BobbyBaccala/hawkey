extends RefCounted
## Skater stick: a one-piece composite stick, original procedural geometry.
##
## Blade (local frame): +X from heel to toe, +Y up, +Z the backhand side; the
## forehand face (-Z) is cupped by a mid curve and opens slightly toward the
## toe. Origin at the blade's puck pocket (skater_visual.gd blade_position):
## the heel is at -0.48 L. The bottom edge sits 2.5 cm under the origin, rocks
## up at the heel and rounds up into a round toe. The blade is 7.4 cm tall at
## the heel, thick at the heel and thin at the toe, with rounded edges.
##
## Hosel: the blade's heel sweeps up into a tapered neck along the shaft's lie
## (about 47 degrees) and ends in the shaft's own cross-section, so the shaft
## (shaft_mesh, a rounded-rectangle tube 2.6 x 1.9 cm) carries straight on from
## it instead of meeting the blade at a corner.

const LIE := 0.82                 # radians between the ice and the shaft (~47 deg)
const HOSEL_LEN := 0.11
const SHAFT_W := 0.026            # in the blade's plane
const SHAFT_D := 0.019            # across (along the blade's face normal)
const BOTTOM := -0.025
const CARBON := Color("#15181c")
const TAPE := [Color("#15181c"), Color("#e9ebec"), Color("#101113")]

static var _material: StandardMaterial3D
static var _shaft: ArrayMesh
static var _blades := {}

static func material() -> StandardMaterial3D:
	if _material == null:
		_material = StandardMaterial3D.new()
		_material.vertex_color_use_as_albedo = true
		_material.vertex_color_is_srgb = true
		_material.roughness = 0.42
		_material.metallic_specular = 0.45
	return _material

## Blade tape by jersey number: mostly white tape, some black, a few bare.
static func tape_for(number: String) -> int:
	var h := absi(hash(number)) % 10
	return 1 if h < 6 else (2 if h < 9 else 0)

static func hosel_dir() -> Vector3:
	return Vector3(-cos(LIE), sin(LIE), 0)

static func hosel_base(length: float) -> Vector3:
	return Vector3(-0.48 * length + 0.018, BOTTOM + 0.028, 0.0)

## Top of the hosel (blade local space): where the shaft begins.
static func hosel_top(length: float) -> Vector3:
	return hosel_base(length) + hosel_dir() * HOSEL_LEN

## Blade surface at t (0 heel .. 1 toe) and v (0 bottom edge .. 1 top edge);
## side -1 forehand, +1 backhand.
static func blade_point(length: float, t: float, v: float, side: float) -> Vector3:
	var x := lerpf(-0.48 * length, 0.52 * length, t)
	var h := 0.074 - 0.010 * t
	var bottom := BOTTOM + 0.012 * pow(maxf(0.0, 0.14 - t) / 0.14, 2.0)
	var top := bottom + h
	if t > 0.80:
		# Round toe: top and bottom edges curl toward the toe tip.
		var u := (t - 0.80) / 0.20
		var round_ := 1.0 - sqrt(maxf(0.0, 1.0 - u * u))
		top -= h * 0.80 * round_
		bottom += h * 0.10 * u * u
	var y := lerpf(bottom, top, v)
	var curve := -0.016 * pow(smoothstep(0.06, 1.0, t), 1.5)
	# Open face: the upper blade leans toward the backhand, more at the toe.
	var open_ := (y - bottom) * 0.10 * t
	var thick := lerpf(0.0175, 0.0100, t) * (1.0 - 0.35 * v)
	var half := 0.5 * thick * pow(sin(PI * clampf(v, 0.0, 1.0)), 0.35)
	return Vector3(x, y, curve + open_ + side * half)

static func _ring_blade(length: float, t: float) -> PackedVector3Array:
	var ring := PackedVector3Array()
	const M := 9
	for j in range(M + 1):
		ring.append(blade_point(length, t, lerpf(0.02, 0.98, float(j) / M), -1.0))
	for j in range(M, -1, -1):
		ring.append(blade_point(length, t, lerpf(0.02, 0.98, float(j) / M), 1.0))
	return ring

## Rounded-rectangle section: w across (u axis), d deep (n axis).
static func _ring_rect(center: Vector3, u: Vector3, n: Vector3, w: float, d: float, count: int) -> PackedVector3Array:
	var ring := PackedVector3Array()
	for k in range(count):
		var a := TAU * k / count
		var c := cos(a)
		var s := sin(a)
		var cx := signf(c) * pow(absf(c), 0.35)
		var sz := signf(s) * pow(absf(s), 0.35)
		ring.append(center + u * cx * w * 0.5 + n * sz * d * 0.5)
	return ring

## Resamples a closed ring to `count` points evenly by perimeter.
static func _resample(ring: PackedVector3Array, count: int) -> PackedVector3Array:
	var lengths := [0.0]
	for i in range(ring.size()):
		lengths.append(lengths[-1] + ring[i].distance_to(ring[(i + 1) % ring.size()]))
	var total: float = lengths[-1]
	var out := PackedVector3Array()
	var seg := 0
	for k in range(count):
		var target := total * k / count
		while seg < ring.size() - 1 and float(lengths[seg + 1]) < target: seg += 1
		var span: float = float(lengths[seg + 1]) - float(lengths[seg])
		var f: float = 0.0 if span <= 0.0 else (target - float(lengths[seg])) / span
		out.append(ring[seg].lerp(ring[(seg + 1) % ring.size()], f))
	return out

static func _loft(st: SurfaceTool, rings: Array, colors: Array) -> void:
	var count: int = rings[0].size()
	var base := 0
	var verts := []
	for r in range(rings.size()):
		for k in range(count):
			st.set_color(colors[r])
			st.add_vertex(rings[r][k])
	for r in range(rings.size() - 1):
		for k in range(count):
			var a := base + r * count + k
			var b := base + r * count + (k + 1) % count
			st.add_index(a); st.add_index(a + count); st.add_index(b + count)
			st.add_index(a); st.add_index(b + count); st.add_index(b)

static func _cap(st: SurfaceTool, ring: PackedVector3Array, color: Color, flip: bool, start_index: int) -> int:
	var c := Vector3.ZERO
	for p in ring: c += p
	c /= ring.size()
	st.set_color(color)
	st.add_vertex(c)
	for p in ring:
		st.set_color(color)
		st.add_vertex(p)
	for k in range(ring.size()):
		var a := start_index + 1 + k
		var b := start_index + 1 + (k + 1) % ring.size()
		if flip:
			st.add_index(start_index); st.add_index(b); st.add_index(a)
		else:
			st.add_index(start_index); st.add_index(a); st.add_index(b)
	return start_index + 1 + ring.size()

static func blade_mesh(length: float, tape: int) -> ArrayMesh:
	var key := "%s|%d" % [length, tape]
	if _blades.has(key): return _blades[key]
	const N := 30
	const COUNT := 20
	var rings := []
	var colors := []
	for i in range(N + 1):
		var t := float(i) / N
		rings.append(_ring_blade(length, t))
		colors.append(TAPE[tape] if (tape > 0 and t > 0.10 and t < 0.97) else CARBON)
	# Hosel: from inside the heel up the lie to the shaft section.
	var hd := hosel_dir()
	var u := Vector3(sin(LIE), cos(LIE), 0)   # in the blade plane, across the neck
	var n := Vector3(0, 0, 1)
	var hosel := []
	var hosel_cols := []
	const HS := 8
	for k in range(HS + 1):
		var s := float(k) / HS
		var e := s * s * (3.0 - 2.0 * s)
		var c := hosel_base(length) + hd * (HOSEL_LEN * s)
		# The neck is broad where it grows out of the heel and tapers to the shaft.
		var w := lerpf(0.050, SHAFT_W, e)
		var d := lerpf(0.0175, SHAFT_D, e)
		hosel.append(_ring_rect(c, u, n, w, d, COUNT))
		hosel_cols.append(CARBON)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var resampled := []
	for r in rings: resampled.append(_resample(r, COUNT))
	_loft(st, resampled, colors)
	var next := resampled.size() * COUNT
	var hosel_start := next
	_loft_offset(st, hosel, hosel_cols, hosel_start)
	next += hosel.size() * COUNT
	next = _cap(st, resampled[-1], colors[-1], false, next)
	next = _cap(st, resampled[0], CARBON, true, next)
	next = _cap(st, hosel[0], CARBON, true, next)
	st.generate_normals()
	var mesh := st.commit()
	_blades[key] = mesh
	return mesh

static func _loft_offset(st: SurfaceTool, rings: Array, color: Array, base: int) -> void:
	var count: int = rings[0].size()
	for r in range(rings.size()):
		for k in range(count):
			st.set_color(color[r])
			st.add_vertex(rings[r][k])
	for r in range(rings.size() - 1):
		for k in range(count):
			var a := base + r * count + k
			var b := base + r * count + (k + 1) % count
			st.add_index(a); st.add_index(a + count); st.add_index(b + count)
			st.add_index(a); st.add_index(b + count); st.add_index(b)

## Unit-length shaft along Y (-0.5 .. 0.5), scaled to length each frame.
## Local X lies in the blade's plane (2.6 cm), Z across it (1.9 cm).
static func shaft_mesh() -> ArrayMesh:
	if _shaft: return _shaft
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings := []
	var cols := []
	for y in [-0.5, -0.25, 0.0, 0.25, 0.5]:
		rings.append(_ring_rect(Vector3(0, y, 0), Vector3.RIGHT, Vector3.BACK, SHAFT_W, SHAFT_D, 16))
		cols.append(CARBON)
	_loft(st, rings, cols)
	var next := rings.size() * 16
	next = _cap(st, rings[-1], CARBON, false, next)
	_cap(st, rings[0], CARBON, true, next)
	st.generate_normals()
	_shaft = st.commit()
	return _shaft
