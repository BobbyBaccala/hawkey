extends SceneTree
## Stick strokes (stroke_anim.gd), the gameplay reads behind them
## (play_moves.gd) and the extra goalie moves: smooth, physical, and on the ice.
const StrokeAnim = preload("res://scripts/stroke_anim.gd")
const PlayMoves = preload("res://scripts/play_moves.gd")
const Visual = preload("res://scripts/skater_visual.gd")
const SkaterAI = preload("res://scripts/skater_ai.gd")
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		push_error(message)
		failures += 1

func _initialize() -> void: call_deferred("run")

func settle(v, frames := 30) -> void:
	for k in range(frames): v.animate(0.0,1.0/60.0)

func run() -> void:
	check_library()
	check_moves()
	check_more_moves()
	var v = Visual.new()
	root.add_child(v)
	await process_frame
	settle(v)
	check_dribble(v)
	check_live_strokes(v)
	check_hold_and_release(v)
	v.queue_free()
	await check_turning()
	await check_receive()
	var g = Visual.new()
	g.goalie = true
	root.add_child(g)
	await process_frame
	check_goalie(g)
	print("Strokes: %d failures" % failures)
	quit(1 if failures > 0 else 0)

func check_library() -> void:
	var lib := StrokeAnim.library()
	for k in ["wrist","snap","slap","one_timer","backhand","pass","saucer","tip","poke","block","receive","deke_fhbh","deke_toe_drag","deke_fake"]:
		check(lib.has(k), "Stroke library has %s" % k)
	var top := Vector3(0.094,0.92,0.384)
	var base := Vector3(-0.339,-0.798,0.497)
	for kind in lib.keys():
		var keys: Array = lib[kind].keys
		check(float(keys[0].t) == 0.0 and keys[0].dir == Vector3.ZERO and keys[keys.size()-1].dir == Vector3.ZERO, "%s starts and ends on the skating pose" % kind)
		for i in range(1,keys.size()): check(float(keys[i].t) > float(keys[i-1].t), "%s keys in time order" % kind)
		var r := StrokeAnim.release_at(kind)
		if StrokeAnim.is_deke(kind) or kind in ["block", "receive"]: check(r < 0.0, "%s never releases the puck" % kind)
		else: check(r > 0.0 and r < StrokeAnim.duration(kind), "%s releases inside the stroke" % kind)
		if StrokeAnim.is_shot(kind) or kind in ["pass","saucer","poke"]:
			# Contact: the blade is on the ice, out in front of the skates.
			var b := StrokeAnim.blade(kind,r,top+StrokeAnim.body(kind,r).grip,base)
			check(b.y < 0.06 and b.z > 0.9, "%s meets the puck on the ice in front (%s)" % [kind,str(b)])
		# Windup on the forehand side for forehand shots, backhand side for the backhand.
		if kind in ["wrist","snap","pass"]:
			var w := StrokeAnim.windup_at(kind)
			var b := StrokeAnim.blade(kind,w,top+StrokeAnim.body(kind,w).grip,base)
			# (a snap shot's pull-back is short by design)
			check(b.x < (-0.38 if kind == "snap" else -0.45), "%s draws the puck back on the forehand (%.2f)" % [kind,b.x])
		# Heel for any direction keeps the stick length.
	for d in [Vector3(-1,-4,1),Vector3(-0.5,0.5,-0.6),Vector3(0,-1,0.01)]:
		var heel := StrokeAnim.heel_for(top,d)
		check(absf(heel.distance_to(top)-StrokeAnim.STICK_L) < 0.002 and heel.y >= StrokeAnim.BLADE_Y-0.001, "Stick length kept for %s" % str(d))
	var slap := StrokeAnim.blade("slap",StrokeAnim.windup_at("slap"),top+StrokeAnim.body("slap",StrokeAnim.windup_at("slap")).grip,base)
	check(slap.y > 1.6 and slap.z < 0.0, "Slap shot backswing goes up high behind (%s)" % str(slap))
	var bh := StrokeAnim.blade("backhand",StrokeAnim.windup_at("backhand"),top,base)
	check(bh.x > 0.3, "Backhand windup on the backhand side (%.2f)" % bh.x)
	# Shot selection and speeds.
	check(StrokeAnim.shot_kind(true,18.0,6.0,0.0,false) == "slap", "Point shot with time -> slap")
	check(StrokeAnim.shot_kind(true,18.0,1.2,0.0,false) == "snap", "Point shot under pressure -> snap")
	check(StrokeAnim.shot_kind(false,6.0,3.0,0.0,false) == "snap", "In tight -> snap")
	check(StrokeAnim.shot_kind(false,6.0,5.0,0.7,false) == "backhand", "Net to the backhand side close in -> backhand")
	check(StrokeAnim.shot_kind(false,10.0,5.0,0.0,false) == "wrist", "Open forward -> wrister")
	check(StrokeAnim.shot_kind(false,10.0,5.0,0.0,true) == "one_timer", "One-timer stays a one-timer")
	check(StrokeAnim.shot_speed("slap",0.5) > StrokeAnim.shot_speed("wrist",0.5) and StrokeAnim.shot_speed("wrist",0.5) > StrokeAnim.shot_speed("backhand",0.5), "Slap > wrist > backhand speed")
	check(StrokeAnim.release_at("slap") > StrokeAnim.release_at("wrist") and StrokeAnim.release_at("wrist") > StrokeAnim.release_at("snap"), "Slap winds up longest, snap shortest")
	for r in [0.1,0.5,0.9]: check(StrokeAnim.is_deke(StrokeAnim.deke_kind(r)), "deke_kind gives a deke")

