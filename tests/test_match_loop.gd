extends SceneTree
var failures:=0
func _initialize()->void:call_deferred("run")
func run()->void:
	var scene=load("res://main.tscn").instantiate()
	root.add_child(scene)
	await physics_frame
	scene.match_state.phase_timer=0
	var start_clock=scene.match_state.clock
	for frame in range(2400):
		await physics_frame
		if frame%120==0:
			for team in range(2):
				var count_=0
				var ids:=[]
				for actor in scene.skaters:
					if scene.body_team(actor)!=team or not actor.get_meta("eligible"):continue
					count_+=1
					if actor.get_meta("roster_id") in ids:failures+=1
					ids.append(actor.get_meta("roster_id"))
					if absf(actor.position.x)>preload("res://scripts/arena.gd").HALF_WIDTH+0.5 or absf(actor.position.z)>30.5:failures+=1
				if count_!=scene.match_state.count(team):failures+=1
	if scene.match_state.clock>=start_clock:failures+=1
	print("20-second match-loop failures: ",failures," • score ",scene.match_state.score," • clock ",scene.match_state.clock_text())
	scene.queue_free()
	await process_frame
	quit(failures)
