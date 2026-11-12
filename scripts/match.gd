extends "res://scripts/lab.gd"
const TeamTactics = preload("res://scripts/team_tactics.gd")
const MatchState = preload("res://scripts/match_state.gd")
const ControllerInput = preload("res://scripts/controller_input.gd")
const PuckPhysics = preload("res://scripts/puck.gd")
const BroadcastHud = preload("res://scripts/broadcast_hud.gd")
const GoalCelebration = preload("res://scripts/goal_celebration.gd")
const Benches = preload("res://scripts/arena_benches.gd")
const GoalReplay = preload("res://scripts/goal_replay.gd")
const GameStats = preload("res://scripts/game_stats.gd")
const ControlSlots = preload("res://scripts/control_slots.gd")
const SkaterAI = preload("res://scripts/skater_ai.gd")
const Rules = preload("res://scripts/rules_offside_icing.gd")
## The local human's owner id in the seat model (a network lobby adds others).
const LOCAL_HUMAN := "local:1"
const CAMERA_NAMES := ["DYNAMIC", "OVERHEAD", "BROADCAST", "FULL RINK"]
## Bench gate (changing skaters head here) just inside the west side boards.
const BENCH_X := -(Arena.HALF_WIDTH - 0.75)
## How far behind the board face a hopping skater lands on the bench floor.
const HOP_BENCH_DEPTH := 0.85
## Longest the tired player waits on the bench floor for a teammate to get up
## (hop 3) before the fresh player goes out anyway.
const HOP_WAIT_MAX := 1.6
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
## Per-period team stats for the intermission / final screens (game_stats.gd).
var game_stats := GameStats.new()
## PLAY NOW seats: who (CPU or human) controls each position (control_slots.gd).
var slots := ControlSlots.new()
## Play Now setup (title screen): the local human's team, control style
## (team / position), position for position-lock, and CPU difficulty.
static var play_team := 0
static var play_style := ControlSlots.STYLE_TEAM
static var play_position := 0
static var play_difficulty := SkaterAI.DEFAULT_DIFFICULTY
static var play_spectate := false
## Offside and icing (rules_offside_icing.gd). Off with --no-rules or by
## clearing this before the match scene loads; lab/practice never use them.
static var rules_on := true
## Share of own-half dumps a CPU still makes with icing on (the rest carry
## the puck to the red line first).
const ICE_IT_ANYWAY := 0.2
var rules := Rules.new()
var ai_rng := RandomNumberGenerator.new()
var passes_by_team := [0,0]
## The teammate a CPU pass is meant for: he skates to meet it (skater_ai.gd
## intercept_point) and can take a firmer pass than a loose puck.
var pass_receiver: CharacterBody3D
var pass_timer := 0.0
## How often CPU carriers chose each option (tests / tuning).
var ai_log := {}
## The glass pane the last hit along the boards rattled (arena.gd rattle_glass()).
var last_rattle: MeshInstance3D
## Goal light, arena light flash and jumbotron GOAL (scripts/goal_celebration.gd).
var celebration: Node3D
## Instant replay after goals (scripts/goal_replay.gd).
var replay: Node
## Phase at the end of the last live tick (a PLAY -> STOPPAGE change is a whistle).
var replay_phase := -1
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
## Set by setup_faceoff(): the next camera update cuts (no blend) to the
## close faceoff framing.
var faceoff_cut := false
## How the close faceoff framing sits relative to the dot, per camera mode
## (Dynamic and Broadcast; Overhead and Full rink keep their wide views).
const FACEOFF_CAM_DYNAMIC := Vector3(2.2,5.2,7.6)
const FACEOFF_CAM_BROADCAST := Vector3(8.5,4.2,0)
## The drop: the linesman stands this far off the dot (across the rink, on the
## side away from the Broadcast camera) holding the puck out over it, and
## throws it down at DROP_SPEED; the draw is decided when it lands.
const LINESMAN_OFFSET := 0.9
const DROP_SPEED := 1.6
## Winning draw: the puck comes back off the winner's blade at this speed, this
## far (radians) round from straight back toward his forehand side.
const DRAW_BACK_SPEED := 6.0
const DRAW_BACK_ANGLE := 0.70
## The official holding the puck at the current faceoff (null in play).
var linesman: Node3D
## Seconds since the puck left the linesman's hand (-1: no drop under way),
## its vertical speed while falling, and whether it has landed.
var drop_timer := -1.0
var drop_velocity := 0.0
var draw_landed := false
## The centres taking the current draw, and the winner once it lands.
var draw_centres: Array = []
var faceoff_winner: CharacterBody3D
## Faceoffs won per team (for the stats screens).
var faceoff_wins := [0,0]
var faceoff_rng := RandomNumberGenerator.new()
## 1 at the faceoff framing, easing to 0 as the camera glides back to play.
var faceoff_cam_ease := 0.0
## User timing on the draw (EA-style): shoot or pass pressed while the puck
## falls tips the odds toward the user's centre, best just before it lands.
## draw_press is drop_timer at the press; DRAW_JUMPED: pressed in the last
## DRAW_JUMP_WINDOW s before the linesman let go; DRAW_NO_PRESS: no press.
const DRAW_NO_PRESS := -2.0
const DRAW_JUMPED := -1.0
const DRAW_JUMP_WINDOW := 0.6
const DRAW_TIMING_BONUS := 0.24
const DRAW_JUMP_PENALTY := 0.12
var draw_press := DRAW_NO_PRESS
## After the drop the linesman backs out of the circle facing the dot,
## skating backward with C-cuts (no turn) for LINESMAN_BACK_TIME s, speeding up to
## LINESMAN_BACK_SPEED, then turns and skates to his line as usual.
const LINESMAN_BACK_TIME := 1.1
const LINESMAN_BACK_SPEED := 2.6
var backing_official: Node3D
var backing_time := -1.0
var backing_dir := Vector3.ZERO
## Grade of the user's last draw ("PERFECT", "GOOD", "EARLY", "JUMPED" or "").
var draw_timing := ""
## Faceoff violations: just before the drop the linesman may wave a centre out
## (VIOLATION_CHANCE per draw, or VIOLATION_JUMP_CHANCE when the user jumped
## it); the centre skates out to a winger's spot and that winger (the better
## faceoff man of the two) comes in to take the draw. The faceoff phase (and
## so the clock) is held VIOLATION_TIME s: the wave, the swap, the set.
const VIOLATION_CHANCE := 0.06
const VIOLATION_JUMP_CHANCE := 0.6
const VIOLATION_WAVE := 0.55
const VIOLATION_SWAP := 1.35
const VIOLATION_TIME := 2.4
var violation_rng := RandomNumberGenerator.new()
var violation_checked := false
## Seconds since the wave-out (-1: no violation at this faceoff).
var violation_timer := -1.0
var violator: CharacterBody3D
var violation_sub: CharacterBody3D
var violation_from := Vector3.ZERO
var violation_to := Vector3.ZERO
## Faceoff violations per team (match totals).
var faceoff_violations := [0,0]
## Violations per team on the faceoff being set up now: a team's second one
## costs a minor (delay of game, rule 76.4) and the faceoff is set up again.
## Once a swap has set, the linesman checks again on the new last tick (up to
## VIOLATION_MAX_CHECKS times a faceoff).
var draw_violations := [0,0]
var violation_checks := 0
const VIOLATION_MAX_CHECKS := 3
const DELAY_OF_GAME := "Delay of game"
## The draw-timing hint shows at the user's first FACEOFF_HINT_COUNT faceoffs.
const FACEOFF_HINT_COUNT := 3
var faceoff_hints_shown := 0

func _init() -> void:
	arena_title = "HAWKEY ARENA"

func _ready() -> void:
	faceoff_rng.seed = 20261027
	violation_rng.seed = 20261030
	super._ready()
	celebration=GoalCelebration.new()
	add_child(celebration)
	rules.enabled=rules_on and not "--no-rules" in OS.get_cmdline_user_args()
	rules.blue_line=Arena.BLUE_LINE
	rules.goal_line=Arena.GOAL_LINE
	rules.end_dot_z=Arena.END_DOT_Z
	rules.neutral_dot_z=Arena.NEUTRAL_DOT_Z
	rules.dot_x=Arena.DOT_X
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
			rosters[team].append({"name":names[(i+team*7)%18],"number":numbers[i],"stamina":1.0,"speed":88-i%5*3,"faceoff":44+(i*29+team*17)%45,"goals":0,"shots":0})
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
	setup_seats()
	player = seat_actor()
	teammate = skaters[1] if player!=skaters[1] else skaters[0]
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
	replay=GoalReplay.new()
	replay.name="GoalReplay"
	add_child(replay)
	replay.camera=camera
	replay.puck=puck
	replay.ice_marks=ice_marks
	replay.track(skaters.map(func(a): return a.get_child(1))+goalkeepers.map(func(a): return a.get_child(1))+referee_nodes)
	setup_faceoff()
	camera.position = Vector3(0,20,24)
	camera.look_at(Vector3.ZERO)
	if "--capture" in OS.get_cmdline_user_args():
		# Normal live match, no staged image substitution.
		match_state.phase_timer = 0.3
		# --faceoff holds the lineup (--faceoff-end: at an end-zone dot).
		# --faceoff-drop / --faceoff-draw: drop it and capture the puck falling
		# from the linesman's hand / the winner's sweep.
		if Array(OS.get_cmdline_user_args()).any(func(a): return str(a).begins_with("--faceoff")):
			match_state.phase_timer = 999.0
			if "--faceoff-end" in OS.get_cmdline_user_args():
				next_faceoff = Vector3(Arena.DOT_X,0,-Arena.END_DOT_Z)
				setup_faceoff()
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

