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
## Rounded four-roll hockey glove; origin at the palm; +Y is up the forearm.
static func skater_glove(kit: Color) -> ArrayMesh:
	var b := MeshBuilder.new()
	var dark := Color("#18232c")
	b.add_rounded_box(Vector3(0, -0.005, 0), Vector3(0.105, 0.10, 0.095), 0.04, dark)
	for i in range(4):
		b.add_rounded_box(Vector3(-0.036 + i * 0.024, -0.075, 0.012), Vector3(0.024, 0.06, 0.07), 0.011, kit.darkened(0.25))
	b.add_rounded_box(Vector3(0.062, -0.03, 0.02), Vector3(0.03, 0.07, 0.045), 0.013, dark)
	b.add_rounded_box(Vector3(0, 0.075, 0), Vector3(0.12, 0.08, 0.11), 0.035, kit.lightened(0.08))
	b.add_rounded_box(Vector3(0, 0.035, 0), Vector3(0.115, 0.016, 0.105), 0.006, WHITE)
	return b.to_mesh(0.62)

# ---------------------------------------------------------------- skates
## Boot, tendon guard, plastic holder and steel runner; +Z toward the toe.
static func skate(goalie: bool) -> ArrayMesh:
	var b := MeshBuilder.new()
	var boot := Color("#12191f")
	b.add_rounded_box(Vector3(0, 0.035, 0.07), Vector3(0.10, 0.075, 0.28), 0.035, boot)
	b.add_rounded_box(Vector3(0, 0.12, 0.0), Vector3(0.105, 0.17, 0.14), 0.04, boot)
	b.add_rounded_box(Vector3(0, 0.19, -0.065), Vector3(0.05, 0.10, 0.03), 0.013, Color("#2a333a"))
	b.add_rounded_box(Vector3(0, 0.11, 0.07), Vector3(0.07, 0.11, 0.07), 0.025, Color("#d4d9dc"))
	if goalie:
		b.add_rounded_box(Vector3(0, -0.015, 0.07), Vector3(0.06, 0.035, 0.30), 0.012, Color("#d9dee1"))
	else:
		b.add_rounded_box(Vector3(0, -0.015, 0.07), Vector3(0.035, 0.035, 0.27), 0.010, Color("#d9dee1"))
	b.add_rounded_box(Vector3(0, -0.045, 0.07), Vector3(0.006, 0.03, 0.31), 0.002, METAL.lightened(0.2))
	return b.to_mesh(0.4)

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

## Padded hockey pants (breezers) over the thigh, with a side stripe.
static func pants_leg(side: float, kit: Color, base: Color) -> ArrayMesh:
	var radii := [0.118, 0.132, 0.136, 0.134, 0.128, 0.120, 0.112, 0.104, 0.098]
	return _limb(radii, 0.92, func(t: float, a: float) -> Color:
		var outer := cos(a) * side
		if outer > 0.93: return kit
		if t > 0.92: return base.lightened(0.12)
		return base)

## Hockey sock pulled over the shin guard, with team stripes.
static func sock(kit: Color, stripe: Color) -> ArrayMesh:
	var radii := [0.074, 0.078, 0.076, 0.072, 0.068, 0.064, 0.060, 0.057, 0.056]
	return _limb(radii, 1.0, func(t: float, _a: float) -> Color:
		if (t > 0.30 and t < 0.40) or (t > 0.46 and t < 0.51): return stripe
		return kit)
