extends Node3D
const GoalNet = preload("res://scripts/goal_net.gd")
const Benches = preload("res://scripts/arena_benches.gd")
## Original procedural rink. Units are metres; visual markings share one ice plane.
const RED = Color("#8f1631")
const BLUE = Color("#174b8c")
const WHITE = Color("#f0f5fa")
## Rink markings to NHL Rule 1 proportions on the 60 m rink (z is the long
## axis, centre ice at 0). Feet converted at 0.3048 m.
const FT := 0.3048
## NHL sheet: 85 ft wide with 28 ft corner radii (the length stays 60 m,
## within a foot of the 200 ft standard). Board face at |x| = HALF_WIDTH.
const HALF_WIDTH := 42.5 * FT            # 12.95 m
const HALF_LENGTH := 30.0
const CORNER_RADIUS := 28.0 * FT         # 8.53 m
## Distance from centre ice where the corner arcs begin.
const CORNER_START := HALF_LENGTH - CORNER_RADIUS
const GOAL_LINE := HALF_LENGTH - 11.0 * FT      # 11 ft from the end boards
const BLUE_LINE := 25.0 * FT             # 25 ft either side of centre
const LINE_WIDTH := 12.0 * 0.0254        # red and blue lines: 12 in
const GOAL_LINE_WIDTH := 2.0 * 0.0254    # goal lines and circles: 2 in
const CIRCLE_RADIUS := 15.0 * FT
const DOT_X := 22.0 * FT                 # faceoff spots 44 ft apart
const END_DOT_Z := GOAL_LINE - 20.0 * FT # end-zone spots 20 ft out from the goal line
const NEUTRAL_DOT_Z := BLUE_LINE - 5.0 * FT  # neutral-zone spots 5 ft inside the blue line
const CREASE_RADIUS := 6.0 * FT
var board_count := 0
var goals: Array[Node3D] = []
## Ice surface shader; `cut_tex` receives the skate-cut map (ice_marks.gd).
var ice_surface_material: ShaderMaterial
## Painted markings (lines, circles, spots, crease, trapezoid) sit a few mm
## above the ice plane, so they sample the same skate-cut map by world
## position: cuts and wear run straight across the paint, frosting it, instead
## of stopping at its edge. One material per paint colour (paint()).
var paint_materials: Array[ShaderMaterial] = []
## Transparent frost layer over the centre emblem (discs + text): carries the
## cuts across the logo, which a Label3D cannot sample itself.
var emblem_wear: MeshInstance3D
var _paint_by_color := {}
var _paint_shader: Shader
var _wear_shader: Shader
## Players mirrored in the ice (scripts/ice_reflection.gd): a mirror-camera
## render of the skaters, sampled at the mirrored screen position with a soft
## vertical smear, Fresnel-weighted and weaker where the ice is cut. Returns
## (radiance to add, how much of the diffuse ice it replaces). Shared by the
## ice sheet and the painted markings so the mirror image runs across lines.
const REFLECT_COMMON := """
uniform sampler2D reflection_tex:source_color,filter_linear,repeat_disable,hint_default_transparent;
uniform float reflection_strength = 0.0;
uniform float reflection_blur = 0.003;
// The mirror image is of undersides that the real ice sees lit by its own
// bounce; brighten it so kit colours read in the smear instead of grey.
uniform float reflection_gain = 1.8;
vec4 ice_reflection(vec2 suv, vec3 n, vec3 v, float cut, float fresh_){
	if(reflection_strength<=0.0) return vec4(0.0);
	vec2 ruv=vec2(1.0-suv.x,suv.y);
	float b=reflection_blur;
	vec4 r=texture(reflection_tex,ruv)*0.30;
	r+=texture(reflection_tex,ruv+vec2(0.0,b))*0.22;
	r+=texture(reflection_tex,ruv-vec2(0.0,b))*0.22;
	r+=texture(reflection_tex,ruv+vec2(b*0.5,b*2.4))*0.13;
	r+=texture(reflection_tex,ruv-vec2(b*0.5,b*2.4))*0.13;
	float fres=0.35+0.65*pow(1.0-clamp(dot(n,v),0.0,1.0),3.0);
	float k=reflection_strength*fres*(1.0-0.75*cut)*(0.85+0.3*fresh_);
	return vec4(r.rgb*k*reflection_gain,r.a*k);
}
"""
## Shared by the paint and emblem-wear shaders: same channels and response as
## the ice shader (R = scratches, G = wear haze), mapped from world x/z.
const CUT_COMMON := """
const float RINK_W = 25.908;
const float RINK_L = 60.0;
uniform sampler2D cut_tex:filter_linear_mipmap,repeat_disable,hint_default_black;
uniform float fresh = 0.0;
varying vec2 rink_uv;
const vec3 FROST = vec3(0.80,0.82,0.85);
void vertex(){vec3 w=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;rink_uv=vec2(w.x/RINK_W+0.5,w.z/RINK_L+0.5);}
"""

