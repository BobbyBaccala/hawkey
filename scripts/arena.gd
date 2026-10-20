extends Node3D
## Original procedural rink. Units are metres; visual markings share one ice plane.
const RED = Color("#8f1631")
const BLUE = Color("#174b8c")
const WHITE = Color("#f0f5fa")
var board_count := 0
var goals: Array[Node3D] = []

func mat(color: Color, roughness: float = 0.5) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if color.a < 1:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m

func block(parent: Node3D, size: Vector3, pos: Vector3, color: Color, solid: bool = false, bounce: float = 0.55) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var shape := BoxMesh.new()
	shape.size = size
	mesh.mesh = shape
	mesh.material_override = mat(color)
	parent.add_child(mesh)
	mesh.position = pos
	if solid:
		var body := StaticBody3D.new()
		var collision := CollisionShape3D.new()
		var s := BoxShape3D.new()
		s.size = size
		collision.shape = s
		body.add_child(collision)
		mesh.add_child(body)
		var physics_material := PhysicsMaterial.new()
		physics_material.friction = 0.03
		physics_material.bounce = bounce
		body.physics_material_override = physics_material
	return mesh

func tube(parent: Node3D, a: Vector3, b: Vector3, radius: float, color: Color, solid: bool = false) -> void:
	var mesh := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = radius
	cylinder.bottom_radius = radius
	cylinder.height = a.distance_to(b)
	cylinder.radial_segments = 8
	mesh.mesh = cylinder
	mesh.material_override = mat(color, 0.3)
	parent.add_child(mesh)
	mesh.position = (a + b) * 0.5
	mesh.quaternion = Quaternion(Vector3.UP, (b - a).normalized())
	if solid:
		var body := StaticBody3D.new()
		var collision := CollisionShape3D.new()
		var shape := CylinderShape3D.new()
		shape.radius = radius
		shape.height = cylinder.height
		collision.shape = shape
		body.add_child(collision)
		mesh.add_child(body)
		var pm := PhysicsMaterial.new()
		pm.bounce = 0.7
		pm.friction = 0.1
		body.physics_material_override = pm

func ring(center: Vector3, radius: float, width: float, color: Color, start: float = 0, end: float = TAU) -> void:
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, mat(color))
	for i in range(96):
		var a := lerpf(start, end, float(i) / 96)
		var b := lerpf(start, end, float(i + 1) / 96)
		var p0 := center + Vector3(cos(a), 0, sin(a)) * (radius - width * 0.5)
		var p1 := center + Vector3(cos(a), 0, sin(a)) * (radius + width * 0.5)
		var p2 := center + Vector3(cos(b), 0, sin(b)) * (radius + width * 0.5)
		var p3 := center + Vector3(cos(b), 0, sin(b)) * (radius - width * 0.5)
		for v in [p0, p2, p1, p0, p3, p2]:
			mesh.surface_set_normal(Vector3.UP)
			mesh.surface_add_vertex(v)
	mesh.surface_end()
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)

func disc(center: Vector3, radius: float, color: Color) -> void:
	var mesh := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = radius
	cylinder.bottom_radius = radius
	cylinder.height = 0.003
	mesh.mesh = cylinder
	mesh.material_override = mat(color)
	mesh.position = center
	add_child(mesh)

func board_segment(a: Vector3, b: Vector3) -> void:
	var root := Node3D.new()
	add_child(root)
	root.position = (a + b) * 0.5
	root.rotation.y = atan2(-(b - a).z, (b - a).x)
	var length_ := a.distance_to(b) + 0.03
	block(root, Vector3(length_, 1.05, 0.24), Vector3(0, 0.525, 0), WHITE)
	# Board-and-glass collider: same inner face, from 0.5 m below the ice to the
	# top of the glass with no gap between board and glass, and
	# 1 m deep behind the face. A puck rests a few millimetres into the ice; with a
	# collider ending at ice level the shortest way out of a board hit was DOWN,
	# so sliding pucks were pushed under the boards and out of the rink. The
	# depth behind the face also stops fast shots from passing through.
	var wall := StaticBody3D.new()
	var wall_shape := CollisionShape3D.new()
	var wall_box := BoxShape3D.new()
	wall_box.size = Vector3(length_, 3.16, 1.0)
	wall_shape.shape = wall_box
	var board_outward := 1.0 if root.basis.z.dot(root.position) > 0 else -1.0
	wall_shape.position = Vector3(0, 1.08, 0.38 * board_outward)
	wall.add_child(wall_shape)
	var wall_material := PhysicsMaterial.new()
	wall_material.friction = 0.03
	wall_material.bounce = 0.55
	wall.physics_material_override = wall_material
	root.add_child(wall)
	# Protective netting above the end and corner glass, as in NHL arenas:
	# a lifted puck drops back into play instead of leaving the rink.
	if absf(root.position.z) > 21.0:
		var net := StaticBody3D.new()
		var net_shape := CollisionShape3D.new()
		var net_box := BoxShape3D.new()
		net_box.size = Vector3(length_, 7.0, 0.6)
		net_shape.shape = net_box
		net_shape.position = Vector3(0, 2.66 + 3.5, (0.12 + 0.3) * board_outward)
		net.add_child(net_shape)
		var net_material := PhysicsMaterial.new()
		net_material.friction = 0.8
		net_material.bounce = 0.05
		net.physics_material_override = net_material
		root.add_child(net)
		var mesh := block(root, Vector3(length_, 7.0, 0.01), Vector3(0, 2.66 + 3.5, 0.12 * board_outward), Color(0.05, 0.07, 0.09, 0.18))
		mesh.material_override.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	block(root, Vector3(length_, 0.18, 0.27), Vector3(0, 0.09, 0), Color("#e8ba37"))
	block(root, Vector3(length_, 0.08, 0.29), Vector3(0, 1.07, 0), Color("#19364f"))
	block(root, Vector3(length_, 1.55, 0.045), Vector3(0, 1.88, 0), Color(0.58, 0.8, 0.87, 0.12))
	tube(root, Vector3(-length_ / 2, 1.1, 0), Vector3(-length_ / 2, 2.66, 0), 0.025, Color("#8a9fac"))
	board_count += 1

