extends "res://scripts/lab.gd"
const MatchState = preload("res://scripts/match_state.gd")
const ControllerInput = preload("res://scripts/controller_input.gd")
const PuckPhysics = preload("res://scripts/puck.gd")
const BroadcastHud = preload("res://scripts/broadcast_hud.gd")
const GoalCelebration = preload("res://scripts/goal_celebration.gd")
const Benches = preload("res://scripts/arena_benches.gd")
const CAMERA_NAMES := ["DYNAMIC", "OVERHEAD", "BROADCAST", "FULL RINK"]
## Bench gate (changing skaters head here) just inside the west side boards.
const BENCH_X := -(Arena.HALF_WIDTH - 0.75)
## How far behind the board face a hopping skater lands on the bench floor.
const HOP_BENCH_DEPTH := 0.85
## Restarting from the pause menu skips the title screen.
static var skip_title := false
var hud_node: CanvasLayer
var hud_layer: CanvasLayer
var camera_mode := 0
var camera_side := 1.0
var in_menu := false
var menu_time := 0.0
var team_shots: Array[int] = [0, 0]
var last_event := ""
var last_phase := -1
var match_state := MatchState.new()
## Goal light, arena light flash and jumbotron GOAL (scripts/goal_celebration.gd).
var celebration: Node3D
var skaters: Array[CharacterBody3D] = []
var rosters: Array = [[],[]]
var active_lines: Array[int] = [0,0]
var defense_pairs: Array[int] = [0,0]
var carrier: CharacterBody3D
var team_panel: Label
var penalties_label: Label
var previous_phase := MatchState.Phase.FACEOFF
var last_faceoff_serial := 0
var last_puck_velocity := Vector3.ZERO
var referee_nodes: Array[Node3D] = []
var decision_clock := 0.0
var action_cooldown := 0.0
var auto_lines := true
var goalie_targets: Array[Vector3] = [Vector3(0,0,-(Arena.GOAL_LINE-1.0)),Vector3(0,0,Arena.GOAL_LINE-1.0)]
var goalie_reaction := 0.0
var goalie_contact_timer := 0.0
var capture_time := 3.0
var known_period := 1
var controller := ControllerInput.new()
var shot_lift := 0.0
var next_faceoff := Vector3.ZERO
var puck_shadow: MeshInstance3D
var controller_help := false

func _init() -> void:
	arena_title = "HAWKEY ARENA"

func _ready() -> void:
	super._ready()
	celebration=GoalCelebration.new()
	add_child(celebration)
	Input.joy_connection_changed.connect(on_controller_connection)
	var devices:=Input.get_connected_joypads()
	if not devices.is_empty():
		controller.device_id=devices[0]
		controller.connected=true
		controller.active=true
	puck_shadow=MeshInstance3D.new()
	var shadow_mesh:=CylinderMesh.new()
	shadow_mesh.top_radius=0.09
	shadow_mesh.bottom_radius=0.09
	shadow_mesh.height=0.001
	puck_shadow.mesh=shadow_mesh
	var shadow_material: StandardMaterial3D=arena.mat(Color(0.015,0.02,0.025,0.35))
	shadow_material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	puck_shadow.material_override=shadow_material
	puck_shadow.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(puck_shadow)
	player.queue_free()
	teammate.queue_free()
	rosters = [[],[]]
	var numbers := [17,28,9,22,13,48,36,8,62,44,19,53,5,24,72,4,39,67]
	var names := ["E. Vale","N. March","A. Renaud","M. Holt","L. Voss","J. Belisle","D. Mercer","O. Lind","T. Keene","I. Caron","S. Adler","P. Kent","R. Cole","V. Baird","G. Laurent","K. Stone","F. Noel","B. Arvid"]
	for team in range(2):
		for i in range(18):
			rosters[team].append({"name":names[(i+team*7)%18],"number":numbers[i],"stamina":1.0,"speed":88-i%5*3,"goals":0,"shots":0})
		for slot in range(5):
			var roster_id := slot if slot<3 else 12+slot-3
			var actor := make_skater(Vector3.ZERO,team_color(team),str(rosters[team][roster_id].number),false,team_accent(team))
			actor.name = ("TOR_" if team==0 else "MTL_")+str(slot)
			actor.set_meta("team",team)
			actor.set_meta("slot",slot)
			actor.set_meta("roster_id",roster_id)
			actor.set_meta("changing",false)
			actor.set_meta("pending_id",-1)
			actor.set_meta("eligible",true)
			actor.set_meta("stun",0.0)
			actor.set_meta("decision",0.0)
			actor.get_child(1).set_nameplate(str(rosters[team][roster_id].name).split(" ")[-1])
			skaters.append(actor)
	# Seated bench players wear the numbers of the roster players not dressed on the ice.
	var bench_node=arena.get_node_or_null("Benches")
	if bench_node!=null:
		for team in range(2): bench_node.set_bench_numbers(team,range(3,12).map(func(i): return rosters[team][i].number))
	player = skaters[0]
	teammate = skaters[1]
	player_visual = player.get_child(1)
	teammate_visual = teammate.get_child(1)
	for goalie in goalkeepers:
		goalie.set_meta("last_contact",-1.0)
	for i in range(2):
		var official:=Skater.new()
		official.referee=true
		official.number=""
		official.kit=Color("#11171e")
		add_child(official)
		official.position=Vector3(-(Arena.HALF_WIDTH-2.0) if i==0 else Arena.HALF_WIDTH-2.0,0,-12 if i==0 else 12)
		referee_nodes.append(official)
	setup_faceoff()
	camera.position = Vector3(0,20,24)
	camera.look_at(Vector3.ZERO)
	if "--capture" in OS.get_cmdline_user_args():
		# Normal live match, no staged image substitution.
		match_state.phase_timer = 0.3
	# The title screen shows in a real window only: headless tests and captures
	# go straight to the game (--title forces it for screenshots).
	var args := OS.get_cmdline_user_args()
	in_menu = ("--title" in args) or (DisplayServer.get_name() != "headless" and not skip_title and not "--capture" in args)
	skip_title = false
	for arg in args:
		if arg.begins_with("--camera="): camera_mode = clampi(int(arg.substr(9)), 0, 3)
	hud_node.show_title(in_menu)
	hud_node.set_controls_text(controller.active)

