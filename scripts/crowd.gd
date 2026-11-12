extends Node3D
## Photographic AI-generated people on fixed seating cards (not 3D spectators).
const IMAGE = preload("res://assets/crowd-spectators-v1.png")
var people_estimate := 0

func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 17031
	for side in [-1.0,1.0]:
		for row in range(10):
			for section in range(12):
				var card := MeshInstance3D.new()
				var quad := QuadMesh.new()
				quad.size = Vector2(4.5,1.5)
				card.mesh = quad
				var m := StandardMaterial3D.new()
				m.albedo_texture = IMAGE
				var brightness := rng.randf_range(0.50,0.8)
				m.albedo_color = Color(brightness,brightness,brightness)
				m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
				m.alpha_scissor_threshold = 0.4
				m.cull_mode = BaseMaterial3D.CULL_DISABLED
				m.roughness = 1
				# Baked photographic lighting avoids washed-out faces.
				m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
				card.material_override = m
				card.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				card.position = Vector3(side * (preload("res://scripts/arena.gd").HALF_WIDTH + 1.5 + row * 0.9),1.0 + row * 0.5,-25 + section * 4.5)
				card.rotation.y = -side * PI / 2
				card.scale.x = -1 if rng.randf() > 0.5 else 1
				add_child(card)
				people_estimate += 8