func goal(end_sign: float) -> void:
	var root := Node3D.new()
	root.name = "NorthGoal" if end_sign < 0 else "SouthGoal"
	add_child(root)
	root.position.z = end_sign * 25
	if end_sign > 0:
		root.rotation.y = PI
	goals.append(root)
	for x in [-0.96, 0.96]:
		tube(root, Vector3(x, 0.04, 0), Vector3(x, 1.22, 0), 0.035, RED, true)
		tube(root, Vector3(x, 1.22, 0), Vector3(x * 0.85, 0.15, -1.1), 0.025, RED)
		# Collision cage invisible visually; mesh strands remain open and readable.
		var side := block(root, Vector3(0.06, 1.2, 1.1), Vector3(x, 0.6, -0.55), Color(1,1,1,0), true, 0.12)
		side.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	tube(root, Vector3(-0.96, 1.22, 0), Vector3(0.96, 1.22, 0), 0.035, RED, true)
	var back := block(root, Vector3(1.96, 1.2, 0.06), Vector3(0, 0.6, -1.12), Color(1,1,1,0), true, 0.12)
	back.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var roof:=block(root,Vector3(1.96,0.05,1.1),Vector3(0,1.20,-0.55),Color(1,1,1,0),true,0.12)
	roof.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for i in range(21):
		var x := lerpf(-0.95, 0.95, float(i) / 20)
		tube(root, Vector3(x, 0.06, -1.08), Vector3(x, 1.15, -1.08), 0.008, WHITE)
		tube(root, Vector3(x, 1.19, 0), Vector3(x, 1.15, -1.08), 0.008, WHITE)
	for i in range(12):
		var y := 0.06 + float(i) * 0.1
		tube(root, Vector3(-0.96, y, -1.08), Vector3(0.96, y, -1.08), 0.008, WHITE)
		for x in [-0.96, 0.96]:
			tube(root, Vector3(x, y, 0), Vector3(x, y, -1.08), 0.008, WHITE)
	for i in range(12):
		var z := -float(i) * 0.1
		for x in [-0.96, 0.96]:
			tube(root, Vector3(x, 0.06, z), Vector3(x, 1.16, z), 0.008, WHITE)

