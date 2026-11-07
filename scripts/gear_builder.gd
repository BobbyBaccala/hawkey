extends RefCounted
## Sculpted hockey equipment built from lofted cross-sections with smooth normals
## and painted vertex colours. Dimensions follow published goaltender equipment
## limits (IIHF/NHL): pad face 28 cm wide, blocker board 20.5 x 38.5 cm,
## catcher perimeter ~114 cm with a 46 cm T-trap, goalie blade ~8.9 cm tall.
## All gear is generic and unbranded. tools/export_gear.gd writes these meshes
## to .glb so they can be opened and refined in Blender.

const WHITE := Color("#eceff0")
const OFFWHITE := Color("#d9dee1")
const LINE := Color("#9aa6ad")
const DARK := Color("#1b232b")
const LACE := Color("#2a2f33")
const METAL := Color("#8e979d")
## UV for untextured geometry: a reserved white strip along the bottom of every
## graphic texture, so vertex colours alone decide those surfaces.
const BLANK_UV := Vector2(0.5, 0.993)
## Face graphics fill v in [0, FACE_V] of a texture; the rest is the white strip.
const FACE_V := 0.97

class MeshBuilder:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()

	## Joins rings of equal point count into a closed, smoothly shaded surface.
	## ring_uvs (optional, same shape as rings) maps painted graphics; without
	## it the piece samples the texture's blank strip.
	func add_loft(rings: Array, ring_colors: Array, cap_start := true, cap_end := true, ring_uvs: Array = []) -> void:
		var count: int = rings[0].size()
		var base := vertices.size()
		var first_index := indices.size()
		for r in range(rings.size()):
			vertices.append_array(rings[r])
			colors.append_array(ring_colors[r])
			if ring_uvs.is_empty():
				for k in range(count): uvs.append(BLANK_UV)
			else:
				uvs.append_array(ring_uvs[r])
		for r in range(rings.size() - 1):
			for j in range(count):
				var a := base + r * count + j
				var b := base + r * count + (j + 1) % count
				indices.append_array(PackedInt32Array([a, a + count, b + count, a, b + count, b]))
		for end_: int in [0, rings.size() - 1]:
			if (end_ == 0 and not cap_start) or (end_ > 0 and not cap_end):
				continue
			var center := Vector3.ZERO
			for p: Vector3 in rings[end_]:
				center += p
			center /= count
			var c := vertices.size()
			vertices.append(center)
			colors.append(ring_colors[end_][0])
			if ring_uvs.is_empty():
				uvs.append(BLANK_UV)
			else:
				var uv_mid := Vector2.ZERO
				for q: Vector2 in ring_uvs[end_]: uv_mid += q
				uvs.append(uv_mid / count)
			for j in range(count):
				var a := base + end_ * count + j
				var b := base + end_ * count + (j + 1) % count
				if end_ == 0:
					indices.append_array(PackedInt32Array([c, a, b]))
				else:
					indices.append_array(PackedInt32Array([c, b, a]))
		_finish_piece(base, first_index)

	## Smooth normals for one piece; flips the piece if it was wound inward.
	func _finish_piece(base: int, first_index: int) -> void:
		var accum := PackedVector3Array()
		accum.resize(vertices.size() - base)
		var centroid := Vector3.ZERO
		for i in range(base, vertices.size()):
			centroid += vertices[i]
		centroid /= maxf(1, vertices.size() - base)
		var outward := 0.0
		for t in range(first_index, indices.size(), 3):
			var a := vertices[indices[t]]
			var b := vertices[indices[t + 1]]
			var c := vertices[indices[t + 2]]
			var n := (b - a).cross(c - a)
			outward += n.dot((a + b + c) / 3.0 - centroid)
			for k in range(3):
				accum[indices[t + k] - base] += n
		# Godot treats clockwise triangles as front faces, so the winding must be
		# the reverse of the counter-clockwise order that yields outward normals.
		var inward := outward < 0
		if not inward:
			for t in range(first_index, indices.size(), 3):
				var swap := indices[t + 1]
				indices[t + 1] = indices[t + 2]
				indices[t + 2] = swap
		for i in range(accum.size()):
			var n := accum[i].normalized()
			normals.append(-n if inward else n)

	## A tube along a polyline, used for cage bars, laces and straps.
	func add_tube(points: PackedVector3Array, radius: float, color: Color, sides := 8) -> void:
		var rings := []
		var ring_colors := []
		var span := (points[points.size() - 1] - points[0]).normalized()
		var across := span.cross(Vector3.UP if absf(span.y) < 0.8 else Vector3.BACK).normalized()
		for i in range(points.size()):
			var prev := points[maxi(i - 1, 0)]
			var next_ := points[mini(i + 1, points.size() - 1)]
			var axis := (next_ - prev).normalized()
			# Carry the previous frame along the tube so rings never twist.
			across = (across - axis * across.dot(axis)).normalized()
			var depth := axis.cross(across).normalized()
			var ring := PackedVector3Array()
			var cols := PackedColorArray()
			for s in range(sides):
				var a := TAU * s / sides
				ring.append(points[i] + (across * cos(a) + depth * sin(a)) * radius)
				cols.append(color)
			rings.append(ring)
			ring_colors.append(cols)
		add_loft(rings, ring_colors)

	## Padded roll along a polyline with a radius per point and rounded
	## (hemispherical) ends, smooth-shaded: finger segments, glove rolls, straps.
	## flat < 1 squashes the section along `normal_hint` (padding that lies flat).
	func add_capsule(points: PackedVector3Array, radii: Array, color: Color, sides := 14, flat := 1.0, normal_hint := Vector3.BACK) -> void:
		var rings := []
		var ring_colors := []
		# Catmull-Rom subdivision so curled paths (fingers) bend smoothly.
		if points.size() > 2:
			var fine := PackedVector3Array()
			var fine_r := []
			var m := points.size()
			for i in range(m - 1):
				var p0 := points[maxi(i - 1, 0)]
				var p1 := points[i]
				var p2 := points[i + 1]
				var p3 := points[mini(i + 2, m - 1)]
				for k in range(3):
					var t := k / 3.0
					fine.append(p1.cubic_interpolate(p2, p0, p3, t))
					fine_r.append(lerpf(radii[i], radii[i + 1], t))
			fine.append(points[m - 1])
			fine_r.append(radii[m - 1])
			points = fine
			radii = fine_r
		var n := points.size()
		var tangents: Array[Vector3] = []
		for i in range(n):
			tangents.append((points[mini(i + 1, n - 1)] - points[maxi(i - 1, 0)]).normalized())
		var frames := []
		for i in range(n):
			var t: Vector3 = tangents[i]
			var depth := (normal_hint - t * normal_hint.dot(t))
			if depth.length_squared() < 0.0001:
				depth = t.cross(Vector3.RIGHT)
			depth = depth.normalized()
			frames.append([t.cross(depth).normalized(), depth])
		var ring_at := func(c: Vector3, f: Array, r: float) -> PackedVector3Array:
			var ring := PackedVector3Array()
			for s in range(sides):
				var a := TAU * s / sides
				ring.append(c + (f[0] as Vector3) * cos(a) * r + (f[1] as Vector3) * sin(a) * r * flat)
			return ring
		var cap_steps := 5
		# Rounded start.
		for k in range(cap_steps, 0, -1):
			var ang := PI * 0.5 * k / (cap_steps + 1)
			var r0: float = radii[0]
			rings.append(ring_at.call(points[0] - tangents[0] * r0 * sin(ang), frames[0], r0 * cos(ang)))
		for i in range(n):
			rings.append(ring_at.call(points[i], frames[i], radii[i]))
		for k in range(1, cap_steps + 1):
			var ang := PI * 0.5 * k / (cap_steps + 1)
			var r1: float = radii[n - 1]
			rings.append(ring_at.call(points[n - 1] + tangents[n - 1] * r1 * sin(ang), frames[n - 1], r1 * cos(ang)))
		for r in rings:
			var cols := PackedColorArray()
			cols.resize(sides)
			cols.fill(color)
			ring_colors.append(cols)
		add_loft(rings, ring_colors)

	## Rounded box: lofted along Y with softened ends.
	func add_rounded_box(center: Vector3, size: Vector3, radius: float, color: Color, basis := Basis.IDENTITY) -> void:
		var rings := []
		var ring_colors := []
		var steps := 6
		var r := minf(radius, minf(size.x, minf(size.y, size.z)) * 0.5 - 0.001)
		var heights := []
		for i in range(steps + 1):
			heights.append([-size.y / 2 + r - r * cos(PI / 2 * i / steps), sin(PI / 2 * i / steps)])
		for i in range(steps, -1, -1):
			heights.append([size.y / 2 - r + r * cos(PI / 2 * i / steps), sin(PI / 2 * i / steps)])
		for h: Array in heights:
			var inset: float = r * (1.0 - h[1])
			var profile := GearProfiles.rounded_rect(size.x - inset * 2, size.z - inset * 2, [r, r, r, r], 3, 2)
			var ring := PackedVector3Array()
			var cols := PackedColorArray()
			for p in profile:
				ring.append(center + basis * Vector3(p.x, h[0], p.y))
				cols.append(color)
			rings.append(ring)
			ring_colors.append(cols)
		add_loft(rings, ring_colors)

	## Flat padded panel (a rounded rectangle with bound edges), its front face
	## mapped to the graphic: size is (width, height), thickness along local Z.
	## u runs along local +X, v along local +Y.
	func add_panel(center: Vector3, size: Vector2, thickness: float, radius: float, basis: Basis, face: Color, edge: Color, back: Color) -> void:
		var profile := GearProfiles.rounded_rect(size.x, size.y, [radius, radius, radius, radius], 6, 10)
		var rings := []
		var ring_colors := []
		var ring_uvs := []
		var layers := [[-0.5, 0.004, back], [-0.35, 0.0, edge], [0.35, 0.0, edge], [0.5, 0.006, face]]
		for layer: Array in layers:
			var ring := PackedVector3Array()
			var cols := PackedColorArray()
			var uv_ring := PackedVector2Array()
			var inset: float = layer[1]
			for p in profile:
				var q := p - p.normalized() * inset
				ring.append(center + basis * Vector3(q.x, q.y, thickness * float(layer[0])))
				cols.append(layer[2])
				uv_ring.append(Vector2(clampf(q.x / size.x + 0.5, 0.0, 1.0), (0.5 - clampf(q.y / size.y, -0.5, 0.5)) * FACE_V) if layer[0] == 0.5 else BLANK_UV)
			rings.append(ring)
			ring_colors.append(cols)
			ring_uvs.append(uv_ring)
		add_loft(rings, ring_colors, true, true, ring_uvs)

	func to_mesh(roughness := 0.6, graphic: Texture2D = null) -> ArrayMesh:
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_COLOR] = colors
		arrays[Mesh.ARRAY_TEX_UV] = uvs
		arrays[Mesh.ARRAY_INDEX] = indices
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var m := StandardMaterial3D.new()
		m.vertex_color_use_as_albedo = true
		m.vertex_color_is_srgb = true
		if graphic:
			# Painted graphics multiply the vertex colours: crisp, anti-aliased
			# panels and stripes instead of colours stepped across triangles.
			m.albedo_texture = graphic
			m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		m.roughness = roughness
		m.metallic_specular = 0.35
		mesh.surface_set_material(0, m)
		return mesh