func team_color(team: int) -> Color:
	# Toronto at home in blue; Montreal in road whites.
	return Color("#164a9a") if team==0 else Color("#e9edf0")

func team_accent(team: int) -> Color:
	return Color("#e8eef5") if team==0 else Color("#b3162c")

func attack_direction(team: int) -> float:
	var direction := -1.0 if team==0 else 1.0
	return direction if match_state.period%2==1 else -direction

func body_team(body: CharacterBody3D) -> int:
	return int(body.get_meta("team",0))

func roster(body: CharacterBody3D) -> Dictionary:
	return rosters[body_team(body)][int(body.get_meta("roster_id",0))]

func build_hud() -> void:
	hud_node = BroadcastHud.new()
	hud_node.team_colors.assign([Color("#164a9a"), Color("#b3162c")])
	hud_layer = hud_node
	add_child(hud_node)
	hud = hud_node.clock_label
	status = hud_node.status_label
	help = hud_node.hint_label
	power = hud_node.power
	penalties_label = hud_node.penalties_label
	team_panel = Label.new()
	hud_node.resume_requested.connect(func(): set_paused(false))
	hud_node.camera_requested.connect(cycle_camera)
	hud_node.restart_requested.connect(func():
		skip_title = true
		get_tree().reload_current_scene())
	hud_node.quit_requested.connect(func(): get_tree().quit())
	hud_node.play_requested.connect(start_from_title)
	hud_node.practice_requested.connect(func(): get_tree().change_scene_to_file("res://practice.tscn"))

func set_paused(on: bool) -> void:
	paused = on
	charge = 0
	hud_node.show_pause(on, CAMERA_NAMES[camera_mode])
	hud_node.set_controls_text(controller.active)

func cycle_camera() -> void:
	camera_mode = (camera_mode + 1) % CAMERA_NAMES.size()
	wide_camera = camera_mode == 3
	if paused: hud_node.show_pause(true, CAMERA_NAMES[camera_mode])
	else: hud_node.show_banner(CAMERA_NAMES[camera_mode] + " CAMERA", "C or the pause menu to change", Color("#93a3b3"), 0.8)

func start_from_title() -> void:
	in_menu = false
	hud_node.show_title(false)
	camera_side = 0.0
	hud_node.show_banner("TORONTO  vs  MONTREAL", "1ST PERIOD", hud_node.team_colors[0], 1.6)

func setup_faceoff() -> void:
	for actor in skaters: actor.get_child(1).stop_mocap()
	carrier = null
	pickup_owner = false
	charge = 0
	cooldown = 0.3
	puck.position = next_faceoff+Vector3(0,0.017,0)
	puck.linear_velocity = Vector3.ZERO
	puck.angular_velocity = Vector3.ZERO
	previous_puck = puck.position
	var spots := [Vector3(0,0,1.25),Vector3(-6,0,1),Vector3(6,0,1),Vector3(-4,0,8),Vector3(4,0,8)]
	for actor in skaters:
		var team := body_team(actor)
		var sign_ := attack_direction(team)
		var slot := int(actor.get_meta("slot"))
		# A change caught by the whistle finishes on the stoppage.
		if is_hopping(actor) or bool(actor.get_meta("changing",false)):
			if bool(actor.get_meta("changing",false)) and int(actor.get_meta("pending_id",-1))>=0:
				change_identity(actor,int(actor.get_meta("pending_id")))
			actor.get_child(1).cancel_hop()
			actor.set_meta("hop",0)
			if bool(actor.get_meta("eligible",true)):
				actor.collision_layer=2
				set_puck_contacts_enabled(actor,true)
		actor.position = spots[slot]
		actor.position.z *= -sign_
		actor.position+=next_faceoff
		actor.position.x=clampf(actor.position.x,-(Arena.HALF_WIDTH-1.0),Arena.HALF_WIDTH-1.0)
		actor.position.z=clampf(actor.position.z,-28,28)
		actor.velocity = Vector3.ZERO
		actor.get_child(1).rotation.y = 0 if sign_<0 else PI
	sync_strength()
	if not bool(player.get_meta("eligible",true)): switch_player()

func sync_strength() -> void:
	for team in range(2):
		var unavailable := []
		for p in match_state.penalties:
			if p.team==team: unavailable.append(int(p.roster_id))
		var target_count := match_state.count(team)
		var active_count := 0
		for actor in skaters:
			if body_team(actor)!=team: continue
			var roster_id := int(actor.get_meta("roster_id"))
			var eligible := roster_id not in unavailable
			# Extra queued penalties never reduce below three on-ice skaters.
			if eligible and active_count<target_count:
				active_count += 1
			else: eligible = false
			var old := bool(actor.get_meta("eligible",true))
			actor.set_meta("eligible",eligible)
			actor.visible = eligible
			actor.collision_layer = 2 if eligible else 0
			set_puck_contacts_enabled(actor,eligible)
			if eligible and not old:
				actor.position = Vector3(Arena.HALF_WIDTH-1.4,0,team*4-2)
				actor.velocity = Vector3.ZERO
		# If a line held multiple penalized IDs, substitute eligible reserves into unused slots.
		if active_count < target_count:
			for actor in skaters:
				if body_team(actor)!=team or bool(actor.get_meta("eligible")): continue
				for id_ in range(18):
					if match_state.penalized(team,id_) or roster_on_ice(team,id_): continue
					change_identity(actor,id_)
					actor.set_meta("eligible",true)
					actor.visible = true
					actor.collision_layer = 2
					set_puck_contacts_enabled(actor,true)
					active_count += 1
					break
				if active_count>=target_count: break

## Mid board hop (line change): the body waits at the bench door while its
## visual travels; it plays no part in play until it is back on the ice.
func is_hopping(actor: CharacterBody3D) -> bool:
	return int(actor.get_meta("hop",0))!=0

## Where a changing skater in `slot` meets the boards: inside his own bench
## front (team 0 at z > 0, team 1 at z < 0, arena_benches.gd), one spot per slot.
func bench_spot(team: int, slot: int) -> Vector3:
	var zsign:=1.0 if team==0 else -1.0
	return Vector3(BENCH_X,0,zsign*(Benches.BENCH_GAP+1.0+slot*1.6))

func roster_on_ice(team: int, roster_id: int) -> bool:
	for actor in skaters:
		if body_team(actor)==team and bool(actor.get_meta("eligible",true)) and int(actor.get_meta("roster_id"))==roster_id: return true
	return false

