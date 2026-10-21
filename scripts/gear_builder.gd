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
	func add_panel(center: Vector3, size: Vector2, thickness: float, radius: float, basis: Basis, face: Color, edge: Color, back: Color, uv_rect := Rect2(0, 0, 1, 1)) -> void:
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
				var fu := clampf(uv_rect.position.x + (q.x / size.x + 0.5) * uv_rect.size.x, 0.0, 1.0)
				var fv := clampf(uv_rect.position.y + (q.y / size.y + 0.5) * uv_rect.size.y, 0.0, 1.0)
				uv_ring.append(Vector2(fu, (1.0 - fv) * FACE_V) if layer[0] == 0.5 else BLANK_UV)
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
## Face and back planes of the pad block (local Z): about 12 cm thick.
const FACE_Z := 0.068
const BACK_Z := -0.044
## The thigh-rise section hinges at this break above the knee.
const PAD_BREAK := PAD_KNEE + 0.115

## Builds the pad between y_from and y_to (default: whole pad), so the
## thigh rise can be a separate hinged piece.
static func goalie_pad(side: float, kit: Color, accent: Color, y_from := -1.0, y_to := 1.0) -> ArrayMesh:
	# Modern flat-face pad (after reference photos of current pro pads): a thick
	# block with a flat face, square edges and full-height flat sidewalls; the
	# face is quilted into three vertical columns and broken horizontally at
	# the thigh rise, knee and boot; the boot section kinks forward over the
	# skate toe and carries vertical boot-break ribs. Inside the leg: knee
	# landing block, calf wrap and straps.
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
		y += 0.006 if (y < bottom + 0.04 or y > top - 0.04) else 0.008
	ys.append(minf(top, y_to))
	if y_from > bottom:
		ys.push_front(y_from)
	var boot_top := PAD_ANKLE + 0.10
	var grooves := [[PAD_BREAK, 0.013], [PAD_KNEE - 0.065, 0.010], [boot_top, 0.012], [top - 0.115, 0.007]]
	for yy: float in ys:
		var w := PAD_WIDTH
		w -= smoothstep(top - 0.12, top, yy) * 0.02
		w -= smoothstep(bottom + 0.08, bottom, yy) * 0.015
		var front := FACE_Z + 0.008 * exp(-pow((yy - PAD_KNEE) / 0.07, 2))
		var back := BACK_Z
		var groove := 0.0
		for g: Array in grooves:
			groove = maxf(groove, _band(yy, g[0], g[1]))
		front -= groove * 0.010
		# Rounded top and toe tip.
		var round_ := 1.0
		if yy > top - 0.03:
			round_ = sqrt(maxf(0.05, 1.0 - pow((yy - (top - 0.03)) / 0.03, 2)))
		elif yy < bottom + 0.025:
			round_ = sqrt(maxf(0.05, 1.0 - pow((bottom + 0.025 - yy) / 0.025, 2)))
		# The boot section kinks forward over the skate toe.
		var toe := 0.075 * pow(smoothstep(boot_top + 0.02, bottom, yy), 1.2)
		var boot := smoothstep(boot_top + 0.01, boot_top - 0.03, yy)
		var d := (front - back) * round_
		var mid := (front + back) * 0.5
		# Square face edges, softer back edges.
		var profile := GearProfiles.rounded_rect(w * lerpf(0.7, 1.0, round_), d, [0.011, 0.011, 0.022, 0.022], 5, 14)
		var ring := PackedVector3Array()
		var cols := PackedColorArray()
		var uv_ring := PackedVector2Array()
		var hw := w * 0.5
		for p in profile:
			var outer := p.x  # positive = outside of the leg
			var z := mid + p.y
			var is_front := p.y > d * 0.5 - 0.010
			var is_side := absf(outer) > hw - 0.012 and not is_front and p.y > -d * 0.5 + 0.02
			if is_front:
				# Quilted columns pillow between the stitch lines; the boot
				# section carries three vertical boot-break ribs instead.
				var col_u := outer / hw
				var pillow := 0.007 * (1.0 - pow(clampf(col_u, -1, 1), 6))
				var stitch := 0.007 * (_band(outer, -hw / 3.0, 0.009) + _band(outer, hw / 3.0, 0.009))
				var rib := 0.010 * pow(0.5 + 0.5 * cos(col_u * 3.0 * PI), 0.6) * boot
				z += (pillow - stitch * (1.0 - boot) + rib) * round_
			ring.append(Vector3(outer * side, yy, z + toe))
			var col := WHITE
			if is_front:
				col = WHITE.lerp(LINE, groove * 0.45)
				uv_ring.append(face_uv(outer / w + 0.5, (yy - bottom) / PAD_LENGTH))
			else:
				uv_ring.append(BLANK_UV)
				if is_side:
					# Flat sidewalls, with a stitched seam just behind the face edge.
					col = WHITE.darkened(0.03)
					if p.y > d * 0.5 - 0.024: col = LINE.lightened(0.25)
					if outer > 0 and p.y < d * 0.5 - 0.030 and p.y > d * 0.5 - 0.045: col = kit
				elif p.y < -d * 0.5 + 0.004:
					col = OFFWHITE.darkened(0.12)  # leg channel
				else:
					col = OFFWHITE
			cols.append(col)
		rings.append(ring)
		ring_colors.append(cols)
		ring_uvs.append(uv_ring)
	b.add_loft(rings, ring_colors, true, true, ring_uvs)
	var graphic := _cached("pad|%s|%s" % [kit.to_html(), accent.to_html()], func(): return _paint_pad(kit, accent))
	# Behind the face: straps, knee landing block, calf wrap.
	if y_from > bottom:
		b.add_rounded_box(Vector3(0, PAD_KNEE + 0.17, BACK_Z - 0.06), Vector3(0.20, 0.03, 0.012), 0.005, OFFWHITE)
		return b.to_mesh(0.62, graphic)
	# Knee landing block on the inside of the knee: a grey dense-foam block
	# the goalie lands on in the butterfly, with an inner knee wedge.
	b.add_rounded_box(Vector3(-side * 0.070, PAD_KNEE - 0.02, BACK_Z - 0.050), Vector3(0.115, 0.15, 0.10), 0.022, Color("#c8cdd1"))
	b.add_rounded_box(Vector3(-side * 0.118, PAD_KNEE - 0.02, BACK_Z - 0.030), Vector3(0.04, 0.12, 0.07), 0.012, WHITE)
	# Calf wrap: a padded flap from the inner sidewall around behind the calf.
	b.add_rounded_box(Vector3(-side * 0.075, (PAD_ANKLE + 0.20 + PAD_KNEE - 0.10) * 0.5, BACK_Z - 0.040), Vector3(0.10, PAD_KNEE - PAD_ANKLE - 0.30, 0.06), 0.02, WHITE, Basis(Vector3.UP, side * 0.45))
	# Outer calf wing and straps (white webbing, dark buckles).
	b.add_rounded_box(Vector3(side * 0.115, (PAD_ANKLE + 0.20 + PAD_KNEE) * 0.5, BACK_Z - 0.028), Vector3(0.026, PAD_KNEE - PAD_ANKLE - 0.20, 0.06), 0.011, WHITE)
	for sy: float in [PAD_ANKLE + 0.21, PAD_KNEE - 0.12]:
		b.add_rounded_box(Vector3(0, sy, BACK_Z - 0.085), Vector3(0.20, 0.03, 0.012), 0.005, OFFWHITE)
		b.add_rounded_box(Vector3(side * 0.09, sy, BACK_Z - 0.088), Vector3(0.03, 0.036, 0.014), 0.004, DARK)
	return b.to_mesh(0.62, graphic)