func mat(color: Color, roughness: float = 0.5) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if color.a < 1:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m

## Paint under the ice surface: its colour, frosted where skates cut or wear it.
func paint(color: Color) -> ShaderMaterial:
	var key := color.to_html()
	if _paint_by_color.has(key): return _paint_by_color[key]
	if _paint_shader == null:
		_paint_shader = Shader.new()
		_paint_shader.code = "shader_type spatial; render_mode cull_disabled;\nuniform vec4 paint_color:source_color;" + CUT_COMMON + REFLECT_COMMON + """
void fragment(){
	vec2 cm=texture(cut_tex,rink_uv).rg;
	float scratch=clamp(cm.r*1.6,0.0,1.0);
	float haze=smoothstep(0.0,0.6,cm.g);
	float cut=clamp(scratch+haze*0.8,0.0,1.0);
	vec3 a=mix(paint_color.rgb,FROST,haze*0.55);
	a=mix(a,FROST*0.78,clamp(scratch*0.85,0.0,0.8));
	vec4 refl=ice_reflection(SCREEN_UV,NORMAL,VIEW,cut,fresh);
	ALBEDO=a*(1.0-0.06*fresh)*(1.0-refl.a);
	EMISSION=refl.rgb;
	ROUGHNESS=clamp(mix(0.22,0.6,cut)-0.17*fresh,0.05,1.0);
	SPECULAR=mix(0.5,0.3,haze)+0.25*fresh;
}"""
	var m := ShaderMaterial.new()
	m.shader = _paint_shader
	m.set_shader_parameter("paint_color", color)
	_paint_by_color[key] = m
	paint_materials.append(m)
	return m

## Frost-only layer (alpha = how cut the ice is) laid over the centre emblem.
func wear_material() -> ShaderMaterial:
	if _wear_shader == null:
		_wear_shader = Shader.new()
		_wear_shader.code = "shader_type spatial; render_mode cull_disabled,depth_draw_never;" + CUT_COMMON + """
void fragment(){
	vec2 cm=texture(cut_tex,rink_uv).rg;
	float scratch=clamp(cm.r*1.6,0.0,1.0)*0.8;
	float haze=smoothstep(0.0,0.6,cm.g)*0.55;
	float cover=1.0-(1.0-scratch)*(1.0-haze);
	ALBEDO=mix(FROST,FROST*0.78,scratch/(scratch+haze+0.0001))*(1.0-0.06*fresh);
	ALPHA=clamp(cover,0.0,0.85);
	ROUGHNESS=clamp(mix(0.22,0.6,cover)-0.17*fresh,0.05,1.0);
	SPECULAR=0.4+0.25*fresh;
}"""
	var m := ShaderMaterial.new()
	m.shader = _wear_shader
	m.render_priority = 1   # always over the Label3D text at the same depth
	paint_materials.append(m)
	return m

## Hands the skaters' mirror image (ice_reflection.gd) to the ice and the
## painted markings.
func set_reflection(texture: Texture2D, strength: float, blur: float) -> void:
	for m in [ice_surface_material] + paint_materials:
		m.set_shader_parameter("reflection_tex", texture)
		m.set_shader_parameter("reflection_strength", strength)
		m.set_shader_parameter("reflection_blur", blur)

