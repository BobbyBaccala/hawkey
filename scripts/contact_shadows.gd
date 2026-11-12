extends MultiMeshInstance3D
## Soft contact shadows that ground every skater, goalie and official on the
## ice: one wide ambient-occlusion blob under the body and one tight, darker
## streak under each skate runner that fades as the skate lifts off the ice.
##
## Works in both renderers. gl_compatibility has no SSAO, so without this the
## players float on the bright sheet; in Forward+ it sits on top of SSAO and
## the key-light shadow as the "contact" term those miss at gameplay distance.
## All blobs are instances of one MultiMesh (a single draw call), updated per
## frame from the skater visuals' public `skates` array.
##
## Skater visuals are picked up automatically (SceneTree.node_added), so lab,
## match and capture tools all get shadows without touching skater_visual.gd.

const SkaterScript = preload("res://scripts/skater_visual.gd")

## Height just above every painted marking and the centre emblem
## (its wear layer sits at 0.027 m).
const ICE_Y := 0.029
## Body blob size (x across the shoulders, z along facing) and darkness.
const BODY_SIZE := Vector2(1.2, 0.95)
const GOALIE_BODY_SIZE := Vector2(1.5, 1.15)
const BODY_STRENGTH := 0.8
## Skate streak: runner length/width and darkness when planted.
const SKATE_SIZE := Vector2(0.17, 0.46)
const SKATE_STRENGTH := 0.9
## Skate origin height when the runner is on the ice, and how much lift fades
## the streak out completely.
const SKATE_PLANTED_Y := 0.06
const SKATE_FADE_HEIGHT := 0.22
const MAX_INSTANCES := 96

var tracked: Array[Node3D] = []
## Blobs drawn last refresh: [{"xform": Transform3D, "strength", "hardness",
## "visual"}]. Kept on the CPU side too so tests can check them headless.
var blobs: Array[Dictionary] = []

func _init() -> void:
	name = "ContactShadows"
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	custom_aabb = AABB(Vector3(-80, -1, -80), Vector3(160, 4, 160))
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	quad.orientation = PlaneMesh.FACE_Y
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = quad
	mm.instance_count = MAX_INSTANCES
	mm.visible_instance_count = 0
	multimesh = mm
	var shader := Shader.new()
	shader.code = """shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
varying float strength;
varying float hardness;
void vertex(){ strength = INSTANCE_CUSTOM.r; hardness = INSTANCE_CUSTOM.g; }
void fragment(){
	float r = length(UV * 2.0 - 1.0);
	// Soft core, long feathered tail: occlusion falls off with distance from
	// the contact point; hardness tightens the skate streaks.
	float a = pow(clamp(1.0 - r, 0.0, 1.0), mix(1.2, 0.8, hardness));
	ALBEDO = vec3(0.012, 0.018, 0.03);
	ALPHA = a * strength;
}"""
	var mat := ShaderMaterial.new()
	mat.shader = shader
	material_override = mat

func _enter_tree() -> void:
	if not get_tree().node_added.is_connected(_on_node_added):
		get_tree().node_added.connect(_on_node_added)
	for node in get_tree().root.find_children("*", "Node3D", true, false):
		_on_node_added(node)

func _exit_tree() -> void:
	if get_tree().node_added.is_connected(_on_node_added):
		get_tree().node_added.disconnect(_on_node_added)

func _on_node_added(node: Node) -> void:
	if node.get_script() == SkaterScript and not tracked.has(node):
		tracked.append(node)
		node.tree_exiting.connect(func(): tracked.erase(node))

## Number of shadow instances a visual gets (body + one per skate).
static func shadows_for(visual: Node3D) -> int:
	return 1 + visual.skates.size()

func _process(_delta: float) -> void:
	refresh()

func refresh() -> void:
	var i := 0
	blobs.clear()
	for visual in tracked:
		if not is_instance_valid(visual) or not visual.is_inside_tree() or not visual.is_visible_in_tree():
			continue
		# Bench figures (arena_benches.gd) leave the group: they sit off the ice.
		if not visual.is_in_group("skater_visuals"): continue
		if i + 3 > MAX_INSTANCES: break
		var origin: Vector3 = visual.global_position
		var yaw: float = visual.global_rotation.y
		var size: Vector2 = GOALIE_BODY_SIZE if visual.goalie else BODY_SIZE
		# Body blob centred between the hips' ground point and the skates.
		var centre := origin
		var count := 1.0
		for skate in visual.skates:
			centre += Vector3(skate.global_position.x, origin.y, skate.global_position.z)
			count += 1.0
		centre /= count
		# A body off the ice (board hop) casts a fading blob on the ground below.
		var body_lift := clampf(origin.y / 0.5, 0.0, 1.0)
		centre.y = 0.0
		push(i, blob(centre, yaw, size), BODY_STRENGTH * (1.0 - body_lift), 0.0, visual)
		i += 1
		for skate in visual.skates:
			var p: Vector3 = skate.global_position
			var lift := clampf((p.y - SKATE_PLANTED_Y) / SKATE_FADE_HEIGHT, 0.0, 1.0)
			var fwd: Vector3 = skate.global_basis.z
			fwd.y = 0
			var skate_yaw := atan2(fwd.x, fwd.z) if fwd.length_squared() > 1e-6 else yaw
			# Centre under the runner (toe 0.225 ahead, heel 0.085 behind).
			var at := p + fwd.normalized() * 0.07 if fwd.length_squared() > 1e-6 else p
			var grow := 1.0 + lift * 0.6   # spreads and softens as it lifts
			push(i, blob(at, skate_yaw, SKATE_SIZE * grow), SKATE_STRENGTH * (1.0 - lift) * (1.0 - lift), 1.0 - lift, visual)
			i += 1
	multimesh.visible_instance_count = i

func push(i: int, xform: Transform3D, strength: float, hardness: float, visual: Node3D) -> void:
	multimesh.set_instance_transform(i, xform)
	multimesh.set_instance_custom_data(i, Color(strength, hardness, 0, 0))
	blobs.append({"xform": xform, "strength": strength, "hardness": hardness, "visual": visual})

static func blob(at: Vector3, yaw: float, size: Vector2) -> Transform3D:
	var basis := Basis(Vector3.UP, yaw).scaled_local(Vector3(size.x, 1.0, size.y))
	return Transform3D(basis, Vector3(at.x, ICE_Y, at.z))

## Instances currently drawn for one visual (tests).
func instance_count() -> int:
	return multimesh.visible_instance_count
