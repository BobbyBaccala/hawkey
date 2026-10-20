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
