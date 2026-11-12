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
##
## Each goal picks one of several broadcast angles (pick_angle()) from the shot:
## "follow" (shooter cam riding behind the puck) for long shots, "ice" (low
## ice-level camera inside the end boards beside the net) for close-range
## goals, "overhead" (looking down on the crease) for plays that cross the slot,
## otherwise "reverse" (above the end boards) - never the same angle twice in a
## row. A skip prompt sits in the corner while it plays.
##
## Big saves get a replay too: the match calls big_save(end_sign, strength) when
## a goalie stops a hard shot, and whistle() when play next stops; if the whistle
## comes within SAVE_WINDOW seconds of the save, the save is replayed (SAVE_*
## clip around the save, tag "GREAT SAVE") SAVE_DELAY after the whistle, so a
## save never interrupts live play. In slow motion a crisp puck trail (a
## camera-facing ribbon through the puck's recorded path, fading out over
## TRAIL_TIME of clip time) shows where the shot went.

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
const SAVE_BEFORE := 2.6
const SAVE_AFTER := 1.0
const SAVE_SLOW_FROM := 0.8
const SAVE_WINDOW := 4.0
const SAVE_DELAY := 1.0
## Weakest save (crowd reaction strength from match.gd save_reaction()) replayed.
const SAVE_MIN := 0.2
const TRAIL_TIME := 0.4
const TRAIL_STEPS := 24
const TRAIL_WIDTH := 0.09
## Saturated broadcast blue: the old pale blue-white vanished against the white
## ice (the ribbon drew, but at ~3% contrast it read as nothing).
const TRAIL_COLOR := Color(0.05, 0.42, 1.0)
const ANGLES := ["reverse", "ice", "overhead", "follow"]
const ANGLE_NAMES := {"reverse": "REVERSE ANGLE", "ice": "ICE LEVEL", "overhead": "OVERHEAD", "follow": "SHOOTER CAM"}
const Arena := preload("res://scripts/arena.gd")

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
## Camera angle of the current/last replay, and an override ("" = pick).
var angle := "reverse"
var last_angle := ""
var force_angle := ""
var _cam_pos := Vector3.ZERO
var _shot_dir := Vector3.BACK
var _release_t := 0.0
var _release_pos := Vector3.ZERO
## "goal" or "save": what the pending/current replay shows (goal_time is the
## moment of the event either way).
var kind := "goal"
var _before := BEFORE
var _after := AFTER
var _slow_from := SLOW_FROM
var _delay := START_DELAY
var _save_t := -100.0
var _save_end := 1.0
var _save_strength := 0.0
var trail: MeshInstance3D
var _trail_mesh: ImmediateMesh

var layer: CanvasLayer
var wipe: Node2D
var wipe_label: Label
var tag: PanelContainer
var angle_label: Label
var skip_prompt: PanelContainer

## Seconds the replay runs on screen (clip at its playback speeds).
static func clip_duration(what := "goal") -> float:
	if what == "save": return (SAVE_BEFORE - SAVE_SLOW_FROM) + (SAVE_SLOW_FROM + SAVE_AFTER) / SLOW
	return (BEFORE - SLOW_FROM) + (SLOW_FROM + AFTER) / SLOW

func _ready() -> void:
	build_ui()
	build_trail()

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
		var start := goal_time + _delay
		if _wipe_t < 0.0 and clock >= start - WIPE * 0.5: _wipe_t = 0.0
		if clock >= start: begin()

func goal(end_: float) -> void:
	if _playing: return
	goal_time = clock
	end_sign = end_
	_set_kind("goal")
	_save_t = -100.0

## A goalie stopped a hard shot (strength: match.gd save_reaction(), 0..0.55).
## Remembered until the next whistle; the strongest recent save wins.
func big_save(end_: float, strength: float) -> void:
	if _playing or strength < SAVE_MIN: return
	if clock - _save_t < SAVE_WINDOW and strength < _save_strength: return
	_save_t = clock
	_save_end = end_
	_save_strength = strength

## Play has stopped (not for a goal): replay a big save from just before it.
## Returns true if a save replay was queued.
func whistle() -> bool:
	if _playing or goal_time >= 0.0: return false
	if clock - _save_t > SAVE_WINDOW: return false
	goal_time = _save_t
	end_sign = _save_end
	_set_kind("save")
	_delay = clock - _save_t + SAVE_DELAY
	_save_t = -100.0
	return true

