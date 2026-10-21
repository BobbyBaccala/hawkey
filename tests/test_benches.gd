extends SceneTree
## Benches and penalty boxes (arena_benches.gd): both team benches on the west
## side with seated players in their team's kit, two glassed penalty boxes
## and the officials' booth across on the east side; no seating rows or crowd
## cards inside those zones; no rink glass in front of the benches (but glass
## everywhere else); nothing pokes onto the ice; penalties seat players in the
## right box.
const Arena = preload("res://scripts/arena.gd")
const Benches = preload("res://scripts/arena_benches.gd")
var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		push_error(message)
		failures += 1

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var m = load("res://main.tscn").instantiate()
	root.add_child(m)
	await physics_frame
	await physics_frame
	var benches = m.arena.get_node_or_null("Benches")
	check(benches != null, "Arena has a Benches node")
	if benches == null:
		finish()
		return
	check(benches.benches.size() == 2 and benches.penalty_boxes.size() == 2, "Two benches and two penalty boxes")
	# Benches on the bench-gate side used by line changes; boxes straight across.
	check(signf(m.BENCH_X) == Benches.BENCH_SIDE, "Benches are on the side match.gd changes lines")
	for team in range(2):
		var figures: Array = benches.seated[team]
		check(figures.size() == Benches.PLAYERS_PER_BENCH, "Team %d bench has %d seated players" % [team, figures.size()])
		var zsign := 1.0 if team == 0 else -1.0
		# Each bench is at the end its team defends in the 1st (long change in the 2nd).
		check(m.match_state.period == 1 and signf(m.attack_direction(team)) == -zsign, "Team %d bench is at its defending end in the 1st period" % team)
		for f in figures:
			var p: Vector3 = f.global_position
			check(p.x < -Arena.HALF_WIDTH - 0.5 and p.x > -Arena.HALF_WIDTH - Benches.DEPTH, "Seated player %s is behind the west boards (x %.2f)" % [f.name, p.x])
			check(signf(p.z) == zsign and absf(p.z) > Benches.BENCH_GAP and absf(p.z) < Benches.BENCH_HALF, "Team %d player sits on his own bench (z %.2f)" % [team, p.z])
		# The team's line-change target (match.gd) is in front of its own bench.
		for slot in range(3):
			var change_z := (slot - 1) * 1.6 + (4 - team * 8)
			check(signf(change_z) == zsign and absf(change_z) < Benches.BENCH_HALF and absf(change_z) > Benches.BENCH_GAP, "Team %d line-change spot %.1f is at its bench" % [team, change_z])
		var box: Node3D = benches.penalty_boxes[team]
		var glass := box.find_children("Glass*", "MeshInstance3D", true, false)
		check(glass.size() >= 3, "Penalty box %d is glassed in (%d panes)" % [team, glass.size()])
		for g in glass:
			check(g.global_position.x > Arena.HALF_WIDTH, "Penalty box %d glass is on the east side" % team)
	# Kit colours follow the team and can be changed at runtime.
	var shirt: StandardMaterial3D = benches._team_mats[0].jersey
	check(shirt.albedo_color.is_equal_approx(m.team_color(0)), "Home bench wears the home jersey colour")
	check(benches._team_mats[1].jersey.albedo_color.is_equal_approx(m.team_color(1)), "Road bench wears the road jersey colour")
	benches.set_team_colors(0, Color.GREEN, Color.BLACK)
	check(shirt.albedo_color == Color.GREEN, "set_team_colors recolours the bench")
	benches.set_team_colors(0, m.team_color(0), m.team_accent(0))
	# Nothing from the benches/boxes reaches the ice side of the board face.
	for mi in benches.find_children("*", "MeshInstance3D", true, false):
		if not mi.is_visible_in_tree() and not mi.get_parent().name.begins_with("PenaltySeat"): continue
		var aabb: AABB = mi.global_transform * mi.get_aabb()
		var inner := minf(absf(aabb.position.x), absf(aabb.end.x))
		if aabb.position.x < 0 and aabb.end.x > 0: inner = 0.0
		check(inner >= Arena.HALF_WIDTH - 0.14, "%s stays behind the boards (|x| %.2f)" % [mi.get_path(), inner])
	# Seating rows 0-1 and their crowd cards are cut out of both zones.
	var dressing = m.arena.get_node("Dressing")
	var near_row := Arena.HALF_WIDTH + 1.4 + 0.85 * 1.5
	for mi in dressing.find_children("*", "MeshInstance3D", true, false):
		var aabb: AABB = mi.global_transform * mi.get_aabb()
		var center := aabb.get_center()
		if absf(center.x) < Arena.HALF_WIDTH + 0.5 or absf(center.x) > near_row: continue
		if aabb.position.y > 2.0: continue
		var side := signf(center.x)
		check(not Benches.in_zone(side, aabb.position.z + 0.01, aabb.end.z - 0.01), "Seating/crowd %s left out of the %s zone (z %.1f..%.1f)" % [mi.name, "bench" if side < 0 else "penalty box", aabb.position.z, aabb.end.z])
	# Rink glass: open in front of both benches, present at the divider and elsewhere.
	var glass_spans: Array[Vector2] = []
	for g in m.arena.find_children("BoardGlass*", "MeshInstance3D", true, false):
		var aabb: AABB = g.global_transform * g.get_aabb()
		if aabb.end.x < -Arena.HALF_WIDTH + 0.2 and aabb.size.z > 0.5:
			glass_spans.append(Vector2(aabb.position.z, aabb.end.z))
	var covered := func(z: float) -> bool:
		for span in glass_spans:
			if z > span.x and z < span.y: return true
		return false
	for z in [-8.0, -5.0, -2.0, 2.0, 5.0, 8.0]:
		check(not covered.call(z), "No glass in front of the bench at z %.1f" % z)
	for z in [-20.0, -11.0, 0.0, 11.0, 20.0]:
		check(covered.call(z), "Side glass still there at z %.1f" % z)
	# Penalties seat players in their box.
	check(benches.penalty_count(0) == 0 and benches.penalty_count(1) == 0, "Penalty boxes start empty")
	m.match_state.minor(1, 0, "Tripping")
	await process_frame
	await process_frame
	check(benches.penalty_count(1) == 1 and benches.penalty_count(0) == 0, "A road minor seats one player in the road box (%d / %d)" % [benches.penalty_count(0), benches.penalty_count(1)])
	var seat: Node3D = benches.box_seats[1][0]
	check(seat.global_position.x > Arena.HALF_WIDTH and seat.global_position.z < -Benches.BOX_GAP, "Road penalty seat is in the road box")
	m.match_state.penalties.clear()
	await process_frame
	await process_frame
	check(benches.penalty_count(1) == 0, "Box empties when the penalty ends")
	await check_motion(m, benches)
	finish()

