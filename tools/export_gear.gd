extends SceneTree
## Writes the sculpted equipment to assets/gear/*.glb so it can be opened and
## refined in Blender (File > Import > glTF 2.0). Vertex colours carry the paint.
## godot --headless --script tools/export_gear.gd
const Gear = preload("res://scripts/gear_builder.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var kit := Color("#185c73")
	var accent := kit.darkened(0.45)
	var items := {
		"goalie_pad_left": Gear.goalie_pad(1, kit, accent),
		"goalie_pad_right": Gear.goalie_pad(-1, kit, accent),
		"blocker_right_hand": Gear.blocker(-1, kit, accent),
		"catcher_left_hand": Gear.catcher(1, kit, accent),
		"goalie_mask": Gear.goalie_mask(kit, accent),
		"skater_glove": Gear.skater_glove(kit),
		"skate_player": Gear.skate(false),
		"skate_goalie": Gear.skate(true),
		"pants_leg_left": Gear.pants_leg(1, kit, Color("#151c24")),
		"sock": Gear.sock(kit, Color("#e4e8ea")),
	}
	DirAccess.make_dir_recursive_absolute("res://assets/gear")
	var failures := 0
	for name_ in items:
		var root_ := Node3D.new()
		root_.name = name_
		var instance := MeshInstance3D.new()
		instance.name = name_
		instance.mesh = items[name_]
		root_.add_child(instance)
		instance.owner = root_
		var doc := GLTFDocument.new()
		var state := GLTFState.new()
		var err := doc.append_from_scene(root_, state)
		if err == OK:
			err = doc.write_to_filesystem(state, "res://assets/gear/%s.glb" % name_)
		print(name_, " -> ", "ok" if err == OK else "error %d" % err)
		failures += int(err != OK)
		root_.free()
	quit(failures)