## Horizontal direction from an actor to the centre of the net its team attacks.
func net_facing(actor: CharacterBody3D) -> Vector3:
	var net_:=Vector3(0,0,attack_direction(body_team(actor))*Arena.GOAL_LINE)
	var d:=net_-actor.position
	d.y=0
	return d.normalized() if d.length()>0.05 else Vector3(0,0,attack_direction(body_team(actor)))

## Which way a skater's body faces: the puck carrier is tethered to the net
## his team attacks; every other skater (defending or supporting) faces the puck.
func body_facing(actor: CharacterBody3D) -> Vector3:
	if actor==carrier: return net_facing(actor)
	var d:=puck.position-actor.position
	d.y=0
	return d.normalized() if d.length()>0.3 else net_facing(actor)

## Shots go at the net the player faces. Aim (mouse / left stick) picks a spot
## on the goal mouth: pointing left or right of the net moves the target toward
## that post; aiming well away from the net still shoots on goal.
func shot_direction() -> Vector3:
	var to_net:=net_facing(player)
	var net_:=Vector3(0,0,attack_direction(body_team(player))*Arena.GOAL_LINE)
	var across:=Vector3(-to_net.z,0,to_net.x)
	var side:=clampf(aim.dot(across)*2.0,-1.0,1.0)
	# Goal mouth runs along x: move the target up to 0.7 m toward the aimed post.
	var target:=net_+Vector3(signf(across.x) if absf(across.x)>0.05 else 1.0,0,0)*side*0.70
	var d:=target-puck.position
	d.y=0
	return d.normalized() if d.length()>0.05 else to_net

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
	apply_play_now(hud_node.play_options)
	in_menu = false
	hud_node.show_title(false)
	# The first faceoff's draw hint was held back while the menu was up.
	if match_state.phase==MatchState.Phase.FACEOFF: hud_node.show_draw_hint(faceoff_hints_shown<=FACEOFF_HINT_COUNT)
	camera_side = 0.0
	hud_node.show_banner("TORONTO  vs  MONTREAL", "1ST PERIOD", hud_node.team_colors[0], 1.6)

func setup_faceoff() -> void:
	for actor in skaters: actor.get_child(1).stop_mocap()
	carrier = null
	rules.reset()
	pickup_owner = false
	charge = 0
	cooldown = 0.3
	puck.position = next_faceoff+Vector3(0,0.017,0)
	puck.linear_velocity = Vector3.ZERO
	puck.angular_velocity = Vector3.ZERO
	previous_puck = puck.position
	# Centres square up just off the dot (blades meet over it), wingers on
	# the wings, D back at the points.
	var spots := [Vector3(0,0,0.95),Vector3(-6,0,1),Vector3(6,0,1),Vector3(-4,0,8),Vector3(4,0,8)]
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
		# Players arrive set in their faceoff stance (the camera cuts to them).
		var visual = actor.get_child(1)
		visual.faceoff_role = 0 if slot==0 else (1 if slot<3 else 2)
		visual.faceoff = 1.0
		visual.faceoff_target = 1.0
	faceoff_cut = true
	draw_centres = []
	for actor in skaters:
		if int(actor.get_meta("slot"))==0: draw_centres.append(actor)
		actor.get_child(1).draw_time = -1.0
		actor.get_child(1).draw_result = 0
	drop_timer = -1.0
	draw_landed = false
	faceoff_winner = null
	draw_press = DRAW_NO_PRESS
	draw_timing = ""
	backing_official = null
	backing_time = -1.0
	violation_checked = false
	end_violation_wave()
	violation_timer = -1.0
	violator = null
	violation_sub = null
	draw_violations = [0,0]
	violation_checks = 0
	faceoff_hints_shown += 1
	if hud_node!=null: hud_node.show_draw_hint(faceoff_hints_shown<=FACEOFF_HINT_COUNT)
	place_linesman()
	sync_strength()
	if not bool(player.get_meta("eligible",true)): switch_player()

## An official skates in to the dot and holds the puck out over it, on the
## side that keeps him out of the camera's line to the centres (the far side
## for Broadcast, away from the Dynamic camera's shoulder offset); the other
## stays by the boards.
func place_linesman() -> void:
	if referee_nodes.is_empty(): return
	var across := linesman_side()
	var dot := Vector3(next_faceoff.x,0,next_faceoff.z)
	var spot := dot+Vector3(across*LINESMAN_OFFSET,0,0)
	linesman = referee_nodes[0] if across<0 else referee_nodes[1]
	if is_instance_valid(linesman):
		linesman.position = spot
		var to_dot := dot-spot
		linesman.rotation.y = atan2(-to_dot.x,-to_dot.z)
		linesman.drop_hand_target = 1.0
		linesman.drop_hand = 1.0
	for i in range(referee_nodes.size()):
		var official := referee_nodes[i]
		if official==linesman: continue
		official.drop_hand_target = 0.0
		official.drop_hand = 0.0
		# The other official keeps to his boards, clear of the draw.
		if Vector2(official.position.x-dot.x,official.position.z-dot.z).length()<3.0:
			official.position = Vector3(-(Arena.HALF_WIDTH-2.0) if i==0 else Arena.HALF_WIDTH-2.0,0,clampf(dot.z+(-9 if i==0 else 9),-(Arena.GOAL_LINE-1.0),Arena.GOAL_LINE-1.0))

## Which side of the dot (x sign) the linesman stands for this camera.
func linesman_side() -> float:
	var side := -signf(attack_direction(0))
	if side==0: side=1.0
	var across := -side if camera_mode==2 else side
	if absf(next_faceoff.x+across*LINESMAN_OFFSET)>Arena.HALF_WIDTH-1.2: across = -across
	return across

## Faceoff set: officials hold their pose, the puck sits in the linesman's hand.
func update_linesman(delta: float) -> void:
	# The camera changed during the lineup: he steps round to the other side.
	if linesman!=null and signf(linesman.position.x-next_faceoff.x)!=linesman_side():
		linesman.drop_hand_target = 0.0
		linesman.position.x = clampf(linesman.position.x,-(Arena.HALF_WIDTH-2.0),Arena.HALF_WIDTH-2.0)
		place_linesman()
	for official in referee_nodes:
		official.back_skate_target = 0.0
		official.animate(0,delta,0,false)
	if linesman!=null:
		# Keep his hand right over the dot: shuffle him by whatever it is off.
		var off: Vector3 = linesman.drop_hand_world()-next_faceoff
		off.y = 0
		linesman.position -= off
		puck.position = linesman.drop_hand_world()
		previous_puck = puck.position

## The linesman lets go: the puck falls to the dot, the centres' blades poise.
func start_drop() -> void:
	drop_timer = 0.0
	drop_velocity = -DROP_SPEED
	draw_landed = false
	puck.position = Vector3(next_faceoff.x,puck.position.y,next_faceoff.z)
	previous_puck = puck.position
	if linesman!=null: linesman.drop_hand_target = 0.0
	for actor in draw_centres:
		actor.get_child(1).draw_time = 0.0
		actor.get_child(1).draw_result = 0

## Puck in the air: falls under gravity (kinematic, so it never clips a blade
## on the way down); on landing the draw is decided and the winner's blade
## pulls it back toward his forehand side.
func step_drop(delta: float) -> void:
	drop_timer += delta
	if draw_landed:
		# Centres come out of their stance once the sweep has played.
		if drop_timer > 0.0 and faceoff_winner!=null and drop_timer-float(faceoff_winner.get_child(1).draw_result_time) > 0.14:
			for actor in draw_centres: actor.get_child(1).faceoff_target = 0.0
			drop_timer = -1.0
			linesman = null
		return
	# Something else moved the puck (a test, a reset): no draw this time.
	if Vector2(puck.position.x-next_faceoff.x,puck.position.z-next_faceoff.z).length()>0.25:
		cancel_drop()
		return
	drop_velocity -= 9.8*delta
	puck.position.y += drop_velocity*delta
	previous_puck = puck.position
	if puck.position.y > 0.017: return
	puck.position.y = 0.017
	draw_landed = true
	start_linesman_backing()
	faceoff_winner = pick_faceoff_winner()
	var winning_team := body_team(faceoff_winner)
	faceoff_wins[winning_team] += 1
	for actor in draw_centres:
		var v = actor.get_child(1)
		v.draw_result = 1 if actor==faceoff_winner else -1
		v.draw_result_time = v.draw_time
	# FACEOFF WON / LOST cue for the user's team, with the timing grade.
	if hud_node!=null:
		var won := winning_team==user_team()
		var sub := (draw_timing+" TIMING") if not draw_timing.is_empty() else ""
		hud_node.show_faceoff_cue(won, sub, hud_node.team_colors[winning_team])
	var v = faceoff_winner.get_child(1)
	var origin: Vector3 = v.rig.to_global(Vector3.ZERO)
	var back: Vector3 = v.rig.to_global(Vector3(-sin(DRAW_BACK_ANGLE),0,-cos(DRAW_BACK_ANGLE)))-origin
	back.y = 0
	puck.freeze = false
	puck.linear_velocity = back.normalized()*DRAW_BACK_SPEED
	puck.angular_velocity = Vector3.ZERO
	# Nobody (the winner included) picks it up before it is clear of the centres.
	cooldown = 0.35