class GearProfiles:
	## Rounded rectangle in the X/Z plane. Radii: front-outer(+x,+z), front-inner(-x,+z),
	## back-inner(-x,-z), back-outer(+x,-z). Every call yields the same point count.
	static func rounded_rect(w: float, d: float, radii: Array, arc_points := 4, edge_points := 4) -> PackedVector2Array:
		var hw := maxf(w * 0.5, 0.002)
		var hd := maxf(d * 0.5, 0.002)
		var corners := [Vector2(hw, hd), Vector2(-hw, hd), Vector2(-hw, -hd), Vector2(hw, -hd)]
		var starts := [0.0, PI * 0.5, PI, PI * 1.5]
		var out := PackedVector2Array()
		for c in range(4):
			var r: float = clampf(radii[c], 0.001, minf(hw, hd) - 0.0005)
			var corner: Vector2 = corners[c]
			var center := Vector2(corner.x - signf(corner.x) * r, corner.y - signf(corner.y) * r)
			var arc := PackedVector2Array()
			for k in range(arc_points):
				var a: float = starts[c] + PI * 0.5 * k / maxf(1, arc_points - 1)
				arc.append(center + Vector2(cos(a), sin(a)) * r)
			out.append_array(arc)
			# Straight edge to the next corner's first arc point.
			var nc: Vector2 = corners[(c + 1) % 4]
			var nr: float = clampf(radii[(c + 1) % 4], 0.001, minf(hw, hd) - 0.0005)
			var ncenter := Vector2(nc.x - signf(nc.x) * nr, nc.y - signf(nc.y) * nr)
			var na: float = starts[(c + 1) % 4]
			var next_start := ncenter + Vector2(cos(na), sin(na)) * nr
			var last := arc[arc.size() - 1]
			for e in range(1, edge_points + 1):
				out.append(last.lerp(next_start, float(e) / (edge_points + 1)))
		return out

	## Evenly resamples a closed 2D outline by perimeter length.
	static func resample(points: PackedVector2Array, count: int) -> PackedVector2Array:
		var lengths := [0.0]
		for i in range(points.size()):
			lengths.append(lengths[-1] + points[i].distance_to(points[(i + 1) % points.size()]))
		var total: float = lengths[-1]
		var out := PackedVector2Array()
		var seg := 0
		for k in range(count):
			var target := total * k / count
			while lengths[seg + 1] < target:
				seg += 1
			var t: float = (target - lengths[seg]) / maxf(0.00001, lengths[seg + 1] - lengths[seg])
			out.append(points[seg].lerp(points[(seg + 1) % points.size()], t))
		return out

	## Smoothed piecewise-linear lookup through [y, value] keys sorted by y.
	static func curve(keys: Array, y: float) -> float:
		if y <= keys[0][0]:
			return keys[0][1]
		for i in range(keys.size() - 1):
			if y <= keys[i + 1][0]:
				var t: float = (y - keys[i][0]) / (keys[i + 1][0] - keys[i][0])
				return lerpf(keys[i][1], keys[i + 1][1], smoothstep(0, 1, t))
		return keys[-1][1]

## Paints flat-colour equipment graphics (panels, sweeps, pinstripes, stitch
## lines) into a texture. Shapes are polygons in face space: u 0..1 across
## (inner edge -> outer edge), v 0..1 up the piece. Drawn at 2x with native
## span fills, then downsampled, so every edge is anti-aliased.
class Graphic:
	const SS := 2
	var image: Image
	var width := 0
	var height := 0

	func _init(w: int, h: int, base: Color) -> void:
		width = w
		height = h
		image = Image.create(w * SS, h * SS, false, Image.FORMAT_RGBA8)
		image.fill(base)
		# The blank strip stays white for untextured geometry.
		image.fill_rect(Rect2i(0, int(FACE_V * h * SS), w * SS, h * SS - int(FACE_V * h * SS)), Color.WHITE)

	func px(p: Vector2) -> Vector2:
		return Vector2(p.x * width * SS, (1.0 - p.y) * FACE_V * height * SS)

	## Scanline polygon fill (even-odd), spans written with fill_rect.
	func poly(points: Array, color: Color) -> void:
		var pts: Array[Vector2] = []
		var top := INF
		var bottom := -INF
		for p: Vector2 in points:
			var q := px(p)
			pts.append(q)
			top = minf(top, q.y)
			bottom = maxf(bottom, q.y)
		var limit := int(FACE_V * height * SS)
		for row in range(maxi(0, int(floor(top))), mini(limit, int(ceil(bottom)))):
			var y := row + 0.5
			var xs: Array[float] = []
			for i in range(pts.size()):
				var a := pts[i]
				var b := pts[(i + 1) % pts.size()]
				if (a.y <= y and b.y > y) or (b.y <= y and a.y > y):
					xs.append(a.x + (y - a.y) / (b.y - a.y) * (b.x - a.x))
			xs.sort()
			for k in range(0, xs.size() - 1, 2):
				var x0 := clampi(int(round(xs[k])), 0, width * SS)
				var x1 := clampi(int(round(xs[k + 1])), 0, width * SS)
				if x1 > x0:
					image.fill_rect(Rect2i(x0, row, x1 - x0, 1), color)

	func rect(u0: float, v0: float, u1: float, v1: float, color: Color) -> void:
		poly([Vector2(u0, v0), Vector2(u1, v0), Vector2(u1, v1), Vector2(u0, v1)], color)

	## A band of constant width (in u units) along a polyline.
	func stripe(path: Array, half_width: float, color: Color) -> void:
		for i in range(path.size() - 1):
			var a: Vector2 = path[i]
			var b: Vector2 = path[i + 1]
			var d := (b - a).normalized()
			var n := Vector2(-d.y, d.x) * half_width
			poly([a + n, b + n, b - n, a - n], color)

	## Dashed stitch line.
	func stitches(a: Vector2, b: Vector2, half_width: float, color: Color, dashes := 24) -> void:
		for k in range(dashes):
			var t0 := float(k) / dashes
			var t1 := t0 + 0.55 / dashes
			stripe([a.lerp(b, t0), a.lerp(b, t1)], half_width, color)

	func texture() -> ImageTexture:
		var out := image.duplicate()
		out.resize(width, height, Image.INTERPOLATE_LANCZOS)
		out.generate_mipmaps()
		return ImageTexture.create_from_image(out)

