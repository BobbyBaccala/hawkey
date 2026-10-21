extends RefCounted
## Materials and surface detail for the skater kit: polyester jersey knit,
## ripstop nylon breezers, ribbed socks, pebbled glove leather, painted helmet
## shells, skate boots and a clear visor. Every texture is generated here from
## code (tiling height functions turned into mipmapped normal maps, and signed
## distance fields of the engine's built-in font for sewn-on twill numbers) and
## cached once per process, so every skater shares the same textures and every
## skater of one colourway shares the same materials. No external images.
## Works in both gl_compatibility and Forward+ (no renderer-specific features).

const CLOTH := preload("res://assets/kit_cloth.gdshader")
const GEAR := preload("res://assets/kit_gear.gdshader")
const VISOR := preload("res://assets/kit_visor.gdshader")

## Off-white used for numbers and stripe borders (sewn tackle twill).
const TWILL_WHITE := Color("#e9ebe6")

static var _cache := {}

static func cached(key: String, make: Callable) -> Variant:
	if not _cache.has(key):
		_cache[key] = make.call()
	return _cache[key]

# ------------------------------------------------------------------ textures

static func _hash(i: int, j: int, salt := 0) -> float:
	var h := (i * 374761393 + j * 668265263 + salt * 2147483647) & 0x7fffffff
	h = ((h ^ (h >> 13)) * 1274126177) & 0x7fffffff
	h = h ^ (h >> 16)
	return float(h % 65536) / 65536.0

## Tiled Worley F1 distance (cells per tile n) at u,v in 0..1.
static func _worley(u: float, v: float, n: int, salt := 0) -> float:
	var x := u * n
	var y := v * n
	var cx := int(floor(x))
	var cy := int(floor(y))
	var best := 9.0
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var i := cx + dx
			var j := cy + dy
			var wi := posmod(i, n)
			var wj := posmod(j, n)
			var p := Vector2(i + 0.15 + 0.7 * _hash(wi, wj, salt), j + 0.15 + 0.7 * _hash(wj, wi, salt + 7))
			best = minf(best, p.distance_to(Vector2(x, y)))
	return best

## Builds a tiling RGBA normal map from a height function h(u, v) in 0..1 that
## wraps at the edges: rgb = tangent-space normal, a = height (cavity / ambient
## occlusion for the albedo). Mipmapped so the detail fades instead of
## shimmering at gameplay distance.
static func normal_texture(size: int, height: Callable, strength: float) -> ImageTexture:
	var hs := PackedFloat32Array()
	hs.resize(size * size)
	for y in range(size):
		for x in range(size):
			hs[y * size + x] = height.call(float(x) / size, float(y) / size)
	var data := PackedByteArray()
	data.resize(size * size * 4)
	for y in range(size):
		for x in range(size):
			var dx := hs[y * size + (x + 1) % size] - hs[y * size + (x - 1 + size) % size]
			var dy := hs[((y + 1) % size) * size + x] - hs[((y - 1 + size) % size) * size + x]
			var n := Vector3(-dx * strength, -dy * strength, 1.0).normalized()
			var i := (y * size + x) * 4
			data[i] = int(clampf(n.x * 0.5 + 0.5, 0, 1) * 255)
			data[i + 1] = int(clampf(n.y * 0.5 + 0.5, 0, 1) * 255)
			data[i + 2] = int(clampf(n.z * 0.5 + 0.5, 0, 1) * 255)
			data[i + 3] = int(clampf(hs[y * size + x], 0, 1) * 255)
	var img := Image.create_from_data(size, size, false, Image.FORMAT_RGBA8, data)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

## Pro jersey "dimple mesh" polyester: staggered rows of small knit pores
## (8 x 8 per tile) over fine knit wales. One tile spans ~2.4 cm.
static func knit_texture() -> Texture2D:
	return cached("tex|knit", func() -> Texture2D: return normal_texture(128, _h_knit, 9.0))