## Hands the skate-cut map to the ice and every painted marking.
func set_cut_map(texture: Texture2D) -> void:
	ice_surface_material.set_shader_parameter("cut_tex", texture)
	for m in paint_materials: m.set_shader_parameter("cut_tex", texture)

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

## Flat painted marking (line, hash, L leg) on the ice.
func line(size: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
	var m := block(self, size, pos, color)
	m.material_override = paint(color)
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return m

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
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, paint(color))
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

func disc(center: Vector3, radius: float, color: Color, painted := true) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = radius
	cylinder.bottom_radius = radius
	cylinder.height = 0.003
	mesh.mesh = cylinder
	mesh.material_override = paint(color) if painted else mat(color)
	mesh.position = center
	add_child(mesh)
	return mesh

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
	if absf(root.position.z) > CORNER_START - 0.5:
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
	board_glass(root, length_)
	tube(root, Vector3(-length_ / 2, 1.1, 0), Vector3(-length_ / 2, 2.66, 0), 0.025, Color("#8a9fac"))
	board_count += 1

## Glass above the boards. Along the west straight it is left out in front
## of the player benches (arena_benches.gd glass_openings()); the collider in
## board_segment() still runs the full length.
func board_glass(root: Node3D, length_: float) -> void:
	var glass_color := Color(0.58, 0.8, 0.87, 0.12)
	var pieces: Array[Vector2] = [Vector2(-length_ / 2, length_ / 2)]
	if root.position.x < -(HALF_WIDTH - 0.3) and length_ > 10.0:
		# Local x runs along the segment; world z = position.z + x * basis.x.z.
		var dir := signf(root.basis.x.z)
		for gap in Benches.glass_openings():
			var lo := minf((gap.x - root.position.z) * dir, (gap.y - root.position.z) * dir)
			var hi := maxf((gap.x - root.position.z) * dir, (gap.y - root.position.z) * dir)
			var next: Array[Vector2] = []
			for piece in pieces:
				if hi <= piece.x or lo >= piece.y:
					next.append(piece)
					continue
				if lo > piece.x: next.append(Vector2(piece.x, lo))
				if hi < piece.y: next.append(Vector2(hi, piece.y))
			pieces = next
	for piece in pieces:
		var glass := block(root, Vector3(piece.y - piece.x, 1.55, 0.045), Vector3((piece.x + piece.y) * 0.5, 1.88, 0), glass_color)
		glass.name = "BoardGlass"

## Half-width of the rink (to the board face) at distance `z` from centre.
static func corner_half_width(z: float) -> float:
	if z <= CORNER_START: return HALF_WIDTH
	var dz := z - CORNER_START
	return HALF_WIDTH - CORNER_RADIUS + sqrt(maxf(0.0, CORNER_RADIUS * CORNER_RADIUS - dz * dz))

## End-zone faceoff circle: 15 ft ring, 2 ft spot, two pairs of 2 ft hash
## marks on the outside of the ring (5 ft 7 in apart) and the four L marks
## around the spot.
func end_zone_circle(c: Vector3) -> void:
	ring(Vector3(c.x, 0.013, c.z), CIRCLE_RADIUS, GOAL_LINE_WIDTH, RED)
	disc(Vector3(c.x, 0.015, c.z), 1.0 * FT, RED)
	var hash_gap := (5.0 * FT + 7.0 * 0.0254) * 0.5
	var hash_len := 2.0 * FT
	for side in [-1.0, 1.0]:
		for dz in [-hash_gap, hash_gap]:
			# Start on the ring and run outward, parallel to the goal line.
			var on_ring := sqrt(CIRCLE_RADIUS * CIRCLE_RADIUS - dz * dz)
			line(Vector3(hash_len, 0.006, GOAL_LINE_WIDTH), Vector3(c.x + side * (on_ring + hash_len * 0.5), 0.014, c.z + dz), RED)
	# L marks: 4 ft legs parallel to the goal line, 3 ft legs toward the ends,
	# corners 2 ft either side of the spot and 9 in above/below it.
	var lx := 2.0 * FT
	var lz := 0.75 * FT
	for side in [-1.0, 1.0]:
		for dir in [-1.0, 1.0]:
			line(Vector3(4.0 * FT, 0.006, GOAL_LINE_WIDTH), Vector3(c.x + side * (lx + 2.0 * FT), 0.014, c.z + dir * lz), RED)
			line(Vector3(GOAL_LINE_WIDTH, 0.006, 3.0 * FT), Vector3(c.x + side * lx, 0.014, c.z + dir * (lz + 1.5 * FT)), RED)