## Pad face graphic: a white pad with team trim, as pros wear them - kit
## thigh-rise cap, a kit knee band with an accent insert, a kit sweep on the
## boot section and a slim kit stripe up the outer edge, plus the face's
## stitch work (column stitching, rows of short tack stitches, break seams).
## Generic: no marks or logos.
static func _paint_pad(kit: Color, accent: Color) -> Texture2D:
	var g := Graphic.new(256, 704, WHITE)
	var v := func(y: float) -> float: return (y + PAD_LENGTH * 0.5) / PAD_LENGTH
	var vk: float = v.call(PAD_KNEE)
	var stitch := WHITE.darkened(0.38)
	# Column stitching and rows of short tack stitches in each column.
	for u in [1.0 / 3.0, 2.0 / 3.0]:
		g.stitches(Vector2(u, 0.03), Vector2(u, 0.975), 0.006, stitch, 80)
	for row in range(14):
		var vv := 0.30 + row * 0.045
		if absf(vv - vk) < 0.07: continue
		for u in [1.0 / 6.0, 0.5, 5.0 / 6.0]:
			g.rect(u - 0.035, vv - 0.003, u + 0.035, vv + 0.003, stitch)
	# Boot section: kit sweep and accent pinstripe.
	g.poly([Vector2(0, 0), Vector2(1, 0), Vector2(1, 0.20), Vector2(0, 0.08)], kit)
	g.stripe([Vector2(-0.05, 0.10), Vector2(1.05, 0.225)], 0.009, accent)
	# Knee band with an accent insert on the inside.
	g.poly([Vector2(0, vk - 0.05), Vector2(1, vk - 0.035), Vector2(1, vk + 0.035), Vector2(0, vk + 0.02)], kit)
	g.poly([Vector2(0, vk - 0.03), Vector2(0.22, vk - 0.026), Vector2(0.22, vk + 0.017), Vector2(0, vk + 0.012)], accent)
	# Thigh-rise cap and pinstripe.
	g.rect(0, 0.945, 1, 1, kit)
	g.rect(0, 0.925, 1, 0.933, accent)
	# Slim kit stripe up the outer edge.
	g.rect(0.93, 0.08, 1, 1, kit)
	# Seams at the breaks.
	for y in [PAD_BREAK, PAD_KNEE - 0.065, PAD_ANKLE + 0.10]:
		g.rect(0, v.call(y) - 0.0025, 1, v.call(y) + 0.0025, LINE)
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