## The puck is down: the linesman backs straight out from the dot, still
## facing it (and clear of the centres, on his own side of the dot).
func start_linesman_backing() -> void:
	if linesman==null or not is_instance_valid(linesman): return
	backing_official = linesman
	backing_time = 0.0
	backing_dir = Vector3(linesman.position.x-next_faceoff.x,0,linesman.position.z-next_faceoff.z)
	backing_dir = backing_dir.normalized() if backing_dir.length()>0.05 else Vector3(signf(linesman.position.x-next_faceoff.x+0.001),0,0)

## Abandons a drop under way: everyone breaks out, the puck is left to physics.
func cancel_drop() -> void:
	drop_timer = -1.0
	draw_landed = false
	for actor in draw_centres:
		actor.get_child(1).faceoff_target = 0.0
		actor.get_child(1).draw_time = -1.0
	if linesman!=null: linesman.drop_hand_target = 0.0
	linesman = null
	puck.freeze = false

## Who wins the draw: the centres' faceoff ratings and stamina weight the odds.
func pick_faceoff_winner() -> CharacterBody3D:
	if draw_centres.size()<2: return draw_centres[0] if not draw_centres.is_empty() else skaters[0]
	var a: CharacterBody3D = draw_centres[0]
	var b: CharacterBody3D = draw_centres[1]
	var ra := float(roster(a).get("faceoff",50))*lerpf(0.8,1.0,float(roster(a).stamina))
	var rb := float(roster(b).get("faceoff",50))*lerpf(0.8,1.0,float(roster(b).stamina))
	var p_a := clampf(0.5+(ra-rb)/120.0,0.2,0.8)
	# The user's timing shifts the odds toward (or away from) his centre.
	var quality := draw_timing_quality(draw_press, drop_timer)
	draw_timing = draw_timing_grade(quality)
	var shift := quality*DRAW_TIMING_BONUS if quality>=0.0 else -DRAW_JUMP_PENALTY
	p_a = clampf(p_a+(shift if body_team(a)==user_team() else -shift),0.1,0.9)
	return a if faceoff_rng.randf()<p_a else b

## The team the user controls.
func user_team() -> int:
	var team := slots.team_of(LOCAL_HUMAN)
	return team if team>=0 else play_team

## Play Now: the local human takes a seat (unless spectating: all 12 CPU).
## Command line for captures/tests: --spectate, --team=0|1,
## --style=team|position, --position=C|LW|RW|LD|RD, --difficulty=PRO etc.
func setup_seats() -> void:
	ai_rng.seed = 20261107
	for arg in OS.get_cmdline_user_args():
		var a := str(arg)
		if a=="--spectate": play_spectate=true
		elif a.begins_with("--team="): play_team=clampi(int(a.substr(7)),0,1)
		elif a.begins_with("--style="): play_style=a.substr(8)
		elif a.begins_with("--position="): play_position=maxi(0,ControlSlots.POSITIONS.find(a.substr(11).to_upper()))
		elif a.begins_with("--difficulty="): play_difficulty=a.substr(13).to_upper()
	slots = ControlSlots.new()
	if play_spectate: return
	if play_style==ControlSlots.STYLE_POSITION:
		slots.claim(LOCAL_HUMAN,play_team,clampi(play_position,0,4),ControlSlots.STYLE_POSITION)
	else:
		slots.join(LOCAL_HUMAN,play_team,ControlSlots.STYLE_TEAM)

## Title screen PLAY NOW: take the chosen seat (team, whole-team or one
## position) and set the CPU skill.
func apply_play_now(options: Dictionary) -> void:
	play_team=int(options.get("team",0))
	play_style=str(options.get("style",ControlSlots.STYLE_TEAM))
	play_position=int(options.get("position",0))
	play_difficulty=str(options.get("difficulty",SkaterAI.DEFAULT_DIFFICULTY))
	play_spectate=false
	slots=ControlSlots.new()
	if play_style==ControlSlots.STYLE_POSITION:
		slots.claim(LOCAL_HUMAN,play_team,clampi(play_position,0,4),ControlSlots.STYLE_POSITION)
	else:
		slots.join(LOCAL_HUMAN,play_team,ControlSlots.STYLE_TEAM)
	player=seat_actor()
	player_visual=player.get_child(1)

## Is this skater driven by the local human right now?
func human_controls(actor: CharacterBody3D) -> bool:
	return actor==player and slots.humans.has(LOCAL_HUMAN)

## The skater on the ice in the local human's seat (or any skater to follow
## with the camera when spectating).
func seat_actor() -> CharacterBody3D:
	var seat := slots.seat_of(LOCAL_HUMAN)
	var team := int(seat.get("team",play_team))
	var position_ := int(seat.get("position",0))
	for actor in skaters:
		if body_team(actor)==team and int(actor.get_meta("slot"))==position_: return actor
	return skaters[0]

func ai_skill(_team: int) -> Dictionary:
	return SkaterAI.skill(play_difficulty)

## How well-timed a draw press was: -1 jumped (before the drop), 0 no press,
## else 0.5 (the instant the puck left the hand) rising to 1 at the landing.
static func draw_timing_quality(press: float, land_time: float) -> float:
	if press==DRAW_JUMPED: return -1.0
	if press<0.0 or land_time<=0.0: return 0.0
	return lerpf(0.5,1.0,clampf(press/land_time,0.0,1.0))

static func draw_timing_grade(quality: float) -> String:
	if quality<0.0: return "JUMPED"
	if quality==0.0: return ""
	if quality>=0.85: return "PERFECT"
	if quality>=0.7: return "GOOD"
	return "EARLY"

## Shoot or pass pressed around a faceoff: the user's timing on the draw.
## Only the first press counts; presses long before the drop are ignored.
func register_draw_press() -> void:
	if draw_press!=DRAW_NO_PRESS: return
	if match_state.phase==MatchState.Phase.FACEOFF:
		if match_state.phase_timer<=DRAW_JUMP_WINDOW: draw_press=DRAW_JUMPED
	elif puck_in_air_at_drop():
		draw_press=maxf(drop_timer,0.0)

## Called once per faceoff just before the drop: does the linesman throw a
## centre out? Returns the offending centre or null.
func pick_violator() -> CharacterBody3D:
	if draw_centres.size()<2: return null
	var roll := violation_rng.randf()
	var user_centre: CharacterBody3D = null
	for c in draw_centres:
		if body_team(c)==user_team(): user_centre=c
	if draw_press==DRAW_JUMPED and user_centre!=null and roll<VIOLATION_JUMP_CHANCE:
		return user_centre
	if roll<VIOLATION_CHANCE:
		return draw_centres[violation_rng.randi()%draw_centres.size()]
	return null

## The winger who comes in for a waved-out centre: the better faceoff man of
## the two wingers who are on the ice and not changing.
func violation_replacement(centre: CharacterBody3D) -> CharacterBody3D:
	var best: CharacterBody3D = null
	for actor in skaters:
		if body_team(actor)!=body_team(centre) or not int(actor.get_meta("slot")) in [1,2]: continue
		if not bool(actor.get_meta("eligible",true)) or bool(actor.get_meta("changing",false)) or is_hopping(actor): continue
		if best==null or float(roster(actor).get("faceoff",50))>float(roster(best).get("faceoff",50)): best=actor
	return best

## The linesman waves the centre out: he stands up and skates to the
## winger's spot, the winger comes in; the drop waits (phase held).
func start_violation(centre: CharacterBody3D) -> bool:
	# A team's second violation on the same faceoff: delay of game.
	if draw_violations[body_team(centre)]>=1: return delay_of_game(centre)
	var sub := violation_replacement(centre)
	if sub==null: return false
	draw_violations[body_team(centre)] += 1
	violator = centre
	violation_sub = sub
	violation_from = centre.position
	violation_to = sub.position
	violation_timer = 0.0
	faceoff_violations[body_team(centre)] += 1
	draw_press = DRAW_NO_PRESS
	match_state.phase_timer = VIOLATION_TIME
	match_state.event = "Faceoff violation"
	centre.get_child(1).faceoff_target = 0.0
	sub.get_child(1).faceoff_target = 0.0
	# The user takes over whoever will take the draw.
	if player==centre:
		player = sub
		player_visual = sub.get_child(1)
	if linesman!=null and is_instance_valid(linesman): linesman.wave_out = 0.0
	if hud_node!=null:
		var team := body_team(centre)
		hud_node.show_faceoff_cue(false, "#%s %s WAVED OUT" % [str(roster(centre).number), str(roster(centre).name).to_upper()], hud_node.team_colors[team], 1.6, "FACEOFF VIOLATION")
		hud_node.show_draw_hint(false)
	return true

## Second faceoff violation by the same team on one faceoff: the linesman
## waves him out and he takes a two-minute minor for delay of game (the
## faceoff is set up again after the stoppage, with his team short-handed).
func delay_of_game(centre: CharacterBody3D) -> bool:
	var team := body_team(centre)
	faceoff_violations[team] += 1
	draw_violations[team] += 1
	if linesman!=null and is_instance_valid(linesman): linesman.wave_out = 1.0
	assess_penalty(centre, DELAY_OF_GAME)
	if not match_state.penalized(team,int(centre.get_meta("roster_id"))): return false
	if hud_node!=null:
		hud_node.show_faceoff_cue(false, "#%s %s · 2:00 MINOR" % [str(roster(centre).number), str(roster(centre).name).to_upper()], hud_node.team_colors[team], 2.0, "DELAY OF GAME")
		hud_node.show_draw_hint(false)
	return true

