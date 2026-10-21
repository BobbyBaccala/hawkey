extends SceneTree
## Board-hop review renders (line change, board_hop.gd): one home skater at his
## bench door, frozen at points through the hop out (tired player) and back in
## (fresh player). Writes /tmp/hawkey-hop-<n>.png (n = 0..5).
## xvfb-run -a -s "-screen 0 1728x1080x24" godot --rendering-method gl_compatibility --rendering-driver opengl3 --resolution 1728x1080 --script tools/capture_hop.gd
## Option: --hop-side  camera along the boards (side-on view of the vault).
const Arena = preload("res://scripts/arena.gd")
const BoardHop = preload("res://scripts/board_hop.gd")
func _initialize() -> void: call_deferred("run")

func shot(cam: Camera3D, pos: Vector3, look: Vector3, fov: float, path: String) -> void:
	cam.fov = fov
	cam.position = pos
	cam.look_at(look)
	cam.cull_mask = preload("res://scripts/arena_lighting.gd").camera_cull_mask(pos)
	for i in range(4): await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)

## Advance the visual's hop to progress u (0..1).
func hop_to(v, u: float) -> void:
	while v.hop_u < u and v.hopping():
		v.animate(0, 1.0 / 120.0, 0, false)

func run() -> void:
	var side_view := "--hop-side" in OS.get_cmdline_user_args() or "--hop-side" in OS.get_cmdline_args()
	var scene = load("res://main.tscn").instantiate()
	scene.get_script().skip_title = true
	root.add_child(scene)
	for i in range(3): await physics_frame
	scene.set_physics_process(false)
	var actor: CharacterBody3D = null
	for s in scene.skaters:
		if scene.body_team(s) == 0 and int(s.get_meta("slot")) == 1 and actor == null: actor = s
		else: s.visible = false
	for g in scene.goalkeepers: g.visible = false
	scene.puck.visible = false
	var hud = scene.get("hud_node")
	if hud: hud.visible = false
	var benches = scene.arena.get_node("Benches")
	benches.watch_target = Vector3(0, 0, 0)
	actor.position = scene.bench_spot(0, 1)
	var v = actor.get_child(1)
	for i in range(30): v.animate(0, 1.0 / 120.0, 0, false)
	var cam: Camera3D = scene.camera
	var w := Arena.HALF_WIDTH
	var z: float = actor.position.z
	var eye := Vector3(-w + 0.6, 1.7, z - 5.5) if side_view else Vector3(-w + 5.0, 2.3, z - 2.6)
	var look := Vector3(-w - 0.3, 0.9, z)
	var bench_floor := Vector3(-(w + scene.HOP_BENCH_DEPTH), 0, z) - actor.position
	var board_x: float = -w - actor.position.x
	v.start_hop(Vector3.ZERO, bench_floor, board_x)
	var n := 0
	for u in [0.30, 0.47, 0.58]:
		hop_to(v, u)
		await shot(cam, eye, look, 42, "/tmp/hawkey-hop-%d.png" % n)
		n += 1
	hop_to(v, 1.0)
	scene.change_identity(actor, 6)
	v.start_hop(v.position + Vector3(0, 0, -0.7), Vector3.ZERO, board_x)
	for u in [0.45, 0.56, 0.80]:
		hop_to(v, u)
		await shot(cam, eye, look, 42, "/tmp/hawkey-hop-%d.png" % n)
		n += 1
	print("hop capture done")
	quit()