## Pass 2: back numbers from the roster, players watch the puck, the scoring
## bench stands and cheers while the other slumps, legs keep their length.
func check_motion(m, benches) -> void:
	benches.set_process(false)
	for team in range(2):
		var dressed := []
		for i in range(3, 12): dressed.append(str(m.rosters[team][i].number))
		var nums: Array = benches._numbers[team]
		check(nums.size() == Benches.PLAYERS_PER_BENCH + 2, "Team %d has a back number per seated figure (%d)" % [team, nums.size()])
		for i in range(Benches.PLAYERS_PER_BENCH):
			check(nums[i].text == dressed[i], "Team %d bench player %d wears roster number %s (got %s)" % [team, i, dressed[i], nums[i].text])
		# Numbers face away from the ice (towards the fans behind the bench).
		var n: Label3D = nums[0]
		var facing: Vector3 = n.global_transform.basis.z
		check(facing.x < -0.7, "Team %d back number faces away from the ice (%.2f)" % [team, facing.x])
	# Heads follow the puck: watch one end, then the other.
	var fig: Node3D = benches.seated[0][4]
	var head: Node3D = fig.get_meta("rig").head
	benches.watch_target = Vector3(0, 0, 25)
	for i in range(240): benches.update_figures(1.0 / 60.0)
	var look_a: Vector3 = head.global_transform.basis.z
	benches.watch_target = Vector3(0, 0, -25)
	for i in range(240): benches.update_figures(1.0 / 60.0)
	var look_b: Vector3 = head.global_transform.basis.z
	check(look_a.z > 0.35 and look_b.z < -0.35, "Bench heads turn to follow the puck (%.2f then %.2f)" % [look_a.z, look_b.z])
	# Turning is smooth: one frame moves the head only a little.
	benches.watch_target = Vector3(0, 0, 25)
	var before: Vector3 = head.global_transform.basis.z
	benches.update_figures(1.0 / 60.0)
	check(head.global_transform.basis.z.distance_to(before) < 0.08, "Head turn is eased, not snapped")
	# Goal: home bench stands and cheers, road bench slumps.
	var upper0: Node3D = fig.get_meta("rig").upper
	var seated_y := upper0.global_position.y
	var road_head: Node3D = benches.seated[1][4].get_meta("rig").head
	var road_up_before: float = road_head.global_transform.basis.z.y
	benches.celebrate(0)
	check(benches.is_cheering(0) and not benches.is_cheering(1), "celebrate() cheers the scoring bench only")
	for i in range(90): benches.update_figures(1.0 / 60.0)
	check(upper0.global_position.y > seated_y + 0.3, "Scoring bench stands up (hips %.2f -> %.2f)" % [seated_y, upper0.global_position.y])
	var arm: Node3D = fig.get_meta("rig").arms[1]
	check(arm.global_transform.basis.y.y < -0.2 or arm.rotation.x < -1.4, "Cheering arms go up (arm rot %.2f)" % arm.rotation.x)
	check(road_head.global_transform.basis.z.y < road_up_before - 0.05, "Conceding bench drops its heads")
	for rig in benches._rigs:
		if rig.team != 0 or rig.fig.name.begins_with("PenaltySeat"): continue
		for leg in rig.legs:
			var t: MeshInstance3D = leg.thigh
			var sh: MeshInstance3D = leg.shin
			var foot: Vector3 = leg.foot.position
			check(foot.y > 0.1 and foot.y < 0.16, "Standing skates stay on the floor")
			var knee: Vector3 = t.position * 2.0 - leg.hip.lerp(Vector3(leg.x * 0.9, Benches.STAND_HIP.y - 0.01, Benches.STAND_HIP.z), 1.0)
			check(sh.position.distance_to((knee + foot) * 0.5) < 0.12, "Shin stays connected between knee and skate")
	# Standing players still stay behind the boards.
	for mi in benches.find_children("*", "MeshInstance3D", true, false):
		if not mi.is_visible_in_tree(): continue
		var aabb: AABB = mi.global_transform * mi.get_aabb()
		if aabb.position.x > 0: continue
		check(aabb.end.x <= -Arena.HALF_WIDTH + 0.14, "Standing %s stays behind the boards (x %.2f)" % [mi.name, aabb.end.x])
	# Then they sit back down.
	for i in range(int(Benches.CHEER_TIME * 60) + 180): benches.update_figures(1.0 / 60.0)
	check(not benches.is_cheering(0) and absf(upper0.global_position.y - seated_y) < 0.05, "Bench sits back down after the goal (%.2f)" % upper0.global_position.y)
	# Goal in the live match triggers the bench reaction.
	var src := FileAccess.get_file_as_string("res://scripts/match.gd")
	check(src.contains("goal_benches.celebrate(scoring_team)"), "match.gd tells the benches who scored")

func finish() -> void:
	print("Bench failures: ", failures)
	print("PASS" if failures == 0 else "FAIL")
	quit(failures)
