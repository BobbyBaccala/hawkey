extends Node3D
## Broadcast arena lighting: overhead spot rigs that throw soft pools of light
## onto each zone of the ice, plus two low, shadowless side lights that catch
## the edges of players (rim light) without flattening the ice.
## Pools are deliberately gentle: the ice stays readable from every camera,
## with a slightly brighter centre under each rig and softer gaps between them.

## Pool centres on the ice (x, z). Two columns either side of the centre line
## and four rows: both end zones and both halves of the neutral zone.
const POOL_X := [-7.0, 7.0]
const POOL_Z := [-21.0, -7.0, 7.0, 21.0]
const RIG_HEIGHT := 19.0
const POOL_ANGLE := 24.0
const POOL_ENERGY := 1.1
const POOL_COLOR := Color("#fff6e8")
const RIM_ENERGY := 0.45
## Visual layer bit given to the arena (ice, boards, bowl, crowd). Rim lights
## skip it, so they only touch players, officials, sticks and the puck.
const ENVIRONMENT_LAYER := 2
const RIM_COLOR := Color("#cfe2ff")

var pools: Array[SpotLight3D] = []
var rims: Array[DirectionalLight3D] = []

func _ready() -> void:
	name = "ArenaLighting"
	for x in POOL_X:
		for z in POOL_Z:
			pools.append(make_pool(Vector3(x, RIG_HEIGHT, z)))
	# Low side lights from each long side: grazing on the ice (little effect
	# there) but bright on helmets, shoulders and pads - a broadcast rim.
	for side in [-1.0, 1.0]:
		var rim := DirectionalLight3D.new()
		rim.name = "RimLight%s" % ("West" if side < 0 else "East")
		rim.light_color = RIM_COLOR
		rim.light_energy = RIM_ENERGY
		rim.light_specular = 1.4
		rim.shadow_enabled = false
		rim.light_cull_mask = 0xFFFFF & ~ENVIRONMENT_LAYER
		# Aim across the rink, 14 degrees above horizontal.
		rim.rotation_degrees = Vector3(-14, 90.0 if side < 0 else -90.0, 0)
		add_child(rim)
		rims.append(rim)

func make_pool(at: Vector3) -> SpotLight3D:
	var spot := SpotLight3D.new()
	spot.name = "Pool_%d_%d" % [int(at.x), int(at.z)]
	spot.position = at
	spot.rotation_degrees = Vector3(-90, 0, 0)  # straight down
	spot.light_color = POOL_COLOR
	spot.light_energy = POOL_ENERGY
	spot.light_specular = 0.6
	spot.spot_range = RIG_HEIGHT * 2.0
	spot.spot_attenuation = 0.0  # even pool, no distance falloff
	spot.spot_angle = POOL_ANGLE
	# A high angle attenuation gives a soft falloff from pool centre to edge.
	spot.spot_angle_attenuation = 3.0
	spot.shadow_enabled = false
	add_child(spot)
	return spot

## Radius of a pool where it meets the ice (metres).
static func pool_radius() -> float:
	return RIG_HEIGHT * tan(deg_to_rad(POOL_ANGLE))

## Moves every mesh under `root` (the arena) onto the environment layer so the
## rim lights leave the ice and stands alone. Cameras render all layers.
static func tag_environment(root: Node) -> int:
	var tagged := 0
	for child in root.find_children("*", "GeometryInstance3D", true, false):
		(child as GeometryInstance3D).layers = ENVIRONMENT_LAYER
		tagged += 1
	return tagged
