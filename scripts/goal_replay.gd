extends Node
## Goal replay: a broadcast-style instant replay after every goal.
##
## The match calls capture(delta) every live physics tick: a ring buffer keeps
## the last KEEP seconds at RATE frames per second, each frame holding the puck
## and, for every tracked figure (skaters, goalies, officials), the visual's
## world transform, the local transform and visibility of every Node3D under it
## (skates, stick, pads, gloves, nameplate...) and every skeleton bone's pose.
## goal(end_sign) marks the goal; START_DELAY seconds later a "REPLAY" wipe
## sweeps across the screen and, while it covers the picture, the clip
## [goal - BEFORE, goal + AFTER] starts playing from a reverse-angle camera
## above the end boards of the net that was scored on, dropping to SLOW speed
## for the last SLOW_FROM seconds before the puck crosses (clip_duration() is
## 4-6 s). While playing() the match is frozen and calls step(delta) instead;
## at the end a second wipe covers the cut back to the live picture, which is
## restored exactly as it was (figures, puck, camera). skip() cuts it short.

const RATE := 30.0
const KEEP := 8.0
const BEFORE := 3.2
const AFTER := 0.6
const SLOW_FROM := 1.0
const SLOW := 0.5
const START_DELAY := 2.0
const WIPE := 0.6
const SLATE := Color("#0b1118")
const ACCENT := Color("#e8b83a")
const INK := Color("#f2f5f8")

var camera: Camera3D
var puck: Node3D
## Node whose _process should pause during playback (skate-cut map), optional.
var ice_marks: Node
var actors: Array[Node3D] = []
var frames: Array = []
var clock := 0.0
var goal_time := -1.0
var end_sign := 1.0
var play_t := 0.0
var _accum := 0.0
var _nodes: Array = []
var _skels: Array = []
var _playing := false
var _ending := false
var _end_wait := 0.0
var _live: Dictionary = {}
var _cam_saved := {}
var _look := Vector3.ZERO
var _side := 1.0
var _clip_start := 0.0
var _clip_end := 0.0
var _wipe_t := -1.0

var layer: CanvasLayer
var wipe: Node2D
var wipe_label: Label
var tag: PanelContainer

## Seconds the replay runs on screen (clip at its playback speeds).
static func clip_duration() -> float:
	return (BEFORE - SLOW_FROM) + (SLOW_FROM + AFTER) / SLOW

func _ready() -> void:
	build_ui()

func track(nodes: Array) -> void:
	for n in nodes:
		if n is Node3D and not actors.has(n): actors.append(n)
	_nodes.clear()
	_skels.clear()
	frames.clear()

func playing() -> bool:
	return _playing

func pending() -> bool:
	return goal_time >= 0.0 and not _playing

## Live tick: record (RATE fps) and start a pending replay when its time comes.
func capture(delta: float) -> void:
	clock += delta
	_tick_wipe(delta)
	_accum += delta
	if _accum >= 1.0 / RATE or frames.is_empty():
		_accum = fmod(_accum, 1.0 / RATE)
		frames.append(snapshot())
		while frames.size() > 2 and clock - float(frames[0].t) > KEEP: frames.pop_front()
	if goal_time >= 0.0:
		var start := goal_time + START_DELAY
		if _wipe_t < 0.0 and clock >= start - WIPE * 0.5: _wipe_t = 0.0
		if clock >= start: begin()

func goal(end_: float) -> void:
	if _playing: return
	goal_time = clock
	end_sign = end_

func begin() -> void:
	if frames.size() < 2:
		goal_time = -1.0
		return
	_live = snapshot()
	_clip_start = maxf(goal_time - BEFORE, float(frames[0].t))
	_clip_end = minf(goal_time + AFTER, float(frames[-1].t))
	play_t = _clip_start
	_playing = true
	_ending = false
	_cam_saved = {"xf": camera.global_transform, "fov": camera.fov, "mask": camera.cull_mask}
	if ice_marks: ice_marks.set_process(false)
	# Shoot across from the side of the rink the puck is not coming from.
	var p0: Transform3D = sample(_clip_start).puck
	_side = -signf(p0.origin.x) if absf(p0.origin.x) > 0.5 else 1.0
	_look = Vector3(0, 0.3, end_sign * 22.0)
	tag.visible = true
	apply(sample(play_t))
	aim_camera(0.0, true)

## Playback tick (called instead of the live simulation).
func step(delta: float) -> void:
	_tick_wipe(delta)
	if not _playing: return
	if _ending:
		_end_wait -= delta
		if _end_wait <= 0.0: finish()
		return
	play_t += delta * (SLOW if play_t >= goal_time - SLOW_FROM else 1.0)
	if play_t >= _clip_end:
		play_t = _clip_end
		_start_end()
	apply(sample(play_t))
	aim_camera(delta, false)

func skip() -> void:
	if _playing and not _ending: _start_end()

func _start_end() -> void:
	_ending = true
	_end_wait = WIPE * 0.5
	_wipe_t = 0.0