## One painted texture per piece and colourway, shared by every goalie.
static var _graphics := {}

static func _cached(key: String, painter: Callable) -> Texture2D:
	if not _graphics.has(key):
		_graphics[key] = painter.call()
	return _graphics[key]

## Face-space (u across, v up, both 0..1) to texture UV.
static func face_uv(u: float, v: float) -> Vector2:
	return Vector2(clampf(u, 0.0, 1.0), (1.0 - clampf(v, 0.0, 1.0)) * FACE_V)

static func _band(y: float, at: float, half: float) -> float:
	return 1.0 - smoothstep(half * 0.5, half, absf(y - at))

# ---------------------------------------------------------------- leg pads
## Local frame: +Y runs up the shin, +Z is the pad face toward the shooter,
## +X*side is the outside of the leg. Origin is the collision-box centre; the
## knee sits at y = PAD_KNEE and the ankle at y = PAD_ANKLE.
## Like a real pad, the bottom rests on the skate (toe cap and blade show
## below it) and the boot channel stands off the laces.
const PAD_LENGTH := 0.73
const PAD_WIDTH := 0.275
const PAD_KNEE := 0.035
const PAD_ANKLE := -0.395
## The thigh-rise section hinges at this break above the knee.
const PAD_BREAK := PAD_KNEE + 0.115

## Builds the pad between y_from and y_to (default: whole pad), so the
## thigh rise can be a separate hinged piece.
static func goalie_pad(side: float, kit: Color, accent: Color, y_from := -1.0, y_to := 1.0) -> ArrayMesh:
	var b := MeshBuilder.new()
	var rings := []
	var ring_colors := []
	var ring_uvs := []
	var top := PAD_LENGTH * 0.5
	var bottom := -PAD_LENGTH * 0.5
	var ys := []
	var y := bottom
	while y < top:
		if y >= y_from and y <= y_to:
			ys.append(y)
		y += 0.008 if (y < bottom + 0.05 or y > top - 0.05) else 0.011
	ys.append(minf(top, y_to))
	if y_from > bottom:
		ys.push_front(y_from)
	var grooves := [PAD_KNEE + 0.115, PAD_KNEE - 0.055, PAD_ANKLE + 0.115]
	for yy: float in ys:
		var w := PAD_WIDTH
		# Thigh rise tapers a little toward its rounded top; the boot end narrows.
		w -= smoothstep(top - 0.16, top, yy) * 0.035
		w -= smoothstep(bottom + 0.10, bottom, yy) * 0.02
		# Face stands proud at the knee (knee roll) and has stitched breaks.
		var front := 0.058 + 0.010 * exp(-pow((yy - PAD_KNEE) / 0.07, 2))
		var back := -0.040
		var groove := 0.0
		for g: float in grooves:
			groove = maxf(groove, _band(yy, g, 0.012))
		front -= groove * 0.011
		# Rounded top and toe tip.
		var round_ := 1.0
		if yy > top - 0.045:
			round_ = sqrt(maxf(0.04, 1.0 - pow((yy - (top - 0.045)) / 0.045, 2)))
		elif yy < bottom + 0.035:
			round_ = sqrt(maxf(0.04, 1.0 - pow((bottom + 0.035 - yy) / 0.035, 2)))
		# Boot channel / toe bridge: the bottom sweeps forward over the skate toe.
		var toe := 0.07 * smoothstep(PAD_ANKLE + 0.25, PAD_ANKLE + 0.06, yy) + 0.014 * smoothstep(bottom + 0.05, bottom, yy)
		var d := (front - back) * round_
		var mid := (front + back) * 0.5
		var profile := GearProfiles.rounded_rect(w * lerpf(0.55, 1.0, round_), d, [0.026, 0.010, 0.016, 0.016], 5, 12)
		var ring := PackedVector3Array()
		var cols := PackedColorArray()
		var uv_ring := PackedVector2Array()
		var hw := w * 0.5
		for p in profile:
			var outer := p.x  # positive = outside of the leg
			var z := mid + p.y
			var is_front := p.y > d * 0.5 - 0.012
			if is_front:
				# Foam pillows gently between the face's vertical stitch lines and
				# the face crowns slightly toward the outer roll.
				z += 0.005 * (1.0 - pow(clampf(outer / (hw - 0.03), -1, 1), 2)) * round_
				z -= 0.003 * (_band(outer, -hw / 3.0, 0.007) + _band(outer, hw / 3.0, 0.007)) * round_
			ring.append(Vector3(outer * side, yy, z + toe))
			var col := WHITE
			if is_front:
				col = WHITE.lerp(LINE, groove * 0.55)
				uv_ring.append(face_uv(outer / w + 0.5, (yy - bottom) / PAD_LENGTH))
			else:
				uv_ring.append(BLANK_UV)
				if outer > hw - 0.02:
					col = kit
				elif outer < -(hw - 0.02):
					col = OFFWHITE
				else:
					col = DARK
			cols.append(col)
		rings.append(ring)
		ring_colors.append(cols)
		ring_uvs.append(uv_ring)
	b.add_loft(rings, ring_colors, true, true, ring_uvs)
	# Outer roll: the raised tube along the outside edge of the face that seals
	# against the post and turns pucks away from the five-hole.
	var roll := PackedVector3Array()
	var roll_from := maxf(bottom + 0.06, y_from)
	var roll_to := minf(top - 0.06, y_to)
	for k in range(13):
		var ry := lerpf(roll_from, roll_to, k / 12.0)
		var rw := PAD_WIDTH - smoothstep(top - 0.16, top, ry) * 0.035 - smoothstep(bottom + 0.10, bottom, ry) * 0.02
		var rtoe := 0.07 * smoothstep(PAD_ANKLE + 0.25, PAD_ANKLE + 0.06, ry)
		roll.append(Vector3((rw * 0.5 - 0.016) * side, ry, 0.050 + 0.010 * exp(-pow((ry - PAD_KNEE) / 0.07, 2)) + rtoe))
	b.add_tube(roll, 0.019, kit, 12)
	var graphic := _cached("pad|%s|%s" % [kit.to_html(), accent.to_html()], func(): return _paint_pad(kit, accent))
	# Knee stack (inside), calf wing (outside) and leg straps behind the face.
	if y_from > bottom:
		b.add_rounded_box(Vector3(0, PAD_KNEE + 0.17, -0.12), Vector3(0.20, 0.028, 0.012), 0.005, DARK)
		return b.to_mesh(0.52, graphic)
	b.add_rounded_box(Vector3(-side * 0.055, PAD_KNEE - 0.01, -0.085), Vector3(0.12, 0.17, 0.09), 0.03, OFFWHITE)
	# Calf wing and straps stay above the skate boot.
	b.add_rounded_box(Vector3(side * 0.118, (PAD_ANKLE + 0.20 + PAD_KNEE) * 0.5, -0.072), Vector3(0.026, PAD_KNEE - PAD_ANKLE - 0.20, 0.07), 0.011, kit)
	for sy: float in [PAD_ANKLE + 0.21, PAD_KNEE - 0.12]:
		b.add_rounded_box(Vector3(0, sy, -0.12), Vector3(0.20, 0.028, 0.012), 0.005, DARK)
	return b.to_mesh(0.52, graphic)

