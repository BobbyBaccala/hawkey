extends "res://scripts/lab.gd"
const MatchState = preload("res://scripts/match_state.gd")
var match_state := MatchState.new()
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
var goalie_targets: Array[Vector3] = [Vector3(0,0,-24),Vector3(0,0,24)]
var goalie_reaction := 0.0
var goalie_contact_timer := 0.0
var capture_time := 8.0
var known_period := 1

func _ready() -> void:
	super._ready()
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
			var actor := make_skater(Vector3.ZERO,team_color(team),str(rosters[team][roster_id].number))
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
		official.position=Vector3(-11 if i==0 else 11,0,-12 if i==0 else 12)
		referee_nodes.append(official)
	setup_faceoff()
	camera.position = Vector3(0,20,24)
	camera.look_at(Vector3.ZERO)
	if "--capture" in OS.get_cmdline_user_args():
		# Normal live match, no staged image substitution.
		match_state.phase_timer = 0.3

func team_color(team: int) -> Color:
	return Color("#174669") if team==0 else Color("#7c1f39")

func attack_direction(team: int) -> float:
	var direction := -1.0 if team==0 else 1.0
	return direction if match_state.period%2==1 else -direction

func body_team(body: CharacterBody3D) -> int:
	return int(body.get_meta("team",0))

func roster(body: CharacterBody3D) -> Dictionary:
	return rosters[body_team(body)][int(body.get_meta("roster_id",0))]

func build_hud() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)
	var top := PanelContainer.new()
	top.position = Vector2(32,24)
	top.size = Vector2(650,76)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025,0.045,0.075,0.98)
	style.border_color = Color("#6994af")
	style.border_width_bottom = 3
	style.content_margin_left = 22
	style.content_margin_top = 10
	style.content_margin_right = 22
	style.content_margin_bottom = 10
	top.add_theme_stylebox_override("panel",style)
	canvas.add_child(top)
	hud = Label.new()
	hud.add_theme_font_size_override("font_size",25)
	top.add_child(hud)
	var status_panel := PanelContainer.new()
	status_panel.position = Vector2(32,110)
	var ss := StyleBoxFlat.new()
	ss.bg_color = Color(0.025,0.045,0.075,0.90)
	ss.content_margin_left = 12
	ss.content_margin_right = 12
	ss.content_margin_top = 7
	ss.content_margin_bottom = 7
	status_panel.add_theme_stylebox_override("panel",ss)
	canvas.add_child(status_panel)
	status = Label.new()
	status.add_theme_font_size_override("font_size",16)
	status_panel.add_child(status)
	var right := PanelContainer.new()
	right.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	right.offset_left = -340
	right.offset_right = -24
	right.offset_top = 24
	var rs := ss.duplicate()
	right.add_theme_stylebox_override("panel",rs)
	canvas.add_child(right)
	penalties_label = Label.new()
	penalties_label.add_theme_font_size_override("font_size",18)
	right.add_child(penalties_label)
	var line_box := PanelContainer.new()
	line_box.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	line_box.offset_left = 32
	line_box.offset_top = -156
	line_box.offset_bottom = -60
	line_box.add_theme_stylebox_override("panel",ss.duplicate())
	canvas.add_child(line_box)
	team_panel = Label.new()
	team_panel.add_theme_font_size_override("font_size",17)
	line_box.add_child(team_panel)
	var bottom := PanelContainer.new()
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_top = -48
	bottom.add_theme_stylebox_override("panel",ss.duplicate())
	canvas.add_child(bottom)
	help = Label.new()
	help.add_theme_font_size_override("font_size",15)
	help.text = "WASD Skate  •  Mouse Aim  •  LMB Shoot  •  RMB Pass  •  Space Switch  •  1–4 Forward lines  •  Q Defence  •  E Poke  •  F Check  •  Esc Pause"
	bottom.add_child(help)
	power = ProgressBar.new()
	power.position = Vector2(32,157)
	power.size = Vector2(180,9)
	power.show_percentage = false
	power.max_value = 1
	canvas.add_child(power)