func finish() -> void:
	apply(_live)
	camera.global_transform = _cam_saved.xf
	camera.fov = _cam_saved.fov
	camera.cull_mask = _cam_saved.mask
	if ice_marks: ice_marks.set_process(true)
	_playing = false
	_ending = false
	goal_time = -1.0
	tag.visible = false
	_live = {}

func aim_camera(delta: float, snap: bool) -> void:
	var p: Vector3 = puck.global_position
	var net := Vector3(0, 0.5, end_sign * preload("res://scripts/arena.gd").GOAL_LINE)
	# Frame the puck with the net low in the picture and the play coming at us.
	var target := p.lerp(net, 0.25) - Vector3(0, 0, end_sign * 2.5)
	target.y = 0.6
	_look = target if snap else _look.lerp(target, 1.0 - exp(-delta * 4.0))
	var half := preload("res://scripts/arena.gd").HALF_LENGTH
	var pos := Vector3(_side * 3.0 + clampf(_look.x * 0.3, -2.0, 2.0), 5.2, end_sign * (half + 0.4))
	camera.global_position = pos
	camera.look_at(_look, Vector3.UP)
	# Push in a little as the play slows down at the net.
	var slow := clampf((play_t - (goal_time - SLOW_FROM)) / (SLOW_FROM + AFTER), 0.0, 1.0)
	camera.fov = lerpf(52.0, 42.0, smoothstep(0.0, 1.0, slow))
	camera.cull_mask = preload("res://scripts/arena_lighting.gd").camera_cull_mask(camera.global_position)

# ---------------------------------------------------------------- recording

func _collect() -> void:
	_nodes.clear()
	_skels.clear()
	for a in actors:
		var list: Array[Node3D] = [a]
		var skels: Array[Skeleton3D] = []
		_walk(a, list, skels)
		_nodes.append(list)
		_skels.append(skels)

func _walk(n: Node, list: Array[Node3D], skels: Array[Skeleton3D]) -> void:
	for c in n.get_children():
		if c is BoneAttachment3D: continue
		if c is Skeleton3D: skels.append(c)
		if c is Node3D: list.append(c)
		_walk(c, list, skels)

func snapshot() -> Dictionary:
	if _nodes.size() != actors.size(): _collect()
	var out := []
	for i in range(actors.size()):
		var list: Array = _nodes[i]
		var xf: Array[Transform3D] = []
		var vis := PackedByteArray()
		xf.resize(list.size())
		vis.resize(list.size())
		for j in range(list.size()):
			var n: Node3D = list[j]
			if not is_instance_valid(n): continue
			xf[j] = n.global_transform if j == 0 else n.transform
			vis[j] = 1 if n.visible else 0
		var bones: Array = []
		for s in _skels[i]:
			var poses: Array[Transform3D] = []
			if is_instance_valid(s):
				poses.resize(s.get_bone_count())
				for b in range(poses.size()): poses[b] = s.get_bone_global_pose(b)
			bones.append(poses)
		out.append({"xf": xf, "vis": vis, "bones": bones})
	return {"t": clock, "puck": puck.global_transform, "actors": out}

## Recorded state at clip time t, blended between the two nearest frames.
func sample(t: float) -> Dictionary:
	var lo := 0
	var hi := frames.size() - 1
	if t <= float(frames[0].t): return frames[0]
	if t >= float(frames[hi].t): return frames[hi]
	while hi - lo > 1:
		var mid := (lo + hi) / 2
		if float(frames[mid].t) <= t: lo = mid
		else: hi = mid
	var a: Dictionary = frames[lo]
	var b: Dictionary = frames[hi]
	var w := (t - float(a.t)) / maxf(float(b.t) - float(a.t), 0.0001)
	# Far apart (teleport, faceoff set-up) frames do not blend.
	var pa: Transform3D = a.puck
	var pb: Transform3D = b.puck
	var puck_xf := pa.interpolate_with(pb, w) if pa.origin.distance_to(pb.origin) < 3.0 else (pa if w < 0.5 else pb)
	var out := []
	for i in range(a.actors.size()):
		var fa: Dictionary = a.actors[i]
		var fb: Dictionary = b.actors[i]
		var xa: Array = fa.xf
		var xb: Array = fb.xf
		if xa.size() != xb.size() or (xa[0] as Transform3D).origin.distance_to((xb[0] as Transform3D).origin) > 2.0:
			out.append(fa if w < 0.5 else fb)
			continue
		var xf: Array[Transform3D] = []
		xf.resize(xa.size())
		for j in range(xa.size()): xf[j] = (xa[j] as Transform3D).interpolate_with(xb[j], w)
		var bones: Array = []
		for k in range(fa.bones.size()):
			var ba: Array = fa.bones[k]
			var bb: Array = fb.bones[k]
			var poses: Array[Transform3D] = []
			poses.resize(ba.size())
			for m in range(ba.size()): poses[m] = (ba[m] as Transform3D).interpolate_with(bb[m], w)
			bones.append(poses)
		out.append({"xf": xf, "vis": fa.vis if w < 0.5 else fb.vis, "bones": bones})
	return {"t": t, "puck": puck_xf, "actors": out}