## Pad face graphic, modern pro style: white face, kit outer edge, a kit boot
## sweep with an accent pinstripe, a knee window, kit thigh-rise cap, accent
## pinstripe up the face and stitched breaks. Generic, no marks or logos.
static func _paint_pad(kit: Color, accent: Color) -> Texture2D:
	var g := Graphic.new(256, 704, WHITE)
	var v := func(y: float) -> float: return (y + PAD_LENGTH * 0.5) / PAD_LENGTH
	var vk: float = v.call(PAD_KNEE)
	var stitch := WHITE.darkened(0.16)
	# Vertical face stitching (behind the panels).
	for u in [1.0 / 3.0, 2.0 / 3.0]:
		g.stitches(Vector2(u, 0.02), Vector2(u, 0.985), 0.004, stitch, 70)
	# Boot sweep and its pinstripe.
	g.poly([Vector2(0, 0), Vector2(1, 0), Vector2(1, 0.27), Vector2(0, 0.11)], kit)
	g.stripe([Vector2(-0.05, 0.135), Vector2(1.05, 0.305)], 0.011, accent)
	# Knee window with an accent insert on the inside.
	g.poly([Vector2(0, vk - 0.075), Vector2(1, vk - 0.05), Vector2(1, vk + 0.085), Vector2(0, vk + 0.06)], kit)
	g.poly([Vector2(0, vk - 0.035), Vector2(0.30, vk - 0.028), Vector2(0.30, vk + 0.048), Vector2(0, vk + 0.042)], accent)
	# Thigh-rise cap and its pinstripe.
	g.rect(0, 0.935, 1, 1, kit)
	g.rect(0, 0.912, 1, 0.922, accent)
	# Pinstripe up the face from the knee window to the cap.
	g.rect(0.60, vk + 0.085, 0.625, 0.912, accent)
	# Outer edge band, behind the outer roll.
	g.rect(0.88, 0, 1, 1, kit)
	# Stitched horizontal breaks at the knee and boot.
	for y in [PAD_KNEE + 0.115, PAD_KNEE - 0.055, PAD_ANKLE + 0.115]:
		g.rect(0, v.call(y) - 0.003, 1, v.call(y) + 0.003, LINE)
	return g.texture()

# ---------------------------------------------------------------- blocker
## Origin at the board centre; +Z faces the shooter; +X*side is away from the body.
const BLOCKER_SIZE := Vector3(0.205, 0.385, 0.034)

static func blocker(side: float, kit: Color, accent: Color) -> ArrayMesh:
	var b := MeshBuilder.new()
	var rings := []
	var ring_colors := []
	var ring_uvs := []
	var hl := BLOCKER_SIZE.y * 0.5
	var y := -hl
	var ys := []
	while y < hl:
		ys.append(y)
		y += 0.008
	ys.append(hl)
	for yy: float in ys:
		var round_ := 1.0
		if yy > hl - 0.02:
			round_ = sqrt(maxf(0.05, 1.0 - pow((yy - (hl - 0.02)) / 0.02, 2)))
		elif yy < -hl + 0.02:
			round_ = sqrt(maxf(0.05, 1.0 - pow((-hl + 0.02 - yy) / 0.02, 2)))
		# The top of the board curls toward the shooter to steer deflections.
		var curl := pow(maxf(0, yy - 0.09) / (hl - 0.09), 2) * 0.034
		var w := BLOCKER_SIZE.x * lerpf(0.75, 1.0, round_)
		var profile := GearProfiles.rounded_rect(w, BLOCKER_SIZE.z * round_, [0.012, 0.012, 0.012, 0.012], 5, 12)
		var ring := PackedVector3Array()
		var cols := PackedColorArray()
		var uv_ring := PackedVector2Array()
		for p in profile:
			var outer := p.x
			# Slightly dished face.
			var dish := 0.006 * (1.0 - pow(outer / (w * 0.5), 2)) if p.y > 0 else 0.0
			ring.append(Vector3(outer * side, yy, p.y - dish + curl))
			var col := WHITE
			if p.y > BLOCKER_SIZE.z * 0.5 - 0.006:
				uv_ring.append(face_uv(outer / BLOCKER_SIZE.x + 0.5, (yy + hl) / BLOCKER_SIZE.y))
			else:
				uv_ring.append(BLANK_UV)
				col = DARK.lerp(WHITE, 0.15) if p.y < 0 else kit
			cols.append(col)
		rings.append(ring)
		ring_colors.append(cols)
		ring_uvs.append(uv_ring)
	b.add_loft(rings, ring_colors, true, true, ring_uvs)
	# Raised finger-protection sidewall along the body side of the board.
	var wall := PackedVector3Array()
	for k in range(9):
		var wy := lerpf(-hl + 0.03, hl - 0.05, k / 8.0)
		wall.append(Vector3(-side * (BLOCKER_SIZE.x * 0.5 - 0.004), wy, 0.016 + pow(maxf(0, wy - 0.09) / (hl - 0.09), 2) * 0.034))
	b.add_tube(wall, 0.014, kit.lightened(0.06), 10)
	# Palm glove and cuff behind the board, hand on the stick.
	b.add_rounded_box(Vector3(-side * 0.03, -0.03, -0.055), Vector3(0.10, 0.14, 0.075), 0.032, DARK)
	b.add_rounded_box(Vector3(-side * 0.02, -0.22, -0.035), Vector3(0.12, 0.11, 0.095), 0.035, OFFWHITE)
	b.add_rounded_box(Vector3(-side * 0.02, -0.17, -0.035), Vector3(0.125, 0.022, 0.10), 0.01, kit)
	var graphic := _cached("blocker|%s|%s" % [kit.to_html(), accent.to_html()], func(): return _paint_blocker(kit, accent))
	return b.to_mesh(0.55, graphic)

## Blocker face: white board with a kit border, a bold diagonal kit sweep with
## an accent pinstripe and a kit corner block at the top outside.
static func _paint_blocker(kit: Color, accent: Color) -> Texture2D:
	var g := Graphic.new(256, 480, WHITE)
	g.poly([Vector2(0, 0.10), Vector2(1, 0.52), Vector2(1, 0.70), Vector2(0, 0.28)], kit)
	g.stripe([Vector2(-0.05, 0.315), Vector2(1.05, 0.745)], 0.014, accent)
	g.stripe([Vector2(-0.05, 0.065), Vector2(1.05, 0.485)], 0.010, accent)
	g.poly([Vector2(0.62, 1), Vector2(1, 1), Vector2(1, 0.83)], kit)
	# Border binding all the way round.
	g.rect(0, 0, 1, 0.045, kit)
	g.rect(0, 0.955, 1, 1, kit)
	g.rect(0, 0, 0.07, 1, kit)
	g.rect(0.93, 0, 1, 1, kit)
	return g.texture()

# ---------------------------------------------------------------- catcher
## Origin at the hand; the pocket opens toward +Z; +X*side is the finger side.
const CATCHER_SIZE := Vector3(0.28, 0.43, 0.11)