func setup_faceoff() -> void:
	carrier = null
	pickup_owner = false
	charge = 0
	cooldown = 0.3
	puck.position = Vector3(0,0.017,0)
	puck.linear_velocity = Vector3.ZERO
	puck.angular_velocity = Vector3.ZERO
	previous_puck = puck.position
	var spots := [Vector3(0,0,1.25),Vector3(-6,0,1),Vector3(6,0,1),Vector3(-4,0,8),Vector3(4,0,8)]
	for actor in skaters:
		var team := body_team(actor)
		var sign_ := attack_direction(team)
		var slot := int(actor.get_meta("slot"))
		actor.position = spots[slot]
		actor.position.z *= -sign_
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
			if eligible and not old:
				actor.position = Vector3(13.6,0,team*4-2)
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
					active_count += 1
					break
				if active_count>=target_count: break

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
		if body_team(actor)!=0 or not bool(actor.get_meta("eligible")) or bool(actor.get_meta("changing")): continue
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
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode==KEY_ESCAPE:
			paused=not paused
			charge=0
		if event.keycode==KEY_F1: debug=not debug
		if event.keycode==KEY_C: wide_camera=not wide_camera
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
				if strike(direction.normalized(),17,true): passes+=1

func pass_target(actor: CharacterBody3D, direction: Vector3) -> CharacterBody3D:
	var best: CharacterBody3D
	var best_score := -INF
	for other in skaters:
		if other==actor or body_team(other)!=body_team(actor) or not bool(other.get_meta("eligible")) or bool(other.get_meta("changing")): continue
		var offset := other.position-actor.position
		var score_ := direction.dot(offset.normalized())*20-offset.length()*0.15
		if score_>best_score: best_score=score_;best=other
	return best

func strike(direction: Vector3, speed: float, is_pass: bool = false) -> bool:
	if match_state.phase!=MatchState.Phase.PLAY or cooldown>0 or player.position.distance_to(puck.position)>1.8: return false
	release_puck(player,direction,speed)
	if not is_pass:
		shots+=1
		roster(player).shots+=1
	return true

func release_puck(actor: CharacterBody3D, direction: Vector3, speed: float) -> void:
	direction.y=0
	puck.linear_velocity=direction.normalized()*speed+actor.velocity*0.2
	carrier=null
	pickup_owner=false
	cooldown=0.42
	actor.get_child(1).shot_follow=1.0
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
	if body is CharacterBody3D and body in goalkeepers and goalie_contact_timer<=0:
		goalie_contact_timer=0.35
		saves+=1
		var end_ := signf(body.position.z)
		var side := 1.0 if puck.position.x>=body.position.x else -1.0
		var speed := clampf(last_puck_velocity.length()*0.32,2,10)
		puck.linear_velocity=Vector3(side*0.7,0,-end_*0.8).normalized()*speed
		cooldown=0.2
		carrier=null
		beep(115)
	elif puck.linear_velocity.length()>8:
		beep(300)

func _physics_process(delta: float) -> void:
	if skaters.is_empty(): return
	puck.freeze=paused or match_state.phase!=MatchState.Phase.PLAY
	if paused:
		status.text="PAUSED  •  Escape to resume"
		return
	elapsed+=delta
	cooldown=maxf(0,cooldown-delta)
	action_cooldown=maxf(0,action_cooldown-delta)
	goalie_contact_timer=maxf(0,goalie_contact_timer-delta)
	var old_phase := match_state.phase
	match_state.advance(delta)
	if match_state.period!=known_period:
		known_period=match_state.period
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
		var horizontal:=Vector3(puck.linear_velocity.x,0,puck.linear_velocity.z).move_toward(Vector3.ZERO,0.35*delta)
		puck.linear_velocity.x=horizontal.x
		puck.linear_velocity.z=horizontal.z
		for end_ in [-1.0,1.0]:
			if Skating.goal_crossing_end(previous_puck,puck.position,end_):
				var scoring_team:=0 if attack_direction(0)==end_ else 1
				match_state.goal(scoring_team)
				beep(550)
				carrier=null
				break
		previous_puck=puck.position
		if puck.position.y< -2 or absf(puck.position.x)>18 or absf(puck.position.z)>33:
			match_state.phase=MatchState.Phase.STOPPAGE
			match_state.phase_timer=1.5
			match_state.event="Puck out of play"
	else:
		for actor in skaters: actor.velocity=Vector3.ZERO
	last_puck_velocity=puck.linear_velocity
	goals=match_state.score[0]
	away_goals=match_state.score[1]
	update_camera(delta)
	update_match_hud()