func change_identity(actor: CharacterBody3D, id_: int) -> void:
	actor.set_meta("roster_id",id_)
	var visual := actor.get_child(1)
	visual.set_number(str(rosters[body_team(actor)][id_].number))
	visual.set_nameplate(str(rosters[body_team(actor)][id_].name).split(" ")[-1])
	actor.set_meta("changing",false)
	actor.set_meta("pending_id",-1)

func request_line(team: int, line_: int, defense: bool = false) -> bool:
	for actor in skaters:
		if body_team(actor)==team and bool(actor.get_meta("changing",false)): return false
	if defense: defense_pairs[team]=posmod(line_,3)
	else: active_lines[team]=posmod(line_,4)
	for actor in skaters:
		if body_team(actor)!=team: continue
		var slot := int(actor.get_meta("slot"))
		if (slot>=3)!=defense: continue
		var id_ := (12+defense_pairs[team]*2+slot-3) if defense else active_lines[team]*3+slot
		if match_state.penalized(team,id_): continue
		if int(actor.get_meta("roster_id"))==id_: continue
		if match_state.phase!=MatchState.Phase.PLAY:
			change_identity(actor,id_)
		else:
			actor.set_meta("changing",true)
			actor.set_meta("pending_id",id_)
			if carrier==actor: release_puck(actor,Vector3(0,0,attack_direction(team)),15)
	return true

func switch_player() -> void:
	var best: CharacterBody3D
	var score_ := INF
	for actor in skaters:
		if body_team(actor)!=0 or not bool(actor.get_meta("eligible")) or bool(actor.get_meta("changing")) or is_hopping(actor): continue
		var distance_ := actor.position.distance_to(puck.position)
		if actor==player: distance_ += 4
		if actor==carrier: distance_ -= 10
		if distance_<score_:
			score_=distance_
			best=actor
	if best!=null:
		player=best
		player_visual=player.get_child(1)
		velocity=player.velocity

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventJoypadMotion or event is InputEventJoypadButton:
		controller.handle(event)
		return
	if event is InputEventMouseMotion and event.relative.length()>2:
		controller.active=false
	if event is InputEventMouseButton: controller.active=false
	if event is InputEventKey and event.pressed:
		if event.physical_keycode in [KEY_W,KEY_A,KEY_S,KEY_D]:
			controller.active=false
		if event.keycode==KEY_F2:
			hud_node.set_controls_text(controller.active)
			hud_node.controls_panel.visible=not hud_node.controls_panel.visible
	if event is InputEventKey and event.pressed and not event.echo:
		if in_menu: return
		if event.keycode==KEY_ESCAPE:
			set_paused(not paused)
		if event.keycode==KEY_F1: debug=not debug
		if event.keycode==KEY_C: cycle_camera()
		if paused: return
		match event.keycode:
			KEY_SPACE: switch_player()
			KEY_1: request_line(0,0)
			KEY_2: request_line(0,1)
			KEY_3: request_line(0,2)
			KEY_4: request_line(0,3)
			KEY_Q: request_line(0,defense_pairs[0]+1,true)
			KEY_L: auto_lines=not auto_lines
			KEY_E: defensive_action(false)
			KEY_F: defensive_action(true)
	if paused or match_state.phase!=MatchState.Phase.PLAY: return
	if event is InputEventMouseButton:
		if event.button_index==MOUSE_BUTTON_WHEEL_UP and event.pressed: zoom=clampf(zoom-0.08,0.55,1.5)
		if event.button_index==MOUSE_BUTTON_WHEEL_DOWN and event.pressed: zoom=clampf(zoom+0.08,0.55,1.5)
		if event.button_index==MOUSE_BUTTON_LEFT and not event.pressed:
			strike(aim,lerpf(16,36,charge))
			charge=0
		if event.button_index==MOUSE_BUTTON_RIGHT and event.pressed:
			var target := pass_target(player,aim)
			if target!=null:
				var direction := target.position+target.velocity*0.25-puck.position
				direction.y=0
				if strike(direction.normalized(),17,true,0.18 if Input.is_physical_key_pressed(KEY_SHIFT) else 0.0): passes+=1

func pass_target(actor: CharacterBody3D, direction: Vector3) -> CharacterBody3D:
	var best: CharacterBody3D
	var best_score := -INF
	for other in skaters:
		if other==actor or body_team(other)!=body_team(actor) or not bool(other.get_meta("eligible")) or bool(other.get_meta("changing")): continue
		var offset := other.position-actor.position
		var score_ := direction.dot(offset.normalized())*20-offset.length()*0.15
		if score_>best_score: best_score=score_;best=other
	return best

func strike(direction: Vector3, speed: float, is_pass: bool = false, elevation: float = -1.0) -> bool:
	if match_state.phase!=MatchState.Phase.PLAY or cooldown>0 or player.position.distance_to(puck.position)>1.8 or puck.position.y>0.22: return false
	if elevation<0:
		elevation=0.0 if is_pass else shot_lift
	release_puck(player,direction,speed,elevation)
	if not is_pass:
		shots+=1
		roster(player).shots+=1
	return true

func release_puck(actor: CharacterBody3D, direction: Vector3, speed: float, elevation: float = 0.0) -> void:
	puck.sleeping=false
	puck.linear_velocity=PuckPhysics.launch(direction,speed,elevation)+actor.velocity*0.2
	puck.angular_velocity=Vector3(0,lerpf(-8,8,controller.right_stick.x) if actor==player else 6,0)
	carrier=null
	pickup_owner=false
	cooldown=0.42
	actor.get_child(1).shot_follow=1.0
	actor.get_child(1).shot_charge=0
	beep(170)

