extends Control
## Fixed screen-space black/white cue; never changes puck physics or scale.
func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	size=Vector2(32,32)
	visible=false
func _draw() -> void:
	draw_arc(Vector2(16,16),10,0,TAU,48,Color.BLACK,5,true)
	draw_arc(Vector2(16,16),10,0,TAU,48,Color.WHITE,2,true)
	for direction in [Vector2.UP,Vector2.DOWN,Vector2.LEFT,Vector2.RIGHT]:
		draw_line(Vector2(16,16)+direction*12,Vector2(16,16)+direction*16,Color.BLACK,3,true)
func track(camera: Camera3D, point: Vector3, enabled: bool) -> void:
	visible=enabled and not camera.is_position_behind(point)
	if not visible: return
	var screen:=camera.unproject_position(point)
	visible=Rect2(Vector2.ZERO,get_viewport_rect().size).has_point(screen)
	position=screen-Vector2(16,16)