func control_player(delta: float) -> void:
	if not bool(player.get_meta("eligible")): switch_player()
	var intent:=Vector3(float(Input.is_physical_key_pressed(KEY_D))-float(Input.is_physical_key_pressed(KEY_A)),0,float(Input.is_physical_key_pressed(KEY_S))-float(Input.is_physical_key_pressed(KEY_W)))
	var m=Plane(Vector3.UP,0).intersects_ray(camera.project_ray_origin(get_viewport().get_mouse_position()),camera.project_ray_normal(get_viewport().get_mouse_position()))
	if m!=null:
		var d:Vector3=m-player.position
		d.y=0
		if d.length()>0.3: aim=d.normalized()
	if bool(player.get_meta("changing")): return
	velocity=Skating.step(player.velocity,intent,float(roster(player).speed)*lerpf(0.65,1,float(roster(player).stamina)),Input.is_physical_key_pressed(KEY_SHIFT),delta)
	if Input.is_physical_key_pressed(KEY_CTRL): velocity=velocity.move_toward(Vector3.ZERO,22*delta)
	player.velocity=velocity
	player.move_and_slide()
	var visual:=player.get_child(1)
	visual.rotation.y=rotate_toward(visual.rotation.y,atan2(-aim.x,-aim.z),6*delta)
	visual.animate(player.velocity.length(),delta,0,intent.length_squared()>0.01,Input.is_physical_key_pressed(KEY_CTRL))
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT): charge=minf(1,charge+delta*1.3)

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
		if not bool(actor.get_meta("eligible")) or bool(actor.get_meta("changing")): continue
		var team:=body_team(actor)
		if nearest[team]==null or actor.position.distance_squared_to(puck.position)<nearest[team].position.distance_squared_to(puck.position):
			nearest[team]=actor
	for actor in skaters:
		if not bool(actor.get_meta("eligible")): continue
		if actor==player and not bool(actor.get_meta("changing")): continue
		var team:=body_team(actor)
		var attack:=attack_direction(team)
		var slot:=int(actor.get_meta("slot"))
		var target:=Vector3.ZERO
		var changing:=bool(actor.get_meta("changing"))
		if changing:
			target=Vector3(-13.7,0,(slot-1)*1.6+(team*8-4))
			if actor.position.distance_to(target)<0.9:
				change_identity(actor,int(actor.get_meta("pending_id")))
				if actor==player: switch_player()
		elif actor==carrier:
			target=Vector3(clampf(actor.position.x*0.6,-5,5),0,attack*22)
			var distance_to_goal:=actor.position.distance_to(Vector3(0,0,attack*25))
			var timer:=float(actor.get_meta("decision"))-delta
			if timer<=0 and cooldown<=0:
				actor.set_meta("decision",0.4)
				var pressure:=closest_opponent_distance(actor)
				if distance_to_goal<16 and distance_to_goal>3:
					var goalie:=goalkeeper_at_end(attack)
					var target_x:float= -0.65 if goalie.position.x>=0 else 0.65
					var shot_dir:Vector3=Vector3(target_x,0.1,attack*25)-puck.position
					release_puck(actor,shot_dir,29)
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
				target=Vector3(clampf(puck.position.x*0.25+x_slots[slot],-12,12),0,clampf(puck.position.z+attack*z_offset[slot],-23,23))
			else:
				var own_goal:float= -attack*25
				var defended_z:float=lerpf(puck.position.z,own_goal,0.35 if slot>=3 else 0.1)
				target=Vector3(clampf(puck.position.x*0.3+x_slots[slot],-11,11),0,clampf(defended_z,-23,23))
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
		if actor==carrier: face=(Vector3(0,0,attack*25)-actor.position).normalized()
		visual.rotation.y=rotate_toward(visual.rotation.y,atan2(-face.x,-face.z),4.8*delta)
		visual.animate(actor.velocity.length(),delta,0,intent.length_squared()>0.01)
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
		if not bool(carrier.get_meta("eligible")) or carrier.position.distance_to(puck.position)>1.9 or cooldown>0:
			carrier=null
	if carrier==null and cooldown<=0:
		var best:=1.15
		for actor in skaters:
			if not bool(actor.get_meta("eligible")) or bool(actor.get_meta("changing")): continue
			var distance_:=actor.position.distance_to(Vector3(puck.position.x,0,puck.position.z))
			if distance_<best and (puck.linear_velocity-actor.velocity).length()<17:
				best=distance_
				carrier=actor
	if carrier!=null:
		var visual:=carrier.get_child(1)
		var target:Vector3=carrier.position-visual.global_basis.z*1.02+visual.global_basis.x*0.20
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
			var goal_center:=Vector3(0,0,end_*25)
			var sight:=Vector3(puck.position.x,0,puck.position.z)-goal_center
			var depth:=clampf(sight.length()*0.065,0.35,1.6)
			var incoming:=puck.linear_velocity.z*end_>3
			var predicted:=Vector3(puck.position.x,0,puck.position.z)
			if incoming: predicted+=Vector3(puck.linear_velocity.x,0,puck.linear_velocity.z)*0.10
			var ray:Vector3=(predicted-goal_center).normalized()
			goalie_targets[i]=goal_center+ray*depth
			goalie_targets[i].x=clampf(goalie_targets[i].x,-0.78,0.78)
			goalie_targets[i].z=clampf(goalie_targets[i].z,23.4,24.65) if end_>0 else clampf(goalie_targets[i].z,-24.65,-23.4)
	for i in range(2):
		var keeper:=goalkeepers[i]
		var visual:=keeper.get_child(1)
		var end_:=signf(keeper.position.z)
		var threat:=puck.linear_velocity.z*end_>3 and absf(puck.position.z-keeper.position.z)<11
		visual.butterfly=move_toward(visual.butterfly,1.0 if threat else 0.0,delta*(6 if threat else 2))
		var shape:BoxShape3D=keeper.get_child(0).shape
		shape.size=Vector3(lerpf(1,1.35,visual.butterfly),lerpf(1.3,0.75,visual.butterfly),0.45)
		keeper.get_child(0).position.y=shape.size.y/2+0.01
		keeper.velocity=(goalie_targets[i]-keeper.position).limit_length(1)*3.8
		keeper.move_and_slide()
		var facing:=puck.position-keeper.position
		visual.rotation.y=rotate_toward(visual.rotation.y,atan2(-facing.x,-facing.z)-keeper.rotation.y,delta*4)
		visual.animate(keeper.velocity.length(),delta,0,false)