## Catcher shape, after reference photos of current pro gloves (frame: +x
## toward the fingers before mirroring, +y up the glove, +z to the shooter).
## The mitt is a rounded body with a thick bound perimeter; the pocket fills
## its upper half and is a string web over a dark leather T; the palm below is
## padded; a large flat cuff ("cheater") stands off the thumb side.
const CATCHER_OUTLINE := [
	Vector2(-0.090, -0.150), Vector2(0.020, -0.165), Vector2(0.100, -0.135), Vector2(0.150, -0.065),
	Vector2(0.170, 0.025), Vector2(0.166, 0.115), Vector2(0.142, 0.188), Vector2(0.098, 0.236),
	Vector2(0.036, 0.258), Vector2(-0.030, 0.252), Vector2(-0.080, 0.226), Vector2(-0.108, 0.172),
	Vector2(-0.118, 0.092), Vector2(-0.114, 0.000), Vector2(-0.104, -0.085)]
const CATCHER_POCKET := [
	Vector2(-0.092, 0.070), Vector2(0.138, 0.070), Vector2(0.146, 0.140), Vector2(0.122, 0.198),
	Vector2(0.080, 0.232), Vector2(0.020, 0.244), Vector2(-0.040, 0.236), Vector2(-0.082, 0.208),
	Vector2(-0.100, 0.150)]
const POCKET_CENTER := Vector2(0.025, 0.150)
## Texture regions: the palm uses the left of the catcher texture, the
## cheater panel's face the right.
const PALM_U := 0.66
const CHEATER_UV := Rect2(0.70, 0.0, 0.30, 1.0)

static func catcher(side: float, kit: Color, accent: Color) -> ArrayMesh:
	var b := MeshBuilder.new()
	var outline := GearProfiles.resample(PackedVector2Array(CATCHER_OUTLINE), 84)
	# [scale toward outline, depth] from the pocket centre, over the rim, to the
	# padded back of the hand. The pocket is deep; the palm below it slopes up
	# to the rim.
	var sections := [[0.02, -0.062], [0.16, -0.056], [0.32, -0.036], [0.48, -0.012], [0.64, 0.008],
		[0.80, 0.022], [0.92, 0.031], [0.975, 0.036], [1.0, 0.030], [1.012, 0.012], [1.0, -0.014],
		[0.975, -0.040], [0.90, -0.058], [0.70, -0.070], [0.40, -0.076], [0.02, -0.077]]
	var rings := []
	var ring_colors := []
	var ring_uvs := []
	for i in range(sections.size()):
		var sc: float = sections[i][0]
		var z: float = sections[i][1]
		var ring := PackedVector3Array()
		var cols := PackedColorArray()
		var uv_ring := PackedVector2Array()
		for p in outline:
			var q := POCKET_CENTER + (p - POCKET_CENTER) * sc
			ring.append(Vector3(q.x * side, q.y, z))
			if i <= 8:
				# Palm and pocket: painted (pocket leather, palm panels, seams).
				cols.append(WHITE)
				uv_ring.append(face_uv(PALM_U * (q.x + 0.13) / 0.31, (q.y + 0.175) / 0.44))
			else:
				uv_ring.append(BLANK_UV)
				# Rim binding, then the padded white back of the hand.
				cols.append(kit if i <= 10 else WHITE.darkened(0.02))
		rings.append(ring)
		ring_colors.append(cols)
		ring_uvs.append(uv_ring)
	b.add_loft(rings, ring_colors, true, true, ring_uvs)
	# Perimeter: a thick bound roll from the thumb tip over the top and down the
	# finger side, laced to the body with white lace wraps.
	var rim := PackedVector3Array()
	var rim_pts := [Vector2(-0.090, 0.214), Vector2(-0.040, 0.248), Vector2(0.036, 0.262), Vector2(0.100, 0.240),
		Vector2(0.146, 0.190), Vector2(0.171, 0.115), Vector2(0.175, 0.025), Vector2(0.155, -0.060), Vector2(0.108, -0.128)]
	for q: Vector2 in rim_pts:
		rim.append(Vector3(q.x * side, q.y, 0.030))
	b.add_tube(rim, 0.024, kit, 14)
	for k in range(1, 15):
		var t := k / 15.0
		var f := t * (rim_pts.size() - 1)
		var a: Vector2 = rim_pts[int(f)]
		var c: Vector2 = rim_pts[mini(int(f) + 1, rim_pts.size() - 1)]
		var q := a.lerp(c, f - int(f))
		var out := (q - POCKET_CENTER).normalized()
		var lace := PackedVector3Array([
			Vector3((q.x - out.x * 0.020) * side, q.y - out.y * 0.020, 0.044),
			Vector3((q.x - out.x * 0.004) * side, q.y - out.y * 0.004, 0.056),
			Vector3((q.x + out.x * 0.014) * side, q.y + out.y * 0.014, 0.050),
			Vector3((q.x + out.x * 0.022) * side, q.y + out.y * 0.022, 0.034)])
		b.add_tube(lace, 0.0035, WHITE, 5)
	# Thumb: a slimmer white roll up the inside edge of the pocket.
	var thumb := PackedVector3Array()
	for q: Vector2 in [Vector2(-0.112, -0.020), Vector2(-0.120, 0.060), Vector2(-0.114, 0.140), Vector2(-0.095, 0.196), Vector2(-0.075, 0.222)]:
		thumb.append(Vector3(q.x * side, q.y, 0.026))
	b.add_tube(thumb, 0.020, WHITE, 12)
	# String web: a diamond lattice stretched across the pocket, slightly
	# cupped, with the dark leather T behind it.
	var pocket := PackedVector2Array(CATCHER_POCKET)
	var cup := func(q: Vector2) -> float:
		return 0.022 - 0.020 * exp(-(q - POCKET_CENTER).length_squared() / 0.006)
	for dir_ in [Vector2(1, 1).normalized(), Vector2(1, -1).normalized()]:
		var normal := Vector2(-dir_.y, dir_.x)
		for k in range(-12, 13):
			var origin := POCKET_CENTER + normal * k * 0.024
			var line := PackedVector2Array([origin - dir_ * 0.4, origin + dir_ * 0.4])
			for seg in Geometry2D.intersect_polyline_with_polygon(line, pocket):
				var a: Vector2 = seg[0]
				var c: Vector2 = seg[seg.size() - 1]
				if a.distance_to(c) < 0.02: continue
				var pts := PackedVector3Array()
				for m in range(6):
					var q := a.lerp(c, m / 5.0)
					pts.append(Vector3(q.x * side, q.y, cup.call(q)))
				b.add_tube(pts, 0.0032, WHITE, 5)
	b.add_rounded_box(Vector3(0.022 * side, 0.155, -0.002), Vector3(0.030, 0.17, 0.010), 0.004, DARK, Basis(Vector3.RIGHT, -0.30))
	b.add_rounded_box(Vector3(0.022 * side, 0.236, 0.018), Vector3(0.15, 0.024, 0.010), 0.004, DARK)
	# Cheater: the big flat cuff panel off the thumb side, angled out a little.
	b.add_panel(Vector3(-0.185 * side, -0.040, -0.004), Vector2(0.155, 0.255), 0.052, 0.026, Basis(Vector3.BACK, 0.10 * side), WHITE, WHITE.darkened(0.05), OFFWHITE, CHEATER_UV)
	# Back of the hand: padded backhand plate with the finger section ridged
	# across the top, and the wrist strap.
	b.add_rounded_box(Vector3(0.02 * side, 0.02, -0.086), Vector3(0.20, 0.20, 0.025), 0.012, WHITE.darkened(0.03))
	for k in range(3):
		b.add_rounded_box(Vector3((0.035 + 0.04 * (k - 1)) * side, 0.17, -0.084), Vector3(0.034, 0.14, 0.028), 0.014, WHITE)
	b.add_rounded_box(Vector3(0.02 * side, -0.115, -0.082), Vector3(0.16, 0.035, 0.015), 0.006, DARK)
	var graphic := _cached("catcher|%s|%s" % [kit.to_html(), accent.to_html()], func(): return _paint_catcher(kit, accent))
	return b.to_mesh(0.58, graphic)

