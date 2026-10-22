extends SceneTree
## Scripted physical stress fixture, not AI gameplay. Body is driven through
## straight skating, a stationary pivot and lateral stickhandling. Puck starts
## at the blade once, then uses normal rigid-body simulation/control only.
var label:="before"
func _initialize()->void:call_deferred("run")
func run()->void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--label="):label=arg.trim_prefix("--label=").validate_filename()
	load("res://scripts/game_settings.gd").path="res://build/carry-check/settings.json"
	load("res://scripts/match.gd").skip_title=true
	var m=load("res://main.tscn").instantiate();root.add_child(m);await physics_frame
	m.set_physics_process(false);m.set_process(false)
	for actor in m.skaters:m.set_actor_active(actor,false)
	for keeper in m.goalkeepers:m.set_actor_active(keeper,false)
	var actor=m.player;m.set_actor_active(actor,true);actor.position=Vector3(-4,0,4)
	var v=actor.get_child(1);v.rotation.y=0;v.animate_motion(Vector3.ZERO,1.0/120,0,false)
	m.sync_skater_contacts(actor);await physics_frame
	m.carrier=actor;m.cooldown=0;m.puck.freeze=false;m.puck.position=v.get_blade_world();m.puck.linear_velocity=Vector3.ZERO
	var errors:Array=[];var held:=0;var drops:=0;var prev:=true
	var phases:={"straight":{"held":0,"ticks":0},"pivot":{"held":0,"ticks":0},"stickhandle":{"held":0,"ticks":0}}
	for tick in range(420):
		var phase_:="straight" if tick<120 else ("pivot" if tick<204 else "stickhandle")
		actor.velocity=Vector3.FORWARD*6 if tick<120 else Vector3.ZERO
		actor.move_and_slide()
		if tick>=120 and tick<204:v.rotation.y+=PI/84
		if tick>=204:v.desired_stick=Vector2(sin((tick-204)/120.0*TAU*1.2)*0.9,0)
		v.animate_motion(actor.velocity,1.0/120,0,tick<120)
		m.sync_skater_contacts(actor);m.update_possession(1.0/120)
		await physics_frame
		var owns:bool=m.carrier==actor
		if prev and not owns:drops+=1
		prev=owns;phases[phase_].ticks+=1
		if owns:held+=1;phases[phase_].held+=1
		errors.append(m.puck.position.distance_to(v.get_blade_world()))
	errors.sort()
	var report:={"label":label,"engine":Engine.get_version_info().string,"fixture":"Scripted skating/pivot/stickhandling; actual puck physics, no puck reposition after initial placement. Not AI gameplay.","ticks":420,"held_ticks":held,"held_fraction":float(held)/420,"drops":drops,"error_p95_m":errors[int(errors.size()*0.95)],"error_max_m":errors[-1],"phases":phases}
	FileAccess.open("res://build/puck-carry-"+label+".json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("CARRY_CHECK ",JSON.stringify(report));quit()
