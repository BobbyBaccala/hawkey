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

## Pass 2/3: the seated players are skinned skaters (skater_visual.gd) in the
## seated pose wearing the roster numbers; they watch the puck, the scoring
## bench stands and cheers while the other slumps, legs keep their length.
func check_motion(m, benches) -> void:
	benches.set_process(false)
	for team in range(2):
		var dressed := []
		for i in range(3, 12): dressed.append(str(m.rosters[team][i].number))
		var nums: Array = benches._numbers[team]
		check(nums.size() == Benches.PLAYERS_PER_BENCH + 2, "Team %d has a skinned skater per seated figure (%d)" % [team, nums.size()])
		for i in range(Benches.PLAYERS_PER_BENCH):
			check(nums[i].number == dressed[i], "Team %d bench player %d wears roster number %s (got %s)" % [team, i, dressed[i], nums[i].number])
		var v = nums[0]
		check(v.skeleton != null and v.kit.is_equal_approx(m.team_color(team)), "Team %d bench player is the skinned skater in the team kit" % team)
		check(not v.is_in_group("skater_visuals"), "Bench skaters cut no ice (not in skater_visuals)")
		# Faces the ice (game-facing -Z towards +x on the west side).
		check((-v.global_transform.basis.z).x > 0.7, "Team %d bench player faces the ice" % team)
		# Seated: hips on the seat, thighs forward, skates on the bench floor.
		var hip: Vector3 = v.rig.global_transform * (v.rest["upperleg01.L"].origin + v.posed_drop)
		check(absf(hip.y - (Benches.SEAT_TOP + 0.1)) < 0.06, "Team %d player sits on the seat (hip %.2f)" % [team, hip.y])
		for i in range(2):
			var knee: Vector3 = v.rig.global_transform * v.knees[i]
			var foot: Vector3 = v.skates[i].global_position
			var hip_i: Vector3 = v.rig.global_transform * (v.rest["upperleg01" + (".L" if i == 0 else ".R")].origin + v.posed_drop)
			check(absf(knee.y - hip_i.y) < 0.15 and knee.distance_to(hip_i) < 0.47, "Thigh runs forward from the seat (knee %.2f, %.2f m)" % [knee.y, knee.distance_to(hip_i)])
			check(foot.y > 0.03 and foot.y < 0.13, "Seated skate on the floor (%.2f)" % foot.y)
	# Heads follow the puck: watch one end, then the other.
	var fig: Node3D = benches.seated[0][4]
	var vis = fig.get_meta("rig").visual
	var head: Node3D = vis.helmet
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
	# Only figures whose pose changed are re-posed, at most POSE_BUDGET a frame.
	var budget_ok := true
	for i in range(30):
		var stamp := []
		for rig in benches._rigs: stamp.append(rig.get("posed", []).duplicate())
		benches.update_figures(1.0 / 60.0)
		var n := 0
		for k in range(benches._rigs.size()):
			if benches._rigs[k].get("posed", []) != stamp[k]: n += 1
		if n > Benches.POSE_BUDGET: budget_ok = false
	check(budget_ok, "At most POSE_BUDGET bench skaters re-posed per frame")
	for i in range(240): benches.update_figures(1.0 / 60.0)
	# Goal: home bench stands and cheers, road bench slumps.
	var seated_y: float = head.global_position.y
	var road_head: Node3D = benches.seated[1][4].get_meta("rig").visual.helmet
	var road_up_before: float = road_head.global_transform.basis.z.y
	benches.celebrate(0)
	check(benches.is_cheering(0) and not benches.is_cheering(1), "celebrate() cheers the scoring bench only")
	for i in range(90): benches.update_figures(1.0 / 60.0)
	check(head.global_position.y > seated_y + 0.3, "Scoring bench stands up (head %.2f -> %.2f)" % [seated_y, head.global_position.y])
	var arm_up: bool = vis.posed_wrists[1].y > vis.shoulder_of(1).y + 0.25 and vis.posed_wrists[0].y > vis.shoulder_of(0).y + 0.25
	check(arm_up, "Cheering arms go up (wrist %.2f, shoulder %.2f)" % [vis.posed_wrists[1].y, vis.shoulder_of(1).y])
	check(road_head.global_transform.basis.z.y < road_up_before - 0.05, "Conceding bench drops its heads")
	for rig in benches._rigs:
		if rig.team != 0 or rig.fig.name.begins_with("PenaltySeat"): continue
		var v = rig.visual
		for i in range(2):
			var foot: Vector3 = v.skates[i].global_position
			check(foot.y > 0.03 and foot.y < 0.13, "Standing skates stay on the floor (%.2f)" % foot.y)
			var hip: Vector3 = v.rest["upperleg01" + (".L" if i == 0 else ".R")].origin + v.posed_drop
			check(hip.distance_to(v.feet[i]) <= v.LEG_REACH + 0.01, "Leg keeps its length")
	# Standing players still stay behind the boards.
	for mi in benches.find_children("*", "MeshInstance3D", true, false):
		if not mi.is_visible_in_tree(): continue
		var aabb: AABB = mi.global_transform * mi.get_aabb()
		if aabb.position.x > 0: continue
		check(aabb.end.x <= -Arena.HALF_WIDTH + 0.14, "Standing %s stays behind the boards (x %.2f)" % [mi.get_path(), aabb.end.x])
	# Then they sit back down.
	for i in range(int(Benches.CHEER_TIME * 60) + 240): benches.update_figures(1.0 / 60.0)
	check(not benches.is_cheering(0) and absf(head.global_position.y - seated_y) < 0.05, "Bench sits back down after the goal (%.2f)" % head.global_position.y)
	# Recolouring a bench rebuilds its skaters in the new kit, numbers kept.
	var num_before: String = benches._numbers[0][2].number
	benches.set_team_colors(0, Color.GREEN, Color.BLACK)
	check(benches._numbers[0][2].kit == Color.GREEN and benches._numbers[0][2].number == num_before, "set_team_colors re-dresses the bench skaters")
	benches.set_team_colors(0, m.team_color(0), m.team_accent(0))
	await check_line_change(m, benches)
	# Goal in the live match triggers the bench reaction.
	var src := FileAccess.get_file_as_string("res://scripts/match.gd")
	check(src.contains("goal_benches.celebrate(scoring_team)"), "match.gd tells the benches who scored")