func defensive_action(body_check: bool) -> void:
	if match_state.phase!=MatchState.Phase.PLAY or action_cooldown>0: return
	action_cooldown=0.6
	var victim: CharacterBody3D
	var distance_ := 1.7 if body_check else 1.35
	for other in skaters:
		if body_team(other)==0 or not bool(other.get_meta("eligible")): continue
		var d := player.position.distance_to(other.position)
		if d<distance_: distance_=d;victim=other
	if victim==null:
		if player.position.distance_to(puck.position)<1.6:
			puck.linear_velocity+=aim*5
			carrier=null
			cooldown=0.18
		return
	var near_puck := victim.position.distance_to(puck.position)<1.7
	var relative_speed := (player.velocity-victim.velocity).length()
	if body_check and not near_puck:
		assess_penalty(player,"Interference")
	elif body_check and relative_speed>8.5:
		assess_penalty(player,"Charging")
	elif not body_check and player.position.distance_to(puck.position)>1.4:
		assess_penalty(player,"Tripping")
	else:
		var push := (victim.position-player.position).normalized()
		victim.velocity+=push*(4 if body_check else 1.2)
		victim.set_meta("stun",0.35 if body_check else 0.08)
		if victim==carrier:
			carrier=null
			puck.linear_velocity=push*5
			cooldown=0.22

func assess_penalty(actor: CharacterBody3D, reason: String) -> void:
	if match_state.minor(body_team(actor),int(actor.get_meta("roster_id")),reason):
		carrier=null
		pickup_owner=false
		sync_strength()
		if actor==player: switch_player()
		beep(900)

func _on_puck_contact(body: Node) -> void:
	var actor:=hit_actor(body)
	if actor is CharacterBody3D and actor in goalkeepers and goalie_contact_timer<=0:
		goalie_contact_timer=0.25
		saves+=1
		if absf(last_puck_velocity.z)>6: team_shots[0 if attack_direction(0)==signf(actor.position.z) else 1]+=1
		cooldown=0.2
		carrier=null
		# Engine contact normals/materials resolve rebound direction and vertical speed.
		var pocket:Vector3=body.to_local(puck.global_position)
		var front_entry:bool=last_puck_velocity.dot(body.global_basis.z)<-1
		var zone:=str(body.get_meta("zone",""))
		if zone in ["body","pad"] and last_puck_velocity.length()>10:
			# Captured body-block reaction through the torso.
			actor.get_child(1).play_mocap("Goalkeeper_Body_Block",false,["spine"],1.5,0.9,0.45)
		if zone=="catcher" and last_puck_velocity.length()<32 and front_entry and absf(pocket.x)<0.085 and absf(pocket.y)<0.10:
			match_state.phase=MatchState.Phase.STOPPAGE
			match_state.phase_timer=2
			match_state.event="Goalkeeper catch"
			next_faceoff=Vector3(-Arena.DOT_X if puck.position.x<0 else Arena.DOT_X,0,signf(actor.position.z)*Arena.END_DOT_Z)
			puck.linear_velocity=Vector3.ZERO
			puck.freeze=true
		beep(115)
	elif puck.linear_velocity.length()>8:
		beep(300)

func _physics_process(delta: float) -> void:
	if skaters.is_empty(): return
	if in_menu:
		# Slow orbit over the arena behind the title screen.
		menu_time += delta
		var angle := menu_time * 0.08
		camera.position = Vector3(sin(angle) * 22.0, 11.0, cos(angle) * 30.0)
		camera.look_at(Vector3(0, 0.5, 0), Vector3.UP)
		for actor in skaters + goalkeepers:
			actor.get_child(1).animate(0, delta, 0, false)
		return
	process_controller_edges()
	puck.freeze=paused or match_state.phase!=MatchState.Phase.PLAY
	if paused:
		if not hud_node.pause_panel.visible: set_paused(true)
		return
	elapsed+=delta
	cooldown=maxf(0,cooldown-delta)
	action_cooldown=maxf(0,action_cooldown-delta)
	goalie_contact_timer=maxf(0,goalie_contact_timer-delta)
	var old_phase := match_state.phase
	match_state.advance(delta)
	if match_state.period!=known_period:
		known_period=match_state.period
		# New period, freshly resurfaced ice.
		if ice_marks: ice_marks.clear()
		for keeper in goalkeepers:
			keeper.position.z *= -1
			keeper.rotation.y += PI
		for i in range(2): goalie_targets[i]=goalkeepers[i].position
	if last_faceoff_serial!=match_state.faceoff_serial:
		last_faceoff_serial=match_state.faceoff_serial
		setup_faceoff()
	if old_phase==MatchState.Phase.FACEOFF and match_state.phase==MatchState.Phase.PLAY:
		puck.freeze=false
		puck.linear_velocity=Vector3(-1,0,-1.5) if match_state.period%2 else Vector3(1,0,1.5)
	sync_strength()
	update_roster_stamina(delta)
	if match_state.phase==MatchState.Phase.PLAY:
		control_player(delta)
		update_team_ai(delta)
		update_possession(delta)
		update_goalkeepers(delta)
		update_officials(delta)

		for end_ in [-1.0,1.0]:
			if Skating.goal_crossing_end(previous_puck,puck.position,end_):
				var scoring_team:=0 if attack_direction(0)==end_ else 1
				match_state.goal(scoring_team)
				team_shots[scoring_team]+=1
				var scorer_name:=""
				if carrier!=null and body_team(carrier)==scoring_team: scorer_name=str(roster(carrier).name).to_upper()
				# Red goal light behind this net, arena light pulse, jumbotron GOAL.
				celebration.celebrate(end_, hud_node.team_colors[scoring_team], hud_node.team_names[scoring_team])
				# Scoring bench jumps up, the other one slumps (arena_benches.gd).
				var goal_benches=arena.get_node_or_null("Benches")
				if goal_benches!=null: goal_benches.celebrate(scoring_team)
				hud_node.show_banner("GOAL", (hud_node.team_names[scoring_team]+("  ·  "+scorer_name if scorer_name!="" else "")), hud_node.team_colors[scoring_team], 2.4)
				# Scorers celebrate with captured motion, sticks raised.
				for actor in skaters:
					if body_team(actor)==scoring_team:
						actor.get_child(1).play_mocap("Standing_Cheering",false,["spine","arms","stick_up"])
				next_faceoff=Vector3.ZERO
				beep(550)
				carrier=null
				break
		previous_puck=puck.position
		if puck.position.y< -2 or absf(puck.position.x)>18 or absf(puck.position.z)>33:
			match_state.phase=MatchState.Phase.STOPPAGE
			match_state.phase_timer=1.5
			match_state.event="Puck out of play"
	else:
		for actor in skaters:
			actor.velocity=Vector3.ZERO
			actor.get_child(1).animate(0,delta,0,false)
	last_puck_velocity=puck.linear_velocity
	goals=match_state.score[0]
	away_goals=match_state.score[1]
	update_camera(delta)
	update_match_hud()
	if is_instance_valid(puck_shadow):
		puck_shadow.position=Vector3(puck.position.x,0.003,puck.position.z)
		var shadow_scale:=clampf(1+puck.position.y*0.15,1,1.8)
		puck_shadow.scale=Vector3(shadow_scale,1,shadow_scale)

