extends SceneTree
## Fixed-step normal AI exhibition soak; no forced passes, goals or positions.
var m
var samples:Array=[]
var acquisitions:=[0,0]
var releases:=0
var previous_carrier
var previous_lock:=0.0
var source_sha:=""
var seconds:=60
func _initialize()->void:call_deferred("run")
func run()->void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seconds="):seconds=int(arg.trim_prefix("--seconds="))
		if arg.begins_with("--source-sha="):source_sha=arg.trim_prefix("--source-sha=")
	load("res://scripts/game_settings.gd").path="res://build/ai-receiving-soak/settings.json"
	var match_script=load("res://scripts/match.gd");match_script.skip_title=true
	seed(42)
	m=load("res://main.tscn").instantiate();m.ai_vs_ai=true
	root.add_child(m);current_scene=m
	for tick in range(seconds*120):
		await physics_frame
		if m.carrier!=null and m.carrier!=previous_carrier:acquisitions[m.body_team(m.carrier)]+=1
		if m.pickup_lock_time>previous_lock+0.004 and is_instance_valid(m.pickup_lock_actor):releases+=1
		previous_carrier=m.carrier;previous_lock=m.pickup_lock_time
		if tick%600==0:
			var sample:={"seconds":float(tick)/120,"clock":m.match_state.clock,"phase":m.match_state.phase,"score":m.match_state.score.duplicate(),"acquisitions":acquisitions.duplicate(),"release_events":releases,"puck":[m.puck.position.x,m.puck.position.y,m.puck.position.z],"shots":m.rosters.map(func(team):return team.reduce(func(total,p):return total+int(p.shots),0))}
			samples.append(sample);print("AI_SOAK ",JSON.stringify(sample))
	var ok:bool=acquisitions[0]>0 and acquisitions[1]>0 and releases>0 and m.puck.position.is_finite()
	FileAccess.open("res://build/ai-receiving-soak.json",FileAccess.WRITE).store_string(JSON.stringify({"source_sha":source_sha,"final_clock":m.match_state.clock,"final_score":m.match_state.score.duplicate(),"final_shots":m.rosters.map(func(team):return team.reduce(func(total,p):return total+int(p.shots),0)),"engine":Engine.get_version_info().string,"fixed_fps":120,"simulation_seconds":seconds,"normal_rules":true,"no_forced_events":true,"passed":ok,"samples":samples,"total_acquisitions":acquisitions,"release_events":releases},"\t"))
	print("AI_SOAK_RESULT ",ok," acquisitions ",acquisitions," releases ",releases)
	quit(0 if ok else 1)