static func _h_knit(u: float, v: float) -> float:
	var py := v * 8.0
	var row := int(floor(py))
	var px := u * 8.0 + (0.5 if row % 2 == 1 else 0.0)
	var q := Vector2(fposmod(px, 1.0) - 0.5, fposmod(py, 1.0) - 0.5)
	var depth := 0.75 + 0.25 * _hash(posmod(int(floor(px)), 8), row)
	var pore := exp(-q.length_squared() / 0.035) * depth
	# Knit wales: little V loops running down the fabric.
	var wale := absf(sin(PI * (u * 32.0 + absf(fposmod(v * 32.0, 1.0) - 0.5))))
	return clampf(0.82 - 0.75 * pore + 0.12 * wale, 0.0, 1.0)

## Big soft cloth folds and wrinkles (one tile ~0.6 m), mostly running around
## the body the way a sweater bunches over the pants and at the elbows.
static func fold_texture() -> Texture2D:
	return cached("tex|fold", func() -> Texture2D: return normal_texture(128, _h_fold, 2.2))

static func _h_fold(u: float, v: float) -> float:
	var h := 0.0
	h += 0.50 * sin(TAU * (v * 3.0 + 0.18 * sin(TAU * u * 2.0)))
	h += 0.30 * sin(TAU * (v * 5.0 - u * 1.0 + 0.10 * sin(TAU * u * 3.0)))
	h += 0.22 * sin(TAU * (v * 2.0 + u * 3.0))
	h += 0.15 * sin(TAU * (v * 9.0 + 0.3 * sin(TAU * u * 4.0)))
	return 0.5 + 0.38 * h / 1.17

## Ribbed sock knit: ribs run along the leg (vertical in texture v). Tile ~3 cm.
static func rib_texture() -> Texture2D:
	return cached("tex|rib", func() -> Texture2D: return normal_texture(64, _h_rib, 7.0))

static func _h_rib(u: float, v: float) -> float:
	var rib := pow(absf(sin(PI * u * 6.0)), 0.6)
	var loops := 0.12 * absf(sin(PI * (v * 16.0 + absf(fposmod(u * 12.0, 1.0) - 0.5))))
	return clampf(0.2 + 0.7 * rib + loops, 0, 1)

## Ripstop nylon shell for the breezers: a fine twill with a raised grid.
static func ripstop_texture() -> Texture2D:
	return cached("tex|ripstop", func() -> Texture2D: return normal_texture(64, _h_ripstop, 5.0))

static func _h_ripstop(u: float, v: float) -> float:
	var twill := 0.5 + 0.5 * sin(TAU * (u + v) * 8.0)
	var gu := smoothstep(0.40, 0.47, absf(fposmod(u * 4.0, 1.0) - 0.5))
	var gv := smoothstep(0.40, 0.47, absf(fposmod(v * 4.0, 1.0) - 0.5))
	return clampf(0.45 + 0.12 * twill + 0.4 * maxf(gu, gv), 0, 1)

## Pebbled synthetic leather (gloves, skate boots). Tile ~2 cm.
static func leather_texture() -> Texture2D:
	return cached("tex|leather", func() -> Texture2D: return normal_texture(128, _h_leather, 6.0))

static func _h_leather(u: float, v: float) -> float:
	var f := _worley(u, v, 14)
	var fine := _worley(u, v, 37, 3)
	return clampf(smoothstep(0.0, 0.62, f) * 0.8 + 0.2 * smoothstep(0.0, 0.7, fine), 0, 1)

## Painted shell "orange peel": very soft bumps for a believable clearcoat.
static func paint_texture() -> Texture2D:
	return cached("tex|paint", func() -> Texture2D: return normal_texture(64, _h_paint, 1.2))

static func _h_paint(u: float, v: float) -> float:
	return 1.0 - smoothstep(0.0, 0.8, _worley(u, v, 6, 11))

## Fine skin pores / mottling for the skinned body (UV mapped).
static func skin_texture() -> Texture2D:
	return cached("tex|skin", func() -> Texture2D: return normal_texture(128, _h_skin, 1.5))

static func _h_skin(u: float, v: float) -> float:
	var pores := smoothstep(0.0, 0.35, _worley(u, v, 48, 5))
	var blotch := 1.0 - smoothstep(0.0, 0.9, _worley(u, v, 5, 9))
	return clampf(0.55 + 0.3 * pores - 0.2 * blotch, 0, 1)

