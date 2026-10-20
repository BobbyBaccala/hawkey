extends RefCounted
## Retargets Mixamo motion-capture clips onto the Hawkey rig.
##
## Mixamo's terms forbid redistributing the raw files, so they live in the
## git-ignored folder res://assets/mixamo/ (FBX, any skin option). Each clip is
## sampled once at 30 fps into skeleton-independent data: unit directions for
## the spine, neck and limb segments, and hip and foot positions normalised by
## hip height. The player blends these into its procedural pose, so gear,
## sticks and collision keep working. Missing files simply disable a clip.

const FOLDER := "res://assets/mixamo/"
const FPS := 30.0
const SEGMENTS := {
	"spine": ["Hips", "Neck"], "neck": ["Neck", "Head"],
	"upper.L": ["LeftArm", "LeftForeArm"], "fore.L": ["LeftForeArm", "LeftHand"],
	"upper.R": ["RightArm", "RightForeArm"], "fore.R": ["RightForeArm", "RightHand"],
	"thigh.L": ["LeftUpLeg", "LeftLeg"], "shin.L": ["LeftLeg", "LeftFoot"],
	"thigh.R": ["RightUpLeg", "RightLeg"], "shin.R": ["RightLeg", "RightFoot"],
}
const POINTS := ["Hips", "LeftFoot", "RightFoot"]

static var _cache := {}

static func path_for(clip_name: String) -> String:
	var spaced := clip_name.replace("_", " ")
	for candidate in [clip_name + ".fbx", clip_name + "_1.fbx", spaced + ".fbx", spaced + " (1).fbx"]:
		if ResourceLoader.exists(FOLDER + candidate):
			return FOLDER + candidate
	return ""

static func available(clip_name: String) -> bool:
	return _cache.has(clip_name) or path_for(clip_name) != ""

static func _find(node: Node, type_: String) -> Node:
	if node.is_class(type_):
		return node
	for child in node.get_children():
		var found := _find(child, type_)
		if found:
			return found
	return null

## Returns {length, frames, mean, travel} or an empty dictionary.
static func clip(clip_name: String, host: Node) -> Dictionary:
	if _cache.has(clip_name):
		return _cache[clip_name]
	var path := path_for(clip_name)
	if path == "" or host == null or not host.is_inside_tree():
		return {}
	var packed: PackedScene = load(path)
	if packed == null:
		return {}
	var instance := packed.instantiate()
	instance.visible = false
	host.add_child(instance)
	var skeleton: Skeleton3D = _find(instance, "Skeleton3D")
	var player: AnimationPlayer = _find(instance, "AnimationPlayer")
	var data := {}
	if skeleton and player:
		var anim_name := "mixamo_com" if player.has_animation("mixamo_com") else player.get_animation_list()[0]
		var animation := player.get_animation(anim_name)
		var bones := {}
		for i in range(skeleton.get_bone_count()):
			bones[skeleton.get_bone_name(i).trim_prefix("mixamorig_").trim_prefix("mixamorig:")] = i
		var hip_height: float = skeleton.get_bone_global_rest(bones["Hips"]).origin.y
		player.play(anim_name)
		var frames := []
		var count := maxi(2, int(animation.length * FPS) + 1)
		var start := Vector3.ZERO
		var end_ := Vector3.ZERO
		for f in range(count):
			player.seek(minf(f / FPS, animation.length), true)
			var pose := {}
			for bone in bones:
				pose[bone] = skeleton.get_bone_global_pose(bones[bone]).origin
			var frame := {"dirs": {}, "points": {}}
			for key in SEGMENTS:
				var a: Vector3 = pose[SEGMENTS[key][0]]
				var b: Vector3 = pose[SEGMENTS[key][1]]
				frame.dirs[key] = (b - a).normalized()
			var hips: Vector3 = pose["Hips"]
			if f == 0:
				start = hips
			end_ = hips
			for point in POINTS:
				var p: Vector3 = pose[point]
				frame.points[point] = (p if point == "Hips" else p - hips) / hip_height
			frames.append(frame)
		# Remove root travel so clips play in place; keep it for stride timing.
		var travel := Vector3(end_.x - start.x, 0, end_.z - start.z) / hip_height
		for f in range(frames.size()):
			var t := float(f) / (frames.size() - 1)
			frames[f].points["Hips"] -= travel * t + Vector3(start.x, 0, start.z) / hip_height
		data = {"length": animation.length, "frames": frames, "travel": travel, "mean": _mean(frames)}
	instance.queue_free()
	_cache[clip_name] = data
	return data

static func _mean(frames: Array) -> Dictionary:
	var mean := {"dirs": {}, "points": {}}
	for key in SEGMENTS:
		var sum := Vector3.ZERO
		for frame in frames:
			sum += frame.dirs[key]
		mean.dirs[key] = sum.normalized()
	for point in POINTS:
		var sum := Vector3.ZERO
		for frame in frames:
			sum += frame.points[point]
		mean.points[point] = sum / frames.size()
	return mean

## Interpolated frame at time t (seconds).
static func sample(data: Dictionary, t: float, loop := true) -> Dictionary:
	var frames: Array = data.frames
	var length: float = data.length
	t = fposmod(t, length) if loop else clampf(t, 0, length)
	var x := t * FPS
	var i := mini(int(x), frames.size() - 1)
	var j := mini(i + 1, frames.size() - 1)
	var k := x - i
	var a: Dictionary = frames[i]
	var b: Dictionary = frames[j]
	var out := {"dirs": {}, "points": {}}
	for key in a.dirs:
		out.dirs[key] = a.dirs[key].lerp(b.dirs[key], k).normalized()
	for key in a.points:
		out.points[key] = a.points[key].lerp(b.points[key], k)
	return out