## Catcher graphic (one texture for palm and cheater): the palm shows the
## dark pocket leather behind the web and stitched palm panels; the cheater
## panel (the add_panel face) uses the same texture's right-hand region.
static func _paint_catcher(kit: Color, accent: Color) -> Texture2D:
	var g := Graphic.new(512, 512, WHITE)
	var to_uv := func(q: Vector2) -> Vector2: return Vector2(PALM_U * (q.x + 0.13) / 0.31, (q.y + 0.175) / 0.44)
	# Pocket: dark leather seen through the web.
	var pocket := []
	for q: Vector2 in CATCHER_POCKET:
		pocket.append(to_uv.call(q + (q - POCKET_CENTER) * 0.08))
	g.poly(pocket, Color("#24292e"))
	# Palm panel seams and a kit accent across the heel of the palm.
	var seam := WHITE.darkened(0.30)
	g.stitches(to_uv.call(Vector2(-0.02, 0.06)), to_uv.call(Vector2(-0.05, -0.15)), 0.004, seam, 18)
	g.stitches(to_uv.call(Vector2(0.06, 0.06)), to_uv.call(Vector2(0.10, -0.12)), 0.004, seam, 18)
	g.stripe([to_uv.call(Vector2(-0.12, -0.11)), to_uv.call(Vector2(0.16, -0.06))], 0.020, kit)
	g.stripe([to_uv.call(Vector2(-0.12, -0.075)), to_uv.call(Vector2(0.16, -0.025))], 0.006, accent)
	# Cheater face: white with a bold kit sweep, an accent pinstripe and a kit
	# binding (u 0..1 across the panel maps into CHEATER_UV).
	var cu := func(u: float, v: float) -> Vector2: return Vector2(CHEATER_UV.position.x + u * CHEATER_UV.size.x, v)
	g.poly([cu.call(0, 0.18), cu.call(1, 0.36), cu.call(1, 0.50), cu.call(0, 0.30)], kit)
	g.stripe([cu.call(-0.05, 0.36), cu.call(1.05, 0.555)], 0.006, accent)
	g.rect(CHEATER_UV.position.x, 0.0, 1.0, 0.04, kit)
	g.rect(CHEATER_UV.position.x, 0.96, 1.0, 1.0, kit)
	var seam2 := WHITE.darkened(0.30)
	g.stitches(cu.call(0.10, 0.62), cu.call(0.90, 0.62), 0.004, seam2, 14)
	g.stitches(cu.call(0.10, 0.80), cu.call(0.90, 0.80), 0.004, seam2, 14)
	return g.texture()

