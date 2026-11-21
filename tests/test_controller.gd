extends SceneTree
const Adapter=preload("res://scripts/controller_input.gd")
var failures:=0
func check(ok:bool,message:String)->void:
	if not ok: push_error(message);failures+=1
func axis(adapter, id_:int, value:float)->void:
	var event:=InputEventJoypadMotion.new()
	event.device=0
	event.axis=id_
	event.axis_value=value
	adapter.handle(event)
func _initialize()->void:call_deferred("run")
func run()->void:
	var input:=Adapter.new()
	check(Adapter.radial(Vector2(0.1,0.1),0.18)==Vector2.ZERO,"Radial deadzone rejects drift")
	check(is_equal_approx(Adapter.radial(Vector2(0.59,0),0.18).x,0.5),"Analog travel must scale continuously")
	axis(input,JOY_AXIS_TRIGGER_RIGHT,0.2)
	check(input.shoot_pressed and input.trigger_down,"Trigger press edge")
	input.clear_edges()
	axis(input,JOY_AXIS_TRIGGER_RIGHT,0.12)
	check(input.trigger_down and not input.shoot_released,"Trigger hysteresis suppresses chatter")
	axis(input,JOY_AXIS_TRIGGER_RIGHT,0.02)
	check(input.shoot_released and not input.trigger_down,"Trigger release edge")
	var scene=load("res://main.tscn").instantiate()
	root.add_child(scene)
	await physics_frame
	scene.set_physics_process(false)
	scene.match_state.phase=scene.MatchState.Phase.PLAY
	scene.puck.freeze=false
	axis(scene.controller,JOY_AXIS_LEFT_Y,-1)
	axis(scene.controller,JOY_AXIS_RIGHT_X,1)
	var blade:Vector3=scene.player_visual.get_blade_world()
	for i in range(25):scene.control_player(1.0/120)
	check(scene.player.velocity.z< -1 and scene.aim.z< -0.99,"Left stick moves and aims skater")
	check(scene.player_visual.get_blade_world().distance_to(blade)>0.2,"Right stick moves physical control target and visible blade")
	axis(scene.controller,JOY_AXIS_TRIGGER_LEFT,1)
	axis(scene.controller,JOY_AXIS_TRIGGER_RIGHT,1)
	for i in range(60):scene.control_player(1.0/120)
	check(scene.charge>0.5,"Held trigger charges shot")
	scene.puck.position=scene.player_visual.get_blade_world()
	scene.cooldown=0
	axis(scene.controller,JOY_AXIS_TRIGGER_RIGHT,0)
	scene.process_controller_edges()
	check(scene.puck.linear_velocity.y>5,"LT elevation plus RT release creates airborne shot")
	check(scene.puck.linear_velocity.z< -10,"Left stick aims shot")
	scene.carrier=scene.player
	scene.puck.position=scene.player.position+Vector3(0,0.5,-0.5)
	scene.cooldown=0
	scene.update_possession(1.0/120)
	check(scene.carrier==null,"Airborne puck cannot auto-attach to stick")
	scene.on_controller_connection(0,false)
	check(scene.paused and not scene.controller.trigger_down and scene.controller.left_stick==Vector2.ZERO,"Controller disconnect pauses and clears held input")
	scene.queue_free()
	await process_frame
	print("Controller failures: ",failures," (synthetic events; hardware untested)")
	quit(failures)