func check_moves() -> void:
	check(absf(PlayMoves.segment_distance(Vector3.ZERO,Vector3(2,0,0),Vector3(1,0.1,0))-0.1) < 1e-5, "Segment distance mid-segment")
	check(absf(PlayMoves.segment_distance(Vector3.ZERO,Vector3(2,0,0),Vector3(3,0,0))-1.0) < 1e-5, "Segment distance past the end")
	# Attacker tip at the net: turned toward the goal mouth.
	var net := Vector3(0,0,26.65)
	var at := Vector3(1.5,0.3,22.0)
	var vel := Vector3(-8,0,10).normalized()*25.0
	var out := PlayMoves.deflect(vel,at,net,true,0.5,0.3)
	var to_net := (net-at).normalized()
	check(out.normalized().dot(to_net) > vel.normalized().dot(to_net), "A tip turns the puck toward the net")
	check(out.length() < vel.length() and out.length() > vel.length()*0.7, "A tip keeps most of the speed")
	var block := PlayMoves.deflect(vel,at,net,false,0.5,0.8)
	check(Vector3(block.x,0,block.z).normalized().dot(Vector3(vel.x,0,vel.z).normalized()) < 0.95 and block.length() < vel.length()*0.8, "A defender's stick knocks the puck off line and slows it")
	check(PlayMoves.in_tip_zone(Vector3(0.5,0,23.5),1.0) and not PlayMoves.in_tip_zone(Vector3(0.5,0,12.0),1.0), "Tip zone is in front of the net")
	# Deke: defender closing from in front, not from behind or too far.
	var pos := Vector3.ZERO
	var v := Vector3(0,0,6)
	check(PlayMoves.wants_deke(pos,v,[Vector3(0.3,0,2.2)],0.0,0.5), "Deke a defender closing from in front")
	check(not PlayMoves.wants_deke(pos,v,[Vector3(0.3,0,-2.2)],0.0,0.5), "No deke on a man behind")
	check(not PlayMoves.wants_deke(pos,v,[Vector3(0.3,0,6.0)],0.0,0.5), "No deke on a man far away")
	check(not PlayMoves.wants_deke(pos,Vector3(0,0,1),[Vector3(0.3,0,2.2)],0.0,0.5), "No deke standing still")
	check(not PlayMoves.wants_deke(pos,v,[Vector3(0.3,0,2.2)],0.9,0.5), "Deke only as often as skill allows")
	var side := PlayMoves.deke_side(pos,v,Vector3(0.5,0,2.0))
	check(side.dot(Vector3(0.5,0,0)) < 0.0, "Deke carries him away from the defender's side")
	# Goalie poke: carrier alone in front coming at him.
	var g := Vector3(0,0,25.5)
	check(PlayMoves.goalie_pokes(g,1.0,Vector3(0.3,0,23.8),Vector3(0,0,5)), "Goalie pokes at a carrier coming in")
	check(not PlayMoves.goalie_pokes(g,1.0,Vector3(0.3,0,20.0),Vector3(0,0,5)), "No poke out of reach")
	check(not PlayMoves.goalie_pokes(g,1.0,Vector3(0.3,0,23.8),Vector3(0,0,-5)), "No poke at a carrier skating away")
	# Post seal side and range.
	check(PlayMoves.choose_post(2.0,-0.5,2.4) == "rvh_left", "Puck behind the net, glove side -> RVH left")
	check(PlayMoves.choose_post(-2.0,0.6,2.4) == "rvh_right", "Puck low at the goal line, blocker side -> RVH right")
	check(PlayMoves.choose_post(2.0,5.0,5.5) == "", "Puck out in front -> no post seal")