static func catcher(side: float, kit: Color, accent: Color) -> ArrayMesh:
	var b := MeshBuilder.new()
	var outline := PackedVector2Array([
		Vector2(-0.02, -0.18), Vector2(0.06, -0.175), Vector2(0.12, -0.13), Vector2(0.148, -0.05),
		Vector2(0.158, 0.05), Vector2(0.152, 0.14), Vector2(0.13, 0.205), Vector2(0.095, 0.24),
		Vector2(0.055, 0.25), Vector2(0.03, 0.232), Vector2(0.008, 0.212), Vector2(-0.018, 0.226),
		Vector2(-0.055, 0.238), Vector2(-0.095, 0.22), Vector2(-0.118, 0.165), Vector2(-0.126, 0.085),
		Vector2(-0.118, 0.0), Vector2(-0.102, -0.08), Vector2(-0.072, -0.15)])
	outline = GearProfiles.resample(outline, 72)
	# The pocket is a deep well high in the mitt, between the thumb and the
	# finger roll under the T; the palm below it is a padded, nearly flat face.
	var center := Vector2(0.012, 0.115)
	# [scale toward outline, depth] from pocket centre, over the rim, to the back.
	var sections := [[0.02, -0.058], [0.14, -0.052], [0.28, -0.030], [0.40, -0.002], [0.52, 0.016],
		[0.66, 0.026], [0.80, 0.033], [0.92, 0.042], [0.975, 0.049], [1.0, 0.042], [1.014, 0.024],
		[0.995, -0.022], [0.95, -0.042], [0.82, -0.058], [0.58, -0.067], [0.30, -0.071], [0.02, -0.071]]
	var rings := []
	var ring_colors := []
	for i in range(sections.size()):
		var s: float = sections[i][0]
		var z: float = sections[i][1]
		var ring := PackedVector3Array()
		var cols := PackedColorArray()
		for p in outline:
			var q := center + (p - center) * s
			ring.append(Vector3(q.x * side, q.y, z))
			var col := WHITE
			if i <= 2:
				# Pocket leather, darker with use.
				col = OFFWHITE.darkened(0.16)
			elif i <= 7:
				# Padded white palm face around the pocket.
				col = WHITE
			elif i <= 11:
				col = kit
			else:
				col = WHITE
				if q.y < -0.06 and q.y > -0.11:
					col = kit
				elif absf(q.x * 0.8 + q.y * 0.5 - 0.03) < 0.014:
					col = accent
			cols.append(col)
		rings.append(ring)
		ring_colors.append(cols)
	b.add_loft(rings, ring_colors)
	# Finger section: a thick padded roll up the outside of the mitt and over
	# the top to the T, the silhouette shooters see first.
	var finger := PackedVector3Array([
		Vector3(0.140, -0.13, 0.030), Vector3(0.156, -0.05, 0.040), Vector3(0.160, 0.05, 0.046),
		Vector3(0.152, 0.13, 0.048), Vector3(0.130, 0.195, 0.048), Vector3(0.095, 0.235, 0.046),
		Vector3(0.055, 0.250, 0.044), Vector3(0.025, 0.244, 0.042)])
	for k in range(finger.size()):
		finger[k].x *= side
	b.add_tube(finger, 0.030, kit.lightened(0.04), 14)
	# Finger stitching ridges across the roll.
	for t: float in [0.30, 0.48, 0.66]:
		var c := finger[int(t * (finger.size() - 1))]
		b.add_tube(PackedVector3Array([c + Vector3(-0.012 * side, 0, 0.026), c + Vector3(0.028 * side, -0.004, 0.012)]), 0.004, kit.darkened(0.25), 6)
	# Thumb: a slimmer roll up the inside, white with a kit tip.
	var thumb := PackedVector3Array([
		Vector3(-0.112, -0.09, 0.030), Vector3(-0.122, 0.0, 0.036), Vector3(-0.118, 0.09, 0.040),
		Vector3(-0.102, 0.170, 0.042), Vector3(-0.075, 0.222, 0.042)])
	for k in range(thumb.size()):
		thumb[k].x *= side
	b.add_tube(thumb, 0.023, WHITE, 12)
	b.add_tube(PackedVector3Array([thumb[3], thumb[4], thumb[4] + Vector3(0.012 * side, 0.014, 0)]), 0.0245, kit, 12)
	# T-trap: a leather T bar up the middle of the pocket, and a laced web
	# strung between the thumb tip and the finger tip.
	b.add_rounded_box(Vector3(0.010 * side, 0.150, 0.030), Vector3(0.026, 0.16, 0.012), 0.005, DARK, Basis(Vector3.RIGHT, -0.22))
	b.add_rounded_box(Vector3(0.000 * side, 0.236, 0.042), Vector3(0.11, 0.018, 0.012), 0.005, DARK)
	for k in range(5):
		var x := lerpf(-0.062, 0.050, k / 4.0)
		b.add_tube(PackedVector3Array([Vector3(x * side, 0.206, 0.040), Vector3((x + 0.008) * side, 0.252, 0.046)]), 0.0045, LACE, 6)
	for yy: float in [0.212, 0.250]:
		b.add_tube(PackedVector3Array([Vector3(-0.070 * side, yy, 0.040), Vector3(0.0, yy + 0.004, 0.046), Vector3(0.060 * side, yy, 0.042)]), 0.0045, LACE, 6)
	# Cuff and cheater: the flat padded panel down the wrist on the thumb side,
	# carrying the glove's graphic toward the shooter.
	b.add_panel(Vector3(-0.030 * side, -0.215, -0.018), Vector2(0.17, 0.15), 0.052, 0.03, Basis(Vector3.BACK, 0.10 * side), WHITE, kit, OFFWHITE)
	var graphic := _cached("catcher|%s|%s" % [kit.to_html(), accent.to_html()], func(): return _paint_cheater(kit, accent))
	return b.to_mesh(0.55, graphic)

## Catcher cuff/cheater panel graphic: kit binding, a kit sweep and an accent
## pinstripe on white, matching the blocker and pads.
static func _paint_cheater(kit: Color, accent: Color) -> Texture2D:
	var g := Graphic.new(256, 256, WHITE)
	g.poly([Vector2(0, 0), Vector2(1, 0), Vector2(1, 0.32), Vector2(0, 0.62)], kit)
	g.stripe([Vector2(-0.05, 0.69), Vector2(1.05, 0.37)], 0.022, accent)
	g.rect(0, 0.93, 1, 1, kit)
	g.rect(0, 0, 0.06, 1, kit)
	g.rect(0.94, 0, 1, 1, kit)
	return g.texture()

# ---------------------------------------------------------------- goalie mask
## Fibreglass shell with a protruding chin, recessed face opening and cat-eye cage.
## Origin near eye level; +Z faces forward.
static func goalie_mask(kit: Color, accent: Color) -> ArrayMesh:
	var b := MeshBuilder.new()
	var width_keys := [[-0.175, 0.035], [-0.14, 0.078], [-0.10, 0.100], [-0.04, 0.114], [0.02, 0.118], [0.09, 0.102], [0.13, 0.065], [0.15, 0.02]]
	var front_keys := [[-0.175, 0.070], [-0.14, 0.150], [-0.10, 0.153], [-0.03, 0.142], [0.03, 0.137], [0.09, 0.112], [0.13, 0.065], [0.15, 0.02]]
	var back_keys := [[-0.175, 0.025], [-0.15, 0.055], [-0.11, 0.095], [-0.06, 0.122], [0.0, 0.135], [0.08, 0.118], [0.13, 0.07], [0.15, 0.02]]
	var rings := []
	var ring_colors := []
	var count := 56
	var y := -0.175
	while y <= 0.1501:
		var ring := PackedVector3Array()
		var cols := PackedColorArray()
		var w := GearProfiles.curve(width_keys, y)
		var f := GearProfiles.curve(front_keys, y)
		var bk := GearProfiles.curve(back_keys, y)
		for k in range(count):
			var a := TAU * k / count - PI
			var cz := cos(a)
			var p := Vector3(sin(a) * w, y, cz * (f if cz > 0 else bk))
			# Face opening: recessed and shadowed behind the cage.
			var opening := smoothstep(0.80, 0.55, absf(a)) * smoothstep(-0.105, -0.085, y) * smoothstep(0.050, 0.030, y)
			p = Vector3(p.x * lerpf(1, 0.82, opening), p.y, p.z * lerpf(1, 0.55, opening))
			ring.append(p)
			var col := WHITE
			var sa := absf(sin(a))
			if sa > 0.62 and cz > -0.45 and (y + 0.03 * cos(a * 4.0)) > -0.09 and (y + 0.03 * cos(a * 4.0)) < 0.06:
				col = kit
			if sa > 0.62 and cz > -0.45 and absf(y - 0.07 + 0.02 * cos(a * 4.0)) < 0.010:
				col = accent
			if sa < 0.16 and y > 0.055 and cz > 0:
				col = kit
			if cz < -0.35 and absf(y - 0.02) < 0.006:
				col = LINE  # backplate seam
			if opening > 0.35:
				col = Color("#0c1014")
			cols.append(col)
		rings.append(ring)
		ring_colors.append(cols)
		y += 0.008
	b.add_loft(rings, ring_colors)
	# Cat-eye cage that follows the front of the shell.
	var cage_point := func(a: float, yy: float) -> Vector3:
		var w := GearProfiles.curve(width_keys, yy)
		var f := GearProfiles.curve(front_keys, yy)
		return Vector3(sin(a) * w * 1.04, yy, cos(a) * f * 1.04 + 0.010)
	for yy: float in [0.038, -0.004, -0.045, -0.088]:
		var bar := PackedVector3Array()
		for k in range(13):
			bar.append(cage_point.call(lerpf(-0.82, 0.82, k / 12.0), yy))
		b.add_tube(bar, 0.0045, METAL, 6)
	for a: float in [-0.26, 0.26]:
		var bar := PackedVector3Array()
		for k in range(9):
			bar.append(cage_point.call(a, lerpf(-0.004, -0.092, k / 8.0)))
		b.add_tube(bar, 0.0045, METAL, 6)
	for s: float in [-1.0, 1.0]:
		# Cat-eye bars rise diagonally beside each eye.
		var bar := PackedVector3Array()
		for k in range(7):
			var t := k / 6.0
			bar.append(cage_point.call(s * lerpf(0.12, 0.62, t), lerpf(-0.004, 0.040, t)))
		b.add_tube(bar, 0.0045, METAL, 6)
	return b.to_mesh(0.28)