# --------------------------------------------------------- twill lettering

## Glyph cells: 64 px tall, capitals 40 px, SDF spread 8 px each side.
const GLYPH_H := 64
const GLYPH_CAP := 40.0
const GLYPH_BASELINE := 52.0
const SDF_SPREAD := 8.0

## Signed distance field of one character of the engine's built-in font
## (Open Sans, OFL, embedded in Godot), from its vector outline.
## Returns {"image": PackedByteArray (w*64, 255 = deep inside), "w": int, "advance": float}.
static func glyph(ch: String) -> Dictionary:
	return cached("glyph|" + ch, func() -> Dictionary: return _make_glyph(ch))

static func _make_glyph(ch: String) -> Dictionary:
	var font: Font = ThemeDB.fallback_font
	var ts := TextServerManager.get_primary_interface()
	var rid: RID = font.get_rids()[0]
	var size := int(round(GLYPH_CAP / 0.703))
	var gi := ts.font_get_glyph_index(rid, size, ch.unicode_at(0), 0)
	var advance: float = ts.font_get_glyph_advance(rid, size, gi).x
	var outline: Dictionary = ts.font_get_glyph_contours(rid, size, gi)
	var w := int(ceil(advance + SDF_SPREAD * 2))
	var origin := Vector2(SDF_SPREAD, GLYPH_BASELINE)
	var polys := []
	if outline.has("points"):
		var pts: PackedVector3Array = outline.points
		var start := 0
		for e: int in outline.contours:
			var contour: Array[Vector3] = []
			for k in range(start, e + 1):
				contour.append(pts[k])
			start = e + 1
			var poly := _flatten(contour, origin)
			if poly.size() > 2:
				polys.append(poly)
	var cov := _coverage(polys, w, GLYPH_H)
	return {"image": _sdf(cov, w, GLYPH_H), "w": w, "advance": advance}