func check_live_strokes(v) -> void:
	var base_blade: Vector3 = v.blade_position
	for kind in StrokeAnim.library().keys():
		v.play_stroke(kind)
		var prev: Vector3 = v.blade_position
		var prev_turn := 0.0
		var worst_len := 0.0
		var worst_step := 0.0
		var worst_turn := 0.0
		var min_y := 9.0
		var finite := true
		for f in range(int(StrokeAnim.duration(kind)*120.0)+20):
			v.animate(0.0,1.0/120.0)
			var b: Vector3 = v.blade_position
			if not b.is_finite(): finite = false
			min_y = minf(min_y,b.y)
			worst_step = maxf(worst_step,b.distance_to(prev))
			prev = b
			var turn := float(v.stroke_body().turn)
			worst_turn = maxf(worst_turn,absf(turn-prev_turn))
			prev_turn = turn
			if v.stroke_kind != "" and v.stroke_fade >= 1.0:
				var top: Vector3 = v.stick_grip()
				worst_len = maxf(worst_len,absf(top.distance_to(v.stick_heel_at(top))-StrokeAnim.STICK_L))
		check(finite, "%s blade stays finite" % kind)
		check(min_y >= StrokeAnim.BLADE_Y-0.001, "%s blade never goes through the ice (%.3f)" % [kind,min_y])
		check(worst_len < 0.01, "%s keeps the stick's length (off by %.3f m)" % [kind,worst_len])
		# 0.3 m per 1/120 s = 36 m/s: a slapshot's stick head, no faster.
		check(worst_step < 0.30, "%s blade moves smoothly (largest step %.3f m at 120 Hz)" % [kind,worst_step])
		check(worst_turn < 0.06, "%s shoulders turn smoothly (largest step %.3f rad)" % [kind,worst_turn])
		check(v.stroke_kind == "" and v.blade_position.distance_to(base_blade) < 0.005, "%s ends back on the skating blade" % kind)

func check_hold_and_release(v) -> void:
	# The user's held charge parks the slap shot at the top of the backswing.
	v.charge_kind = "slap"
	v.shot_charge = 1.0
	for k in range(90): v.animate(0.0,1.0/60.0)
	check(v.stroke_kind == "slap" and absf(v.stroke_t-StrokeAnim.windup_at("slap")) < 0.02, "Held charge waits at the top of the slap backswing (t %.2f)" % v.stroke_t)
	check(v.blade_position.y > 1.4, "Stick held up for the slapper (%.2f)" % v.blade_position.y)
	# The puck waits on the ice in front while the stick is up.
	var spot: Vector3 = v.rig.to_local(v.get_puck_world())
	check(spot.y < 0.05 and spot.z > 0.9, "Puck waits on the ice ahead of the slapper (%s)" % str(spot))
	v.shot_charge = 0.0
	v.release_stroke("slap")
	check(v.stroke_hold < 0.0 and v.stroke_t >= StrokeAnim.release_at("slap")-0.035, "Release swings through from contact")
	v.charge_kind = ""
	for k in range(90): v.animate(0.0,1.0/60.0)
	check(v.stroke_kind == "", "Slap shot finishes")
	# A release with no windup still shows the stroke, from just before contact.
	v.release_stroke("pass")
	check(v.stroke_kind == "pass" and v.stroke_t > 0.0, "An instant pass plays its stroke")
	# One-timer: loaded and waiting, then unwinds if the pass never comes.
	for k in range(60): v.animate(0.0,1.0/60.0)
	v.load_one_timer(0.5)
	for k in range(20): v.animate(0.0,1.0/60.0)
	check(v.stroke_kind == "one_timer" and v.stroke_hold >= 0.0, "Loaded for the one-timer")
	for k in range(40): v.animate(0.0,1.0/60.0)
	check(v.stroke_kind == "", "Unwinds when the pass doesn't arrive")