# ---------------------------------------------------------------- skater gloves
## Skater hockey glove closed around the stick. Origin is the grip (the shaft
## runs through it along local X); +Y runs up the forearm to the cuff, +Z is
## the back of the hand. Padded backhand rolls, four joined finger rolls that
## curl round the shaft, a thumb with a stiff thumb lock, and a flared gauntlet
## cuff with a rolled lip. `side` mirrors the thumb (+1: thumb toward +X).
const GLOVE_CUFF_TOP := 0.175
static func skater_glove(kit: Color, side := 1.0) -> ArrayMesh:
	var b := MeshBuilder.new()
	var dark := Color("#18232c")
	var roll := kit.darkened(0.25)
	var cuff := kit.lightened(0.08)
	# Leather palm core inside the fist.
	b.add_capsule(PackedVector3Array([Vector3(-0.034, 0.005, -0.002), Vector3(0.034, 0.005, -0.002)]), [0.040, 0.040], dark, 16, 0.85, Vector3.BACK)
	# Gauntlet cuff: an open, flared shell with a rolled lip, wider at the top.
	var rings := []
	var cols := []
	var levels := [[0.035, 0.052, 0.046], [0.06, 0.059, 0.053], [0.10, 0.065, 0.059], [0.14, 0.070, 0.063], [GLOVE_CUFF_TOP, 0.073, 0.066], [GLOVE_CUFF_TOP + 0.008, 0.076, 0.069], [GLOVE_CUFF_TOP + 0.010, 0.068, 0.061], [GLOVE_CUFF_TOP - 0.01, 0.062, 0.055]]
	for k in range(levels.size()):
		var l: Array = levels[k]
		var ring := PackedVector3Array()
		var c := PackedColorArray()
		for j in range(28):
			var a := TAU * j / 28
			var square := 1.0 + 0.08 * pow(sin(2.0 * a), 2)
			var cx := cos(a) * square
			var sz := sin(a) * square
			# Cuff padding segments: two shallow vertical seams on the back.
			var seam := 1.0 - 0.06 * exp(-pow((cx - 0.35) / 0.08, 2)) * float(sz > 0) - 0.06 * exp(-pow((cx + 0.35) / 0.08, 2)) * float(sz > 0)
			ring.append(Vector3(cx * l[1] * seam, l[0], sz * l[2] * seam + 0.004))
			c.append(WHITE if k == 4 else cuff)
		rings.append(ring)
		cols.append(c)
	b.add_loft(rings, cols, true, false)
	# Backhand: two padded rolls across the back of the hand, and a wrist roll.
	for row: Array in [[0.036, 0.038, 0.020], [0.000, 0.044, 0.022], [-0.034, 0.042, 0.020]]:
		var pts := PackedVector3Array()
		for k in range(5):
			var x := lerpf(-0.044, 0.044, k / 4.0)
			pts.append(Vector3(x, row[0], row[1] - 0.010 * pow(x / 0.044, 2)))
		b.add_capsule(pts, [row[2] * 0.85, row[2], row[2], row[2], row[2] * 0.85], kit if row[0] > 0.02 else roll, 18, 0.72, Vector3.BACK)
	# Fingers: four rounded, touching rolls curling down round the shaft.
	for i in range(4):
		var x := lerpf(-0.036, 0.036, i / 3.0) * side
		var r := 0.0150 - 0.0010 * absf(i - 1.0)
		var length := 1.0 - 0.10 * absf(i - 1.2)
		var pts := PackedVector3Array([Vector3(x, -0.050, 0.034), Vector3(x, -0.070, 0.012 * length), Vector3(x, -0.066, -0.022 * length), Vector3(x, -0.044, -0.042 * length), Vector3(x, -0.016, -0.046 * length)])
		var rad := [r * 1.12, r * 1.08, r, r * 0.96, r * 0.92]
		b.add_capsule(pts, rad, roll, 16, 1.0, Vector3.RIGHT)
	# Thumb with its stiff thumb lock along the outside of the index finger.
	var tx := 0.056 * side
	b.add_capsule(PackedVector3Array([Vector3(tx, 0.020, 0.010), Vector3(tx + 0.006 * side, -0.016, 0.006), Vector3(tx, -0.044, -0.012), Vector3(tx * 0.72, -0.050, -0.034)]), [0.019, 0.018, 0.016, 0.014], roll, 16, 0.9, Vector3.RIGHT * side)
	b.add_capsule(PackedVector3Array([Vector3(tx + 0.010 * side, 0.034, 0.018), Vector3(tx + 0.016 * side, -0.010, 0.020)]), [0.015, 0.013], kit, 16, 0.75, Vector3.RIGHT * side)
	return b.to_mesh(0.62)

# ---------------------------------------------------------------- skates
## Boot, tendon guard, plastic holder and steel runner; +Z toward the toe.
## Origin 5 cm below the ankle joint. With with_cuff false only the foot part
## is built (sole, toe box, heel cup, holder, runner): skaters get the ankle
## cuff as a separate mesh (skate_cuff) that follows the shin, so the leg
## always goes down into the boot instead of leaning out of a rigid box.
static func skate(goalie: bool, with_cuff := true) -> ArrayMesh:
	var b := MeshBuilder.new()
	var boot := Color("#12191f")
	var quarter := Color("#1c252d")
	# Toe box and forefoot, low and rounded.
	b.add_rounded_box(Vector3(0, 0.032, 0.085), Vector3(0.096, 0.068, 0.25), 0.033, boot)
	b.add_rounded_box(Vector3(0, 0.026, 0.19), Vector3(0.088, 0.054, 0.07), 0.026, quarter)
	# Heel cup and quarter panels up to the ankle; the cuff sits on top of it.
	b.add_rounded_box(Vector3(0, 0.058, -0.005), Vector3(0.104, 0.096, 0.15), 0.04, boot)
	# Outsole edge where the boot meets the holder.
	b.add_rounded_box(Vector3(0, -0.002, 0.07), Vector3(0.094, 0.012, 0.29), 0.005, Color("#3a434b"))
	if with_cuff:
		b.add_rounded_box(Vector3(0, 0.12, 0.0), Vector3(0.105, 0.17, 0.14), 0.04, boot)
		b.add_rounded_box(Vector3(0, 0.19, -0.065), Vector3(0.05, 0.10, 0.03), 0.013, Color("#2a333a"))
		b.add_rounded_box(Vector3(0, 0.11, 0.07), Vector3(0.07, 0.11, 0.07), 0.025, Color("#d4d9dc"))
	if goalie:
		b.add_rounded_box(Vector3(0, -0.015, 0.07), Vector3(0.06, 0.035, 0.30), 0.012, Color("#d9dee1"))
	else:
		# Holder: two towers joined by a bridge, as on a real skate.
		var holder := Color("#d9dee1")
		b.add_rounded_box(Vector3(0, -0.013, -0.04), Vector3(0.034, 0.03, 0.07), 0.010, holder)
		b.add_rounded_box(Vector3(0, -0.013, 0.17), Vector3(0.034, 0.03, 0.08), 0.010, holder)
		b.add_rounded_box(Vector3(0, -0.026, 0.065), Vector3(0.022, 0.012, 0.27), 0.005, holder)
	b.add_rounded_box(Vector3(0, -0.045, 0.07), Vector3(0.006, 0.03, 0.31), 0.002, METAL.lightened(0.2))
	return b.to_mesh(0.4)