func control_player(delta: float) -> void:
	if not bool(player.get_meta("eligible")): switch_player()
	var intent:=Vector3.ZERO
	var effort:=false
	var braking:=false
	if controller.active:
		intent=screen_to_rink(Vector3(controller.left_stick.x,0,controller.left_stick.y))
		if intent.length()>0.05: aim=intent.normalized()
		effort=controller.effort
		braking=controller.stop
		shot_lift=controller.lift*0.32
		player_visual.desired_stick=controller.right_stick
		if controller.trigger_down:
			charge=minf(1,charge+delta*lerpf(0.6,1.3,controller.shoot_trigger))
	else:
		intent=screen_to_rink(Vector3(float(Input.is_physical_key_pressed(KEY_D))-float(Input.is_physical_key_pressed(KEY_A)),0,float(Input.is_physical_key_pressed(KEY_S))-float(Input.is_physical_key_pressed(KEY_W))))
		var m=Plane(Vector3.UP,0).intersects_ray(camera.project_ray_origin(get_viewport().get_mouse_position()),camera.project_ray_normal(get_viewport().get_mouse_position()))
		if m!=null:
			var d:Vector3=m-player.position
			d.y=0
			if d.length()>0.3: aim=d.normalized()
		effort=Input.is_physical_key_pressed(KEY_SHIFT)
		braking=Input.is_physical_key_pressed(KEY_CTRL)
		shot_lift=0.18 if Input.is_physical_key_pressed(KEY_ALT) else 0.02
		player_visual.desired_stick=Vector2.ZERO
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT): charge=minf(1,charge+delta*1.3)
	if bool(player.get_meta("changing")) or is_hopping(player): return
	velocity=Skating.step(player.velocity,intent,float(roster(player).speed)*lerpf(0.65,1,float(roster(player).stamina)),effort,delta)
	if braking: velocity=velocity.move_toward(Vector3.ZERO,22*delta)
	player.velocity=velocity
	player.move_and_slide()
	var visual:=player.get_child(1)
	visual.rotation.y=rotate_toward(visual.rotation.y,atan2(-aim.x,-aim.z),6*delta)
	visual.shot_charge=charge
	visual.animate(player.velocity.length(),delta,0,intent.length_squared()>0.01,braking)
	sync_skater_contacts(player)

func update_roster_stamina(delta: float) -> void:
	for team in range(2):
		for i in range(18):
			var active:=false
			for actor in skaters:
				if body_team(actor)==team and int(actor.get_meta("roster_id"))==i and bool(actor.get_meta("eligible")):
					active=true
					var effort:=0.0008+actor.velocity.length()*0.00045
					rosters[team][i].stamina=maxf(0.35,rosters[team][i].stamina-delta*effort)
					break
			if not active: rosters[team][i].stamina=minf(1,rosters[team][i].stamina+delta*0.012)
		if auto_lines and match_state.phase==MatchState.Phase.PLAY:
			var total:=0.0
			var count_:=0
			for actor in skaters:
				if body_team(actor)==team and int(actor.get_meta("slot"))<3:
					total+=float(roster(actor).stamina)
					count_+=1
			if total/maxi(count_,1)<0.70 and puck.position.z*attack_direction(team)>-8:
				request_line(team,active_lines[team]+1)