## Violation under way: the linesman's wave, then the two players swap spots
## (skating, turned to their travel), then both set in their new stance.
func step_violation(delta: float) -> void:
	violation_timer += delta
	if linesman!=null and is_instance_valid(linesman):
		linesman.wave_out = move_toward(linesman.wave_out, 1.0 if violation_timer<VIOLATION_WAVE+0.35 else 0.0, delta*4.0)
		linesman.wave_phase += delta*9.0
	var u := clampf((violation_timer-VIOLATION_WAVE*0.6)/VIOLATION_SWAP,0.0,1.0)
	var s := u*u*(3.0-2.0*u)
	for pair in [[violator,violation_from,violation_to],[violation_sub,violation_to,violation_from]]:
		var actor: CharacterBody3D = pair[0]
		if actor==null: continue
		var from: Vector3 = pair[1]
		var to: Vector3 = pair[2]
		var pos := from.lerp(to,s)
		var speed := (pos-actor.position).length()/maxf(delta,0.0001)
		actor.position = pos
		actor.velocity = Vector3.ZERO
		var visual = actor.get_child(1)
		var set_yaw := 0.0 if attack_direction(body_team(actor))<0 else PI
		var travel := to-from
		var target_yaw := atan2(-travel.x,-travel.z) if u>0.0 and u<0.85 else set_yaw
		visual.rotation.y = lerp_angle(visual.rotation.y,target_yaw,1.0-exp(-delta*9.0))
		visual.animate(speed,delta,0,speed>0.5)
	if u>=1.0 and draw_centres.has(violator):
		# Both set: the winger takes the draw in the centre's stance.
		draw_centres[draw_centres.find(violator)] = violation_sub
		violation_sub.get_child(1).faceoff_role = 0
		violator.get_child(1).faceoff_role = 1
		for actor in [violator,violation_sub]:
			actor.get_child(1).faceoff_target = 1.0
		# Set again: the linesman watches the new draw's last tick too.
		violation_checks += 1
		if violation_checks<VIOLATION_MAX_CHECKS: violation_checked = false

## Is this skater being moved by a faceoff violation swap right now?
func violation_moving(actor: CharacterBody3D) -> bool:
	return violation_timer>=0.0 and (actor==violator or actor==violation_sub)

func end_violation_wave() -> void:
	for official in referee_nodes:
		if is_instance_valid(official): official.wave_out = 0.0

## True while the puck is falling from the linesman's hand.
func puck_in_air_at_drop() -> bool:
	return drop_timer>=0.0 and not draw_landed

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

## Line change, bench side: the tired player has stepped down onto the bench;
## the fresh player (a new identity on the same body) goes out over the boards
## from where the bench player who got up stands, and the tired one walks to
## the free seat (arena_benches.gd go_out()).
func hop_out(actor: CharacterBody3D, team: int, target: Vector3, visual_: Node3D) -> void:
	# Fresh legs climb out a little further along the bench.
	var tired_number:String=visual_.number
	# Where he stepped down onto the bench: he walks on from there to the free seat.
	var landing:Vector3=visual_.global_position
	var landing_face:Vector3=-visual_.global_transform.basis.z
	change_identity(actor,int(actor.get_meta("pending_id")))
	var from_:Vector3=visual_.position+Vector3(0,0,-signf(target.z)*0.7)
	# The one who got up goes out from where he stands; the player
	# who came off takes his seat (arena_benches.gd go_out()).
	var out_benches=arena.get_node_or_null("Benches")
	var out_at=out_benches.go_out(team,tired_number,landing,landing_face) if out_benches!=null else null
	if out_at is Vector3:
		from_=actor.to_local(out_at)
		from_.y=visual_.position.y
	# A different player now: he gets up off the bench facing the ice, stick up.
	visual_.rotation.y=-PI*0.5
	visual_.start_hop(from_,Vector3.ZERO,-Arena.HALF_WIDTH-actor.position.x,true)
	actor.set_meta("hop",2)
	if actor==player: switch_player()

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
	var seat := slots.seat_of(LOCAL_HUMAN)
	if not seat.is_empty() and seat.style==ControlSlots.STYLE_POSITION:
		# Position lock: always the skater in that position (back after a penalty).
		var mine := seat_actor()
		if bool(mine.get_meta("eligible")) or not bool(player.get_meta("eligible")):
			player=mine
			player_visual=player.get_child(1)
			velocity=player.velocity
		return
	var best: CharacterBody3D
	var score_ := INF
	for actor in skaters:
		if body_team(actor)!=user_team() or not bool(actor.get_meta("eligible")) or bool(actor.get_meta("changing")) or is_hopping(actor): continue
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
		slots.move(LOCAL_HUMAN,int(player.get_meta("slot")))

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
			KEY_1: request_line(user_team(),0)
			KEY_2: request_line(user_team(),1)
			KEY_3: request_line(user_team(),2)
			KEY_4: request_line(user_team(),3)
			KEY_Q: request_line(user_team(),defense_pairs[user_team()]+1,true)
			KEY_L: auto_lines=not auto_lines
			KEY_E: defensive_action(false)
			KEY_F: defensive_action(true)
	if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_LEFT,MOUSE_BUTTON_RIGHT] and not paused and not in_menu:
		register_draw_press()
	if paused or match_state.phase!=MatchState.Phase.PLAY: return
	if event is InputEventMouseButton:
		if event.button_index==MOUSE_BUTTON_WHEEL_UP and event.pressed: zoom=clampf(zoom-0.08,0.55,1.5)
		if event.button_index==MOUSE_BUTTON_WHEEL_DOWN and event.pressed: zoom=clampf(zoom+0.08,0.55,1.5)
		if event.button_index==MOUSE_BUTTON_LEFT and not event.pressed:
			strike(shot_direction(),lerpf(16,36,charge))
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
		if body_team(other)==body_team(player) or not bool(other.get_meta("eligible")): continue
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
		if body_check:
			land_body_check(player,victim)
		else:
			victim.velocity+=push*1.2
			victim.set_meta("stun",0.08)
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

## Crowd reaction to a save (0 = none): only shots heading at the net, from
## 0 at 14 m/s up to 0.55 for a 32 m/s blast.
static func save_reaction(puck_velocity: Vector3, goalie_z: float) -> float:
	if signf(puck_velocity.z)!=signf(goalie_z): return 0.0
	return clampf((puck_velocity.length()-14.0)/18.0,0.0,1.0)*0.55

func _on_puck_contact(body: Node) -> void:
	var actor:=hit_actor(body)
	if actor is CharacterBody3D and actor in goalkeepers and goalie_contact_timer<=0:
		goalie_contact_timer=0.25
		rules.goalie_touch()
		saves+=1
		if absf(last_puck_velocity.z)>6: team_shots[0 if attack_direction(0)==signf(actor.position.z) else 1]+=1
		# A hard shot stopped: the crowd comes up off its seats (arena_dressing.gd).
		var save_dressing:=arena.get_node_or_null("Dressing")
		var save_roar:=save_reaction(last_puck_velocity,actor.position.z)
		if save_dressing!=null and save_roar>0.05: save_dressing.crowd_react(save_roar,signf(actor.position.z),0.5)
		# Replayed at the next whistle if it was a big one (goal_replay.gd).
		replay.big_save(signf(actor.position.z),save_roar)
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
	else:
		# A skater's body or stick got a piece of it: no icing after that.
		if actor is CharacterBody3D and actor in skaters and actor!=carrier: rules.note_touch(body_team(actor),puck.position)
		if puck.linear_velocity.length()>8: beep(300)

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
	puck.freeze=paused or match_state.phase!=MatchState.Phase.PLAY or puck_in_air_at_drop()
	if paused:
		if not hud_node.pause_panel.visible: set_paused(true)
		return
	if replay.playing():
		# Instant replay: the live match waits; Enter/Space or A skips.
		if Input.is_action_just_pressed("ui_accept"): replay.skip()
		replay.step(delta)
		hud_node.banner.visible=false
		selection.visible=not replay.playing()
		if is_instance_valid(puck_shadow): puck_shadow.position=Vector3(puck.position.x,0.003,puck.position.z)
		return
	elapsed+=delta
	cooldown=maxf(0,cooldown-delta)
	action_cooldown=maxf(0,action_cooldown-delta)
	goalie_contact_timer=maxf(0,goalie_contact_timer-delta)
	var old_phase := match_state.phase
	# Last tick of the lineup: the linesman may throw a centre out first.
	if match_state.phase==MatchState.Phase.FACEOFF and not violation_checked and match_state.phase_timer<=delta:
		violation_checked = true
		var offender := pick_violator()
		if offender!=null: start_violation(offender)
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
		# Puck dropped: wingers and D break out of the stance; the centres
		# stay down for the draw (step_drop()).
		for actor in skaters:
			if not actor in draw_centres: actor.get_child(1).faceoff_target=0.0
		end_violation_wave()
		if hud_node!=null: hud_node.show_draw_hint(false)
		start_drop()
	sync_strength()
	update_roster_stamina(delta)
	if match_state.phase==MatchState.Phase.FACEOFF:
		update_linesman(delta)
		if violation_timer>=0.0: step_violation(delta)
	if match_state.phase==MatchState.Phase.PLAY and drop_timer>=0.0:
		step_drop(delta)
	if match_state.phase==MatchState.Phase.PLAY and puck_in_air_at_drop():
		# Everyone waits for the puck to hit the ice.
		for actor in skaters:
			actor.velocity = Vector3.ZERO
			actor.get_child(1).animate(0,delta,0,false)
		for official in referee_nodes: official.animate(0,delta,0,false)
	elif match_state.phase==MatchState.Phase.PLAY:
		if slots.humans.has(LOCAL_HUMAN): control_player(delta)
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
				# REPLAY wipe and a reverse-angle replay a couple of seconds later.
				replay.goal(end_)
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
		if match_state.phase==MatchState.Phase.PLAY: step_rules()
		if puck.position.y< -2 or absf(puck.position.x)>18 or absf(puck.position.z)>33:
			match_state.phase=MatchState.Phase.STOPPAGE
			match_state.phase_timer=1.5
			match_state.event="Puck out of play"
	else:
		for actor in skaters:
			if violation_moving(actor): continue
			actor.velocity=Vector3.ZERO
			actor.get_child(1).animate(0,delta,0,false)
	last_puck_velocity=puck.linear_velocity
	goals=match_state.score[0]
	away_goals=match_state.score[1]
	update_camera(delta)
	update_match_hud()
	# Whistle shortly after a big save: replay the save during the stoppage.
	if replay_phase==MatchState.Phase.PLAY and match_state.phase==MatchState.Phase.STOPPAGE: replay.whistle()
	replay_phase=match_state.phase
	replay.capture(delta)
	if is_instance_valid(puck_shadow):
		puck_shadow.position=Vector3(puck.position.x,0.003,puck.position.z)
		var shadow_scale:=clampf(1+puck.position.y*0.15,1,1.8)
		puck_shadow.scale=Vector3(shadow_scale,1,shadow_scale)

