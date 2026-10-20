extends SceneTree
## Arena lighting pass: overhead pools cover every zone of the ice, point
## straight down and don't cast shadows; rim lights stay off the environment
## (ice, boards, crowd) but reach the players.
var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		push_error(message)
		failures += 1

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var m = load("res://main.tscn").instantiate()
	root.add_child(m)
	await physics_frame
	var lighting = m.get_node_or_null("ArenaLighting")
	check(lighting != null, "ArenaLighting node exists")
	if lighting == null:
		print("Lighting failures: ", failures)
		quit(failures)
		return
	var pools: Array = lighting.pools
	check(pools.size() == 8, "Eight overhead pools (two per zone row), got %d" % pools.size())
	var radius: float = lighting.pool_radius()
	check(radius > 6.0 and radius < 11.0, "Pool radius on the ice is soft-pool sized: %.2f m" % radius)
	for spot in pools:
		var aim: Vector3 = -spot.global_basis.z
		check(aim.dot(Vector3.DOWN) > 0.99, "%s points straight down" % spot.name)
		check(not spot.shadow_enabled, "%s casts no shadows (cost)" % spot.name)
		check(spot.spot_range > spot.global_position.y, "%s reaches the ice" % spot.name)
	# Every point of the playing surface sits close enough to a pool centre to
	# be lit by its soft edge (no black holes in a corner or the slot).
	for x in range(-14, 15, 2):
		for z in range(-28, 29, 2):
			var nearest := INF
			for spot in pools:
				nearest = minf(nearest, Vector2(spot.global_position.x - x, spot.global_position.z - z).length())
			check(nearest < radius * 1.45, "Ice point (%d, %d) is %.1f m from a pool" % [x, z, nearest])
	# Rim lights: low and shadowless, masked off the environment layer.
	var rims: Array = lighting.rims
	check(rims.size() == 2, "Two rim lights")
	for rim in rims:
		var aim: Vector3 = -rim.global_basis.z
		check(aim.y < 0 and aim.y > -0.4, "%s is low-angle (aim.y %.2f)" % [rim.name, aim.y])
		check(rim.light_cull_mask & lighting.ENVIRONMENT_LAYER == 0, "%s skips the environment layer" % rim.name)
		check(rim.light_cull_mask & 1 != 0, "%s still lights the default (player) layer" % rim.name)
	var env_meshes: Array = m.arena.find_children("*", "GeometryInstance3D", true, false)
	check(env_meshes.size() > 20, "Arena has meshes to tag")
	var rigging := 0
	for g in env_meshes:
		var want: int = lighting.RIGGING_LAYER if g.has_meta("rigging") else lighting.ENVIRONMENT_LAYER
		if g.has_meta("rigging"): rigging += 1
		if g.layers != want:
			check(false, "Arena mesh %s not on its layer (%d, want %d)" % [g.name, g.layers, want])
			break
	# Overhead rigging (trusses, lamps, jumbotron) is hidden by the full-rink
	# camera only, so the whole sheet is visible from above.
	check(rigging > 40, "Trusses, lamps and jumbotron are tagged as rigging (%d)" % rigging)
	for rim in rims:
		check(rim.light_cull_mask & lighting.RIGGING_LAYER == 0, "%s skips the rigging" % rim.name)
	for mode in [0, 3]:
		m.camera_mode = mode
		await physics_frame
		await physics_frame
		var sees_rigging: bool = m.camera.cull_mask & lighting.RIGGING_LAYER != 0
		check(sees_rigging == (mode != 3), "Camera %d rigging visibility" % mode)
		check(m.camera.cull_mask & lighting.ENVIRONMENT_LAYER != 0, "Camera %d sees the arena" % mode)
	var player_meshes: Array = m.player.find_children("*", "GeometryInstance3D", true, false)
	check(player_meshes.size() > 0, "Player has meshes")
	for g in player_meshes:
		if g.layers & lighting.ENVIRONMENT_LAYER != 0:
			check(false, "Player mesh %s wrongly on the environment layer" % g.name)
			break
	m.queue_free()
	await process_frame
	print("Lighting failures: ", failures)
	quit(failures)