func apply(frame: Dictionary) -> void:
	puck.global_transform = frame.puck
	var data: Array = frame.actors
	for i in range(mini(data.size(), _nodes.size())):
		var list: Array = _nodes[i]
		var f: Dictionary = data[i]
		var xf: Array = f.xf
		for j in range(mini(list.size(), xf.size())):
			var n: Node3D = list[j]
			if not is_instance_valid(n): continue
			if j == 0: n.global_transform = xf[j]
			else: n.transform = xf[j]
			n.visible = f.vis[j] == 1
		for k in range(mini(f.bones.size(), _skels[i].size())):
			var s: Skeleton3D = _skels[i][k]
			if not is_instance_valid(s): continue
			var poses: Array = f.bones[k]
			s.clear_bones_global_pose_override()
			for b in range(mini(poses.size(), s.get_bone_count())):
				s.set_bone_global_pose_override(b, poses[b], 1.0, true)

# ---------------------------------------------------------------- wipe UI

func build_ui() -> void:
	layer = CanvasLayer.new()
	layer.layer = 6
	add_child(layer)
	wipe = Node2D.new()
	wipe.visible = false
	layer.add_child(wipe)
	var band := Polygon2D.new()
	band.name = "Band"
	band.color = Color(SLATE, 0.97)
	wipe.add_child(band)
	var stripe := Polygon2D.new()
	stripe.name = "Stripe"
	stripe.color = ACCENT
	wipe.add_child(stripe)
	var stripe2 := Polygon2D.new()
	stripe2.name = "Stripe2"
	stripe2.color = ACCENT
	wipe.add_child(stripe2)
	wipe_label = Label.new()
	wipe_label.text = "REPLAY"
	wipe_label.add_theme_font_override("font", _font(800))
	wipe_label.add_theme_font_size_override("font_size", 120)
	wipe_label.add_theme_color_override("font_color", INK)
	wipe_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wipe_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	wipe.add_child(wipe_label)
	tag = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(SLATE, 0.92)
	style.border_color = ACCENT
	style.border_width_left = 8
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	tag.add_theme_stylebox_override("panel", style)
	var tag_label := Label.new()
	tag_label.text = "REPLAY"
	tag_label.add_theme_font_override("font", _font(800))
	tag_label.add_theme_font_size_override("font_size", 30)
	tag_label.add_theme_color_override("font_color", INK)
	tag.add_child(tag_label)
	tag.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	tag.offset_left = -200
	tag.offset_right = -36
	tag.offset_top = 28
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tag.visible = false
	layer.add_child(tag)

func _font(weight: int) -> Font:
	var f := SystemFont.new()
	f.font_names = PackedStringArray(["Bahnschrift", "DIN Alternate", "Barlow Condensed", "Roboto Condensed", "Arial Narrow", "DejaVu Sans Condensed", "DejaVu Sans"])
	f.font_weight = weight
	f.font_stretch = 75
	f.font_italic = true
	return f

## Wipe progress 0..1: the slanted band enters from the left, covers the whole
## picture at 0.5 (the moment the cut happens) and leaves to the right.
func _tick_wipe(delta: float) -> void:
	if _wipe_t < 0.0:
		wipe.visible = false
		return
	_wipe_t += delta / WIPE
	if _wipe_t >= 1.0:
		_wipe_t = -1.0
		wipe.visible = false
		return
	layout_wipe(_wipe_t)

func wipe_progress() -> float:
	return _wipe_t

func layout_wipe(u: float) -> void:
	var size := Vector2(1728, 1080)
	if is_inside_tree(): size = get_viewport().get_visible_rect().size
	var slant := size.y * 0.35
	var w := size.x + 2.0 * slant
	# Off left (-w) -> covering the picture (-1.5 slant) at u 0.42-0.58 -> off right.
	var x: float
	if u < 0.5: x = lerpf(-w, -1.5 * slant, smoothstep(0.0, 1.0, u / 0.42))
	else: x = lerpf(-1.5 * slant, size.x, smoothstep(0.0, 1.0, (u - 0.58) / 0.42))
	wipe.visible = true
	wipe.position = Vector2(x, 0)
	(wipe.get_node("Band") as Polygon2D).polygon = PackedVector2Array([Vector2(slant, 0), Vector2(w + slant, 0), Vector2(w, size.y), Vector2(0, size.y)])
	(wipe.get_node("Stripe") as Polygon2D).polygon = PackedVector2Array([Vector2(w + slant, 0), Vector2(w + slant + 22, 0), Vector2(w + 22, size.y), Vector2(w, size.y)])
	(wipe.get_node("Stripe2") as Polygon2D).polygon = PackedVector2Array([Vector2(slant - 34, 0), Vector2(slant - 22, 0), Vector2(-22, size.y), Vector2(-34, size.y)])
	wipe_label.position = Vector2(1.5 * slant, 0)
	wipe_label.size = size