func _set_kind(what: String) -> void:
	kind = what
	var save := what == "save"
	_before = SAVE_BEFORE if save else BEFORE
	_after = SAVE_AFTER if save else AFTER
	_slow_from = SAVE_SLOW_FROM if save else SLOW_FROM
	_delay = START_DELAY

func begin() -> void:
	if frames.size() < 2:
		goal_time = -1.0
		return
	_live = snapshot()
	_clip_start = maxf(goal_time - _before, float(frames[0].t))
	_clip_end = minf(goal_time + _after, float(frames[-1].t))
	play_t = _clip_start
	_playing = true
	_ending = false
	_cam_saved = {"xf": camera.global_transform, "fov": camera.fov, "mask": camera.cull_mask}
	if ice_marks: ice_marks.set_process(false)
	# Shoot across from the side of the rink the puck is not coming from.
	var p0: Transform3D = sample(_clip_start).puck
	_side = -signf(p0.origin.x) if absf(p0.origin.x) > 0.5 else 1.0
	_look = Vector3(0, 0.3, end_sign * 22.0)
	var net := Vector3(0, 0, end_sign * Arena.GOAL_LINE)
	_release_t = release_time()
	var shot_from: Vector3 = (sample(_release_t).puck as Transform3D).origin
	_release_pos = shot_from
	var early: Vector3 = (sample(goal_time - 1.2).puck as Transform3D).origin
	var late: Vector3 = (sample(goal_time - 0.1).puck as Transform3D).origin
	angle = force_angle if ANGLES.has(force_angle) else pick_angle(shot_from, net, absf(late.x - early.x), last_angle)
	last_angle = angle
	var away := Vector3(shot_from.x - net.x, 0, shot_from.z - net.z)
	_shot_dir = away.normalized() if away.length() > 0.5 else Vector3(0, 0, -end_sign)
	angle_label.text = ("GREAT SAVE  ·  " if kind == "save" else "") + ANGLE_NAMES[angle]
	tag.visible = true
	skip_prompt.visible = true
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
	play_t += delta * (SLOW if slow_motion() else 1.0)
	if play_t >= _clip_end:
		play_t = _clip_end
		_start_end()
	apply(sample(play_t))
	aim_camera(delta, false)
	update_trail()

func slow_motion() -> bool:
	return _playing and play_t >= goal_time - _slow_from

func skip() -> void:
	if _playing and not _ending: _start_end()

## Clip time the shot left the stick: the first moment in the 1.5 s before the
## goal the puck moves faster than 12 m/s (goal - 0.45 s if none is found).
func release_time() -> float:
	var prev: Dictionary = {}
	for f in frames:
		var t := float(f.t)
		if t < goal_time - 1.5 or t > goal_time: continue
		if not prev.is_empty():
			var v := (f.puck as Transform3D).origin.distance_to((prev.puck as Transform3D).origin) / maxf(t - float(prev.t), 0.001)
			if v > 12.0 and v < 60.0: return float(prev.t)
		prev = f
	return goal_time - 0.45

## Broadcast angle for a goal: shot taken from shot_from at the net, with the
## puck moving `lateral` metres across the ice in the last second; never `last`.
static func pick_angle(shot_from: Vector3, net: Vector3, lateral: float, last: String) -> String:
	var d := Vector2(shot_from.x - net.x, shot_from.z - net.z).length()
	var order: Array
	if d > 9.0: order = ["follow", "reverse", "overhead", "ice"]
	elif d < 4.5: order = ["ice", "overhead", "reverse", "follow"]
	elif lateral > 3.0: order = ["overhead", "ice", "reverse", "follow"]
	else: order = ["reverse", "ice", "follow", "overhead"]
	for a in order:
		if a != last: return a
	return order[0]

func _start_end() -> void:
	_ending = true
	skip_prompt.visible = false
	trail.visible = false
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
	skip_prompt.visible = false
	trail.visible = false
	_live = {}