## TrueType contour (on-curve and quadratic control points) to a polyline.
static func _flatten(contour: Array[Vector3], origin: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	var n := contour.size()
	var first := -1
	for k in range(n):
		if int(contour[k].z) & 1:
			first = k
			break
	if first < 0:
		return out
	var to2 := func(p: Vector3) -> Vector2: return Vector2(p.x, p.y) + origin
	var prev: Vector2 = to2.call(contour[first])
	out.append(prev)
	var ctrl := Vector2.INF
	for step in range(1, n + 1):
		var p := contour[(first + step) % n]
		var pt: Vector2 = to2.call(p)
		if int(p.z) & 1:
			if ctrl == Vector2.INF:
				out.append(pt)
			else:
				_quad(out, prev, ctrl, pt)
				ctrl = Vector2.INF
			prev = pt
		else:
			if ctrl != Vector2.INF:
				var mid := (ctrl + pt) * 0.5
				_quad(out, prev, ctrl, mid)
				prev = mid
			ctrl = pt
	return out

static func _quad(out: PackedVector2Array, a: Vector2, c: Vector2, b: Vector2) -> void:
	for k in range(1, 7):
		var t := k / 6.0
		out.append(a.lerp(c, t).lerp(c.lerp(b, t), t))

## Even-odd coverage with 4 sub-rows and exact horizontal span coverage.
static func _coverage(polys: Array, w: int, h: int) -> PackedFloat32Array:
	var cov := PackedFloat32Array()
	cov.resize(w * h)
	for row in range(h):
		for s in range(4):
			var y := row + (s + 0.5) / 4.0
			var xs: Array[float] = []
			for poly: PackedVector2Array in polys:
				var count := poly.size()
				for i in range(count):
					var a := poly[i]
					var b := poly[(i + 1) % count]
					if (a.y <= y and b.y > y) or (b.y <= y and a.y > y):
						xs.append(a.x + (y - a.y) / (b.y - a.y) * (b.x - a.x))
			xs.sort()
			for k in range(0, xs.size() - 1, 2):
				var x0 := clampf(xs[k], 0, w)
				var x1 := clampf(xs[k + 1], 0, w)
				var i0 := int(floor(x0))
				var i1 := int(floor(x1))
				if i0 == i1:
					if i0 < w: cov[row * w + i0] += (x1 - x0) * 0.25
					continue
				cov[row * w + i0] += (i0 + 1 - x0) * 0.25
				for i in range(i0 + 1, mini(i1, w)):
					cov[row * w + i] += 0.25
				if i1 < w: cov[row * w + i1] += (x1 - i1) * 0.25
	return cov

## Euclidean distance (dead-reckoning propagation of the nearest seed) both
## ways; pixels on the outline use their exact coverage instead.
static func _sdf(cov: PackedFloat32Array, w: int, h: int) -> PackedByteArray:
	var inside := PackedByteArray()
	inside.resize(w * h)
	for i in range(w * h):
		inside[i] = 1 if cov[i] >= 0.5 else 0
	var d_out := _distance(inside, 1, w, h)
	var d_in := _distance(inside, 0, w, h)
	var out := PackedByteArray()
	out.resize(w * h)
	for i in range(w * h):
		var c := cov[i]
		var signed := (d_out[i] - 0.5) if c < 0.5 else -(d_in[i] - 0.5)
		if c > 0.02 and c < 0.98:
			signed = 0.5 - c
		out[i] = int(clampf(0.5 - signed / (2.0 * SDF_SPREAD), 0.0, 1.0) * 255.0)
	return out

## Distance from every pixel to the nearest pixel whose mask equals `target`.
static func _distance(mask: PackedByteArray, target: int, w: int, h: int) -> PackedFloat32Array:
	var d := PackedFloat32Array()
	var sx := PackedInt32Array()
	var sy := PackedInt32Array()
	d.resize(w * h)
	sx.resize(w * h)
	sy.resize(w * h)
	for i in range(w * h):
		var seed := mask[i] == target
		d[i] = 0.0 if seed else 1e6
		sx[i] = i % w if seed else -100000
		sy[i] = i / w if seed else -100000
	var fwd := [Vector2i(-1, 0), Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1)]
	var bwd := [Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1), Vector2i(-1, 1)]
	for pass_ in range(2):
		var offsets: Array = fwd if pass_ == 0 else bwd
		var ys := range(h) if pass_ == 0 else range(h - 1, -1, -1)
		var xs := range(w) if pass_ == 0 else range(w - 1, -1, -1)
		for y: int in ys:
			for x: int in xs:
				var i := y * w + x
				for o: Vector2i in offsets:
					var nx := x + o.x
					var ny := y + o.y
					if nx < 0 or ny < 0 or nx >= w or ny >= h: continue
					var j := ny * w + nx
					if d[j] >= 1e6: continue
					var ddx := float(x - sx[j])
					var ddy := float(y - sy[j])
					var dist := sqrt(ddx * ddx + ddy * ddy)
					if dist < d[i]:
						d[i] = dist
						sx[i] = sx[j]
						sy[i] = sy[j]
	return d

## SDF texture of a whole string (64 px tall, width in pixels = texture width),
## glyph fields merged with max(). Cached per string.
static func text_texture(text: String, tracking := 1.0) -> ImageTexture:
	return cached("text|%s|%s" % [text, tracking], func() -> ImageTexture:
		var glyphs := []
		var pen := 0.0
		for k in range(text.length()):
			var g := glyph(text[k])
			glyphs.append([g, pen])
			pen += g.advance * tracking
		var w := maxi(int(ceil(pen + SDF_SPREAD * 2)), 4)
		var data := PackedByteArray()
		data.resize(w * GLYPH_H)
		for entry: Array in glyphs:
			var g: Dictionary = entry[0]
			var x0 := int(round(entry[1]))
			var gw: int = g.w
			var src: PackedByteArray = g.image
			for y in range(GLYPH_H):
				for x in range(gw):
					var tx := x0 + x
					if tx < 0 or tx >= w: continue
					var i := y * w + tx
					data[i] = maxi(data[i], src[y * gw + x])
		var img := Image.create_from_data(w, GLYPH_H, false, Image.FORMAT_L8, data)
		img.generate_mipmaps()
		return ImageTexture.create_from_image(img))

