extends Node3D
const Arena = preload("res://scripts/arena.gd")
var kit := Color("#116c9e")
var number := "17"
var goalie := false
var legs: Array[Node3D] = []
var phase := 0.0
var torso: Node3D
var rig: Node3D
var stick: Node3D

func part(size: Vector3, pos: Vector3, color: Color, parent: Node3D = null) -> MeshInstance3D:
	var target := parent if parent != null else rig
	var instance := MeshInstance3D.new()
	var mesh: Mesh
	if size.y > 0.25 or (size.y > 0.15 and size.z < 0.4):
		var sphere := SphereMesh.new()
		sphere.radius = 0.5
		sphere.height = 1.0
		sphere.radial_segments = 20
		sphere.rings = 12
		mesh = sphere
		instance.scale = size
	else:
		var box := BoxMesh.new()
		box.size = size
		mesh = box
	instance.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.65
	instance.material_override = material
	instance.position = pos
	target.add_child(instance)
	return instance

func _ready() -> void:
	rig = Node3D.new()
	add_child(rig)
	torso = Node3D.new()
	rig.add_child(torso)
	torso.position.y = 1.12
	torso.rotation.x = -0.22
	part(Vector3(0.64,0.64,0.36), Vector3(0,0.14,0), kit, torso)
	part(Vector3(0.67,0.12,0.38), Vector3(0,-0.07,0), Color("#edf2f7"), torso)
	part(Vector3(0.18,0.2,0.19), Vector3(0,0.53,0), Color("#b9977e"), torso)
	part(Vector3(0.36,0.32,0.42), Vector3(0,0.72,0.02), Color("#12263b"), torso)
	part(Vector3(0.44,0.19,0.035), Vector3(0,0.65,-0.20), Color("#bbd5e2"), torso)
	for side in [-1.0,1.0]:
		var leg := Node3D.new()
		leg.position = Vector3(side * 0.2,0.95,0)
		rig.add_child(leg)
		legs.append(leg)
		part(Vector3(0.26,0.4,0.3), Vector3(0,-0.18,0), Color("#14283e"), leg)
		part(Vector3(0.22,0.39,0.24), Vector3(0,-0.55,0.06), WHITE(), leg)
		part(Vector3(0.24,0.10,0.26), Vector3(0,-0.48,0.06), kit, leg)
		part(Vector3(0.2,0.14,0.43), Vector3(0,-0.83,-0.04), Color("#182735"), leg)
		part(Vector3(0.035,0.055,0.44), Vector3(0,-0.92,-0.04), Color("#a4bbc9"), leg)
		var arm := part(Vector3(0.22,0.52,0.24), Vector3(side * 0.4,0.08,-0.12), kit, torso)
		arm.rotation.x = -0.6
		part(Vector3(0.23,0.18,0.25), Vector3(side * 0.4,-0.13,-0.28), Color("#12263b"), torso)
		if goalie:
			part(Vector3(0.38,0.76,0.26), Vector3(side * 0.28,0.44,-0.22), WHITE())
			part(Vector3(0.07,0.72,0.28), Vector3(side * 0.28,0.44,-0.23), kit)
	stick = Node3D.new()
	rig.add_child(stick)
	var helper := Arena.new()
	helper.tube(stick, Vector3(0.36,1.08,-0.32), Vector3(0.52,0.08,-1.04),0.025,Color("#252e38"))
	part(Vector3(0.45,0.075,0.09),Vector3(0.32,0.08,-1.04),Color("#1c232b"),stick)
	helper.free()
	var jersey := Label3D.new()
	jersey.text = number
	jersey.font_size = 52
	jersey.pixel_size = 0.007
	jersey.position = Vector3(0,1.4,0.22)
	jersey.rotation.y = PI
	jersey.modulate = WHITE()
	rig.add_child(jersey)

func WHITE() -> Color:
	return Color("#edf4f8")

func animate(speed: float, delta: float, turn: float = 0) -> void:
	phase += delta * (3.0 + speed * 1.5)
	var stride := clampf(speed / 7,0,1)
	for i in range(legs.size()):
		legs[i].rotation.x = sin(phase + i * PI) * 0.45 * stride
		legs[i].rotation.z = sin(phase + i * PI) * 0.18 * stride
	rig.rotation.z = lerpf(rig.rotation.z, clampf(turn,-0.15,0.15), delta * 8)
	torso.position.y = 1.12 + absf(sin(phase)) * stride * 0.025