## Offside / icing: feed the rules one snapshot per tick; on a call the
## linesman's whistle stops play, the banner names it and the next faceoff
## goes to the spot the rules give (rules_offside_icing.gd).
func step_rules() -> void:
	if not rules.enabled: return
	var snapshot: Array = []
	var carrier_index := -1
	for actor in skaters:
		if not bool(actor.get_meta("eligible")) or bool(actor.get_meta("changing")) or is_hopping(actor): continue
		if actor==carrier: carrier_index=snapshot.size()
		snapshot.append({"team":body_team(actor),"pos":actor.position})
	var attack := [attack_direction(0),attack_direction(1)]
	var short := [match_state.count(0)<match_state.count(1),match_state.count(1)<match_state.count(0)]
	var verdict: Dictionary = rules.step({"puck":puck.position,"carrier":carrier_index,"skaters":snapshot,"attack":attack,"shorthanded":short})
	if str(verdict.call)!=Rules.NONE: rule_whistle(str(verdict.call),int(verdict.team),verdict.spot)

func rule_whistle(kind: String, team: int, spot: Vector3) -> void:
	match_state.phase=MatchState.Phase.STOPPAGE
	match_state.phase_timer=2.2
	match_state.event=kind.capitalize()+" — "+("TOR" if team==0 else "MTL")
	next_faceoff=spot
	carrier=null
	puck.linear_velocity=Vector3.ZERO
	if hud_node!=null: hud_node.show_banner(kind,str(hud_node.team_names[team]),hud_node.team_colors[team],2.0)
	beep(880)

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
	# The puck carrier is tethered to the net he attacks (shoot at any moment);
	# without the puck the player faces the puck (body_facing()).
	var to_net:=body_facing(player)
	visual.rotation.y=rotate_toward(visual.rotation.y,atan2(-to_net.x,-to_net.z),8*delta)
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

var ai_opponents: Array = [[],[]]
var ai_coverage: Array = [{},{}]

func update_team_ai(delta: float) -> void:
	refresh_ai_reads()
	pass_timer=maxf(0.0,pass_timer-delta)
	if carrier!=null or pass_timer<=0.0: pass_receiver=null
	# Chaser per team: the nearest skater allowed to chase (TeamTactics.may_chase:
	# D don't chase into the offensive zone).
	var nearest: Array[CharacterBody3D]=[null,null]
	for actor in skaters:
		if not bool(actor.get_meta("eligible")) or bool(actor.get_meta("changing")) or is_hopping(actor): continue
		var team:=body_team(actor)
		if not TeamTactics.may_chase(int(actor.get_meta("slot")),attack_direction(team),puck.position): continue
		if nearest[team]==null or actor.position.distance_squared_to(puck.position)<nearest[team].position.distance_squared_to(puck.position):
			nearest[team]=actor
	for actor in skaters:
		if not bool(actor.get_meta("eligible")): continue
		if human_controls(actor) and not bool(actor.get_meta("changing")) and not is_hopping(actor): continue
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
				# A player on the bench gets up to go out (arena_benches.gd).
				var hop_benches=arena.get_node_or_null("Benches")
				if hop_benches!=null: hop_benches.stand_up(team,actor.position.z)
				actor.collision_layer=0
				set_puck_contacts_enabled(actor,false)
				if carrier==actor: carrier=null
			elif hop==1 and visual_.hop_finished():
				# Nobody up to go out (stand_up() found nobody when he started,
				# or the one who got up sat back down): a player gets up now,
				# quickly, while the tired one waits on the bench floor (hop 3),
				# rather than the fresh player appearing beside him.
				var wait_benches=arena.get_node_or_null("Benches")
				if wait_benches!=null and not wait_benches.has_riser(team) and wait_benches.stand_up(team,visual_.global_position.z,true):
					actor.set_meta("hop",3)
					actor.set_meta("hop_wait",0.0)
				else:
					hop_out(actor,team,target,visual_)
			elif hop==3:
				var wait_:=float(actor.get_meta("hop_wait",0.0))+delta
				actor.set_meta("hop_wait",wait_)
				var wait_benches=arena.get_node_or_null("Benches")
				if wait_benches==null or wait_benches.has_riser(team,true) or not wait_benches.has_riser(team) or wait_>HOP_WAIT_MAX:
					hop_out(actor,team,target,visual_)
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
			# CPU puck carrier (skater_ai.gd): every reaction interval he reads
			# the ice and picks shoot / pass / carry / dump / protect.
			var is_d:=TeamTactics.is_defence(slot)
			var timer:=float(actor.get_meta("decision"))-delta
			var plan:Dictionary=actor.get_meta("plan",{})
			if timer<=0 and cooldown<=0:
				var sk:=ai_skill(team)
				actor.set_meta("decision",float(sk.react)*lerpf(0.8,1.25,ai_rng.randf()))
				if bool(actor.get_meta("one_timer",false)):
					actor.set_meta("one_timer",false)
					plan={"kind":"shoot","target":SkaterAI.net(attack),"receiver":-1,"value":1.0}
					ai_log["one_timer"]=int(ai_log.get("one_timer",0))+1
				else:
					plan=SkaterAI.carrier_decision(ai_context(actor,team,attack,is_d))
				actor.set_meta("plan",plan)
				ai_log[str(plan.kind)]=int(ai_log.get(str(plan.kind),0))+1
				match str(plan.kind):
					"shoot": ai_shoot(actor,attack,is_d)
					"pass": ai_pass(actor,plan)
					"dump":
						# Gain the red line first: a dump from his own half is an icing.
						# Under pressure he still fires it away now and then (ICE_IT_ANYWAY).
						if rules.enabled and puck.position.z*attack<0.4 and ai_rng.randf()>ICE_IT_ANYWAY: plan.kind="carry"
						else: release_puck(actor,SkaterAI.flat(plan.target-puck.position),19,0.08)
			else: actor.set_meta("decision",timer)
			if plan.is_empty() or str(plan.kind) in ["shoot","pass","dump"]:
				target=SkaterAI.carry_target(actor.position,attack,ai_opponents[team])
			else:
				target=plan.target
				# Re-steer every tick around whoever is closing in.
				if str(plan.kind)=="carry": target=SkaterAI.carry_target(actor.position,attack,ai_opponents[team])
		elif actor==pass_receiver:
			# Meet the pass: skate to where it can be taken, don't wait for it.
			var meet_pass:=SkaterAI.intercept_point(puck.position,puck.linear_velocity,actor.position,8.5,1.6)
			target=meet_pass if meet_pass!=Vector3.INF else Vector3(puck.position.x,0,puck.position.z)
		elif nearest[team]==actor and not (pass_receiver!=null and body_team(pass_receiver)==team):
			if actor.get_child(1).has_method("tie_up_weight") and actor.get_child(1).tie_up_weight()>0.0:
				# Faceoff tie-up: drive straight into the man on the puck.
				target=Vector3(puck.position.x,0,puck.position.z)
			elif carrier!=null and body_team(carrier)!=team:
				# Take the middle away: inside-out angle on the carrier.
				target=SkaterAI.pursue_target(carrier.position,carrier.velocity,attack,actor.position)
			else:
				# Loose or passed puck: go to where he can first get to it.
				var meet:=SkaterAI.intercept_point(puck.position,puck.linear_velocity,actor.position,8.5)
				target=meet if meet!=Vector3.INF else Vector3(puck.position.x,0,puck.position.z)+Vector3(puck.linear_velocity.x,0,puck.linear_velocity.z)*0.08
		else:
			# Role-based support positioning (scripts/team_tactics.gd): D stay
			# home, forwards don't go too deep defensively; then read the play
			# (skater_ai.gd): get open for a pass, gap up on a rush, mark a man
			# goal-side in the own zone, jump a passing lane.
			var possession:=carrier!=null and body_team(carrier)==team
			target=TeamTactics.support_target(slot,attack,puck.position,possession)
			var pa:=puck.position.z*attack
			if possession:
				target=SkaterAI.open_spot(target,carrier.position,ai_opponents[team])
			elif carrier!=null:
				if ai_coverage[team].has(actor):
					target=SkaterAI.mark_target(ai_coverage[team][actor],attack)
				elif TeamTactics.is_defence(slot) and pa>-Arena.BLUE_LINE and pa<Arena.BLUE_LINE+2.0:
					target=SkaterAI.gap_target(carrier.position,attack,TeamTactics.side(slot))
			else:
				var meet:=SkaterAI.intercept_point(puck.position,puck.linear_velocity,actor.position,8.0,0.6)
				if meet!=Vector3.INF and puck.linear_velocity.length()>6.0: target=meet
		if rules.enabled and not changing and not is_hopping(actor):
			target=onside_target(actor,team,attack,target)
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
		# Carrier faces the net he attacks; everyone else faces the puck.
		var face:=body_facing(actor)
		visual.rotation.y=rotate_toward(visual.rotation.y,atan2(-face.x,-face.z),6.0*delta)
		visual.animate(actor.velocity.length(),delta,0,intent.length_squared()>0.01)
		sync_skater_contacts(actor)
		# Stick checks and hits (skater_ai.gd skill): a poke only works some of
		# the time, and each skater gets one try every half second.
		ai_defend(actor,team,delta)