func pose_goalie(g, kind: String, target: Vector2, down: bool) -> void:
	for k in range(120):
		g.butterfly = move_toward(g.butterfly,1.0 if down else 0.0,6.0/60.0)
		g.set_save(kind,target,1.0/60.0)
		g.animate(0.0,1.0/60.0,0,false)

func check_goalie(g) -> void:
	pose_goalie(g,"",Vector2(0,0.8),false)
	var stance_blade: Vector3 = g.blade_position
	pose_goalie(g,"poke",Vector2(0,0.1),false)
	check(float(g.save_weights.poke) > 0.99, "Poke check weight reaches the pose")
	check(g.blade_position.z > stance_blade.z+0.6, "Poke check shoots the stick out (%.2f vs %.2f)" % [g.blade_position.z,stance_blade.z])
	pose_goalie(g,"cover",Vector2(0.1,0.05),true)
	check(g.posed_wrists[0].y < 0.5 and g.posed_wrists[0].z > 0.45, "Cover: catcher down over the puck in front (%s)" % str(g.posed_wrists[0]))
	pose_goalie(g,"body",Vector2(0,0.75),false)
	check(absf(g.posed_wrists[0].x) < 0.35, "Chest save: catcher clamps in (%s)" % str(g.posed_wrists[0]))
	pose_goalie(g,"rvh_left",Vector2(1.2,0.1),true)
	# Glove-side (left, i 0) pad down on the ice, blocker-side skate planted, knee up.
	check(g.knees[0].y < 0.25, "RVH: post-side knee on the ice (%.2f)" % g.knees[0].y)
	check(g.knees[1].y > 0.35, "RVH: off-post knee up (%.2f)" % g.knees[1].y)
	check(g.feet[1].y < 0.2, "RVH: off-post skate on the ice (%.2f)" % g.feet[1].y)
	pose_goalie(g,"",Vector2(0,0.8),false)
	check(g.knees[1].y > 0.35 and absf(g.blade_position.z-stance_blade.z) < 0.02, "Back to the stance afterwards")
	# Pad-stack dive: mid-dive the hips have travelled further than the body
	# has rolled, and he is off the ice; the full stack is the same pose.
	pose_goalie(g,"",Vector2(0,0.8),false)
	var mid_seen := false
	for k in range(30):
		g.set_save("stack_left",Vector2(0.9,0.1),1.0/60.0)
		g.animate(0.0,1.0/60.0,0,false)
		var w: float = g.stack_weight()
		if w > 0.35 and w < 0.65 and not mid_seen:
			mid_seen = true
			var shift_frac: float = absf(g.rig.position.x)/g.STACK_SHIFT
			var roll_frac: float = absf(g.stack_roll)/g.STACK_ROLL
			check(shift_frac > roll_frac+0.15, "Dive: hips lead, body rolls after (shift %.2f vs roll %.2f)" % [shift_frac,roll_frac])
			check(g.rig.position.y > g.STACK_LIFT*roll_frac+0.05, "Dive: off the ice mid-dive (%.2f m)" % g.rig.position.y)
	check(mid_seen, "Dive passes through mid-weight")
	for k in range(90):
		g.set_save("stack_left",Vector2(0.9,0.1),1.0/60.0)
		g.animate(0.0,1.0/60.0,0,false)
	check(absf(absf(g.stack_roll)-g.STACK_ROLL) < 0.01 and absf(g.rig.position.y-g.STACK_LIFT) < 0.01, "Full stack: same roll and height as before the dive shape")