## Pass 3 slice 6: seated sticks stand nearly upright with the knob above the
## helmet; on a line change a seated player gets up (stand_up()), leaves from
## where he stands (go_out()) and the player coming off takes his seat.
func check_line_change(m, benches) -> void:
	for rig in benches._rigs:
		if not rig.stick or rig.fig.name.begins_with("PenaltySeat") or not rig.fig.visible: continue
		var v = rig.visual
		var knob: Vector3 = v.sticks.global_transform * v.stick_knob_end()
		var helmet_top: float = v.helmet.global_position.y + 0.12
		check(knob.y > helmet_top, "Seated stick knob stands above the helmet (%.2f vs %.2f)" % [knob.y, helmet_top])
		var blade: Vector3 = v.stick_blade.global_position
		var shaft_up: Vector3 = (v.sticks.global_transform.basis * v.stick_shaft.basis.y).normalized()
		check(absf(shaft_up.y) > 0.9, "Seated stick is nearly upright (%.2f)" % absf(shaft_up.y))
		check(blade.y < 0.15 and blade.x < -Arena.HALF_WIDTH - 0.2, "Seated blade on the bench floor (%.2f, x %.2f)" % [blade.y, blade.x])
		check(absf(Vector2(knob.x - blade.x, knob.z - blade.z).length()) < 0.6, "Stick stays in front of its player")
	# The tired player lands on the bench floor in front of seat 3; the one
	# going out is about a seat along (PASS_GAP) so they pass side by side.
	var z0: float = benches.seated[0][3].global_position.z
	check(benches.stand_up(0, z0), "A bench player gets up to go out")
	check(benches.rising_count(0) == 1 and benches.rising_count(1) == 0, "Only one player gets up, on the changing team's bench")
	var rig: Dictionary = {}
	for r in benches._rigs:
		if r.team == 0 and r.rise_target > 0.0: rig = r
	var fig: Node3D = rig.fig
	var v = rig.visual
	var dz := absf(fig.global_position.z - z0)
	check(dz > 0.5 and dz < 1.2, "The one going out sits about a seat along from the landing (%.2f)" % dz)
	var head0: float = v.helmet.global_position.y
	var prev: float = head0
	var smooth := true
	for i in range(70):
		benches.update_figures(1.0 / 60.0)
		var h: float = v.helmet.global_position.y
		if absf(h - prev) > 0.04: smooth = false
		prev = h
	check(smooth, "Getting up is eased, no pop")
	check(v.helmet.global_position.y > head0 + 0.2, "He is on his feet (head %.2f -> %.2f)" % [head0, v.helmet.global_position.y])
	check(v.stick_carry > 0.95 and v.sticks.visible, "Stick up, ready for the hop")
	for i in range(2):
		var foot: Vector3 = v.skates[i].global_position
		check(foot.y > 0.03 and foot.y < 0.13 and foot.x < -Arena.HALF_WIDTH - 0.3, "Standing skate on the bench floor (%.2f, x %.2f)" % [foot.y, foot.x])
	# Without a landing (old path) he reappears at the seat after SEAT_RETURN.
	var at = benches.go_out(0, "77")
	check(at is Vector3 and not fig.visible, "He leaves his seat for the hop")
	if at is Vector3:
		check(absf(at.z - fig.global_position.z) < 0.5 and at.x < -Arena.HALF_WIDTH - 1.0, "Hop starts where he stood (x %.2f)" % at.x)
	for i in range(int(Benches.SEAT_RETURN * 60) + 4): benches.update_figures(1.0 / 60.0)
	check(fig.visible and v.number == "77", "The player coming off takes the free seat (%s)" % v.number)
	for i in range(120): benches.update_figures(1.0 / 60.0)
	check(absf(v.helmet.global_position.y - head0) < 0.06 and benches.rising_count(0) == 0, "and sits down (head %.2f)" % v.helmet.global_position.y)
	check_seat_walk(benches, z0)
	# A change called off (nobody goes out): he sits back down by himself.
	benches.stand_up(1, -5.0)
	for i in range(int(4.5 * 60)): benches.update_figures(1.0 / 60.0)
	check(benches.rising_count(1) == 0, "A player left standing sits back down")
	var src := FileAccess.get_file_as_string("res://scripts/match.gd")
	check(src.contains("hop_benches.stand_up(") and src.contains(".go_out(team,tired_number,landing,landing_face)"), "match.gd line change drives the bench")