## CPUs and the blue line (rules_offside_icing.gd): on a delayed offside every
## attacker tags up; without the puck in the zone nobody goes in ahead of it;
## the carrier holds up at the line while a team-mate is still inside.
func onside_target(actor: CharacterBody3D, team: int, attack: float, target: Vector3) -> Vector3:
	var line:=Arena.BLUE_LINE
	var hold:=Vector3(target.x,0,attack*(line-1.2))
	if rules.delayed_offside(team):
		return hold if actor!=carrier and (actor.position.z*attack>line-0.8 or target.z*attack>line-0.8) else target
	var puck_in:=puck.position.z*attack>line+0.1
	if puck_in: return target
	if actor==carrier:
		for mate in skaters:
			if mate!=actor and body_team(mate)==team and bool(mate.get_meta("eligible")) and mate.position.z*attack>line+Rules.SKATER_MARGIN-0.05:
				return hold if target.z*attack>line-1.2 else target
		return target
	# Loose puck or a team-mate carrying it up ice: wait at the line. With the
	# other team in possession he is defending and stays outside anyway.
	if target.z*attack>line-0.5: return Vector3(target.x,0,attack*(line-0.5))
	return target

## Positions the CPUs read this tick: opponents per team and, for a team
## defending in its own zone, who marks whom (skater_ai.gd assign_coverage).
func refresh_ai_reads() -> void:
	var on_ice: Array=[[],[]]
	var bodies: Array=[[],[]]
	for actor in skaters:
		if not bool(actor.get_meta("eligible")) or bool(actor.get_meta("changing")) or is_hopping(actor): continue
		on_ice[body_team(actor)].append(actor.position)
		bodies[body_team(actor)].append(actor)
	for team in range(2):
		ai_opponents[team]=on_ice[1-team]
		ai_coverage[team]={}
		var attack:=attack_direction(team)
		if carrier==null or body_team(carrier)==team or puck.position.z*attack>-Arena.BLUE_LINE: continue
		var defenders:=[]
		var defender_pos:=[]
		for actor in bodies[team]:
			if human_controls(actor): continue
			if actor.position.distance_to(carrier.position)<2.0: continue   # the chaser
			defenders.append(actor)
			defender_pos.append(actor.position)
		var attackers:=[]
		for actor in bodies[1-team]:
			if actor!=carrier: attackers.append(actor.position)
		var pairs:=SkaterAI.assign_coverage(defender_pos,attackers,attack)
		for di in pairs: ai_coverage[team][defenders[di]]=attackers[pairs[di]]

func ai_context(actor: CharacterBody3D, team: int, attack: float, is_d: bool) -> Dictionary:
	var mates:=[]
	for i in range(skaters.size()):
		var other:=skaters[i]
		if other==actor or body_team(other)!=team or not bool(other.get_meta("eligible")) or bool(other.get_meta("changing")) or is_hopping(other): continue
		mates.append({"pos":other.position,"vel":other.velocity,"index":i})
	return {"pos":actor.position,"vel":actor.velocity,"attack":attack,"is_d":is_d,"goalie":goalkeeper_at_end(attack).position,"opponents":ai_opponents[team],"teammates":mates,"skill":ai_skill(team),"roll":ai_rng.randf()}

## CPU shot: the corner away from the goalie, accuracy by difficulty; D take
## a harder slapper from the point, forwards a quick wrister.
func ai_shoot(actor: CharacterBody3D, attack: float, is_d: bool) -> void:
	var sk:=ai_skill(body_team(actor))
	var goalie:=goalkeeper_at_end(attack)
	var aim:=SkaterAI.shot_aim(puck.position,attack,goalie.position,float(sk.shot_noise),ai_rng.randf(),ai_rng.randf())
	var direction:Vector3=aim-puck.position
	var distance_:=Vector2(direction.x,direction.z).length()
	var speed:=(33.0 if is_d and distance_>14.0 else 27.0)+ai_rng.randf()*3.0
	var elevation_:float=PuckPhysics.solve_elevation(distance_,speed,aim.y,puck.position.y)
	release_puck(actor,direction,speed,elevation_)
	roster(actor).shots+=1

## CPU pass: to the lead point, off by up to the difficulty's pass error.
func ai_pass(actor: CharacterBody3D, plan: Dictionary) -> void:
	var direction:=SkaterAI.flat(plan.target-puck.position)
	var error:=(ai_rng.randf()*2.0-1.0)*float(ai_skill(body_team(actor)).pass_noise)
	# Firm but catchable: softer for short feeds.
	var speed:=clampf(9.0+direction.length()*0.45,10.0,SkaterAI.PASS_SPEED)
	release_puck(actor,direction.rotated(Vector3.UP,error),speed)
	passes_by_team[body_team(actor)]+=1
	if int(plan.get("receiver",-1))>=0:
		pass_receiver=skaters[int(plan.receiver)]
		pass_timer=1.6

## A CPU defender within reach of the carrier: stick check (pokes work some
## of the time, by skill) or, with speed toward a carrier near the boards, a
## hit (rarely too late: interference/charging).
func ai_defend(actor: CharacterBody3D, team: int, delta: float) -> void:
	var try_:=maxf(0.0,float(actor.get_meta("poke",0.0))-delta)
	actor.set_meta("poke",try_)
	var hit_wait:=maxf(0.0,float(actor.get_meta("hit_cd",0.0))-delta)
	actor.set_meta("hit_cd",hit_wait)
	# Dead puck (whistle, faceoff set-up, intermission): nobody finishes a check.
	if match_state.phase!=MatchState.Phase.PLAY: return
	if carrier==null or body_team(carrier)==team or cooldown>0 or try_>0: return
	var reach:=actor.position.distance_to(puck.position)
	var sk:=ai_skill(team)
	# Body check (skater_ai.gd wants_hit(): on top of the carrier, closing with
	# speed and skating into him; along the wall or, with a real run, in open
	# ice; never from behind into the boards). One try, then HIT_COOLDOWN.
	if hit_wait<=0.0 and bool(carrier.get_meta("eligible")) and SkaterAI.wants_hit(actor.position,actor.velocity,carrier.position,carrier.velocity):
		actor.set_meta("poke",1.6)
		if ai_rng.randf()<float(sk.check):
			var victim:=carrier
			var push:=land_body_check(actor,victim)
			actor.set_meta("hit_cd",SkaterAI.HIT_COOLDOWN)
			ai_log["hit"]=int(ai_log.get("hit",0))+1
			puck.linear_velocity=push*4.5
			carrier=null
			cooldown=0.22
		return
	if reach<1.05:
		actor.set_meta("poke",0.5)
		if ai_rng.randf()<float(sk.check)*0.6:
			ai_log["poke"]=int(ai_log.get("poke",0))+1
			puck.linear_velocity=(puck.position-actor.position).normalized()*5
			carrier=null
			cooldown=0.22