## Ankle cuff of a player skate. Origin at the ankle joint, +Y up the shin,
## +Z forward (toe side). Overlaps down into the heel cup of skate(false).
static func skate_cuff() -> ArrayMesh:
	var b := MeshBuilder.new()
	var boot := Color("#12191f")
	# Shell: one smooth rounded-square tube from the heel up the lower shin
	# (top to bottom, like _limb), slightly fuller at the ankle bones.
	var rings := []
	var cols := []
	var levels := [[0.140, 0.060, 0.066, -0.012], [0.120, 0.061, 0.069, -0.010], [0.08, 0.060, 0.072, -0.006],
		[0.03, 0.060, 0.075, 0.002], [-0.015, 0.057, 0.074, 0.008], [-0.03, 0.053, 0.068, 0.012]]
	for k in range(levels.size()):
		var l: Array = levels[k]
		var ring := PackedVector3Array()
		var c := PackedColorArray()
		for j in range(24):
			var a := TAU * j / 24
			# Superellipse: square-ish sides with rounded corners.
			var cx := signf(cos(a)) * pow(absf(cos(a)), 0.7)
			var sz := signf(sin(a)) * pow(absf(sin(a)), 0.7)
			ring.append(Vector3(cx * l[1], l[0], sz * l[2] + l[3]))
			c.append(Color("#252e36") if k == 0 else boot)
		rings.append(ring)
		cols.append(c)
	b.add_loft(rings, cols, false, true)
	# Tendon guard rising from the back, following the calf.
	b.add_rounded_box(Vector3(0, 0.15, -0.074), Vector3(0.046, 0.07, 0.018), 0.008, Color("#20282f"), Basis(Vector3.RIGHT, -0.15))
	# Felt tongue: a thin flap rising out of the laces, tipped forward.
	b.add_rounded_box(Vector3(0, 0.15, 0.058), Vector3(0.07, 0.07, 0.012), 0.006, Color("#b9c0c5"), Basis(Vector3.RIGHT, 0.28))
	# Laces across the front of the shell.
	for k in range(5):
		b.add_rounded_box(Vector3(0, -0.02 + k * 0.028, 0.066), Vector3(0.062, 0.006, 0.012), 0.003, Color("#e6e9eb"))
	return b.to_mesh(0.45)

# ---------------------------------------------------------------- limb shells
## Unit-length shells built along +Y (0 at the top joint, 1 at the bottom joint);
## the player scales Y to the bone length every frame. +Z faces forward.
static func _limb(radii: Array, depth_ratio: float, color_at: Callable, sides := 20) -> ArrayMesh:
	var b := MeshBuilder.new()
	var rings := []
	var ring_colors := []
	for k in range(radii.size()):
		var t: float = float(k) / (radii.size() - 1)
		var r: float = radii[k]
		var ring := PackedVector3Array()
		var cols := PackedColorArray()
		for s in range(sides):
			var a := TAU * s / sides
			ring.append(Vector3(cos(a) * r, -t, sin(a) * r * depth_ratio))
			cols.append(color_at.call(t, a))
		rings.append(ring)
		ring_colors.append(cols)
	b.add_loft(rings, ring_colors)
	return b.to_mesh(0.8)

## Padded hockey pants (breezers) over the thigh: unit length along -Y like
## _limb (0 at the waist, 1 at the hem above the knee), +Z forward, +X*side
## outward. Waist belt line, hip pad roll on the outside, a seat that fills
## out behind, a raised thigh guard down the front, quilted padding breaks,
## a flatter inner leg and a hem that flares over the knee with a rolled lip.
const PANTS_RINGS := 26
const PANTS_SIDES := 36
static func pants_leg(side: float, kit: Color, base: Color, flare := 1.0) -> ArrayMesh:
	var b := MeshBuilder.new()
	# flare 0: goalie pants taper in above the pads' thigh rises.
	var base_r := [[0.0, 0.100], [0.06, 0.116], [0.16, 0.132], [0.32, 0.136], [0.55, 0.131], [0.75, lerpf(0.114, 0.122, flare)], [0.86, lerpf(0.105, 0.119, flare)], [0.95, lerpf(0.099, 0.126, flare)], [1.0, lerpf(0.097, 0.128, flare)]]
	var rings := []
	var ring_colors := []
	var ts := []
	for k in range(PANTS_RINGS - 2):
		ts.append(float(k) / (PANTS_RINGS - 3))
	for t: float in ts:
		var r0 := GearProfiles.curve(base_r, t)
		var ring := PackedVector3Array()
		var cols := PackedColorArray()
		for s in range(PANTS_SIDES):
			var a := TAU * s / PANTS_SIDES
			var outer := cos(a) * side
			var front := sin(a)
			var r := r0
			# Hip pad roll high on the outside and the seat filling out behind.
			r += 0.009 * pow(maxf(0.0, outer), 2) * _band(t, 0.13, 0.14)
			r += 0.007 * maxf(0.0, -front) * smoothstep(0.45, 0.10, t)
			# Thigh guard: a raised plate down the front of the thigh.
			r += 0.011 * smoothstep(0.25, 0.75, front) * smoothstep(0.18, 0.32, t) * smoothstep(0.82, 0.68, t)
			# Outer thigh plate under the stripe.
			r += 0.006 * smoothstep(0.5, 0.95, outer) * smoothstep(0.2, 0.3, t) * smoothstep(0.85, 0.7, t)
			# Inner leg lies flatter against its partner.
			r *= 1.0 - 0.12 * pow(maxf(0.0, -outer), 2.0)
			# Quilted padding breaks and the belt line at the waist.
			r -= 0.0045 * (_band(t, 0.20, 0.022) + _band(t, 0.50, 0.022)) * (0.4 + 0.6 * maxf(0.0, front))
			r += 0.004 * _band(t, 0.045, 0.03)
			# Vertical front pleats where the thigh guard meets the side.
			r -= 0.003 * exp(-pow((front - 0.55) / 0.08, 2)) * smoothstep(0.15, 0.3, t) * smoothstep(0.9, 0.75, t)
			ring.append(Vector3(cos(a) * r, -t, front * r * 0.94))
			var col := base
			if outer > 0.93 and t > 0.08 and t < 0.97: col = kit
			elif t > 0.94: col = base.lightened(0.12)
			elif _band(t, 0.045, 0.03) > 0.5: col = base.lightened(0.05)
			cols.append(col)
		rings.append(ring)
		ring_colors.append(cols)
	# Rolled hem lip turning back in under the flare.
	var last: PackedVector3Array = rings[-1]
	for step: Array in [[0.012, 0.92], [0.020, 0.86]]:
		var ring := PackedVector3Array()
		for p in last:
			ring.append(Vector3(p.x * step[1], p.y + step[0], p.z * step[1]))
		rings.append(ring)
		var cols := PackedColorArray()
		cols.resize(PANTS_SIDES)
		cols.fill(base.lightened(0.12))
		ring_colors.append(cols)
	b.add_loft(rings, ring_colors, true, true)
	return b.to_mesh(0.8)