func update_camera(delta: float) -> void:
	# No lateral offset, yaw or roll: rink markings remain horizontally aligned.
	var focus:=Vector3(puck.position.x*0.55,0,clampf(puck.position.z,-20,20))
	if wide_camera: focus=Vector3.ZERO
	camera_target=camera_target.lerp(focus,1-exp(-delta*3.5))
	var offset:=Vector3(0,51,44) if wide_camera else Vector3(0,17,22)*zoom
	camera.position=camera.position.lerp(camera_target+offset,1-exp(-delta*5))
	camera.position.x=camera_target.x
	camera.look_at(camera_target+Vector3(0,0.4,-3),Vector3.UP)
	camera.rotation.z=0
	selection.position=player.position+Vector3(0,0.025,0)
	selection.visible=match_state.phase!=MatchState.Phase.FINAL

func update_match_hud() -> void:
	var strength:="%d ON %d"%[match_state.count(0),match_state.count(1)]
	hud.text="TOR  %02d    —    %02d  MTL     |     %s    %s\nHAWKEY    •    EXHIBITION    •    %s"%[match_state.score[0],match_state.score[1],str(match_state.period)+"st" if match_state.period==1 else str(match_state.period)+("nd" if match_state.period==2 else "rd"),match_state.clock_text(),strength]
	status.text=match_state.event if match_state.phase!=MatchState.Phase.PLAY else ("TORONTO POSSESSION" if carrier!=null and body_team(carrier)==0 else ("MONTREAL POSSESSION" if carrier!=null else "LOOSE PUCK"))
	var penalty_text:=match_state.penalty_text()
	penalties_label.text="PENALTIES\n"+(penalty_text if not penalty_text.is_empty() else "None  •  Even strength")
	var line_text:="TORONTO  •  LINE %d   /   D PAIR %d"%[active_lines[0]+1,defense_pairs[0]+1]
	for actor in skaters:
		if body_team(actor)==0 and int(actor.get_meta("slot"))<3:
			line_text+="\n#%d  %s    %d%%%s"%[roster(actor).number,roster(actor).name,float(roster(actor).stamina)*100,"  → BENCH" if bool(actor.get_meta("changing")) else ""]
	team_panel.text=line_text
	power.visible=charge>0
	power.value=charge
	if debug: status.text+="  |  FPS %d  •  %d skaters  •  puck %.1f m/s"%[Engine.get_frames_per_second(),skaters.size(),puck.linear_velocity.length()]

func capture_preview() -> void:
	await get_tree().create_timer(capture_time).timeout
	for frame in range(600):
		if match_state.phase==MatchState.Phase.PLAY: break
		await get_tree().physics_frame
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
		var target:=Vector3(-11 if i==0 else 11,0,clampf(puck.position.z+(-9 if i==0 else 9),-24,24))
		var move:Vector3=(target-official.position).limit_length(1)*4
		official.position+=move*delta
		if move.length()>0.2:
			official.rotation.y=rotate_toward(official.rotation.y,atan2(-move.x,-move.z),delta*4)
		official.animate(move.length(),delta,0,move.length()>0.2)