func update_team_ai(delta: float) -> void:
	var nearest: Array[CharacterBody3D]=[null,null]
	for actor in skaters:
		if not bool(actor.get_meta("eligible")) or bool(actor.get_meta("changing")) or is_hopping(actor): continue
		var team:=body_team(actor)
		if nearest[team]==null or actor.position.distance_squared_to(puck.position)<nearest[team].position.distance_squared_to(puck.position):
			nearest[team]=actor
	for actor in skaters:
		if not bool(actor.get_meta("eligible")): continue
		if actor==player and not bool(actor.get_meta("changing")) and not is_hopping(actor): continue
		var team:=body_team(actor)
		var attack:=attack_direction(team)
		var slot:=int(actor.get_meta("slot"))
		var target:=Vector3.ZERO
		var changing:=bool(actor.get_meta("changing"))
		if changing or is_hopping(actor):
			# Line change: skate to a door-side spot on the own bench front, hop
			# the boards onto the bench floor (board_hop.gd), swap in the fresh
			# player there, and he hops back over onto the ice.
			target=bench_spot(team,slot)
			var visual_:=actor.get_child(1)
			var hop:=int(actor.get_meta("hop",0))
			if hop==0 and changing and actor.position.distance_to(target)<0.9:
				actor.velocity=Vector3.ZERO
				var bench_floor:=Vector3(-(Arena.HALF_WIDTH+HOP_BENCH_DEPTH),0,actor.position.z)
				visual_.start_hop(Vector3.ZERO,bench_floor-actor.position,-Arena.HALF_WIDTH-actor.position.x)
				actor.set_meta("hop",1)
				actor.collision_layer=0
				set_puck_contacts_enabled(actor,false)
				if carrier==actor: carrier=null
			elif hop==1 and visual_.hop_finished():
				# Fresh legs climb out a little further along the bench.
				change_identity(actor,int(actor.get_meta("pending_id")))
				var from_:Vector3=visual_.position+Vector3(0,0,-signf(target.z)*0.7)
				# A different player now: he gets up off the bench facing the ice, stick up.
				visual_.rotation.y=-PI*0.5
				visual_.start_hop(from_,Vector3.ZERO,-Arena.HALF_WIDTH-actor.position.x,true)
				actor.set_meta("hop",2)
				if actor==player: switch_player()
			elif hop==2 and visual_.hop_finished():
				visual_.cancel_hop()
				actor.set_meta("hop",0)
				actor.collision_layer=2
				set_puck_contacts_enabled(actor,true)
			if hop!=0:
				actor.velocity=Vector3.ZERO
				visual_.animate(0,delta,0,false)
				continue
		elif actor==carrier:
			target=Vector3(clampf(actor.position.x*0.6,-5,5),0,attack*(Arena.GOAL_LINE-3.0))
			var distance_to_goal:=actor.position.distance_to(Vector3(0,0,attack*Arena.GOAL_LINE))
			var timer:=float(actor.get_meta("decision"))-delta
			if timer<=0 and cooldown<=0:
				actor.set_meta("decision",0.4)
				var pressure:=closest_opponent_distance(actor)
				if distance_to_goal<16 and distance_to_goal>3:
					var goalie:=goalkeeper_at_end(attack)
					var target_x:float= -0.65 if goalie.position.x>=0 else 0.65
					var shot_dir:Vector3=Vector3(target_x,0.1,attack*Arena.GOAL_LINE)-puck.position
					var distance_:float=Vector2(shot_dir.x,shot_dir.z).length()
					var elevation_:float=PuckPhysics.solve_elevation(distance_,29,0.85,puck.position.y)
					release_puck(actor,shot_dir,29,elevation_)
					roster(actor).shots+=1
				elif pressure<2.6:
					var other:=pass_target(actor,Vector3(0,0,attack))
					if other!=null: release_puck(actor,other.position+other.velocity*0.25-puck.position,17)
			else: actor.set_meta("decision",timer)
		elif nearest[team]==actor:
			target=Vector3(puck.position.x,0,puck.position.z)+Vector3(puck.linear_velocity.x,0,puck.linear_velocity.z)*0.08
		else:
			var possession:=carrier!=null and body_team(carrier)==team
			var x_slots: Array[float]=[0,-6,6,-5,5]
			var z_offset: Array[float]=[3,1,1,-8,-8]
			if possession:
				target=Vector3(clampf(puck.position.x*0.25+x_slots[slot],-(Arena.HALF_WIDTH-1.5),Arena.HALF_WIDTH-1.5),0,clampf(puck.position.z+attack*z_offset[slot],-(Arena.GOAL_LINE-2.0),Arena.GOAL_LINE-2.0))
			else:
				var own_goal:float= -attack*Arena.GOAL_LINE
				var defended_z:float=lerpf(puck.position.z,own_goal,0.35 if slot>=3 else 0.1)
				target=Vector3(clampf(puck.position.x*0.3+x_slots[slot],-(Arena.HALF_WIDTH-2.0),Arena.HALF_WIDTH-2.0),0,clampf(defended_z,-(Arena.GOAL_LINE-2.0),Arena.GOAL_LINE-2.0))
		var to_target:=target-actor.position
		var intent:=to_target.limit_length(1)
		if to_target.length()<0.6: intent=Vector3.ZERO
		var stun:=maxf(0,float(actor.get_meta("stun"))-delta)
		actor.set_meta("stun",stun)
		if stun<=0:
			var rating_:float=float(roster(actor).speed)*lerpf(0.65,1,float(roster(actor).stamina))
			actor.velocity=Skating.step(actor.velocity,intent,rating_,false,delta)
		actor.move_and_slide()
		var visual:=actor.get_child(1)
		var face:=intent if intent.length()>0.1 else (puck.position-actor.position).normalized()
		if actor==carrier: face=(Vector3(0,0,attack*Arena.GOAL_LINE)-actor.position).normalized()
		visual.rotation.y=rotate_toward(visual.rotation.y,atan2(-face.x,-face.z),4.8*delta)
		visual.animate(actor.velocity.length(),delta,0,intent.length_squared()>0.01)
		sync_skater_contacts(actor)
		# Poke separation only within physical reach; AI uses the same puck object.
		if carrier!=null and body_team(carrier)!=team and actor.position.distance_to(puck.position)<1.0 and cooldown<=0:
			puck.linear_velocity=(puck.position-actor.position).normalized()*5
			carrier=null
			cooldown=0.22

func closest_opponent_distance(actor: CharacterBody3D) -> float:
	var result:=INF
	for other in skaters:
		if body_team(other)!=body_team(actor) and bool(other.get_meta("eligible")):
			result=minf(result,actor.position.distance_to(other.position))
	return result

func update_possession(delta: float) -> void:
	if carrier!=null:
		if not bool(carrier.get_meta("eligible")) or carrier.position.distance_to(puck.position)>1.9 or cooldown>0 or puck.position.y>0.18:
			carrier=null
	if carrier==null and cooldown<=0 and puck.position.y<0.14:
		var best:=1.15
		for actor in skaters:
			if not bool(actor.get_meta("eligible")) or bool(actor.get_meta("changing")) or is_hopping(actor): continue
			var distance_:=actor.position.distance_to(Vector3(puck.position.x,0,puck.position.z))
			if distance_<best and (puck.linear_velocity-actor.velocity).length()<17:
				best=distance_
				carrier=actor
	if carrier!=null:
		var visual:=carrier.get_child(1)
		var target:Vector3=visual.get_blade_world()
		var error:=target-puck.position
		error.y=0
		var relative:=puck.linear_velocity-carrier.velocity
		relative.y=0
		puck.linear_velocity+=(error*160-relative*25).limit_length(100)*delta
	pickup_owner=carrier==player

