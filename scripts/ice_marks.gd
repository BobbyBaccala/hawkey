extends Node
## Skate cuts: every blade on the ice scores the "cut map", a two-channel
## texture covering the rink that the ice shader reads:
##   R = fine blade scratches: thin, anti-aliased lines (sub-texel splats along
##       the blade path, so strokes are continuous, never beaded or stair-stepped)
##   G = wear haze: soft, wide, low-intensity build-up where traffic is heavy
##       (faceoff dots, the slot, along the boards), like snow on used ice.
## Both build up over a period; clear() is a fresh flood at period start.

const RINK_SIZE := Vector2(30.0, 60.0)   # x, z extent of the ice (metres)
const PX_PER_M := 36.0                   # ~2.8 cm per texel
const ON_ICE_HEIGHT := 0.11              # skate origin above this = foot lifted
const MIN_SPEED := 0.8                   # m/s blade speed before it cuts
const SCRATCH := 70.0                    # 0..255 added per pass on the line centre
const HAZE := 14.0                        # 0..255 added per haze splat centre
const HAZE_SPACING := 0.35               # metres of blade travel per haze splat
const HAZE_RADIUS := 4                   # texels (~11 cm)
const UPLOAD_INTERVAL := 1.0 / 6.0
## Seconds for a freshly flooded sheet's wet gloss to dry off.
const DRY_TIME := 90.0
## Ice shader whose `fresh` uniform follows the flood (set by lab.gd).
var material: ShaderMaterial
## Painted markings and emblem wear (arena.paint_materials) share the gloss.
var paint_materials: Array = []
## Seconds since the last resurface.
var since_flood := 0.0

var image: Image
var texture: ImageTexture
var last_blade := {}
var haze_travel := {}
var dirty := false
var upload_timer := 0.0
var cut_texels := 0
var haze_kernel: PackedFloat32Array

func _ready() -> void:
	var size := Vector2i(int(RINK_SIZE.x * PX_PER_M), int(RINK_SIZE.y * PX_PER_M))
	image = Image.create(size.x, size.y, true, Image.FORMAT_RG8)
	texture = ImageTexture.create_from_image(image)
	haze_kernel = PackedFloat32Array()
	for dy in range(-HAZE_RADIUS, HAZE_RADIUS + 1):
		for dx in range(-HAZE_RADIUS, HAZE_RADIUS + 1):
			var d := sqrt(dx * dx + dy * dy) / (HAZE_RADIUS + 0.5)
			haze_kernel.append(maxf(0.0, 1.0 - d * d))

func to_texel(p: Vector3) -> Vector2:
	return Vector2((p.x / RINK_SIZE.x + 0.5) * image.get_width(), (p.z / RINK_SIZE.y + 0.5) * image.get_height())

## 1 straight after a flood, falling to 0 as the sheet dries.
func freshness() -> float:
	return clampf(1.0 - since_flood / DRY_TIME, 0.0, 1.0)

func _process(delta: float) -> void:
	since_flood += delta
	if material: material.set_shader_parameter("fresh", freshness())
	for m in paint_materials: m.set_shader_parameter("fresh", freshness())
	var seen := {}
	for visual in get_tree().get_nodes_in_group("skater_visuals"):
		if not is_instance_valid(visual) or not visual.is_inside_tree():
			continue
		for skate in visual.skates:
			var id: int = skate.get_instance_id()
			seen[id] = true
			var now: Vector3 = skate.global_position
			var before = last_blade.get(id)
			last_blade[id] = now
			if before == null or now.y > ON_ICE_HEIGHT or before.y > ON_ICE_HEIGHT:
				continue
			var step: float = Vector2(now.x - before.x, now.z - before.z).length()
			# Ignore teleports (faceoff set-up, line changes) and standing still.
			if step > 1.0 or delta <= 0 or step / delta < MIN_SPEED:
				continue
			var strength := clampf(step / delta / 7.0, 0.35, 1.0)
			score(before, now, strength)
			var travelled: float = haze_travel.get(id, 0.0) + step
			if travelled >= HAZE_SPACING:
				travelled = fmod(travelled, HAZE_SPACING)
				haze(now, strength)
			haze_travel[id] = travelled
	for id in last_blade.keys():
		if not seen.has(id):
			last_blade.erase(id)
			haze_travel.erase(id)
	upload_timer += delta
	if dirty and upload_timer >= UPLOAD_INTERVAL:
		flush()

## Scores one anti-aliased blade stroke from a to b (strength 0..1). Samples
## sit every half texel from a up to, but not including, b, so consecutive
## strokes join without a doubled (beaded) joint.
func score(a: Vector3, b: Vector3, strength: float) -> void:
	var ta := to_texel(a)
	var tb := to_texel(b)
	var samples := maxi(1, int(ceil(ta.distance_to(tb) * 2.0)))
	var add := SCRATCH * strength * 0.5
	for i in range(samples):
		var t := ta.lerp(tb, float(i) / samples) - Vector2(0.5, 0.5)
		var x := int(floor(t.x))
		var y := int(floor(t.y))
		var fx := t.x - x
		var fy := t.y - y
		deposit(x, y, 0, add * (1.0 - fx) * (1.0 - fy))
		deposit(x + 1, y, 0, add * fx * (1.0 - fy))
		deposit(x, y + 1, 0, add * (1.0 - fx) * fy)
		deposit(x + 1, y + 1, 0, add * fx * fy)

## Soft wide splat into the haze channel.
func haze(p: Vector3, strength: float) -> void:
	var c := to_texel(p)
	var cx := int(c.x)
	var cy := int(c.y)
	var k := 0
	for dy in range(-HAZE_RADIUS, HAZE_RADIUS + 1):
		for dx in range(-HAZE_RADIUS, HAZE_RADIUS + 1):
			var w := haze_kernel[k]
			k += 1
			if w > 0.0:
				deposit(cx + dx, cy + dy, 1, HAZE * strength * w)

## Adds `amount` (0..255 scale) to one channel, easing off as it saturates so
## heavy traffic turns into worn ice rather than solid paint.
func deposit(x: int, y: int, channel: int, amount: float) -> void:
	if amount < 0.5 or x < 0 or y < 0 or x >= image.get_width() or y >= image.get_height():
		return
	var c := image.get_pixel(x, y)
	var v := c.r if channel == 0 else c.g
	if v >= 0.999:
		return
	if channel == 0 and v == 0.0:
		cut_texels += 1
	v = minf(1.0, v + amount / 255.0 * (1.0 - v * 0.7))
	if channel == 0: c.r = v
	else: c.g = v
	image.set_pixel(x, y, c)
	dirty = true

func flush() -> void:
	# Mipmaps keep distant cuts as a soft wear tone instead of shimmering pixels.
	image.generate_mipmaps()
	texture.update(image)
	dirty = false
	upload_timer = 0.0

## Fresh sheet: wipes every cut (period start / resurfacing).
func clear() -> void:
	image.fill(Color(0, 0, 0))
	cut_texels = 0
	last_blade.clear()
	haze_travel.clear()
	since_flood = 0.0
	flush()