# ---------------------------------------------------------------- skater helmet
## Modern skater helmet shell, sized to the base human's head (skull about
## 16 cm wide and 20 cm front to back; helmet shells sit 2.5 cm off it).
## Origin at the centre of the skull, +Z forward (the face side), +Y up.
## Low-profile two-piece shell: a smooth, slightly flattened crown, a brow
## edge just above the eyebrows, the sides down over the tops of the ears and
## an occipital tuck at the back. Vents are shallow slots with dark inserts
## (helmet_fittings) so they read as openings, not dents.
const HELMET_W := 0.104
const HELMET_D := 0.126
const HELMET_H := 0.112
## Helmet origin relative to the head bone (rest), for skaters.
const HELMET_OFFSET := Vector3(0, 0.066, 0.004)
## Vent slots: [angle round the head (0 = front), phi down from the crown, half-length (rad), half-width (rad)].
const HELMET_VENTS := [[0.30, 0.55, 0.20, 0.045], [-0.30, 0.55, 0.20, 0.045], [PI - 0.30, 0.70, 0.18, 0.045], [PI + 0.30, 0.70, 0.18, 0.045], [0.95, 0.95, 0.12, 0.04], [-0.95, 0.95, 0.12, 0.04]]
static func helmet_point(a: float, phi: float, inset := 0.0) -> Vector3:
	# a: angle round the head, 0 = front (+Z); phi: angle down from the crown.
	var s := sin(phi)
	var c := cos(phi)
	var front := maxf(0.0, cos(a))
	var back := maxf(0.0, -cos(a))
	# Plan: rounded rectangle-ish (superellipse), a touch longer at the back.
	var ca := cos(a)
	var sa := sin(a)
	var e := 0.82
	var px := signf(sa) * pow(absf(sa), e)
	var pz := signf(ca) * pow(absf(ca), e)
	var d := HELMET_D * (1.0 + 0.04 * back)
	# Crown slightly flattened; sides fall nearly vertical below the equator.
	var cy := signf(c) * pow(absf(c), 1.15)
	var sy := pow(s, 0.85)
	var p := Vector3(px * sy * (HELMET_W - inset), cy * (HELMET_H - inset), pz * sy * (d - inset))
	var out := Vector3(sa, 0, ca)
	# Brow: the front edge turns slightly out over the visor clip line.
	p += out * 0.004 * pow(front, 4) * smoothstep(1.35, 1.6, phi)
	# Two-piece shell: the rear/lower piece stands 3 mm proud along a line
	# that sweeps from the temples up over the back.
	var step_line := lerpf(1.25, 0.85, back)
	p += out * 0.003 * smoothstep(step_line - 0.02, step_line + 0.02, phi) * (1.0 - front)
	# Occipital tuck under the back of the skull.
	p -= out * 0.012 * back * smoothstep(1.75, 2.05, phi)
	# Vent slots: a recess with a crisp edge.
	var vent := helmet_vent(a, phi)
	p -= out * 0.005 * vent
	p.y -= 0.005 * vent * c
	return p

## 0..1: how far (a, phi) lies inside a vent slot.
static func helmet_vent(a: float, phi: float) -> float:
	var v := 0.0
	for vt: Array in HELMET_VENTS:
		var da := wrapf(a - float(vt[0]), -PI, PI) * sin(phi)
		var dp := phi - float(vt[1])
		var r := Vector2(dp / float(vt[2]), da / float(vt[3])).length()
		v = maxf(v, smoothstep(1.0, 0.8, r))
	return v

## Lower edge of the shell (phi) round the head: brow at the front just above
## the eyebrows, down over the tops of the ears, low at the occipital lock.
static func helmet_edge(a: float) -> float:
	var front := maxf(0.0, cos(a))
	var back := maxf(0.0, -cos(a))
	var side := absf(sin(a))
	return 1.80 + 0.18 * back + 0.10 * side * side - 0.20 * pow(front, 3)

static func skater_helmet() -> ArrayMesh:
	var b := MeshBuilder.new()
	var cols_n := 64
	var rows := 24
	var rings := []
	var ring_colors := []
	var shell := Color("#132434")
	# Rolled lip on the inside first, then up the shell to the crown.
	for r in range(-2, rows + 1):
		var ring := PackedVector3Array()
		var cols := PackedColorArray()
		for j in range(cols_n):
			var a := TAU * j / cols_n
			var edge := helmet_edge(a)
			if r < 0:
				var p := helmet_point(a, edge)
				var inward := Vector3(p.x, 0, p.z).normalized()
				ring.append(p - inward * (0.010 if r == -2 else 0.004) + Vector3(0, 0.012 if r == -2 else -0.003, 0))
			else:
				var v := float(r) / rows
				ring.append(helmet_point(a, edge * (1.0 - v * 0.995)))
			cols.append(shell)
		rings.append(ring)
		ring_colors.append(cols)
	b.add_loft(rings, ring_colors, true, true)
	return b.to_mesh(0.27)

## Ear guards, vent inserts, occipital adjuster and chin strap.
## Head landmarks (helmet space): ears at x = +-0.082, y = -0.06, z = -0.01;
## chin at y = -0.13, z = 0.075.
static func helmet_fittings() -> ArrayMesh:
	var b := MeshBuilder.new()
	var plastic := Color("#0b1621")
	for s: float in [-1.0, 1.0]:
		# Ear guard: a flat oval plate with a raised rim, clipped to the lower
		# shell in front of and over the ear.
		var side := Basis(Vector3.UP, s * 0.10)
		var ear := Vector3(s * 0.096, -0.062, 0.006)
		b.add_rounded_box(ear, Vector3(0.010, 0.058, 0.046), 0.005, plastic, side)
		b.add_rounded_box(ear + Vector3(s * 0.004, 0.004, 0), Vector3(0.006, 0.040, 0.030), 0.003, Color("#1c2a36"), side)
		# Chin strap: from the ear guard's lower front, along the jaw and under the chin.
		var pts := PackedVector3Array([
			ear + Vector3(-s * 0.004, -0.028, 0.012),
			Vector3(s * 0.078, -0.112, 0.040),
			Vector3(s * 0.050, -0.136, 0.066),
			Vector3(s * 0.016, -0.142, 0.078),
			Vector3(0.0, -0.142, 0.080)])
		b.add_tube(pts, 0.0045, Color("#26313a"), 8)
	# Chin cup.
	b.add_rounded_box(Vector3(0, -0.140, 0.081), Vector3(0.040, 0.012, 0.024), 0.006, Color("#26313a"))
	# Dark inserts set just under each vent so the slots read as openings.
	for vt: Array in HELMET_VENTS:
		var pts := PackedVector3Array()
		for k in range(7):
			var phi: float = float(vt[1]) + lerpf(-0.75, 0.75, k / 6.0) * float(vt[2])
			pts.append(helmet_point(float(vt[0]), phi, 0.006))
		b.add_tube(pts, 0.006, Color("#05090d"), 8)
	# Occipital lock adjuster on the back of the shell.
	var occ := helmet_point(PI, 1.92)
	b.add_rounded_box(occ + Vector3(0, 0.004, -0.004), Vector3(0.050, 0.014, 0.010), 0.004, plastic)
	return b.to_mesh(0.4)

## Curved half visor clipped at the temples: brow line to the nose tip,
## 2 cm off the face, cut up toward the sides.
static func visor() -> ArrayMesh:
	var b := MeshBuilder.new()
	var rings := []
	var ring_colors := []
	var count := 31
	for k in range(count):
		var a := lerpf(-1.25, 1.25, float(k) / (count - 1))
		var edge := helmet_edge(a)
		var top := helmet_point(a, edge)
		var out := Vector3(sin(a), 0, cos(a))
		var drop := lerpf(0.062, 0.036, pow(absf(a) / 1.25, 1.8))
		var ring := PackedVector3Array()
		var profile := GearProfiles.rounded_rect(drop, 0.0035, [0.0015, 0.0015, 0.0015, 0.0015], 2, 1)
		for p in profile:
			var y := top.y + 0.006 - drop * 0.5 + p.x
			var rake := (top.y - y) * 0.10
			ring.append(Vector3(top.x, 0, top.z) + out * (0.006 + rake + p.y) + Vector3(0, y, 0))
		rings.append(ring)
		var cols := PackedColorArray()
		cols.resize(profile.size())
		cols.fill(Color.WHITE)
		ring_colors.append(cols)
	b.add_loft(rings, ring_colors, true, true)
	return b.to_mesh(0.15)

## Hockey sock pulled over the shin guard, with team stripes.
static func sock(kit: Color, stripe: Color) -> ArrayMesh:
	var radii := [0.074, 0.078, 0.076, 0.072, 0.068, 0.064, 0.060, 0.057, 0.056]
	return _limb(radii, 1.0, func(t: float, _a: float) -> Color:
		if (t > 0.30 and t < 0.40) or (t > 0.46 and t < 0.51): return stripe
		return kit)