# ---------------------------------------------------------------- goalie mask
## Modern fibreglass goalie mask after reference photos: a smooth shell with a
## raised crest over the forehead, wide cheeks and side flares behind the
## cage, a long chin that juts forward below the cage, vent holes, temple
## straps and a chrome cage (straight bars, cat-eye opening).
## Origin near eye level; +Z faces forward.
## Shell keys per height y: [y, half-width, centre z, front reach, back reach].
const MASK_KEYS := [
	[-0.238, 0.022, 0.128, 0.018, 0.010],
	[-0.215, 0.046, 0.108, 0.046, 0.022],
	[-0.185, 0.068, 0.080, 0.074, 0.040],
	[-0.150, 0.082, 0.050, 0.104, 0.070],
	[-0.115, 0.104, 0.028, 0.124, 0.104],
	[-0.075, 0.118, 0.014, 0.136, 0.128],
	[-0.030, 0.124, 0.006, 0.142, 0.138],
	[0.020, 0.122, 0.002, 0.142, 0.140],
	[0.065, 0.112, 0.000, 0.135, 0.134],
	[0.105, 0.092, -0.004, 0.115, 0.115],
	[0.135, 0.062, -0.008, 0.082, 0.082],
	[0.155, 0.028, -0.010, 0.040, 0.040],
	[0.163, 0.004, -0.010, 0.006, 0.006]]
const MASK_BOTTOM := -0.238
const MASK_TOP := 0.163

## Catmull-Rom through the shell keys, so the surface has no ripples.
static func _mask_key(y: float, k: int) -> float:
	var n := MASK_KEYS.size()
	if y <= MASK_KEYS[0][0]: return MASK_KEYS[0][k]
	if y >= MASK_KEYS[n - 1][0]: return MASK_KEYS[n - 1][k]
	var i := 0
	while MASK_KEYS[i + 1][0] < y: i += 1
	var y1: float = MASK_KEYS[i][0]
	var y2: float = MASK_KEYS[i + 1][0]
	var t := (y - y1) / (y2 - y1)
	var p0: float = MASK_KEYS[maxi(i - 1, 0)][k]
	var p1: float = MASK_KEYS[i][k]
	var p2: float = MASK_KEYS[i + 1][k]
	var p3: float = MASK_KEYS[mini(i + 2, n - 1)][k]
	return 0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t * t + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t * t * t)

## Point on the mask shell at angle a (0 = straight ahead) and height y.
static func mask_point(a: float, y: float) -> Vector3:
	var w := _mask_key(y, 1)
	var c := _mask_key(y, 2)
	var rf := _mask_key(y, 3)
	var rb := _mask_key(y, 4)
	var cz := cos(a)
	var sa := sin(a)
	# Crest: a raised ridge up the forehead to the crown.
	var crest := 0.010 * exp(-pow(a / 0.22, 2)) * smoothstep(0.02, 0.10, y)
	# Side flares: the shell widens behind the cage over the ears.
	var flare := 1.0 + 0.07 * exp(-pow((absf(a) - 1.75) / 0.45, 2)) * smoothstep(-0.16, -0.08, y) * smoothstep(0.10, 0.04, y)
	var z := c + (cz * (rf + crest) if cz > 0 else cz * rb)
	return Vector3(sa * w * flare, y, z)

