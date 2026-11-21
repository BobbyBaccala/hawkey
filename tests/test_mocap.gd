extends SceneTree
## Captured-motion integration: goal celebrations and goalie save reactions in a
## live match. Skips (and passes) when the Mixamo clips are not installed.
var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		push_error(message)
		failures += 1

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var Mocap = load("res://scripts/mocap.gd")
	if not Mocap.available("Standing_Cheering"):
		print("Mocap failures: 0 (skipped: clips not installed in assets/mixamo/)")
		quit(0)
		return
	var match_ = load("res://main.tscn").instantiate()
	root.add_child(match_)
	await physics_frame
	match_.match_state.phase = match_.MatchState.Phase.PLAY
	# Fire a puck across the goal line that team 0 attacks.
	var end_: float = match_.attack_direction(0)
	match_.carrier = null
	match_.puck.freeze = false
	match_.puck.global_position = Vector3(0, 0.02, end_ * 24.2)
	match_.previous_puck = match_.puck.position
	match_.puck.linear_velocity = Vector3(0, 0, end_ * 12)
	for keeper in match_.goalkeepers:
		keeper.position.x = 3.0
	var scored := false
	for i in range(60):
		await physics_frame
		if match_.match_state.score[0] > 0:
			scored = true
			break
	check(scored, "Test shot scores")
	for i in range(60):
		await physics_frame
	var celebrating := 0
	var raised := 0
	for actor in match_.skaters:
		var visual = actor.get_child(1)
		if match_.body_team(actor) == 0:
			celebrating += int(not visual.mocap.is_empty())
			raised += int(visual.raised_stick > 0.5)
		else:
			check(visual.mocap.is_empty(), "Conceding team does not celebrate")
	check(celebrating >= 5, "Scoring skaters play the captured celebration (%d)" % celebrating)
	check(raised >= 5, "Celebrating skaters raise their sticks (%d)" % raised)
	match_.setup_faceoff()
	for i in range(40):
		await physics_frame
	for actor in match_.skaters:
		check(actor.get_child(1).mocap_fade == 0.0, "Faceoff ends the celebration")
	# A hard shot off the pads triggers the captured body-block reaction.
	var keeper = match_.goalkeepers[0]
	match_.match_state.phase = match_.MatchState.Phase.PLAY
	match_.goalie_contact_timer = 0
	match_.last_puck_velocity = Vector3(0, 0, 20)
	match_._on_puck_contact(keeper.get_node("PadLeft"))
	check(not keeper.get_child(1).mocap.is_empty(), "Pad save plays the body-block reaction")
	match_.queue_free()
	await process_frame
	print("Mocap failures: ", failures)
	quit(failures)