func _ready() -> void:
	block(self, Vector3(85, 0.5, 100), Vector3(0, -0.65, 0), Color("#101e31"))
	var ice := block(self, Vector3(30, 0.3, 60), Vector3(0, -0.15, 0), Color("#e4edf2"), true, 0.02)
	ice.get_child(0).physics_material_override.friction=0.0
	# The ice is on its own layer (5). Skaters stand on it; the puck does not
	# collide with it, because puck.gd supports the puck on the ice plane itself.
	# Jolt's continuous collision otherwise caught the ice under a resting puck
	# and stopped every sliding pass and shot dead.
	ice.get_child(0).collision_layer = 16
	ice.visible = false
	var ice_material := mat(Color("#afc0cc"),0.38)
	ice.material_override = ice_material
	# Rounded perimeter: half width 15, half length 30, 8 metre corners.
	var points: Array[Vector3] = []
	for corner in [Vector2(7, 22), Vector2(-7, 22), Vector2(-7,-22), Vector2(7,-22)]:
		var start := 0.0
		if corner.x < 0 and corner.y > 0: start = PI * 0.5
		if corner.x < 0 and corner.y < 0: start = PI
		if corner.x > 0 and corner.y < 0: start = PI * 1.5
		for i in range(17):
			var angle := start + float(i) / 16 * PI * 0.5
			points.append(Vector3(corner.x + cos(angle) * 8, 0, corner.y + sin(angle) * 8))
	var surface := ImmediateMesh.new()
	surface.surface_begin(Mesh.PRIMITIVE_TRIANGLES,ice_material)
	for i in range(points.size()):
		for v in [Vector3.ZERO, points[i], points[(i + 1) % points.size()]]:
			surface.surface_set_normal(Vector3.UP)
			surface.surface_set_uv(Vector2(v.x / 30, v.z / 60))
			surface.surface_add_vertex(v)
	surface.surface_end()
	var surface_instance := MeshInstance3D.new()
	surface_instance.mesh = surface
	var ice_shader := Shader.new()
	ice_shader.code = "shader_type spatial; render_mode cull_disabled; uniform sampler2D ice_tex:source_color,repeat_enable,filter_linear_mipmap; void fragment(){vec3 tex=texture(ice_tex,UV*vec2(3.0,6.0)).rgb;float grain=dot(tex,vec3(0.3,0.59,0.11));ALBEDO=vec3(0.43,0.45,0.46)+(grain-0.4)*0.035;ROUGHNESS=0.48;SPECULAR=0.3;}"
	var ice_shader_material := ShaderMaterial.new()
	ice_shader_material.shader = ice_shader
	ice_shader_material.set_shader_parameter("ice_tex",preload("res://assets/ice-surface-v1.png"))
	surface_instance.material_override = ice_shader_material
	add_child(surface_instance)
	for i in range(points.size()):
		board_segment(points[i], points[(i + 1) % points.size()])
	# All markings are flush at one elevation; intended widths are explicit.
	for z in [-10.0, 10.0]:
		block(self, Vector3(29.65, 0.006, 0.30), Vector3(0, 0.008, z), BLUE)
	block(self, Vector3(29.65, 0.006, 0.30), Vector3(0, 0.008, 0), RED)
	for z in [-25.0, 25.0]:
		block(self, Vector3(28.0, 0.006, 0.05), Vector3(0, 0.008, z), RED)
	ring(Vector3(0,0.013,0), 4.5, 0.075, BLUE)
	disc(Vector3(0,0.014,0), 0.18, BLUE)
	for z in [-20.0, 20.0]:
		for x in [-6.5, 6.5]:
			ring(Vector3(x,0.013,z), 4.5, 0.075, RED)
			disc(Vector3(x,0.015,z), 0.22, RED)
			for side in [-1.0,1.0]:
				for offset in [-0.7,0.7]:
					block(self, Vector3(0.6,0.006,0.05), Vector3(x + side * 0.7,0.014,z + offset), RED)
	for z in [-7.0,7.0]:
		for x in [-6.5,6.5]:
			disc(Vector3(x,0.014,z),0.18,RED)
	for sign_ in [-1.0, 1.0]:
		# Half-disc crease faces the play, with the goal mouth on its straight edge.
		var crease_mesh := ImmediateMesh.new()
		crease_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES,mat(Color("#618fa9")))
		var from := 0.0 if sign_ < 0 else PI
		var center := Vector3(0,0.012,sign_ * 25)
		for i in range(48):
			var a := from + float(i) / 48 * PI
			var b := from + float(i + 1) / 48 * PI
			for v in [center, center + Vector3(cos(a),0,sin(a)) * 1.8, center + Vector3(cos(b),0,sin(b)) * 1.8]:
				crease_mesh.surface_set_normal(Vector3.UP)
				crease_mesh.surface_add_vertex(v)
		crease_mesh.surface_end()
		var crease := MeshInstance3D.new()
		crease.mesh = crease_mesh
		add_child(crease)
		ring(center + Vector3(0,0.004,0),1.8,0.075,RED,from,from + PI)
		goal(sign_)
	var logo := Label3D.new()
	logo.text = "H / H"
	logo.font_size = 160
	logo.pixel_size = 0.018
	logo.modulate = Color("#173b58")
	logo.rotation_degrees.x = -90
	logo.position = Vector3(0, 0.022, 0)
	add_child(logo)
	# Occupied seating bowl: dark structural steps behind photographic crowd cards.
	for side in [-1.0,1.0]:
		for row in range(10):
			block(self, Vector3(1.0,0.45 + row * 0.5,61),Vector3(side * (16.5 + row * 0.9),row * 0.25,0),Color("#0f1a27"))
		block(self,Vector3(0.2,1.2,64),Vector3(side * 25.6,5.5,0),Color("#101c2c"))
		block(self,Vector3(0.1,0.20,62),Vector3(side * 25.4,5.9,0),Color("#1d7d99"))
	add_child(preload("res://scripts/crowd.gd").new())
	for side in [-1.0,1.0]:
		block(self, Vector3(30,1.5,2), Vector3(0,0.75,side * 33), Color("#152a40"))
		var banner := Label3D.new()
		banner.text = "H A W K E Y     /     P R A C T I C E   C E N T R E"
		banner.font_size = 72
		banner.pixel_size = 0.015
		banner.position = Vector3(0,1.5,side * 32)
		if side > 0: banner.rotation.y = PI
		add_child(banner)
