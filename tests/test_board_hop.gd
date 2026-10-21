extends SceneTree
## Board hop (line change): the visual leaves the body at the bench door,
## vaults the dasher with the knees tucked so no part of either skate passes
## through the boards, lands on the bench floor, and the hop back out ends
## exactly on the body. The path and pose change smoothly (no pops).
const Arena = preload("res://scripts/arena.gd")
const BoardHop = preload("res://scripts/board_hop.gd")
const DT := 1.0 / 120
var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		push_error(message)
		failures += 1

func _initialize() -> void:
	call_deferred("run")

## World-space AABB of every mesh under a node.
func world_box(node: Node) -> AABB:
	var box := AABB()
	var first := true
	for child in node.find_children("*", "MeshInstance3D", true, false):
		var mi := child as MeshInstance3D
		if mi.mesh == null or not mi.visible: continue
		var b: AABB = mi.global_transform * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box

## Lowest skate point inside the board's footprint (x band), or INF if none.
func lowest_over_boards(v) -> float:
	var low := INF
	for skate in v.skates:
		var b := world_box(skate)
		if b.end.x > -(Arena.HALF_WIDTH + 0.30) and b.position.x < -Arena.HALF_WIDTH + 0.02:
			low = minf(low, b.position.y)
	return low

func run_hop(v, body: Node3D, a: Vector3, b: Vector3) -> Dictionary:
	v.start_hop(a, b, -Arena.HALF_WIDTH - body.position.x)
	var result := {"clear": INF, "max_step": 0.0, "max_tuck_step": 0.0, "peak": 0.0, "frames": 0, "crossed": false}
	var last: Vector3 = v.position
	var last_tuck := 0.0
	while v.hopping():
		v.animate(0, DT, 0, false)
		result.frames += 1
		result.clear = minf(result.clear, lowest_over_boards(v))
		result.max_step = maxf(result.max_step, (v.position - last).length())
		var tuck: float = v.hop_state.get("tuck", 0.0)
		result.max_tuck_step = maxf(result.max_tuck_step, absf(tuck - last_tuck))
		result.peak = maxf(result.peak, tuck)
		last = v.position
		last_tuck = tuck
		if result.frames > 1000: break
	return result

func run() -> void:
	var Visual = load("res://scripts/skater_visual.gd")
	var body := Node3D.new()
	body.position = Vector3(-(Arena.HALF_WIDTH - 0.75), 0, 4.0)
	root.add_child(body)
	var v = Visual.new()
	body.add_child(v)
	await process_frame
	for f in range(30): v.animate(0, DT, 0, false)

	# Over the boards onto the bench floor.
	var bench := Vector3(-(Arena.HALF_WIDTH + 0.85), 0, 4.0) - body.position
	var out := run_hop(v, body, Vector3.ZERO, bench)
	check(out.frames >= int(BoardHop.DURATION / DT) - 2 and out.frames <= int(BoardHop.DURATION / DT) + 2, "Hop takes about %.2f s (%d frames)" % [BoardHop.DURATION, out.frames])
	check(v.hop_finished(), "Hop out reaches its end")
	check(out.clear > BoardHop.BOARD_TOP + 0.02, "Skates clear the board top going over (lowest %.3f m)" % out.clear)
	check(out.peak > 0.9, "Knees tuck over the boards (%.2f)" % out.peak)
	check(out.max_step < 0.05, "Hop path is continuous (largest step %.3f m)" % out.max_step)
	check(out.max_tuck_step < 0.08, "Tuck blends smoothly (largest step %.3f)" % out.max_tuck_step)
	check(v.global_position.distance_to(body.position + bench) < 0.01, "Lands on the bench floor")
	check(absf(v.global_position.y) < 0.001, "Stands on the bench floor after landing")
	# Facing the bench while going out: game forward (-Z of the visual) points -x.
	var forward: Vector3 = -v.global_basis.z
	check(forward.x < -0.9, "Faces the bench going out")

	# Fresh player back over onto the ice, ending on the body.
	var back := run_hop(v, body, v.position + Vector3(0, 0, -0.7), Vector3.ZERO)
	check(back.clear > BoardHop.BOARD_TOP + 0.02, "Skates clear the boards coming back (lowest %.3f m)" % back.clear)
	check(back.max_step < 0.05, "Return path is continuous (largest step %.3f m)" % back.max_step)
	check(v.position.length() < 0.001, "Return hop ends on the body")
	forward = -v.global_basis.z
	check(forward.x > 0.9, "Faces the ice coming back")
	v.cancel_hop()
	check(not v.hopping() and v.hop_state.is_empty() and v.position == Vector3.ZERO, "cancel_hop() resets the visual")

	# Pure path: offsets stay on the near side before take-off and the far side after landing.
	for k in range(101):
		var u := k / 100.0
		var s: Dictionary = BoardHop.sample(u, Vector3(1.2, 0, 0), Vector3(-0.9, 0, 0.3), 0.0)
		if u < BoardHop.VAULT_START: check(s.offset.x >= BoardHop.TAKEOFF - 0.001, "Near side before take-off (u=%.2f)" % u)
		if u > BoardHop.VAULT_END: check(s.offset.x <= -BoardHop.BOARD_DEPTH - BoardHop.TAKEOFF + 0.001, "Far side after landing (u=%.2f)" % u)
		if u < BoardHop.VAULT_START - 0.06 or u > BoardHop.VAULT_END + 0.04: check(s.tuck == 0.0, "No tuck while skating (u=%.2f)" % u)
	body.queue_free()
	await process_frame
	print("Board hop failures: ", failures)
	quit(failures)
