extends SceneTree
## Body-check review render: an away CPU finishes his check on a home carrier
## along the east boards; frozen mid-stagger (match.gd land_body_check(),
## skater_visual.gd take_hit()). Writes /tmp/hawkey-cpu-check.png.
## xvfb-run -a -s "-screen 0 1728x1080x24" godot --rendering-method gl_compatibility --rendering-driver opengl3 --resolution 1728x1080 --script tools/capture_cpu_check.gd
const Arena = preload("res://scripts/arena.gd")
const SkaterAI = preload("res://scripts/skater_ai.gd")
func _initialize() -> void: call_deferred("run")

func run() -> void:
	var scene = load("res://main.tscn").instantiate()
	scene.get_script().skip_title = true
	root.add_child(scene)
	for i in range(3): await physics_frame
	scene.set_physics_process(false)
	var hitter: CharacterBody3D = null
	var victim: CharacterBody3D = null
	for s in scene.skaters:
		if scene.body_team(s) == 1 and hitter == null: hitter = s
		elif scene.body_team(s) == 0 and victim == null: victim = s
		else: s.visible = false
	var hud = scene.get("hud_node")
	if hud: hud.visible = false
	var w := Arena.HALF_WIDTH
	victim.position = Vector3(w - 0.75, 0, 6.0)
	hitter.position = victim.position + Vector3(-0.95, 0, 0.25)
	scene.puck.position = victim.position + Vector3(-0.5, 0.03, -0.9)
	var vv = victim.get_child(1)
	var hv = hitter.get_child(1)
	vv.rotation.y = PI          # skating toward +z along the wall
	hv.rotation.y = -PI * 0.5 - 0.3   # driving into him
	for i in range(40):
		vv.animate(5.0, 1.0 / 120.0, 0, true)
		hv.animate(6.0, 1.0 / 120.0, 0, true)
	scene.land_body_check(hitter, victim)
	for i in range(20):
		vv.animate(3.0, SkaterAI.HIT_STAGGER * 0.25 / 20.0, 0, false)
		hv.animate(3.0, 1.0 / 120.0, 0, false)
	var cam: Camera3D = scene.camera
	cam.fov = 40
	cam.position = Vector3(w - 4.6, 1.5, 8.6)
	cam.look_at(victim.position + Vector3(-0.3, 0.95, 0))
	cam.cull_mask = preload("res://scripts/arena_lighting.gd").camera_cull_mask(cam.position)
	for i in range(4): await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/hawkey-cpu-check.png")
	quit()