func update_goalkeepers(delta: float) -> void:
	goalie_reaction-=delta
	if goalie_reaction<=0:
		goalie_reaction=0.14
		for i in range(2):
			var keeper:=goalkeepers[i]
			var end_:=signf(keeper.position.z)
			var goal_center:=Vector3(0,0,end_*Arena.GOAL_LINE)
			var sight:=Vector3(puck.position.x,0,puck.position.z)-goal_center
			var depth:=clampf(sight.length()*0.065,0.35,1.6)
			var incoming:=puck.linear_velocity.z*end_>3
			var predicted:=Vector3(puck.position.x,0,puck.position.z)
			if incoming: predicted+=Vector3(puck.linear_velocity.x,0,puck.linear_velocity.z)*0.10
			var ray:Vector3=(predicted-goal_center).normalized()
			goalie_targets[i]=goal_center+ray*depth
			goalie_targets[i].x=clampf(goalie_targets[i].x,-0.78,0.78)
			goalie_targets[i].z=clampf(goalie_targets[i].z,Arena.GOAL_LINE-1.6,Arena.GOAL_LINE-0.35) if end_>0 else clampf(goalie_targets[i].z,-(Arena.GOAL_LINE-0.35),-(Arena.GOAL_LINE-1.6))
	for i in range(2):
		var keeper:=goalkeepers[i]
		var visual:=keeper.get_child(1)
		var end_:=signf(keeper.position.z)
		var incoming:=puck.linear_velocity.z*end_>3
		var intercept_time:=0.0
		if incoming: intercept_time=clampf((keeper.position.z-puck.position.z)/puck.linear_velocity.z,0,1)
		var intercept_height:=PuckPhysics.ballistic_height(puck.position.y,puck.linear_velocity.y,intercept_time)
		var threat:=incoming and absf(puck.position.z-keeper.position.z)<12
		# Save selection from where the puck will cross the goalie: butterfly or a
		# pad extension low, glove or blocker high to either side, body block in
		# the middle. Each save blends in fast and recovers slowly, and a new
		# read interrupts the old one.
		var kind:=""
		var crossing:=Vector2.ZERO
		if threat:
			var at:Vector3=puck.position+puck.linear_velocity*intercept_time
			var local:Vector3=visual.rig.global_transform.affine_inverse()*Vector3(at.x,intercept_height,at.z)
			crossing=Vector2(local.x,intercept_height)
			kind=visual.choose_save(local.x,intercept_height)
		var drop_down:bool=kind in ["butterfly","pad_left","pad_right"]
		visual.butterfly=move_toward(visual.butterfly,1.0 if drop_down else 0.0,delta*(6 if drop_down else 2))
		visual.set_save(kind,crossing if threat else visual.save_target,delta)
		var desired_height:=clampf(intercept_height-0.7,0,0.40) if threat and kind=="body" else 0.0
		visual.goalie_save_height=move_toward(visual.goalie_save_height,desired_height,delta*2.8)
		keeper.velocity=(goalie_targets[i]-keeper.position).limit_length(1)*3.8
		keeper.move_and_slide()
		var facing:=puck.position-keeper.position
		visual.rotation.y=rotate_toward(visual.rotation.y,atan2(-facing.x,-facing.z)-keeper.rotation.y,delta*4)
		visual.animate(keeper.velocity.length(),delta,0,false)
		sync_goalie_contacts(keeper)
		if puck.position.y<0.13 and puck.linear_velocity.length()<2 and keeper.position.distance_to(puck.position)<0.65 and cooldown<=0:
			match_state.phase=MatchState.Phase.STOPPAGE
			match_state.phase_timer=2
			match_state.event="Goalkeeper cover"
			next_faceoff=Vector3(-Arena.DOT_X if puck.position.x<0 else Arena.DOT_X,0,end_*Arena.END_DOT_Z)
			puck.freeze=true
			puck.linear_velocity=Vector3.ZERO
			carrier=null

func update_camera(delta: float) -> void:
	# The user's team always attacks up the screen, as in EA's default cameras:
	# the camera sits behind the end Toronto defends and flips between periods.
	var side:=-signf(attack_direction(0))
	if side==0: side=1.0
	var snap:=side!=camera_side
	camera_side=side
	var lead:=-side*2.5
	var focus:=Vector3(clampf(puck.position.x*0.35,-6,6),0,clampf(puck.position.z+lead,-(Arena.GOAL_LINE-3.0),Arena.GOAL_LINE-3.0))
	if camera_mode==3: focus=Vector3.ZERO
	camera_target=focus if snap else camera_target.lerp(focus,1-exp(-delta*3.2))
	var desired:Vector3
	var look:Vector3
	match camera_mode:
		0: # Dynamic: low and close behind the play, like a chase broadcast cam.
			desired=camera_target+Vector3(0,9.5,side*12.5)*zoom/0.8
			look=camera_target+Vector3(0,0.2,-side*5.0)
		1: # Overhead: high above the ice, attacking up.
			desired=camera_target+Vector3(0,25,side*15)*zoom
			look=camera_target+Vector3(0,0.4,-side*3.0)
		2: # Broadcast: press-box side view; the camera changes sides between
			# periods so Toronto always attacks to the right, as on TV.
			desired=Vector3(side*(Arena.HALF_WIDTH+6.5)*zoom/0.8,12.0,camera_target.z*0.85)
			look=Vector3(camera_target.x*0.4,0,camera_target.z)
		_: # Full rink.
			desired=Vector3(0,51,side*27)
			look=Vector3(0,0.4,-side*3.0)
	camera.position=desired if snap else camera.position.lerp(desired,1-exp(-delta*5))
	if camera_mode!=2: camera.position.x=camera_target.x
	# A camera up among the rigging over the sheet (Overhead, Full rink, a
	# zoomed-out Dynamic) hides the trusses and jumbotron so they never sit
	# between it and the ice.
	camera.cull_mask=preload("res://scripts/arena_lighting.gd").camera_cull_mask(camera.position)
	camera.look_at(look,Vector3.UP)
	camera.rotation.z=0
	selection.position=player.position+Vector3(0,0.025,0)
	selection.visible=match_state.phase!=MatchState.Phase.FINAL

## Converts stick or WASD input (x right, z down the screen) into rink space
## using the camera's facing, so up on the stick is always up the screen.
func screen_to_rink(input: Vector3) -> Vector3:
	var b:=camera.global_basis
	var right:=Vector3(b.x.x,0,b.x.z).normalized()
	var forward:=-Vector3(b.z.x,0,b.z.z).normalized()
	if forward.length_squared()<0.5: forward=Vector3(0,0,-1)
	return right*input.x+forward*(-input.z)