static func goalie_mask(kit: Color, accent: Color) -> ArrayMesh:
	var b := MeshBuilder.new()
	var rings := []
	var ring_colors := []
	var ring_uvs := []
	var count := 72
	var y := MASK_BOTTOM
	while y <= MASK_TOP + 0.0001:
		var ring := PackedVector3Array()
		var cols := PackedColorArray()
		var uv_ring := PackedVector2Array()
		for k in range(count):
			var a := TAU * k / count - PI
			var p := mask_point(a, y)
			# Face opening: recessed behind the cage, from the brow to the mouth.
			var opening := smoothstep(0.78, 0.58, absf(a)) * smoothstep(-0.118, -0.098, y) * smoothstep(0.050, 0.032, y)
			p = Vector3(p.x * lerpf(1, 0.80, opening), p.y, lerpf(p.z, p.z * 0.45, opening))
			ring.append(p)
			cols.append(Color("#14181c") if opening > 0.35 else WHITE)
			uv_ring.append(face_uv((a + PI) / TAU, (y - MASK_BOTTOM) / (MASK_TOP - MASK_BOTTOM)))
		rings.append(ring)
		ring_colors.append(cols)
		ring_uvs.append(uv_ring)
		y += 0.005
	b.add_loft(rings, ring_colors, true, true, ring_uvs)
	# Vent holes: dark recessed discs on the crown and over the ears.
	for vent: Vector2 in [Vector2(-0.30, 0.125), Vector2(0.30, 0.125), Vector2(-0.95, 0.105), Vector2(0.95, 0.105),
			Vector2(-1.85, 0.055), Vector2(1.85, 0.055), Vector2(-1.75, -0.040), Vector2(1.75, -0.040), Vector2(-2.10, -0.010), Vector2(2.10, -0.010)]:
		var p := mask_point(vent.x, vent.y)
		var n := (p - Vector3(0, vent.y * 0.6, _mask_key(vent.y, 2))).normalized()
		b.add_tube(PackedVector3Array([p - n * 0.006, p + n * 0.0015]), 0.0105, Color("#101316"), 12)
	# Temple and jaw straps (beige webbing) on both sides.
	for s_: float in [-1.0, 1.0]:
		for strap: Vector2 in [Vector2(1.45, 0.065), Vector2(1.55, -0.105)]:
			var p := mask_point(s_ * strap.x, strap.y)
			b.add_rounded_box(p + Vector3(s_ * 0.004, 0, 0), Vector3(0.010, 0.022, 0.050), 0.004, Color("#d9cfb8"))
	# Backplate seam line around the back of the head.
	var seam := PackedVector3Array()
	for k in range(9):
		var a := lerpf(2.05, TAU - 2.05, k / 8.0)
		seam.append(mask_point(a, 0.0 + 0.10 * absf(sin(a))) * 1.012)
	b.add_tube(seam, 0.003, LINE, 6)
	# Chrome cage: straight horizontal and vertical bars standing off the
	# shell, wrapping round to the temples; cat-eye bars beside the eyes.
	var chrome := Color("#a3acb3")
	var cage := func(a: float, yy: float) -> Vector3:
		var p := mask_point(a, yy)
		return Vector3(p.x * 1.05, yy, p.z + 0.016)
	for yy: float in [0.040, 0.004, -0.034, -0.072, -0.106]:
		var bar := PackedVector3Array()
		var reach := 0.92 if yy > -0.09 else 0.70
		for k in range(15):
			bar.append(cage.call(lerpf(-reach, reach, k / 14.0), yy))
		b.add_tube(bar, 0.0042, chrome, 6)
	for a: float in [-0.13, 0.13, -0.42, 0.42]:
		var bar := PackedVector3Array()
		for k in range(9):
			bar.append(cage.call(a, lerpf(0.004 if absf(a) < 0.2 else 0.040, -0.108, k / 8.0)))
		b.add_tube(bar, 0.0042, chrome, 6)
	for s_: float in [-1.0, 1.0]:
		var bar := PackedVector3Array()
		for k in range(7):
			var t := k / 6.0
			bar.append(cage.call(s_ * lerpf(0.13, 0.62, t), lerpf(0.004, 0.040, t)))
		b.add_tube(bar, 0.0042, chrome, 6)
		# Clips holding the cage to the shell at brow and cheek.
		for clip: Vector2 in [Vector2(0.80, 0.044), Vector2(0.86, -0.090)]:
			b.add_rounded_box(mask_point(s_ * clip.x, clip.y) + Vector3(0, 0, 0.004), Vector3(0.018, 0.016, 0.018), 0.005, chrome)
	var graphic := _cached("mask|%s|%s" % [kit.to_html(), accent.to_html()], func(): return _paint_mask(kit, accent))
	return b.to_mesh(0.22, graphic)