## Goaltender trapezoid behind each net: 22 ft wide at the goal line,
## 28 ft at the end boards.
func trapezoid(end_sign: float) -> void:
	for side in [-1.0, 1.0]:
		var a := Vector3(side * 11.0 * FT, 0.012, end_sign * GOAL_LINE)
		var b := Vector3(side * 14.0 * FT, 0.012, end_sign * 29.92)
		var seg := line(Vector3(GOAL_LINE_WIDTH, 0.006, a.distance_to(b)), (a + b) * 0.5, RED)
		seg.rotation.y = atan2(b.x - a.x, b.z - a.z)

func goal(end_sign: float) -> void:
	var root := GoalNet.new()
	root.name = "NorthGoal" if end_sign < 0 else "SouthGoal"
	add_child(root)
	root.position.z = end_sign * GOAL_LINE
	if end_sign > 0:
		root.rotation.y = PI
	goals.append(root)
	root.build(self)

## Ripples the netting when the puck hits it: a sharp change in the puck's
## velocity while it is inside (or right against) a net. Set by lab.gd.
var puck: RigidBody3D
var _puck_velocity := Vector3.ZERO

func _physics_process(_delta: float) -> void:
	if puck == null or not is_instance_valid(puck): return
	var v := puck.linear_velocity
	var change := (v - _puck_velocity).length()
	var speed := _puck_velocity.length()
	if speed > 1.5 and change > maxf(1.5, speed * 0.3):
		for g in goals:
			var local: Vector3 = g.to_local(puck.global_position)
			# Mouth-plane crossings and post/crossbar hits are not net hits.
			if local.z < -0.08 and GoalNet.near_net(local):
				g.impact(local, speed)
	_puck_velocity = v