## Skill-stick gestures, shot lanes, rebound control, own-crease passes.
func check_more_moves() -> void:
	var h := [[0.0, Vector2(-0.9, 0.0)], [0.12, Vector2(0.0, 0.1)], [0.22, Vector2(0.9, 0.0)]]
	check(PlayMoves.skill_stick_deke(h) == "deke_fhbh", "Right stick side to side -> forehand-backhand deke")
	check(PlayMoves.skill_stick_deke([[0.0, Vector2(0.0, -0.9)], [0.2, Vector2(0.1, 0.9)]]) == "deke_toe_drag", "Forward then back -> toe drag")
	check(PlayMoves.skill_stick_deke([[0.0, Vector2(0.0, 0.9)], [0.2, Vector2(0.9, 0.1)]]) == "deke_fake", "Back then to the side -> fake shot")
	check(PlayMoves.skill_stick_deke([[0.0, Vector2(-0.9, 0.0)], [0.6, Vector2(0.9, 0.0)]]) == "", "Too slow is stickhandling, not a deke")
	check(PlayMoves.skill_stick_deke([[0.0, Vector2(-0.4, 0.0)], [0.1, Vector2(0.4, 0.0)]]) == "", "Small moves are stickhandling")
	var net := Vector3(0, 0, 26.65)
	check(PlayMoves.in_shot_lane(Vector3(0, 0, 12), net, Vector3(0.3, 0, 15.0)), "Defender in the lane blocks")
	check(not PlayMoves.in_shot_lane(Vector3(0, 0, 12), net, Vector3(2.5, 0, 15.5)), "Defender beside the lane doesn't")
	check(not PlayMoves.in_shot_lane(Vector3(0, 0, 12), net, Vector3(0.2, 0, 10.0)), "Defender behind the shooter doesn't")
	check(not PlayMoves.in_shot_lane(Vector3(0, 0, 12), net, Vector3(0.2, 0, 12.5)), "Defender on top of the puck isn't blocking a lane")
	# Rebounds come back out, slowed, never on into the net.
	for zone in ["pad", "body", "blocker", "stick", "catcher", "mask"]:
		var out := PlayMoves.rebound(Vector3(1.0, 0.2, 28.0), zone, 1.0, 0.3, 0.6)
		check(out.z < 0.0 and out.length() < 28.0 * 0.5, "%s rebound comes back out, slowed (%s)" % [zone, str(out)])
	var blk := PlayMoves.rebound(Vector3(1.0, 0.2, 28.0), "blocker", 1.0, 0.3, 0.6)
	var pad := PlayMoves.rebound(Vector3(1.0, 0.2, 28.0), "pad", 1.0, 0.3, 0.6)
	check(absf(blk.x) / absf(blk.z) > absf(pad.x) / absf(pad.z), "Blocker steers it wider than a pad")
	check(absf(pad.x) > absf(pad.z), "A pad rebound goes wide toward the corner, not into the slot")
	check(PlayMoves.rebound(Vector3(1.0, 0.2, 28.0), "body", 1.0, 0.3, 0.6).length() < 2.0, "Off the chest it drops dead for a cover")
	check(PlayMoves.rebound(Vector3(0, 0, -20), "pad", 1.0, 0.5, 0.5) == Vector3(0, 0, -20), "A puck going away from the net is left alone")
	check(SkaterAI.crosses_own_crease(Vector3(-5, 0, -25.5), Vector3(5, 0, -25.0), 1.0), "Pass across the own crease is flagged")
	check(not SkaterAI.crosses_own_crease(Vector3(-5, 0, -18), Vector3(5, 0, -18), 1.0), "Pass across the high slot is fine")
	check(not SkaterAI.crosses_own_crease(Vector3(-3, 0, -28.2), Vector3(3, 0, -28.2), 1.0), "D-to-D pass behind the own net is fine")
	var g := Vector3(0, 0, 25.9)
	check(PlayMoves.goalie_covers(g, 1.0, Vector3(0.9, 0.02, 25.6), 1.0, 1.0), "Butterfly goalie covers a loose puck at his pad")
	check(not PlayMoves.goalie_covers(g, 1.0, Vector3(0.9, 0.02, 25.6), 1.0, 0.0), "Standing he can't reach that far")
	check(not PlayMoves.goalie_covers(g, 1.0, Vector3(0.3, 0.02, 25.6), 6.0, 1.0), "A moving puck isn't covered")
	check(not PlayMoves.goalie_covers(g, 1.0, Vector3(0.3, 0.02, 26.6), 1.0, 1.0), "Not behind him at the goal line")
	# Freezes: most chest and glove saves are held, never a pad or a puck going away.
	var frozen := 0
	for k in range(20): if PlayMoves.freezes("body", Vector3(0, 0.3, 25), 1.0, k / 20.0): frozen += 1
	check(frozen >= 12 and frozen <= 17, "About three in four chest saves are smothered (%d/20)" % frozen)
	check(not PlayMoves.freezes("pad", Vector3(0, 0.3, 25), 1.0, 0.0), "Pad saves are never frozen")
	check(not PlayMoves.freezes("body", Vector3(0, 0.3, -25), 1.0, 0.0), "A puck going away isn't a save")
	check(PlayMoves.rebound(Vector3(1, 0.2, 28), "arm", 1.0, 0.3, 0.6).z < 0.0, "Off the arm it comes back out")
	check(PlayMoves.rebound(Vector3(0.2, 0.0, 5.0), "pad", 1.0, 0.3, 0.6).z < 0.0, "A slow dribble off the pad comes back out too")
	check(PlayMoves.squeezes(0.2, 0.1) and not PlayMoves.squeezes(1.5, 0.1) and not PlayMoves.squeezes(0.2, 0.95), "Squeezed at the line (mostly), not out in front")
	# Shooting ratings: the first line and first pair are the best shooters.
	var M = load("res://scripts/match.gd")
	for team in range(2):
		check(M.shooting_rating(0, team) > M.shooting_rating(9, team) and M.shooting_rating(1, team) > M.shooting_rating(4, team), "First line out-shoots the fourth")
		check(M.shooting_rating(12, team) > M.shooting_rating(16, team), "First pair out-shoots the third")
	check(StrokeAnim.has("block") and StrokeAnim.release_at("block") < 0.0, "Shot block stroke")
	var top := Vector3(0.094, 0.92, 0.384)
	var b := StrokeAnim.body("block", 0.4)
	check((b.hip as Vector3).y < -0.25, "Block drops the hips")


