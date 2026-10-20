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
	check(input.trigger_pressed and not input.shoot_pressed and input.trigger_down,"Trigger press edge")
	input.clear_edges()
	axis(input,JOY_AXIS_TRIGGER_RIGHT,0.12)
	check(input.trigger_down and not input.trigger_released,"Trigger hysteresis suppresses chatter")
	axis(input,JOY_AXIS_TRIGGER_RIGHT,0.02)
	check(input.trigger_released and not input.trigger_down,"Trigger release edge")
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
	# Right-stick shots are immediate; holding never adds power or repeats.
	scene.puck.position=scene.player_visual.get_blade_world()
	scene.cooldown=0
	axis(scene.controller,JOY_AXIS_RIGHT_Y,-1)
	scene.process_controller_edges()
	var first_velocity:Vector3=scene.puck.linear_velocity
	check(first_velocity.z < -10 and first_velocity.y > 0,"Right-stick flick creates a net-targeted airborne shot")
	var shots_before:int=scene.shots
	for i in range(60):
		scene.control_player(1.0/120)
		scene.process_controller_edges()
	check(scene.charge==0 and scene.shots==shots_before,"Held right stick neither charges nor repeats")
	scene.cooldown=0
	axis(scene.controller,JOY_AXIS_RIGHT_Y,0)
	scene.process_controller_edges()
	check(scene.shots==shots_before,"Stick release does not fire")
	input.clear_edges()
	axis(input,JOY_AXIS_RIGHT_Y,0.9)
	axis(input,JOY_AXIS_RIGHT_Y,-0.9)
	check(input.shoot_pressed and input.slap_requested,"Right-stick down/up requests a slap shot")
	input.clear_edges()
	axis(input,JOY_AXIS_RIGHT_Y,0)
	axis(input,JOY_AXIS_RIGHT_Y,-0.9)
	check(input.shoot_pressed and not input.slap_requested,"Forward flick without backstroke requests wrist shot")

	# R2 is a possession-dependent pass/switch action, never a shot.
	scene.cooldown=0
	scene.carrier=scene.player
	scene.puck.position=scene.player.position+Vector3(0,0.03,-0.5)
	axis(scene.controller,JOY_AXIS_TRIGGER_RIGHT,1)
	scene.process_controller_edges()
	check(scene.shots==shots_before and scene.passes==0,"R2 press arms a pass without shooting")
	scene.controller.advance(0.8)
	check(scene.controller.pass_speed()>20,"Holding R2 increases pass strength")
	axis(scene.controller,JOY_AXIS_TRIGGER_RIGHT,0)
	scene.process_controller_edges()
	check(scene.passes==1 and scene.shots==shots_before,"R2 release passes without shooting")
	var previous_player=scene.player
	scene.carrier=scene.skaters[5]
	scene.puck.position=scene.skaters[1].position
	scene.player.position=Vector3(12,0,20)
	axis(scene.controller,JOY_AXIS_TRIGGER_RIGHT,1)
	scene.process_controller_edges()
	check(scene.player!=previous_player,"R2 on defense switches player")
	axis(scene.controller,JOY_AXIS_TRIGGER_RIGHT,0)
	scene.carrier=scene.player
	scene.process_controller_edges()
	check(scene.passes==1,"Defensive switch release cannot become an accidental pass")
	input.clear_edges()
	axis(input,JOY_AXIS_RIGHT_Y,0.9)
	axis(input,JOY_AXIS_RIGHT_Y,0)
	input.advance(0.2)
	axis(input,JOY_AXIS_RIGHT_Y,-0.9)
	check(input.shoot_pressed and not input.slap_requested,"Resting at neutral cancels a windup")
	input.clear_edges()
	axis(input,JOY_AXIS_RIGHT_Y,0.9)
	axis(input,JOY_AXIS_RIGHT_Y,0)
	input.advance(0.008)
	axis(input,JOY_AXIS_RIGHT_Y,-0.9)
	check(input.slap_requested,"Continuous slap gesture survives crossing neutral")

	var bumper:=InputEventJoypadButton.new()
	bumper.device=0;bumper.button_index=JOY_BUTTON_RIGHT_SHOULDER;bumper.pressed=true
	input.clear_edges();input.handle(bumper)
	check(input.saucer_pressed and input.poke_pressed and not input.pass_pressed,"R1 exposes contextual saucer/poke, never standard pass")
	scene.carrier=scene.skaters[5];scene.action_cooldown=0
	axis(scene.controller,JOY_AXIS_RIGHT_Y,-1)
	scene.process_controller_edges()
	check(scene.action_cooldown>0 and scene.shots==shots_before,"Defensive right-stick flick checks without shooting")
	# Pass armed before a pause must not fire after resuming.
	scene.carrier=scene.player;scene.cooldown=0
	axis(scene.controller,JOY_AXIS_TRIGGER_RIGHT,1);scene.process_controller_edges()
	scene.set_paused(true);scene.process_controller_edges()
	scene.set_paused(false)
	axis(scene.controller,JOY_AXIS_TRIGGER_RIGHT,0);scene.process_controller_edges()
	check(scene.passes==1,"Pause cancels an armed pass")

	scene.carrier=scene.player
	scene.puck.position=scene.player.position+Vector3(0,0.5,-0.5)
	scene.cooldown=0
	scene.update_possession(1.0/120)
	check(scene.carrier==null,"Airborne puck cannot auto-attach to stick")
	var view:=InputEventJoypadButton.new()
	view.device=0;view.button_index=JOY_BUTTON_BACK;view.pressed=true
	scene.controller.handle(view);scene.process_controller_edges()
	check(scene.hud_node.controls_panel.visible,"View/Back opens the advertised controls overlay")
	view.pressed=false;scene.controller.handle(view)
	view.pressed=true;scene.controller.handle(view);scene.process_controller_edges()
	check(not scene.hud_node.controls_panel.visible,"View/Back dismisses controls overlay")
	scene.on_controller_connection(0,false)
	check(scene.paused and not scene.controller.trigger_down and scene.controller.left_stick==Vector2.ZERO,"Controller disconnect pauses and clears held input")
	scene.queue_free()
	await process_frame
	print("Controller failures: ",failures," (synthetic events; hardware untested)")
	quit(failures)