func _ready() -> void:
	block(self, Vector3(85, 0.5, 100), Vector3(0, -0.65, 0), Color("#101e31"))
	var ice := block(self, Vector3(HALF_WIDTH * 2.0, 0.3, HALF_LENGTH * 2.0), Vector3(0, -0.15, 0), Color("#e4edf2"), true, 0.02)
	ice.get_child(0).physics_material_override.friction=0.0
	# The ice is on its own layer (5). Skaters stand on it; the puck does not
	# collide with it, because puck.gd supports the puck on the ice plane itself.
	# Jolt's continuous collision otherwise caught the ice under a resting puck
	# and stopped every sliding pass and shot dead.
	ice.get_child(0).collision_layer = 16
	ice.visible = false
	var ice_material := mat(Color("#afc0cc"),0.38)
	ice.material_override = ice_material
	# Rounded perimeter: 85 ft wide, 60 m long, 28 ft corners.
	var points: Array[Vector3] = []
	var cx := HALF_WIDTH - CORNER_RADIUS
	for corner in [Vector2(cx, CORNER_START), Vector2(-cx, CORNER_START), Vector2(-cx, -CORNER_START), Vector2(cx, -CORNER_START)]:
		var start := 0.0
		if corner.x < 0 and corner.y > 0: start = PI * 0.5
		if corner.x < 0 and corner.y < 0: start = PI
		if corner.x > 0 and corner.y < 0: start = PI * 1.5
		for i in range(17):
			var angle := start + float(i) / 16 * PI * 0.5
			points.append(Vector3(corner.x + cos(angle) * CORNER_RADIUS, 0, corner.y + sin(angle) * CORNER_RADIUS))
	var surface := ImmediateMesh.new()
	surface.surface_begin(Mesh.PRIMITIVE_TRIANGLES,ice_material)
	for i in range(points.size()):
		for v in [Vector3.ZERO, points[i], points[(i + 1) % points.size()]]:
			surface.surface_set_normal(Vector3.UP)
			surface.surface_set_uv(Vector2(v.x / (HALF_WIDTH * 2.0), v.z / (HALF_LENGTH * 2.0)))
			surface.surface_add_vertex(v)
	surface.surface_end()
	var surface_instance := MeshInstance3D.new()
	surface_instance.mesh = surface
	var ice_shader := Shader.new()
	# Bright sheet, exposed so it does not clip to pure white. cut_tex
	# (ice_marks.gd): R = thin anti-aliased blade scratches (grey, matte),
	# G = wear haze (duller, snowy); 0 = clean. UV + 0.5 maps the cut map.
	# Board reflection: a faint mirrored band of the kick plate/dashers right at
	# the boards, then a softer blue-grey smear of glass and stands. `fresh`
	# (1 just after a flood, drying to 0; set by ice_marks.gd) makes the sheet
	# glossier and a touch darker. Reflections fade where the ice is cut up.
	ice_shader.code = """shader_type spatial; render_mode cull_disabled;
uniform sampler2D ice_tex:source_color,repeat_enable,filter_linear_mipmap;
uniform sampler2D cut_tex:filter_linear_mipmap,repeat_disable,hint_default_black;
uniform float fresh = 0.0;
uniform vec2 half_size = vec2(12.954, 30.0);
uniform float corner_radius = 8.5344;
""" + REFLECT_COMMON + """
float board_distance(vec2 p){vec2 inner=half_size-vec2(corner_radius);vec2 d=abs(p)-inner;return corner_radius-(length(max(d,vec2(0.0)))+min(max(d.x,d.y),0.0));}
void fragment(){
	vec3 tex=texture(ice_tex,UV*vec2(2.6,6.0)).rgb;float grain=dot(tex,vec3(0.3,0.59,0.11));
	vec2 cm=texture(cut_tex,UV+0.5).rg;
	float scratch=clamp(cm.r*1.6,0.0,1.0)*(0.75+grain*0.6);
	float haze=smoothstep(0.0,0.6,cm.g);
	float cut=clamp(scratch+haze*0.8,0.0,1.0);
	vec3 base=vec3(0.64,0.67,0.70)+(grain-0.4)*0.05;
	vec3 albedo=mix(base,vec3(0.79,0.81,0.84),haze*0.7);
	albedo=mix(albedo,base*vec3(0.70,0.74,0.78),clamp(scratch*0.75,0.0,0.75));
	float d=max(board_distance(UV*half_size*2.0),0.0);
	float dasher=exp(-d/0.35);float stands=exp(-d/1.6)-dasher;
	float mirror=(1.0-0.7*cut)*(0.75+0.25*fresh);
	albedo=mix(albedo,vec3(0.78,0.74,0.55),dasher*0.32*mirror);
	albedo=mix(albedo,vec3(0.30,0.35,0.46),stands*0.30*mirror);
	ALBEDO=albedo*(1.0-0.06*fresh);
	vec4 refl=ice_reflection(SCREEN_UV,NORMAL,VIEW,cut,fresh);
	ALBEDO*=1.0-refl.a;
	EMISSION=refl.rgb;
	ROUGHNESS=clamp(mix(0.22,0.6,cut)-0.17*fresh,0.05,1.0);
	SPECULAR=mix(0.5,0.3,haze)+0.25*fresh;
}"""
	var ice_shader_material := ShaderMaterial.new()
	ice_shader_material.shader = ice_shader
	ice_shader_material.set_shader_parameter("ice_tex",preload("res://assets/ice-surface-v1.png"))
	surface_instance.material_override = ice_shader_material
	ice_surface_material = ice_shader_material
	add_child(surface_instance)
	for i in range(points.size()):
		board_segment(points[i], points[(i + 1) % points.size()])
	# All markings are flush at one elevation; intended widths are explicit.
	for z in [-BLUE_LINE, BLUE_LINE]:
		line(Vector3(HALF_WIDTH * 2.0 - 0.35, 0.006, LINE_WIDTH), Vector3(0, 0.008, z), BLUE)
	line(Vector3(HALF_WIDTH * 2.0 - 0.35, 0.006, LINE_WIDTH), Vector3(0, 0.008, 0), RED)
	# Centre red line is broken by the faceoff circle's blue ring only visually.
	for z in [-GOAL_LINE, GOAL_LINE]:
		# Goal line runs board to board: chord of the corner arc at this depth.
		var half := corner_half_width(absf(z)) - 0.05
		line(Vector3(half * 2.0, 0.006, GOAL_LINE_WIDTH), Vector3(0, 0.008, z), RED)
	ring(Vector3(0,0.013,0), CIRCLE_RADIUS, GOAL_LINE_WIDTH, BLUE)
	disc(Vector3(0,0.014,0), 0.5 * FT, BLUE)
	for z in [-END_DOT_Z, END_DOT_Z]:
		for x in [-DOT_X, DOT_X]:
			end_zone_circle(Vector3(x, 0.0, z))
	for z in [-NEUTRAL_DOT_Z, NEUTRAL_DOT_Z]:
		for x in [-DOT_X, DOT_X]:
			disc(Vector3(x,0.014,z), 1.0 * FT, RED)
	for sign_ in [-1.0, 1.0]:
		trapezoid(sign_)
	for sign_ in [-1.0, 1.0]:
		# Half-disc crease faces the play, with the goal mouth on its straight edge.
		var crease_mesh := ImmediateMesh.new()
		crease_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES,paint(Color("#618fa9")))
		var from := 0.0 if sign_ < 0 else PI
		var center := Vector3(0,0.012,sign_ * GOAL_LINE)
		for i in range(48):
			var a := from + float(i) / 48 * PI
			var b := from + float(i + 1) / 48 * PI
			for v in [center, center + Vector3(cos(a),0,sin(a)) * CREASE_RADIUS, center + Vector3(cos(b),0,sin(b)) * CREASE_RADIUS]:
				crease_mesh.surface_set_normal(Vector3.UP)
				crease_mesh.surface_add_vertex(v)
		crease_mesh.surface_end()
		var crease := MeshInstance3D.new()
		crease.mesh = crease_mesh
		add_child(crease)
		ring(center + Vector3(0,0.004,0),CREASE_RADIUS,GOAL_LINE_WIDTH,RED,from,from + PI)
		goal(sign_)
	# Centre-ice emblem.
	# Plain paint underneath: the emblem_wear layer frosts discs and text alike.
	disc(Vector3(0,0.016,0), 2.35, Color("#0d2a52"), false)
	disc(Vector3(0,0.018,0), 2.1, Color("#eef3f7"), false)
	disc(Vector3(0,0.020,0), 1.95, Color("#164a9a"), false)
	var logo := Label3D.new()
	logo.text = "HAWKEY"
	logo.font_size = 96
	logo.pixel_size = 0.0068
	logo.outline_size = 0
	logo.modulate = Color("#f4f7fa")
	logo.rotation_degrees.x = -90
	logo.position = Vector3(0, 0.024, 0)
	add_child(logo)
	emblem_wear = disc(Vector3(0,0.027,0), 2.36, Color.WHITE, false)
	emblem_wear.name = "EmblemWear"
	emblem_wear.material_override = wear_material()
	emblem_wear.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var dressing := preload("res://scripts/arena_dressing.gd").new()
	var title = get_parent().get("arena_title") if get_parent() else null
	if title != null: dressing.arena_name = title
	dressing.name = "Dressing"
	add_child(dressing)
	dressing.add_board_ads(points)
	var benches := Benches.new()
	benches.name = "Benches"
	add_child(benches)