## Mask paint: white base, a kit sweep along each side from the chin back over
## the ears, an accent pinstripe and a kit stripe over the crest. u runs round
## the head (0.5 = front), v from chin (0) to crown (1).
static func _paint_mask(kit: Color, accent: Color) -> Texture2D:
	var g := Graphic.new(512, 256, WHITE)
	for s_: float in [-1.0, 1.0]:
		var u := func(a: float) -> float: return 0.5 + s_ * a / TAU
		g.poly([Vector2(u.call(0.55), 0.05), Vector2(u.call(1.10), 0.10), Vector2(u.call(2.50), 0.42), Vector2(u.call(2.70), 0.66),
			Vector2(u.call(1.90), 0.60), Vector2(u.call(1.20), 0.32), Vector2(u.call(0.70), 0.22)], kit)
		g.stripe([Vector2(u.call(0.80), 0.30), Vector2(u.call(1.40), 0.42), Vector2(u.call(2.30), 0.72)], 0.006, accent)
	g.rect(0.47, 0.84, 0.53, 1.0, kit)
	g.rect(0.455, 0.84, 0.462, 1.0, accent)
	g.rect(0.538, 0.84, 0.545, 1.0, accent)
	return g.texture()

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
	if is_zero_approx(flare):
		# Keep the fitted goalie silhouette clear of articulated pads during saves.
		# The new flared skater breezers below use a different hem/closure profile.
		return _limb([0.118,0.132,0.136,0.134,0.128,0.120,0.112,0.104,0.098],0.92,func(t: float,a: float) -> Color:
			if cos(a)*side>0.93: return kit
			return base.lightened(0.12) if t>0.92 else base)
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
	# Plan: smooth oval, a touch longer at the back.
	var ca := cos(a)
	var sa := sin(a)
	# Smooth oval, with a modest broadening toward the temples. Fractional
	# signed powers made the derivatives singular on the front/rear axes.
	var px := sa * (1.0 + 0.08 * ca * ca)
	var pz := ca
	var d := HELMET_D * (1.0 + 0.04 * back)
	# Crown slightly flattened; sides fall nearly vertical below the equator.
	var cy := signf(c) * pow(absf(c), 1.15)
	var sy := pow(s, 0.85)
	var p := Vector3(px * sy * (HELMET_W - inset), cy * (HELMET_H - inset), pz * sy * (d - inset))
	var out := Vector3(sa, 0, ca)
	# Brow: the front edge turns slightly out over the visor clip line.
	p += out * 0.004 * pow(front, 4) * smoothstep(1.35, 1.6, phi)
	# Two-piece shell: the rear/lower piece stands 1.5 mm proud along a line
	# that sweeps from the temples up over the back.
	var step_line := lerpf(1.25, 0.85, back)
	p += out * 0.0015 * smoothstep(step_line - 0.10, step_line + 0.10, phi) * (1.0 - front)
	# Occipital tuck under the back of the skull.
	p -= out * 0.012 * back * smoothstep(1.75, 2.05, phi)
	# Vent openings are cut from the topology below. Do not dent the shell:
	# even shallow displaced slots produce unrealistic pinched reflections.
	return p

## 0..1: how far (a, phi) lies inside a vent slot.
static func helmet_vent(a: float, phi: float) -> float:
	var v := 0.0
	for vt: Array in HELMET_VENTS:
		var da := wrapf(a - float(vt[0]), -PI, PI) * sin(phi)
		var dp := phi - float(vt[1])
		var r := Vector2(dp / float(vt[2]), da / float(vt[3])).length()
		v = maxf(v, 1.0 - smoothstep(0.55, 1.15, r))
	return v

## Lower edge of the shell (phi) round the head: brow at the front just above
## the eyebrows, down over the tops of the ears, low at the occipital lock.
static func helmet_edge(a: float) -> float:
	var front := maxf(0.0, cos(a))
	var back := maxf(0.0, -cos(a))
	var side := absf(sin(a))
	return 1.80 + 0.18 * back + 0.10 * side * side - 0.20 * pow(front, 3)

static func helmet_inside_vent(a: float, phi: float, radius: float) -> bool:
	for vent: Array in HELMET_VENTS:
		var da := wrapf(a - float(vent[0]), -PI, PI) * sin(phi)
		var dp := phi - float(vent[1])
		if Vector2(dp / float(vent[2]), da / float(vent[3])).length() < radius:
			return true
	return false

static var _helmet_mesh: ArrayMesh
static func helmet_normal(a: float, phi: float) -> Vector3:
	if phi < 0.015: return Vector3.UP
	# Derivatives of the continuous surface, independent of triangle diagonal.
	var delta := 0.0005
	var around := helmet_point(a + delta, phi) - helmet_point(a - delta, phi)
	var down := helmet_point(a, phi + delta) - helmet_point(a, phi - delta)
	return down.cross(around).normalized()