## Points of skate i's boot box (corners, edge midpoints, centre) that lie
## inside skate j's own oriented boot box, shrunk by `margin` (the boxes are
## the meshes' local AABBs, so turned skates are not inflated by world axes).
func skate_points(v, i: int) -> Array:
	var pts := []
	for mi in (v.skates[i] as Node3D).find_children("*", "MeshInstance3D", true, false):
		var b: AABB = (mi as MeshInstance3D).get_aabb()
		var xf: Transform3D = (mi as MeshInstance3D).global_transform
		for cx in [0.0, 0.5, 1.0]:
			for cy in [0.0, 0.5, 1.0]:
				for cz in [0.0, 0.5, 1.0]:
					pts.append(xf * (b.position + b.size * Vector3(cx, cy, cz)))
	return pts

func skates_overlap(v, margin := 0.01) -> int:
	var hits := 0
	for pair in [[0, 1], [1, 0]]:
		var pts := skate_points(v, pair[0])
		for mi in (v.skates[pair[1]] as Node3D).find_children("*", "MeshInstance3D", true, false):
			var b: AABB = (mi as MeshInstance3D).get_aabb().grow(-margin)
			var inv: Transform3D = (mi as MeshInstance3D).global_transform.affine_inverse()
			for p in pts:
				if b.has_point(inv * p): hits += 1
	return hits