func update_match_hud() -> void:
	var pp:=""
	for team in range(2):
		var advantage:=match_state.count(team)-match_state.count(1-team)
		if advantage>0:
			var remaining:=999.0
			for p in match_state.active_penalties(1-team): remaining=minf(remaining,p.remaining)
			var seconds:=int(ceil(remaining))
			pp="%s POWER PLAY   %d:%02d   %d ON %d"%[hud_node.team_codes[team],seconds/60,seconds%60,match_state.count(team),match_state.count(1-team)]
	hud_node.update_bug(match_state.score,match_state.period,match_state.clock_text(),[match_state.count(0),match_state.count(1)],pp,team_shots)
	# Centre-hung scoreboard mirrors the score bug (rebuilt only when it changes).
	var board_line:="TOR  %d     MTL  %d"%[match_state.score[0],match_state.score[1]]
	var board_sub:="%s   %s"%[["1ST","2ND","3RD"][clampi(match_state.period-1,0,2)],match_state.clock_text()]
	if board_line+board_sub!=str(get_meta("board_text","")):
		set_meta("board_text",board_line+board_sub)
		var dressing:=arena.get_node_or_null("Dressing")
		if dressing: dressing.set_scoreboard(board_line,board_sub)
	# Event banners for the moments a broadcast would mark.
	if match_state.event!=last_event:
		var e:=match_state.event
		if e.begins_with("END OF PERIOD"):
			hud_node.show_banner("END OF "+["1ST","2ND","3RD"][clampi(match_state.period-1,0,2)], "TOR %d   –   %d MTL"%[match_state.score[0],match_state.score[1]], Color("#93a3b3"), 3.5)
		elif e.begins_with("Period "):
			hud_node.show_banner(["1ST","2ND","3RD"][clampi(match_state.period-1,0,2)]+" PERIOD", "Ends switched", Color("#93a3b3"), 1.6)
		elif e.begins_with("FINAL"):
			hud_node.show_banner("FINAL", "TOR %d   –   %d MTL"%[match_state.score[0],match_state.score[1]], hud_node.ACCENT, 600.0)
		elif " — " in e and (e.begins_with("TOR") or e.begins_with("MTL")):
			var team:=0 if e.begins_with("TOR") else 1
			hud_node.show_banner("PENALTY", e.substr(6).to_upper(), hud_node.team_colors[team], 2.0)
		last_event=e
	var stopped:=match_state.phase!=MatchState.Phase.PLAY
	var quiet_events:=["Play","Centre faceoff","Opening faceoff"]
	status.text=("" if not stopped or match_state.event in quiet_events or match_state.event.ends_with("GOAL") else match_state.event.to_upper())
	if debug:
		status.text+="  FPS %d  ·  puck %.1f m/s  ·  height %.2f m  ·  %s"%[Engine.get_frames_per_second(),puck.linear_velocity.length(),puck.position.y,("TOR POSSESSION" if carrier!=null and body_team(carrier)==0 else ("MTL POSSESSION" if carrier!=null else "LOOSE PUCK"))]
	hud_node.status_panel.visible=not status.text.strip_edges().is_empty()
	var penalty_text:=match_state.penalty_text()
	hud_node.penalties_panel.visible=not penalty_text.is_empty()
	penalties_label.text="PENALTIES\n"+penalty_text
	# Penalised players sit in their team's box (arena_benches.gd, at most two shown).
	var benches=arena.get_node_or_null("Benches")
	if benches!=null:
		for t in range(2): benches.set_penalty_count(t,match_state.penalties.filter(func(p): return p.team==t).size())
	var players:=[]
	for actor in skaters:
		if body_team(actor)==0 and int(actor.get_meta("slot"))<3:
			players.append({"number":roster(actor).number,"name":str(roster(actor).name).split(" ")[-1],"stamina":float(roster(actor).stamina),"changing":bool(actor.get_meta("changing"))})
	hud_node.update_line(active_lines[0],defense_pairs[0],players)
	power.visible=charge>0
	power.value=charge
	help.text=("START  PAUSE   ·   VIEW  CONTROLS" if controller.active else "ESC  PAUSE   ·   F2  CONTROLS   ·   C  CAMERA")

func capture_preview() -> void:
	# --capture-time=<seconds> lets wear such as skate cuts build up first.
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-time="): capture_time = clampf(float(arg.substr(15)), 0.5, 120.0)
	await get_tree().create_timer(capture_time).timeout
	for frame in range(600):
		if match_state.phase==MatchState.Phase.PLAY: break
		await get_tree().physics_frame
	if "--paused" in OS.get_cmdline_user_args():
		set_paused(true)
		await get_tree().process_frame
	if "--goal-banner" in OS.get_cmdline_user_args():
		hud_node.show_banner("GOAL", "TORONTO  ·  VALE", hud_node.team_colors[0], 5.0)
		for i in range(20): await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/tmp/hawkey-match-preview.png")
	get_tree().quit()

func goalkeeper_at_end(end_sign: float) -> CharacterBody3D:
	for keeper in goalkeepers:
		if signf(keeper.position.z)==end_sign: return keeper
	return goalkeepers[0]


func update_officials(delta: float) -> void:
	for i in range(referee_nodes.size()):
		var official:=referee_nodes[i]
		var target:=Vector3(-(Arena.HALF_WIDTH-2.0) if i==0 else Arena.HALF_WIDTH-2.0,0,clampf(puck.position.z+(-9 if i==0 else 9),-(Arena.GOAL_LINE-1.0),Arena.GOAL_LINE-1.0))
		var move:Vector3=(target-official.position).limit_length(1)*4
		official.position+=move*delta
		if move.length()>0.2:
			official.rotation.y=rotate_toward(official.rotation.y,atan2(-move.x,-move.z),delta*4)
		official.animate(move.length(),delta,0,move.length()>0.2)

func process_controller_edges() -> void:
	if controller.pause_pressed and not in_menu:
		set_paused(not paused)
	if not controller.active:
		controller.clear_edges()
		return
	if controller.left_stick.length()>0.05:
		aim=screen_to_rink(Vector3(controller.left_stick.x,0,controller.left_stick.y)).normalized()
	if not paused and not in_menu:
		if controller.switch_pressed: switch_player()
		if controller.line_delta!=0: request_line(0,active_lines[0]+controller.line_delta)
		if controller.pair_delta!=0: request_line(0,defense_pairs[0]+controller.pair_delta,true)
		if controller.check_pressed: defensive_action(true)
		if controller.poke_pressed: defensive_action(false)
		if match_state.phase==MatchState.Phase.PLAY:
			if controller.shoot_released:
				strike(aim,lerpf(16,36,charge),false,controller.lift*0.32)
				charge=0
			if controller.pass_pressed or controller.saucer_pressed:
				var target:=pass_target(player,aim)
				if target!=null:
					var direction:=target.position+target.velocity*0.25-puck.position
					direction.y=0
					if strike(direction.normalized(),16,true,0.18 if controller.saucer_pressed else 0): passes+=1
	controller.clear_edges()

func on_controller_connection(device: int, is_connected: bool) -> void:
	if not is_connected and controller.disconnected(device):
		set_paused(true)
		status.text="CONTROLLER DISCONNECTED — reconnect, then Start / Options"
	elif is_connected:
		controller.connected=true