## A body check lands (user or CPU, same rules): the victim is knocked along
## the line of the hit and can't skate for HIT_STUN, the hit is booked for the
## hitter's team (game_stats.gd), the victim visibly staggers away from the
## hit (skater_visual.gd take_hit()) and, along the boards, the glass rattles.
## Returns the push direction.
func land_body_check(hitter: CharacterBody3D, victim: CharacterBody3D) -> Vector3:
	var push:=victim.position-hitter.position
	push.y=0
	push=push.normalized() if push.length()>0.01 else Vector3(0,0,1)
	victim.velocity+=push*4.0
	victim.set_meta("stun",SkaterAI.HIT_STUN)
	game_stats.add_hit(body_team(hitter),match_state.period)
	var visual=victim.get_child(1)
	if visual!=null and visual.has_method("take_hit"):
		visual.take_hit(visual.global_transform.basis.inverse()*push,SkaterAI.HIT_STAGGER)
	if SkaterAI.boards_distance(victim.position)<SkaterAI.HIT_DANGER+0.4:
		last_rattle=Arena.rattle_glass(get_tree(),victim.global_position+push*1.2,1.0)
		beep(95)
	return push

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
			var soft_hands:=24.0 if actor==pass_receiver else 20.0
			if distance_<best and (puck.linear_velocity-actor.velocity).length()<soft_hands:
				best=distance_
				carrier=actor
				if actor==pass_receiver:
					ai_log["pass_done"]=int(ai_log.get("pass_done",0))+1
					# A CPU taking a pass in a scoring spot can shoot it first time.
					if not human_controls(actor):
						var team_:=body_team(actor)
						var attack_:=attack_direction(team_)
						var q_:=SkaterAI.shot_quality(actor.position,attack_,goalkeeper_at_end(attack_).position,ai_opponents[team_])
						if SkaterAI.one_timer(q_,float(ai_skill(team_).shot_bar)):
							actor.set_meta("one_timer",true)
				elif pass_receiver!=null and body_team(actor)!=body_team(pass_receiver): ai_log["intercepted"]=int(ai_log.get("intercepted",0))+1
				# A fresh read on gaining it: a short reaction, no stale plan.
				actor.set_meta("plan",{})
				actor.set_meta("decision",0.06 if bool(actor.get_meta("one_timer",false)) else float(ai_skill(body_team(actor)).react)*0.5)
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
			# A goalie already sliding toward a low, wide shot stacks the pads
			# (kept once started); see SkaterVisual.choose_save().
			kind=visual.choose_save(local.x,intercept_height,visual.lateral,visual.save_kind)
		var drop_down:bool=kind in ["butterfly","pad_left","pad_right"]
		visual.butterfly=move_toward(visual.butterfly,1.0 if drop_down else 0.0,delta*(6 if drop_down else 2))
		visual.set_save(kind,crossing if threat else visual.save_target,delta)
		var desired_height:=clampf(intercept_height-0.7,0,0.40) if threat and kind=="body" else 0.0
		visual.goalie_save_height=move_toward(visual.goalie_save_height,desired_height,delta*2.8)
		keeper.velocity=(goalie_targets[i]-keeper.position).limit_length(1)*3.8
		keeper.move_and_slide()
		# The goalie works off the middle of his net: he stays on the line from
		# the net centre to the puck (goalie_targets) and keeps his chest square
		# to the puck. When the puck goes behind the goal line he turns to follow
		# it but no further than sideways along the line (hugging the post).
		var base:=Vector3(0,0,end_*Arena.GOAL_LINE)
		var facing:=puck.position-base
		facing.y=0
		var out_:=Vector3(0,0,-end_)
		var angle:=out_.signed_angle_to(facing.normalized(),Vector3.UP) if facing.length()>0.05 else 0.0
		angle=clampf(angle,-deg_to_rad(100),deg_to_rad(100))
		facing=out_.rotated(Vector3.UP,angle)
		visual.rotation.y=rotate_toward(visual.rotation.y,atan2(-facing.x,-facing.z)-keeper.rotation.y,delta*9)
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
	var snap:=side!=camera_side or faceoff_cut
	faceoff_cut=false
	camera_side=side
	var at_faceoff:=(match_state.phase==MatchState.Phase.FACEOFF or puck_in_air_at_drop()) and camera_mode in [0,2]
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
	if at_faceoff:
		# Faceoff: cut in close and low on the dot, both centres in frame, the
		# wingers either side; after the drop the normal framing eases back.
		var dot:=Vector3(next_faceoff.x,0,next_faceoff.z)
		camera_target=Vector3(dot.x,0,clampf(dot.z+lead,-(Arena.GOAL_LINE-3.0),Arena.GOAL_LINE-3.0))
		if camera_mode==0:
			# Off the user's centre's shoulder so the opposing centre and both
			# blades over the dot are not hidden behind him.
			desired=dot+Vector3(-side*FACEOFF_CAM_DYNAMIC.x,FACEOFF_CAM_DYNAMIC.y,side*FACEOFF_CAM_DYNAMIC.z)
			look=dot+Vector3(0,0.45,-side*1.2)
		else:
			desired=dot+Vector3(side*FACEOFF_CAM_BROADCAST.x,FACEOFF_CAM_BROADCAST.y,0)
			look=dot+Vector3(0,0.5,0)
	camera.position=desired if snap else camera.position.lerp(desired,1-exp(-delta*(8 if at_faceoff else 5)))
	# Leaving the faceoff framing, the camera glides back onto the play line
	# instead of snapping across.
	faceoff_cam_ease = 1.0 if at_faceoff else (0.0 if snap else move_toward(faceoff_cam_ease,0.0,delta*1.6))
	if camera_mode!=2 and not at_faceoff: camera.position.x=lerpf(camera.position.x,camera_target.x,1.0-faceoff_cam_ease*faceoff_cam_ease)
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
	# Book this tick's goals/shots/faceoffs/penalties to the period (stats screens).
	game_stats.sync(match_state,team_shots,faceoff_wins)
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
		# Intermission / final: the stats card (stats_screen.gd) replaces the old banner.
		if e.begins_with("END OF PERIOD"):
			hud_node.show_stats(game_stats,match_state.score,match_state.period,false)
		elif e.begins_with("Period "):
			hud_node.hide_stats()
			hud_node.show_banner(["1ST","2ND","3RD"][clampi(match_state.period-1,0,2)]+" PERIOD", "Ends switched", Color("#93a3b3"), 1.6)
		elif e.begins_with("FINAL"):
			hud_node.show_stats(game_stats,match_state.score,match_state.period,true)
		elif " — " in e and (e.begins_with("TOR") or e.begins_with("MTL")):
			var team:=0 if e.begins_with("TOR") else 1
			hud_node.show_banner("PENALTY", e.substr(6).to_upper(), hud_node.team_colors[team], 2.0)
		last_event=e
	var stopped:=match_state.phase!=MatchState.Phase.PLAY
	var quiet_events:=["Play","Centre faceoff","Opening faceoff"]
	status.text=("" if not stopped or match_state.event in quiet_events or match_state.event.ends_with("GOAL") or hud_node.stats_screen.mode!="" else match_state.event.to_upper())
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
		if body_team(actor)==user_team() and int(actor.get_meta("slot"))<3:
			players.append({"number":roster(actor).number,"name":str(roster(actor).name).split(" ")[-1],"stamina":float(roster(actor).stamina),"changing":bool(actor.get_meta("changing"))})
	hud_node.update_line(active_lines[user_team()],defense_pairs[user_team()],players)
	power.visible=charge>0
	power.value=charge
	help.text=("START  PAUSE   ·   VIEW  CONTROLS" if controller.active else "ESC  PAUSE   ·   F2  CONTROLS   ·   C  CAMERA")

func capture_preview() -> void:
	# --capture-time=<seconds> lets wear such as skate cuts build up first.
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-time="): capture_time = clampf(float(arg.substr(15)), 0.5, 120.0)
	await get_tree().create_timer(capture_time).timeout
	var args := OS.get_cmdline_user_args()
	# --faceoff-violation[=<s>]: the user's centre is waved out; capture <s>
	# (default 0.9) seconds into the violation (wave, then the swap).
	for arg in args:
		if str(arg).begins_with("--faceoff-violation"):
			var at := float(str(arg).substr(20)) if str(arg).contains("=") else 0.9
			for c in draw_centres:
				if body_team(c)==user_team(): start_violation(c)
			for f in range(600):
				if violation_timer<0.0 or violation_timer>=at: break
				await get_tree().physics_frame
			get_tree().paused = true
			for i in range(2): await get_tree().process_frame
	# --faceoff-delay: the user's team is thrown out twice on one faceoff; the
	# DELAY OF GAME cue as the stoppage starts.
	if "--faceoff-delay" in args:
		for c in draw_centres:
			if body_team(c)==user_team(): start_violation(c)
		for f in range(600):
			if violation_checks>=1: break
			await get_tree().physics_frame
		if violation_sub!=null: start_violation(violation_sub)
		for f in range(60): await get_tree().physics_frame
		get_tree().paused = true
		for i in range(2): await get_tree().process_frame
	# --faceoff-backing[=<s>]: drop the puck and capture <s> (default 0.5)
	# seconds after it lands, the linesman skating backward out of the circle.
	for arg in args:
		if str(arg).begins_with("--faceoff-backing"):
			var after := float(str(arg).substr(18)) if str(arg).contains("=") else 0.5
			violation_checked = true
			match_state.phase_timer = 0.0
			for f in range(600):
				await get_tree().physics_frame
				if draw_landed and backing_time>=after: break
			get_tree().paused = true
			for i in range(2): await get_tree().process_frame
	if "--faceoff-drop" in args or "--faceoff-draw" in args:
		match_state.phase_timer = 0.0
		for f in range(240):
			await get_tree().physics_frame
			# --faceoff-timing: the user presses shoot just before the landing.
			if "--faceoff-timing" in args and puck_in_air_at_drop() and puck.position.y < 0.2: register_draw_press()
			if "--faceoff-drop" in args and puck_in_air_at_drop() and puck.position.y < 0.42: break
			if "--faceoff-draw" in args and draw_landed and faceoff_winner!=null:
				var wv = faceoff_winner.get_child(1)
				# (Long enough for the FACEOFF WON / LOST cue to fade in.)
				if float(wv.draw_time)-float(wv.draw_result_time) > 0.16: break
		# Hold that instant while the frame is drawn.
		get_tree().paused = true
		for i in range(2): await get_tree().process_frame
	for frame in range(600):
		if match_state.phase==MatchState.Phase.PLAY or match_state.phase_timer>100.0 or get_tree().paused: break
		await get_tree().physics_frame
	if "--paused" in OS.get_cmdline_user_args():
		set_paused(true)
		await get_tree().process_frame
	if "--replay-save" in OS.get_cmdline_user_args():
		await capture_save_replay()
	elif "--replay" in OS.get_cmdline_user_args() or "--replay-wipe" in OS.get_cmdline_user_args():
		await capture_replay("--replay-wipe" in OS.get_cmdline_user_args())
	for arg in OS.get_cmdline_user_args():
		if str(arg).begins_with("--stats-screen"):
			await capture_stats_screen(str(arg).substr(15) if str(arg).contains("=") else "intermission", "--stats-demo" in OS.get_cmdline_user_args())
	for arg in OS.get_cmdline_user_args():
		# --rule-banner=offside|icing: the linesman's call as the match shows it.
		if str(arg).begins_with("--rule-banner"):
			var kind:=Rules.ICING if str(arg).ends_with("icing") else Rules.OFFSIDE
			rule_whistle(kind,0,rules.offside_spot(0,attack_direction(0)) if kind==Rules.OFFSIDE else rules.icing_spot(attack_direction(0)))
			for i in range(20): await get_tree().process_frame
	if "--goal-banner" in OS.get_cmdline_user_args():
		hud_node.show_banner("GOAL", "TORONTO  ·  VALE", hud_node.team_colors[0], 5.0)
		for i in range(20): await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/tmp/hawkey-match-preview.png")
	get_tree().quit()