## Pass 3 slice 7: the player coming off does not vanish at his landing spot
## - he stands there from the same frame, walks to the free seat (curving back
## off the boards first so he passes the one going out), turns to face the
## ice and sits, with no jumps on the way.
func check_seat_walk(benches, z0: float) -> void:
	check(benches.stand_up(0, z0), "Second change: a player gets up")
	for i in range(70): benches.update_figures(1.0 / 60.0)
	var landing := Vector3(-(Arena.HALF_WIDTH + 0.85), 0, z0)
	var away := Vector3(-1, 0, 0)
	var rig: Dictionary = {}
	for r in benches._rigs:
		if r.team == 0 and r.rise_target > 0.0: rig = r
	var fig: Node3D = rig.fig
	var v = rig.visual
	var seat_head: float = -1.0
	var at = benches.go_out(0, "45", landing, away)
	check(at is Vector3, "He goes out from where he stood")
	if not at is Vector3: return
	check(fig.visible and v.number == "45", "The player coming off is shown at once, wearing his number")
	var p0: Vector3 = v.global_position
	check(Vector2(p0.x - landing.x, p0.z - landing.z).length() < 0.05, "He starts at his landing spot (%.2f m off)" % Vector2(p0.x - landing.x, p0.z - landing.z).length())
	var f0: Vector3 = -v.global_transform.basis.z
	check(f0.dot(away) > 0.95, "He still faces the way he landed (%.2f)" % f0.dot(away))
	# The one going out heads straight for the boards at the landing's z.
	var fresh_a: Vector3 = at
	var fresh_b := Vector3(-Arena.HALF_WIDTH, 0, z0)
	var prev: Vector3 = v.helmet.global_position
	var max_step := 0.0
	var min_pass := INF
	var frames := int((rig.walk_time + Benches.CLOSE_TIME) * 60.0) + 2
	# Slice 8 step cycle: skates lift and plant alternately; a planted skate
	# stays put on the floor (no gliding over the rubber).
	var floor_y: float = v.skates[0].global_position.y
	var last_foot: Array = [v.skates[0].global_position, v.skates[1].global_position]
	var lifts := [0, 0]
	var lifted := [false, false]
	var max_lift := 0.0
	var both_up := 0
	var slip := 0.0
	var touchdown := 0.0
	var was_pinned := [false, false]
	# Slice 9: from the first frame to the last (setting off, stopping and the
	# closing steps) a skate on the floor never slides; it only moves lifted.
	var floor_slide := 0.0
	var was_down := [0, 0]
	var foot_jump := 0.0
	var closing_lifts := 0
	var close_lifted := false
	for i in range(frames):
		benches.update_figures(1.0 / 60.0)
		var h: Vector3 = v.helmet.global_position
		max_step = maxf(max_step, h.distance_to(prev))
		prev = h
		var q: Vector3 = v.global_position
		q.y = 0
		if i < int(rig.walk_time * 30.0):
			var seg := Geometry3D.get_closest_point_to_segment(q, Vector3(fresh_a.x, 0, fresh_a.z), fresh_b)
			min_pass = minf(min_pass, q.distance_to(seg))
		for k in range(2):
			var foot: Vector3 = v.skates[k].global_position
			if foot.x > -Arena.HALF_WIDTH - 0.2 or foot.x < -Arena.HALF_WIDTH - Benches.DEPTH + 0.15: max_step = INF
			var up: float = foot.y - floor_y
			var down := up < 0.004
			var moved: Vector3 = foot - last_foot[k]
			# (Down for 2+ frames: the touchdown frame itself is the swing landing.)
			if down and was_down[k] >= 2: floor_slide = maxf(floor_slide, Vector2(moved.x, moved.z).length())
			was_down[k] = was_down[k] + 1 if down else 0
			# (Mid-walk swings are fast as he turns round; check the set-off, stop and hand-over.)
			if rig.walk_t < rig.walk_time * 0.2 or v.walk_close > 0.0 or not benches.is_walking(rig): foot_jump = maxf(foot_jump, moved.length())
			if v.walk_close > 0.0 and up > 0.02 and not close_lifted: closing_lifts += 1
			if v.walk_close > 0.0: close_lifted = up > 0.02 if k == 1 else close_lifted or up > 0.02
			max_lift = maxf(max_lift, up)
			var is_up := up > 0.02
			if is_up and not lifted[k]: lifts[k] += 1
			lifted[k] = is_up
			var pinned: bool = v.walk_plants[k] != null and v.walk_amount > 0.99 and v.walk_close == 0.0 and benches.is_walking(rig)
			var d: Vector3 = foot - last_foot[k]
			if pinned and was_pinned[k]: slip = maxf(slip, Vector2(d.x, d.z).length())
			elif pinned: touchdown = maxf(touchdown, Vector2(d.x, d.z).length())
			was_pinned[k] = pinned
			last_foot[k] = foot
		if lifted[0] and lifted[1]: both_up += 1
	check(lifts[0] >= 2 and lifts[1] >= 2, "He steps: each skate lifts and plants again (%d / %d steps)" % [lifts[0], lifts[1]])
	check(max_lift > 0.05 and max_lift < 0.12, "Skates clear the floor in the swing (%.3f m)" % max_lift)
	check(both_up == 0, "Never both skates off the floor (%d frames)" % both_up)
	check(slip < 0.002, "A planted skate stays put, no gliding (max %.3f m/frame)" % slip)
	check(touchdown < 0.025, "Skates set down gently, slower than he walks (%.3f m/frame)" % touchdown)
	check(max_step < 0.05, "Walk to the seat has no pops (max head step %.3f m/frame)" % max_step)
	check(min_pass > 0.25, "He passes the player going out side by side (closest %.2f m)" % min_pass)
	check(not benches.is_walking(rig), "He reaches the seat")
	var p1: Vector3 = v.global_position
	var seat_spot: Vector3 = fig.global_transform * Vector3(0, 0, Benches.RISE_STEP)
	check(Vector2(p1.x - seat_spot.x, p1.z - seat_spot.z).length() < 0.05, "and stands in front of the free seat")
	var f1: Vector3 = -v.global_transform.basis.z
	check(f1.dot(Vector3(1, 0, 0)) > 0.9, "turned round to face the ice (%.2f)" % f1.dot(Vector3(1, 0, 0)))
	check(floor_slide < 0.002, "No skate slides on the floor setting off, stopping or closing (max %.4f m/frame)" % floor_slide)
	check(foot_jump < 0.03, "Skates never jump setting off or stopping (max %.3f m/frame)" % foot_jump)
	check(closing_lifts >= 1, "He closes his stance with a step when he stops (%d)" % closing_lifts)
	var sk0: Vector3 = v.skates[0].global_position
	var sk1: Vector3 = v.skates[1].global_position
	check(absf(sk0.y - floor_y) < 0.004 and absf(sk1.y - floor_y) < 0.004, "and ends on both skates")
	# Sitting down from there moves the skates smoothly (no snap from the walk).
	var sit_jump := 0.0
	var lf: Array = [sk0, sk1]
	for i in range(30):
		benches.update_figures(1.0 / 60.0)
		for k in range(2):
			sit_jump = maxf(sit_jump, v.skates[k].global_position.distance_to(lf[k]))
			lf[k] = v.skates[k].global_position
	check(sit_jump < 0.03, "No skate snap as the walk hands over to sitting (%.3f m/frame)" % sit_jump)
	for i in range(120): benches.update_figures(1.0 / 60.0)
	seat_head = v.helmet.global_position.y
	check(seat_head < 1.25 and benches.rising_count(0) == 0, "then sits down (head %.2f)" % seat_head)
	check(v.sticks.visible and v.seat_stick, "holding the stick he came off with")

func finish() -> void:
	print("Bench failures: ", failures)
	print("PASS" if failures == 0 else "FAIL")
	quit(failures)
