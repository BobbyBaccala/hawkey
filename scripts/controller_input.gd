extends RefCounted
## Controller-first input adapter; Godot's standard joypad mapping needs no add-on.
var device_id := -1
var active := false
var connected := false
var deadzone := 0.18
var left_raw := Vector2.ZERO
var right_raw := Vector2.ZERO
var left_stick := Vector2.ZERO
var right_stick := Vector2.ZERO
var lift := 0.0
var shoot_trigger := 0.0
var trigger_down := false
var shoot_pressed := false
var shoot_released := false
var pass_pressed := false
var saucer_pressed := false
var switch_pressed := false
var check_pressed := false
var poke_pressed := false
var pause_pressed := false
var line_delta := 0
var pair_delta := 0
var effort := false
var stop := false

static func radial(value: Vector2, zone: float) -> Vector2:
	var magnitude := value.length()
	if magnitude <= zone: return Vector2.ZERO
	return value.normalized()*clampf((magnitude-zone)/(1-zone),0,1)

func handle(event: InputEvent) -> void:
	if event is InputEventJoypadMotion:
		device_id=event.device
		connected=true
		if absf(event.axis_value)>deadzone:
			active=true
		match event.axis:
			JOY_AXIS_LEFT_X: left_raw.x=event.axis_value
			JOY_AXIS_LEFT_Y: left_raw.y=event.axis_value
			JOY_AXIS_RIGHT_X: right_raw.x=event.axis_value
			JOY_AXIS_RIGHT_Y: right_raw.y=event.axis_value
			JOY_AXIS_TRIGGER_LEFT: lift=clampf(event.axis_value,0,1)
			JOY_AXIS_TRIGGER_RIGHT:
				shoot_trigger=clampf(event.axis_value,0,1)
				if not trigger_down and shoot_trigger>0.18:
					trigger_down=true
					shoot_pressed=true
				elif trigger_down and shoot_trigger<0.08:
					trigger_down=false
					shoot_released=true
		left_stick=radial(left_raw,deadzone)
		right_stick=radial(right_raw,deadzone)
	elif event is InputEventJoypadButton:
		device_id=event.device
		connected=true
		active=true
		if event.button_index==JOY_BUTTON_LEFT_STICK: effort=event.pressed
		if event.button_index==JOY_BUTTON_RIGHT_STICK: stop=event.pressed
		if not event.pressed: return
		match event.button_index:
			JOY_BUTTON_A: switch_pressed=true
			JOY_BUTTON_B: check_pressed=true
			JOY_BUTTON_X: poke_pressed=true
			JOY_BUTTON_Y: saucer_pressed=true
			JOY_BUTTON_RIGHT_SHOULDER: pass_pressed=true
			JOY_BUTTON_START: pause_pressed=true
			JOY_BUTTON_DPAD_UP: line_delta=1
			JOY_BUTTON_DPAD_DOWN: line_delta=-1
			JOY_BUTTON_DPAD_LEFT: pair_delta=-1
			JOY_BUTTON_DPAD_RIGHT: pair_delta=1

func disconnected(id_: int) -> bool:
	if id_!=device_id: return false
	var was_active:=active
	left_raw=Vector2.ZERO
	right_raw=Vector2.ZERO
	left_stick=Vector2.ZERO
	right_stick=Vector2.ZERO
	lift=0
	shoot_trigger=0
	trigger_down=false
	effort=false
	stop=false
	active=false
	connected=false
	clear_edges()
	return was_active

func clear_edges() -> void:
	shoot_pressed=false
	shoot_released=false
	pass_pressed=false
	saucer_pressed=false
	switch_pressed=false
	check_pressed=false
	poke_pressed=false
	pause_pressed=false
	line_delta=0
	pair_delta=0