# ------------------------------------------------------------------ materials

static func _cloth(kit: Color, accent: Color, garment: int) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = CLOTH
	m.set_shader_parameter("kit", kit)
	m.set_shader_parameter("stripe_color", accent)
	m.set_shader_parameter("trim_color", TWILL_WHITE)
	m.set_shader_parameter("garment", garment)
	m.set_shader_parameter("sheen", 0.35)
	m.set_shader_parameter("knit_tex", knit_texture())
	m.set_shader_parameter("fold_tex", fold_texture())
	return m

## Jersey body with sewn hem stripes, collar and twill number and nameplate.
## One material per colourway + number + name (textures are shared).
static func jersey(kit: Color, accent: Color, number: String, name_: String, referee := false, hem_v := 0.865, collar_v := 0.0) -> ShaderMaterial:
	var key := "jersey|%s|%s|%s|%s|%s|%s|%s" % [kit.to_html(), accent.to_html(), number, name_, referee, hem_v, collar_v]
	return cached(key, func() -> ShaderMaterial:
		var m := _cloth(kit, accent, 3 if referee else 1)
		m.set_shader_parameter("uv_metres", Vector2(0.8, 1.0))
		m.set_shader_parameter("hem_v", hem_v)
		m.set_shader_parameter("collar_v", collar_v)
		if not referee and number != "":
			var tex := text_texture(number, 0.92)
			m.set_shader_parameter("number_tex", tex)
			m.set_shader_parameter("number_aspect", float(tex.get_width()) / GLYPH_H)
			m.set_shader_parameter("show_number", true)
		if not referee and name_ != "":
			var tex := text_texture(name_.to_upper(), 1.06)
			m.set_shader_parameter("name_tex", tex)
			m.set_shader_parameter("name_aspect", float(tex.get_width()) / GLYPH_H)
			m.set_shader_parameter("show_name", true)
		return m)

## Sleeve (UV: u around the arm, v shoulder -> wrist) with elbow stripes and cuff.
static func sleeve(kit: Color, accent: Color, referee := false) -> ShaderMaterial:
	return cached("sleeve|%s|%s|%s" % [kit.to_html(), accent.to_html(), referee], func() -> ShaderMaterial:
		var m := _cloth(kit, accent, 0 if referee else 2)
		m.set_shader_parameter("uv_metres", Vector2(0.52, 0.58))
		return m)

## Plain knit panel without UVs (shoulder yoke caps): object-space mapping.
static func knit_panel(kit: Color, accent: Color) -> ShaderMaterial:
	return cached("panel|%s|%s" % [kit.to_html(), accent.to_html()], func() -> ShaderMaterial:
		var m := _cloth(kit, accent, 0)
		m.set_shader_parameter("use_uv", false)
		return m)