func aim_camera(delta: float, snap: bool) -> void:
	var p: Vector3 = puck.global_position
	var net := Vector3(0, 0.5, end_sign * Arena.GOAL_LINE)
	var k := 1.0 if snap else 1.0 - exp(-delta * 4.0)
	# 0 -> 1 as the play slows down at the net: every angle pushes in a little.
	var slow := smoothstep(0.0, 1.0, clampf((play_t - (goal_time - _slow_from)) / (_slow_from + _after), 0.0, 1.0))
	var pos: Vector3
	match angle:
		"ice":
			# Low in the end-boards corner beside the net, looking out at the play.
			_look = _look.lerp(Vector3(lerpf(p.x, net.x, 0.3), 0.35, lerpf(p.z, net.z, 0.3)), k)
			pos = Vector3(_side * 4.2, 0.42, end_sign * (Arena.GOAL_LINE + 2.2))
			camera.fov = lerpf(40.0, 30.0, slow)
		"overhead":
			# Straight down over the slot and crease, net at the top of the picture.
			_look = _look.lerp(Vector3(lerpf(p.x, net.x, 0.45), 0.0, lerpf(p.z, net.z, 0.45)), k)
			pos = _look + Vector3(0, 14.0, -end_sign * 2.2)
			camera.fov = lerpf(54.0, 44.0, slow)
		"follow":
			# Ride behind the carrier along the shot line; from the release hold
			# over the shooter's shoulder and watch the puck go in.
			var anchor := p if play_t < _release_t else _release_pos
			_look = _look.lerp(Vector3(lerpf(p.x, net.x, 0.35), 0.5, lerpf(p.z, net.z, 0.35)), k)
			var want := anchor + _shot_dir * 4.5 + Vector3(0, 2.3, 0)
			want.x = clampf(want.x, -(Arena.HALF_WIDTH - 0.6), Arena.HALF_WIDTH - 0.6)
			want.z = clampf(want.z, -(Arena.HALF_LENGTH - 0.6), Arena.HALF_LENGTH - 0.6)
			_cam_pos = want if snap else _cam_pos.lerp(want, 1.0 - exp(-delta * 3.0))
			pos = _cam_pos
			camera.fov = lerpf(55.0, 44.0, slow)
		_:
			# Reverse angle above the end boards: the play comes at us, net low in frame.
			var target := p.lerp(net, 0.25) - Vector3(0, 0, end_sign * 2.5)
			target.y = 0.6
			_look = _look.lerp(target, k)
			pos = Vector3(_side * 3.0 + clampf(_look.x * 0.3, -2.0, 2.0), 5.2, end_sign * (Arena.HALF_LENGTH + 0.4))
			camera.fov = lerpf(52.0, 42.0, slow)
	camera.global_position = pos
	camera.look_at(_look, Vector3.UP)
	camera.cull_mask = preload("res://scripts/arena_lighting.gd").camera_cull_mask(camera.global_position)

# ---------------------------------------------------------------- puck trail

func build_trail() -> void:
	_trail_mesh = ImmediateMesh.new()
	trail = MeshInstance3D.new()
	trail.name = "PuckTrail"
	trail.mesh = _trail_mesh
	trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	trail.visible = false
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.vertex_color_use_as_albedo = true
	m.no_depth_test = false
	m.render_priority = 2
	trail.material_override = m
	add_child(trail)

## Puck position at clip time t (no blending across a teleport).
func puck_at(t: float) -> Vector3:
	return (sample_puck(t) as Transform3D).origin

func sample_puck(t: float) -> Transform3D:
	if frames.is_empty(): return puck.global_transform
	var lo := 0
	var hi := frames.size() - 1
	if t <= float(frames[0].t): return frames[0].puck
	if t >= float(frames[hi].t): return frames[hi].puck
	while hi - lo > 1:
		var mid := (lo + hi) / 2
		if float(frames[mid].t) <= t: lo = mid
		else: hi = mid
	var pa: Transform3D = frames[lo].puck
	var pb: Transform3D = frames[hi].puck
	var w := (t - float(frames[lo].t)) / maxf(float(frames[hi].t) - float(frames[lo].t), 0.0001)
	return pa.interpolate_with(pb, w) if pa.origin.distance_to(pb.origin) < 3.0 else (pa if w < 0.5 else pb)

