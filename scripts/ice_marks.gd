extends Node
## Skate cuts: every skate blade on the ice scores a thin line into a
## low-resolution "cut map" covering the whole rink. The ice shader darkens and
## roughens the ice where cuts build up, so trails stay behind players and the
## ice gets visibly worn as a period goes on. clear() is a fresh resurface.

const RINK_SIZE := Vector2(30.0, 60.0)   # x, z extent of the ice (metres)
const PX_PER_M := 24.0                   # ~4 cm per texel
const ON_ICE_HEIGHT := 0.11              # skate origin above this = foot lifted
const MIN_SPEED := 0.6                   # m/s blade speed before it cuts
const UPLOAD_INTERVAL := 1.0 / 15.0
## Seconds for a freshly flooded sheet's wet gloss to dry off.
const DRY_TIME := 90.0
## Ice shader whose `fresh` uniform follows the flood (set by lab.gd).
var material: ShaderMaterial
## Seconds since the last resurface.
var since_flood := 0.0

var image: Image
var texture: ImageTexture
var last_blade := {}
var dirty := false
var upload_timer := 0.0
var cut_texels := 0

func _ready() -> void:
	var size := Vector2i(int(RINK_SIZE.x * PX_PER_M), int(RINK_SIZE.y * PX_PER_M))
	image = Image.create(size.x, size.y, false, Image.FORMAT_L8)
	texture = ImageTexture.create_from_image(image)

func to_texel(p: Vector3) -> Vector2:
	return Vector2((p.x / RINK_SIZE.x + 0.5) * image.get_width(), (p.z / RINK_SIZE.y + 0.5) * image.get_height())

## 1 straight after a flood, falling to 0 as the sheet dries.
func freshness() -> float:
	return clampf(1.0 - since_flood / DRY_TIME, 0.0, 1.0)

func _process(delta: float) -> void:
	since_flood += delta
	if material: material.set_shader_parameter("fresh", freshness())
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
			score(before, now, clampf(step / delta / 8.0, 0.25, 1.0))
	for id in last_blade.keys():
		if not seen.has(id):
			last_blade.erase(id)
	upload_timer += delta
	if dirty and upload_timer >= UPLOAD_INTERVAL:
		flush()

## Scores a line from a to b with strength 0..1 into the cut map.
func score(a: Vector3, b: Vector3, strength: float) -> void:
	var ta := to_texel(a)
	var tb := to_texel(b)
	var steps := maxi(1, int(ceil(ta.distance_to(tb))))
	var add := int(85.0 * strength)
	for i in range(steps + 1):
		var t := ta.lerp(tb, float(i) / steps)
		var x := int(t.x)
		var y := int(t.y)
		cut(x, y, add)
		# A blade edge reads about two texels wide from broadcast height.
		cut(x + 1, y, add >> 1)

func cut(x: int, y: int, add: int) -> void:
	if x < 0 or y < 0 or x >= image.get_width() or y >= image.get_height():
		return
	var v := image.get_pixel(x, y).r8
	if v < 255:
		if v == 0: cut_texels += 1
		image.set_pixel(x, y, Color8(mini(255, v + add), 0, 0))
		dirty = true

func flush() -> void:
	texture.update(image)
	dirty = false
	upload_timer = 0.0

## Fresh sheet: wipes every cut (period start / resurfacing).
func clear() -> void:
	image.fill(Color(0, 0, 0))
	cut_texels = 0
	last_blade.clear()
	since_flood = 0.0
	flush()