static func _gear(detail: Texture2D, tiles: float, strength: float, roughness: float, specular: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = GEAR
	m.set_shader_parameter("detail_tex", detail)
	m.set_shader_parameter("detail_tiles", tiles)
	m.set_shader_parameter("detail_strength", strength)
	m.set_shader_parameter("roughness", roughness)
	m.set_shader_parameter("specular", specular)
	return m

## Vertex-coloured gear (colours come from gear_builder), so these materials
## are shared by every team (socks: one per colourway).
static func breezers() -> ShaderMaterial:
	return cached("breezers", func() -> ShaderMaterial:
		var m := _gear(ripstop_texture(), 50.0, 0.32, 0.86, 0.24)
		m.set_shader_parameter("sheen", 0.20)
		m.set_shader_parameter("albedo_variation", 0.10)
		m.set_shader_parameter("quilting", 1.0)
		return m)

static func socks(kit: Color, stripe: Color) -> ShaderMaterial:
	return cached("socks|%s|%s" % [kit.to_html(), stripe.to_html()], func() -> ShaderMaterial:
		var m := _gear(rib_texture(), 34.0, 0.9, 0.86, 0.25)
		m.set_shader_parameter("sock_stripes", true)
		m.set_shader_parameter("sock_color", kit)
		m.set_shader_parameter("sock_stripe", stripe)
		m.set_shader_parameter("sheen", 0.45)
		m.set_shader_parameter("albedo_variation", 0.16)
		return m)

static func gloves() -> ShaderMaterial:
	return cached("gloves", func() -> ShaderMaterial:
		var m := _gear(leather_texture(), 40.0, 0.55, 0.68, 0.32)
		m.set_shader_parameter("sheen", 0.25)
		m.set_shader_parameter("albedo_variation", 0.12)
		m.set_shader_parameter("quilting", 0.6)
		return m)

static func skate_boot() -> ShaderMaterial:
	return cached("skate", func() -> ShaderMaterial:
		var m := _gear(leather_texture(), 55.0, 0.45, 0.34, 0.5)
		m.set_shader_parameter("clearcoat", 0.6)
		m.set_shader_parameter("albedo_variation", 0.08)
		m.set_shader_parameter("metal_from_grey", true)
		return m)

## Painted helmet shell: uniform colour, clearcoat over an orange-peel base.
static func helmet_shell(color: Color) -> ShaderMaterial:
	return cached("helmet|%s" % color.to_html(), func() -> ShaderMaterial:
		var m := _gear(paint_texture(), 30.0, 0.015, 0.38, 0.42)
		m.set_shader_parameter("use_vertex_color", false)
		m.set_shader_parameter("base_color", color)
		m.set_shader_parameter("clearcoat", 0.45)
		# The sculpted shell has real vents and ridges; no painted grooves.
		m.set_shader_parameter("helmet_panels", false)
		m.set_shader_parameter("albedo_variation", 0.03)
		return m)

## Matte impact liner/rubber backing: no plastic sparkle inside vent holes.
static func helmet_liner() -> ShaderMaterial:
	return cached("helmet_liner",func() -> ShaderMaterial:
		var m := _gear(ripstop_texture(),40.0,0.06,0.94,0.12)
		m.set_shader_parameter("base_color",Color("#22272b"))
		return m)

## Satin crown insert and lightly translucent ear protection from the photo
## comparison. These do not change the approved visor shader/material.
static func helmet_crown_panel() -> ShaderMaterial:
	return cached("helmet_crown_panel",func() -> ShaderMaterial:
		var m := _gear(paint_texture(),30.0,0.01,0.45,0.32)
		m.set_shader_parameter("use_vertex_color",false)
		m.set_shader_parameter("base_color",Color("#1b2b3b"))
		return m)
static func helmet_ears() -> StandardMaterial3D:
	return cached("helmet_ears",func() -> StandardMaterial3D:
		var m := StandardMaterial3D.new()
		m.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
		m.cull_mode=BaseMaterial3D.CULL_DISABLED
		m.albedo_color=Color(0.62,0.69,0.73,0.38)
		m.roughness=0.14;m.metallic_specular=0.65
		return m)

## Original clips/silver fasteners; preserve vertex colors independently of
## the dark liner so hardware does not disappear into the shell.
static func helmet_hardware() -> ShaderMaterial:
	return cached("helmet_hardware",func() -> ShaderMaterial:
		var m := _gear(paint_texture(),60.0,0.05,0.55,0.30)
		m.set_shader_parameter("metal_from_grey",true)
		return m)

## Matte woven nylon, distinct from the retention clips and painted shell.
static func chinstrap() -> ShaderMaterial:
	return cached("chinstrap", func() -> ShaderMaterial:
		return _gear(ripstop_texture(),120.0,0.14,0.88,0.20))

## Hard plastic / rubber parts (vents, clips) with a light texture.
static func plastic(color: Color, roughness := 0.45) -> ShaderMaterial:
	return cached("plastic|%s|%s" % [color.to_html(), roughness], func() -> ShaderMaterial:
		var m := _gear(paint_texture(), 30.0, 0.3, roughness, 0.45)
		m.set_shader_parameter("use_vertex_color", false)
		m.set_shader_parameter("base_color", color)
		return m)

static func visor() -> ShaderMaterial:
	return cached("visor", func() -> ShaderMaterial:
		var m := ShaderMaterial.new()
		m.shader = VISOR
		return m)