static func skater_helmet() -> ArrayMesh:
	if _helmet_mesh != null: return _helmet_mesh
	var b := MeshBuilder.new()
	var cols_n := 96
	var rows := 36
	var rings := []
	var ring_colors := []
	var shell := Color("#132434")
	# Rolled lip on the inside first, then up the shell to the crown.
	for r in range(-2, 1):
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
	# Keep the rolled rim separate. The outer shell uses sampled rounded vent
	# boundaries, rather than deleting coarse grid triangles (sawtooth edges).
	b.add_loft(rings.slice(0, 3), ring_colors.slice(0, 3), true, false)
	var domain := PackedVector2Array()
	for r in range(rows + 1):
		for j in range(cols_n + 1):
			var uv := Vector2(float(j) / cols_n, float(r) / rows)
			var a := uv.x * TAU - PI / 2.0
			var phi := helmet_edge(a) * (1.0 - uv.y)
			if not helmet_inside_vent(a, phi, 1.025): domain.append(uv)
	for vent: Array in HELMET_VENTS:
		for j in range(40):
			var angle := TAU * j / 40.0
			var phi: float = vent[1] + vent[2] * cos(angle)
			var a: float = vent[0] + vent[3] * sin(angle) / sin(phi)
			a = wrapf(a, -PI / 2.0, TAU - PI / 2.0)
			domain.append(Vector2((a + PI / 2.0) / TAU, 1.0 - phi / helmet_edge(a)))
	var base := b.vertices.size()
	for uv in domain:
		var a := uv.x * TAU - PI / 2.0
		var phi := helmet_edge(a) * (1.0 - uv.y)
		b.vertices.append(helmet_point(a, phi))
		b.normals.append(helmet_normal(a, phi))
		b.colors.append(shell);b.uvs.append(BLANK_UV)
	var triangles := Geometry2D.triangulate_delaunay(domain)
	for t in range(0, triangles.size(), 3):
		var ia := triangles[t];var ib := triangles[t + 1];var ic := triangles[t + 2]
		var uv := (domain[ia] + domain[ib] + domain[ic]) / 3.0
		var a := uv.x * TAU - PI / 2.0
		if helmet_inside_vent(a, helmet_edge(a) * (1.0 - uv.y), 0.999): continue
		var normal := (b.vertices[base + ib] - b.vertices[base + ia]).cross(b.vertices[base + ic] - b.vertices[base + ia])
		if normal.length_squared() < 1e-18: continue
		if normal.dot(b.normals[base + ia]) > 0:
			b.indices.append_array(PackedInt32Array([base + ia, base + ic, base + ib]))
		else:
			b.indices.append_array(PackedInt32Array([base + ia, base + ib, base + ic]))
	_helmet_mesh = b.to_mesh(0.27)
	return _helmet_mesh

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
		# Small round press-stud at the strap anchor, not a large chin cup.
		var snap := Vector3(s * 0.102, -0.078, 0.026)
		b.add_tube(PackedVector3Array([snap, snap + Vector3(s * 0.0018, 0, 0)]), 0.0045, Color("#899299"), 16)
	# Dark inserts set just under each vent so the slots read as openings.
	for vt: Array in HELMET_VENTS:
		var pts := PackedVector3Array()
		for k in range(7):
			var phi: float = float(vt[1]) + lerpf(-0.75, 0.75, k / 6.0) * float(vt[2])
			pts.append(helmet_point(float(vt[0]), phi, 0.0025))
		b.add_tube(pts, 0.0022, Color("#05090d"), 8)
	# Curved impact-liner backing under each aperture. A tube alone leaves
	# scalp visible at oblique angles; the patch overlaps the rounded opening.
	for vent: Array in HELMET_VENTS:
		var liner_rings := []
		var liner_colors := []
		for radius: float in [1.6, 0.01]:
			var ring := PackedVector3Array()
			var cols := PackedColorArray()
			for j in range(40):
				var angle := TAU * j / 40.0
				var phi: float = vent[1] + vent[2] * cos(angle) * radius
				var a: float = vent[0] + vent[3] * sin(angle) * radius / sin(phi)
				ring.append(helmet_point(a, phi, 0.003))
				cols.append(Color("#05090d"))
			liner_rings.append(ring);liner_colors.append(cols)
		b.add_loft(liner_rings, liner_colors, false, true)
	# Occipital lock adjuster on the back of the shell.
	var occ := helmet_point(PI, 1.92)
	b.add_rounded_box(occ + Vector3(0, 0.004, -0.004), Vector3(0.050, 0.014, 0.010), 0.004, plastic)
	return b.to_mesh(0.4)

## Unbranded retention webbing: flat 12 mm nylon, 1.4 mm thick, routed
## under the chin. Coordinates remain in the existing head-attached frame.
const CHINSTRAP_WIDTH := 0.012
const CHINSTRAP_THICKNESS := 0.0014
static var _chinstrap_mesh: ArrayMesh
static func chinstrap_path() -> PackedVector3Array:
	var controls := PackedVector3Array([
		Vector3(-0.101,-0.078,0.026), Vector3(-0.085,-0.111,0.047),
		Vector3(-0.057,-0.138,0.066), Vector3(-0.027,-0.148,0.071),
		Vector3(0,-0.150,0.071), Vector3(0.027,-0.148,0.071),
		Vector3(0.057,-0.138,0.066), Vector3(0.085,-0.111,0.047),
		Vector3(0.101,-0.078,0.026)])
	var result := PackedVector3Array()
	for i in range(controls.size() - 1):
		for k in range(4):
			result.append(controls[i].cubic_interpolate(controls[i+1],controls[maxi(0,i-1)],controls[mini(controls.size()-1,i+2)],float(k)/4.0))
	result.append(controls[-1])
	return result

static func chinstrap() -> ArrayMesh:
	if _chinstrap_mesh != null: return _chinstrap_mesh
	var b := MeshBuilder.new()
	var points := chinstrap_path()
	var rings := [];var colors := []
	var profile := GearProfiles.rounded_rect(CHINSTRAP_WIDTH,CHINSTRAP_THICKNESS,[0.0005,0.0005,0.0005,0.0005],2,1)
	for i in range(points.size()):
		var axis := (points[mini(i+1,points.size()-1)]-points[maxi(i-1,0)]).normalized()
		var out := Vector3(points[i].x/0.10,-0.30,0.15).normalized()
		out = (out-axis*out.dot(axis)).normalized()
		var width := axis.cross(out).normalized()
		var ring := PackedVector3Array();var cols := PackedColorArray()
		for p in profile:
			ring.append(points[i]+width*p.x+out*p.y)
			cols.append(Color("#050607"))
		rings.append(ring);colors.append(cols)
	b.add_loft(rings,colors)
	_chinstrap_mesh=b.to_mesh(0.88)
	return _chinstrap_mesh

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