## Trail points, newest first: the puck's path over the last TRAIL_TIME of clip
## time, cut at a teleport. Empty when the puck has barely moved.
func trail_points() -> PackedVector3Array:
	var pts := PackedVector3Array()
	var prev := puck.global_position
	pts.append(prev)
	for i in range(1, TRAIL_STEPS + 1):
		var t := play_t - TRAIL_TIME * float(i) / TRAIL_STEPS
		if t < _clip_start: break
		var q := puck_at(t)
		if q.distance_to(prev) > 1.0: break
		pts.append(q)
		prev = q
	var length := 0.0
	for i in range(1, pts.size()): length += pts[i].distance_to(pts[i - 1])
	if length < 0.6: return PackedVector3Array()
	return pts

func update_trail() -> void:
	_trail_mesh.clear_surfaces()
	var pts := trail_points() if slow_motion() and not _ending else PackedVector3Array()
	trail.visible = pts.size() >= 2
	if not trail.visible: return
	var eye := camera.global_position
	_trail_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in range(pts.size()):
		var u := float(i) / float(pts.size() - 1)
		var along := (pts[maxi(i - 1, 0)] - pts[mini(i + 1, pts.size() - 1)])
		if along.length() < 0.0001: along = Vector3.FORWARD
		var side := along.cross(eye - pts[i]).normalized() * TRAIL_WIDTH * 0.5 * (1.0 - 0.7 * u)
		var c := Color(TRAIL_COLOR, 0.95 * pow(1.0 - u, 1.2))
		# Lift the ribbon just off the ice so it never fights the ice surface.
		var p := pts[i] + Vector3(0, 0.012, 0)
		_trail_mesh.surface_set_color(c)
		_trail_mesh.surface_add_vertex(p + side)
		_trail_mesh.surface_set_color(c)
		_trail_mesh.surface_add_vertex(p - side)
	_trail_mesh.surface_end()

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
	var tag_box := VBoxContainer.new()
	tag_box.add_theme_constant_override("separation", -4)
	tag.add_child(tag_box)
	var tag_label := Label.new()
	tag_label.text = "REPLAY"
	tag_label.add_theme_font_override("font", _font(800))
	tag_label.add_theme_font_size_override("font_size", 30)
	tag_label.add_theme_color_override("font_color", INK)
	tag_box.add_child(tag_label)
	angle_label = Label.new()
	angle_label.text = ANGLE_NAMES["reverse"]
	angle_label.add_theme_font_override("font", _font(700))
	angle_label.add_theme_font_size_override("font_size", 17)
	angle_label.add_theme_color_override("font_color", ACCENT)
	tag_box.add_child(angle_label)
	tag.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	tag.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	tag.offset_left = -36
	tag.offset_right = -36
	tag.offset_top = 28
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tag.visible = false
	layer.add_child(tag)
	# Skip prompt, bottom right: "SKIP" next to a key cap.
	skip_prompt = PanelContainer.new()
	var pstyle := StyleBoxFlat.new()
	pstyle.bg_color = Color(SLATE, 0.8)
	pstyle.set_corner_radius_all(6)
	pstyle.content_margin_left = 14
	pstyle.content_margin_right = 14
	pstyle.content_margin_top = 6
	pstyle.content_margin_bottom = 6
	skip_prompt.add_theme_stylebox_override("panel", pstyle)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	skip_prompt.add_child(row)
	var cap := PanelContainer.new()
	var cstyle := StyleBoxFlat.new()
	cstyle.bg_color = INK
	cstyle.set_corner_radius_all(4)
	cstyle.content_margin_left = 9
	cstyle.content_margin_right = 9
	cap.add_theme_stylebox_override("panel", cstyle)
	var key := Label.new()
	key.text = "ENTER / A"
	key.add_theme_font_override("font", _font(800))
	key.add_theme_font_size_override("font_size", 18)
	key.add_theme_color_override("font_color", SLATE)
	cap.add_child(key)
	row.add_child(cap)
	var skip_label := Label.new()
	skip_label.text = "SKIP REPLAY"
	skip_label.add_theme_font_override("font", _font(700))
	skip_label.add_theme_font_size_override("font_size", 20)
	skip_label.add_theme_color_override("font_color", INK)
	row.add_child(skip_label)
	skip_prompt.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	skip_prompt.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	skip_prompt.grow_vertical = Control.GROW_DIRECTION_BEGIN
	skip_prompt.offset_left = -36
	skip_prompt.offset_right = -36
	skip_prompt.offset_top = -96
	skip_prompt.offset_bottom = -96
	skip_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	skip_prompt.visible = false
	layer.add_child(skip_prompt)

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