## Turning: a skater driven round a circle leans into it and crosses over;
## the skates never run through each other; straight again, it all fades.
func check_turning() -> void:
	var body := Node3D.new()
	root.add_child(body)
	var v = Visual.new()
	body.add_child(v)
	await process_frame
	var radius := 6.0
	var speed := 7.0
	var dt := 1.0 / 120.0
	var ang := 0.0
	var worst_overlap := 0.0
	var min_foot := 9.0
	var angles := []
	for k in range(720):
		ang += speed / radius * dt
		body.position = Vector3(cos(ang) * radius, 0, sin(ang) * radius)
		var dir := Vector3(-sin(ang), 0, cos(ang))
		v.rotation.y = atan2(-dir.x, -dir.z)
		v.animate(speed, dt, 0, true)
		if k < 360: continue
		worst_overlap = maxf(worst_overlap, skates_overlap(v))
		min_foot = minf(min_foot, minf(v.feet[0].y, v.feet[1].y))
		# Head over the skates, toward the centre of the circle (world).
		var mid: Vector3 = v.rig.to_global((v.feet[0] + v.feet[1]) * 0.5)
		var head: Vector3 = v.rig.to_global(v.posed_head)
		var to_centre := -Vector3(body.position.x, 0, body.position.z).normalized()
		angles.append(rad_to_deg(atan2((head - mid).dot(to_centre), head.y - mid.y)))
	var mean_angle: float = angles.reduce(func(x, y): return x + y, 0.0) / angles.size()
	check(mean_angle > 15.0 and mean_angle < 32.0, "Leans into the turn, toward the centre (%.1f deg)" % mean_angle)
	check(v.cross_w > 0.9, "Crossovers in a hard turn at speed (%.2f)" % v.cross_w)
	# The check itself: two skates on one spot do overlap.
	var keep: Transform3D = v.skates[1].global_transform
	v.skates[1].global_transform = v.skates[0].global_transform
	check(skates_overlap(v) > 0, "Skate overlap check detects two skates on one spot")
	v.skates[1].global_transform = keep
	check(worst_overlap == 0, "Skates never run through each other on the crossovers (%d box points inside the other boot)" % worst_overlap)
	check(min_foot >= 0.10, "Skates stay on the ice (ankle %.3f m)" % min_foot)
	# Straight again: lean and crossovers fade out.
	var dir2 := Vector3(-sin(ang), 0, cos(ang))
	for k in range(240):
		body.position += dir2 * speed * dt
		v.animate(speed, dt, 0, true)
	check(absf(v.turn_lean) < 0.03 and v.cross_w < 0.05, "Straight ahead: no lean, normal stride (lean %.2f, cross %.2f)" % [v.turn_lean, v.cross_w])
	body.queue_free()


## Stickhandling: a carrier with no stick input dribbles the puck side to side;
## without the puck, or steering the stick himself, the blade holds.
func check_dribble(v) -> void:
	v.carrying = true
	var xs := []
	for k in range(120):
		v.animate(3.0, 1.0 / 60.0)
		xs.append(v.blade_position.x)
	var span: float = xs.max() - xs.min()
	check(span > 0.25 and span < 0.6, "Carrier stickhandles side to side (blade sweeps %.2f m)" % span)
	v.desired_stick = Vector2(0.8, 0)
	for k in range(30): v.animate(3.0, 1.0 / 60.0)
	var held: float = v.blade_position.x
	for k in range(30): v.animate(3.0, 1.0 / 60.0)
	check(absf(v.blade_position.x - held) < 0.01, "The user's right stick overrides the dribble")
	v.desired_stick = Vector2.ZERO
	v.carrying = false
	for k in range(60): v.animate(0.0, 1.0 / 60.0)
	var a: float = v.blade_position.x
	for k in range(30): v.animate(0.0, 1.0 / 60.0)
	check(absf(v.blade_position.x - a) < 0.005, "No puck: the blade holds still")


## Pass reception: the blade reaches out toward an incoming puck, and the
## receive stroke gives back toward the body.
func check_receive() -> void:
	var body := Node3D.new()
	root.add_child(body)
	var v = Visual.new()
	body.add_child(v)
	await process_frame
	for k in range(30): v.animate(0.0, 1.0 / 60.0)
	var rest: Vector3 = v.blade_position
	v.reach_for(v.rig.to_global(Vector3(-0.9, 0.03, 1.3)))
	for k in range(30): v.animate(0.0, 1.0 / 60.0)
	check(v.blade_position.x < rest.x - 0.25, "Blade reaches out toward the incoming pass (%.2f vs %.2f)" % [v.blade_position.x, rest.x])
	v.reach_for(Vector3.INF)
	v.play_stroke("receive")
	var max_back := 0.0
	var z0: float = v.blade_position.z
	for k in range(30):
		v.animate(0.0, 1.0 / 60.0)
		max_back = maxf(max_back, z0 - v.blade_position.z)
	check(max_back > 0.15, "Receiving: the blade gives back toward the body (%.2f m)" % max_back)
	body.queue_free()