## --stats-screen=intermission|final [--stats-demo]: run the clock out of the
## 1st (intermission) or 3rd (final) period and capture the stats card;
## --stats-demo fills a plausible game first (game_stats.gd fill_demo()).
func capture_stats_screen(which: String, demo: bool) -> void:
	var final_ := which=="final"
	match_state.period=3 if final_ else 1
	if demo:
		var d:=game_stats.fill_demo(match_state.period)
		match_state.score.assign(d.score)
		team_shots.assign(d.shots)
		faceoff_wins=d.faceoffs.duplicate()
	match_state.phase=MatchState.Phase.PLAY
	match_state.clock=0.01
	for f in range(120):
		await get_tree().physics_frame
		if hud_node.stats_screen.mode!="": break
	# Let the card's fade-in finish (real time: physics ticks outrun frames here).
	await get_tree().create_timer(0.8).timeout
	get_tree().paused=true
	for i in range(2): await get_tree().process_frame

## --replay / --replay-wipe screenshots: a skater carries the puck in on the
## net Toronto attacks and it is put over the line; capture during the replay's
## slow motion, or with the REPLAY wipe covering the cut.
func capture_replay(wipe_frame: bool) -> void:
	# Software rendering runs this at ~1/30 real time: skip drawing the 3D
	# world until just before the frame we want.
	get_viewport().disable_3d=true
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--replay-angle="): replay.force_angle=arg.substr(15)
	var end_:=attack_direction(0)
	var net_z:=end_*Arena.GOAL_LINE
	# A shooter walks in on the slot and lets a shot go at the far post.
	var shooter:=skaters[0]
	shooter.position=Vector3(3.0,0,net_z-end_*11.0)
	puck.position=shooter.position+Vector3(-0.3,0.02,end_*0.8)
	puck.linear_velocity=Vector3(-0.4,0,end_*6.0)
	for i in range(int(0.9*Engine.physics_ticks_per_second)): await get_tree().physics_frame
	puck.position=Vector3(2.2,0.05,net_z-end_*7.5)
	# The goalie cheats to the shooter's post so the far-side shot goes in: a
	# saved shot left the replay showing the puck at his pads (behind him from
	# the ice-level camera) and a trail cut short by the old teleport.
	var keeper:=goalkeeper_at_end(end_)
	keeper.position.x+=1.3
	puck.linear_velocity=(Vector3(-0.6,0.3,net_z)-puck.position).normalized()*26.0
	var scored:int=match_state.score[0]+match_state.score[1]
	for i in range(60):
		await get_tree().physics_frame
		if match_state.score[0]+match_state.score[1]!=scored: break
	if match_state.score[0]+match_state.score[1]==scored:
		# Saved anyway: fire it in from just outside the crease (no teleport
		# across the goal line, so the replay trail stays continuous).
		match_state.phase=MatchState.Phase.PLAY
		puck.position=Vector3(-0.2,0.03,net_z-end_*1.6)
		puck.linear_velocity=Vector3(-0.3,0,end_*14.0)
		for i in range(40):
			await get_tree().physics_frame
			if match_state.score[0]+match_state.score[1]!=scored: break
	for i in range(1200):
		await get_tree().physics_frame
		if wipe_frame and replay.wipe_progress()>0.2: get_viewport().disable_3d=false
		if not wipe_frame and replay.playing() and replay.play_t>replay.goal_time-0.7: get_viewport().disable_3d=false
		if wipe_frame and replay.wipe_progress()>0.44 and replay.wipe_progress()<0.56: break
		if not wipe_frame and replay.playing() and replay.play_t>replay.goal_time-0.25: break
	get_viewport().disable_3d=false

## --replay-save screenshot: a hard shot from the slot into the goalie's
## chest, the whistle goes, and the save replay is caught in slow motion with
## the puck trail just short of the goalie.
func capture_save_replay() -> void:
	get_viewport().disable_3d=true
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--replay-angle="): replay.force_angle=arg.substr(15)
	var end_:=attack_direction(0)
	var keeper:=goalkeeper_at_end(end_)
	var shooter:=skaters[0]
	shooter.position=Vector3(2.5,0,keeper.position.z-end_*10.0)
	puck.position=shooter.position+Vector3(-0.3,0.02,end_*0.8)
	puck.linear_velocity=Vector3(-0.3,0,end_*5.0)
	for i in range(int(0.9*Engine.physics_ticks_per_second)): await get_tree().physics_frame
	puck.position=Vector3(1.6,0.05,keeper.position.z-end_*8.0)
	puck.linear_velocity=(keeper.position+Vector3(0,0.55,0)-puck.position).normalized()*27.0
	var shot_clock:float=replay.clock
	for i in range(int(0.6*Engine.physics_ticks_per_second)):
		await get_tree().physics_frame
		if replay._save_t>=shot_clock or puck.linear_velocity.length()<12.0: break
	# No hard save registered (stick/glancing contact): mark it where the shot died.
	if replay._save_t<shot_clock: replay.big_save(end_,0.4)
	for i in range(int(0.4*Engine.physics_ticks_per_second)): await get_tree().physics_frame
	if match_state.phase==MatchState.Phase.PLAY:
		match_state.phase=MatchState.Phase.STOPPAGE
		match_state.phase_timer=2
		match_state.event="Goalkeeper catch"
	for i in range(1200):
		await get_tree().physics_frame
		if replay.playing() and replay.play_t>replay.goal_time-0.5: get_viewport().disable_3d=false
		if replay.playing() and replay.play_t>replay.goal_time-0.06: break
	get_viewport().disable_3d=false

func goalkeeper_at_end(end_sign: float) -> CharacterBody3D:
	for keeper in goalkeepers:
		if signf(keeper.position.z)==end_sign: return keeper
	return goalkeepers[0]


func update_officials(delta: float) -> void:
	for i in range(referee_nodes.size()):
		var official:=referee_nodes[i]
		if official==backing_official and backing_time>=0.0:
			backing_time+=delta
			if backing_time<LINESMAN_BACK_TIME:
				# Backward glide: eases up to speed, holds his facing on the dot.
				var back_speed:=LINESMAN_BACK_SPEED*smoothstep(0.0,0.35,backing_time)*(1.0-0.5*smoothstep(0.7,1.0,backing_time/LINESMAN_BACK_TIME))
				official.position+=backing_dir*back_speed*delta
				official.position.x=clampf(official.position.x,-(Arena.HALF_WIDTH-1.2),Arena.HALF_WIDTH-1.2)
				# Real backward skating: alternating C-cuts (skater_visual.gd back_skate).
				official.back_skate_target=1.0
				official.animate(back_speed,delta,0,false)
				continue
			backing_official=null
			backing_time=-1.0
		official.back_skate_target=0.0
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
		if controller.line_delta!=0: request_line(user_team(),active_lines[user_team()]+controller.line_delta)
		if controller.pair_delta!=0: request_line(user_team(),defense_pairs[user_team()]+controller.pair_delta,true)
		if controller.check_pressed: defensive_action(true)
		if controller.poke_pressed: defensive_action(false)
		if controller.shoot_pressed or controller.pass_pressed: register_draw_press()
		if match_state.phase==MatchState.Phase.PLAY:
			if controller.shoot_released:
				strike(shot_direction(),lerpf(16,36,charge),false,controller.lift*0.32)
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
