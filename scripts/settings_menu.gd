extends Control
const UI=preload("res://scripts/mode_ui.gd")
const Settings=preload("res://scripts/game_settings.gd")
var settings:=Settings.new()
var camera: OptionButton
var zone: HSlider
var value_label: Label
var message: Label
var sound_level: HSlider
var sound_label: Label
var motion: CheckButton
var puck_cue: CheckButton
var focus_order: Array[Control]=[]
func text(parent: Node, value: String, size: int=17, color: Color=UI.INK) -> Label:
	var label:=UI.text(value,size,color);label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;parent.add_child(label);return label
func _ready() -> void:
	settings.load_settings()
	var box:=UI.setup(self)
	box.add_child(UI.text("PREFERENCES  /  PLAY YOUR WAY",14,UI.ACCENT))
	box.add_child(UI.text("Make the ice yours",40))
	box.add_child(UI.text("Saved independently of your GM season.",18,UI.MUTED))
	var columns:=HBoxContainer.new();columns.add_theme_constant_override("separation",20);columns.size_flags_vertical=Control.SIZE_EXPAND_FILL;box.add_child(columns)
	var general:=UI.card(columns);var access:=UI.card(columns)
	text(general,"Controls & sound",26)
	text(general,"Default match camera",20)
	camera=OptionButton.new()
	for value in ["Dynamic","Overhead","Broadcast","Full rink"]: camera.add_item(value)
	camera.select(int(settings.values.camera));general.add_child(camera)
	text(general,"Controller stick dead zone",20)
	value_label=text(general,"",16,UI.MUTED)
	zone=HSlider.new();zone.min_value=0.05;zone.max_value=0.4;zone.step=0.01;zone.value=settings.values.deadzone;zone.custom_minimum_size.y=40
	zone.value_changed.connect(func(value): value_label.text="%d%% · Increase to reduce stick drift"%roundi(value*100));general.add_child(zone);zone.value_changed.emit(zone.value)
	text(general,"On-ice sound effects",20)
	sound_label=text(general,"",16,UI.MUTED)
	sound_level=HSlider.new();sound_level.min_value=0;sound_level.max_value=1;sound_level.step=0.05;sound_level.value=settings.values.sfx_volume;sound_level.custom_minimum_size.y=40
	sound_level.value_changed.connect(func(value): sound_label.text="Muted" if value==0 else "%d%%"%roundi(value*100));general.add_child(sound_level);sound_level.value_changed.emit(sound_level.value)
	text(general,"Camera applies in matches. Dead zone and sound apply in matches and Practice.",16,UI.MUTED)
	text(access,"Visibility & comfort",26)
	motion=CheckButton.new();motion.text="Reduced motion";motion.button_pressed=settings.values.reduce_motion;motion.custom_minimum_size.y=54;access.add_child(motion)
	motion.toggled.connect(func(on): motion.text="Reduced motion · "+("On" if on else "Off"));motion.toggled.emit(motion.button_pressed)
	text(access,"Use a fixed full-rink camera. Stop menu orbiting, banner zoom and animated goal flashes. Skating and rules stay active.",17,UI.MUTED)
	puck_cue=CheckButton.new();puck_cue.text="High-contrast puck marker";puck_cue.button_pressed=settings.values.puck_indicator;puck_cue.custom_minimum_size.y=54;access.add_child(puck_cue)
	puck_cue.toggled.connect(func(on): puck_cue.text="High-contrast puck marker · "+("On" if on else "Off"));puck_cue.toggled.emit(puck_cue.button_pressed)
	text(access,"A black-and-white ring follows the puck on screen without changing puck size or physics. Available in Play Now, GM matches and Practice.",17,UI.MUTED)
	text(access,"MARKER PREVIEW",14,UI.ACCENT)
	var preview:=Control.new();preview.custom_minimum_size.y=52;access.add_child(preview)
	var ice:=ColorRect.new();ice.color=Color("#c8d5dc");ice.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);preview.add_child(ice)
	var marker=preload("res://scripts/puck_indicator.gd").new();preview.add_child(marker);marker.position=Vector2(18,10);marker.visible=true
	var caption:=UI.text("Black + white · readable without color",15,Color("#102338"));caption.position=Vector2(64,15);preview.add_child(caption)
	text(access,"KEYBOARD & CONTROLLER",14,UI.ACCENT)
	text(access,"Tab / Shift+Tab: move focus\nArrows / D-pad: navigate\nEnter / A / ×: activate\nArrow keys: adjust a focused slider",17,UI.MUTED)
	var actions:=HBoxContainer.new();actions.add_theme_constant_override("separation",14);box.add_child(actions)
	var save:=UI.button("Save preferences",save_preferences);actions.add_child(save)
	var back:=UI.button("Return to menu",func():
		load("res://scripts/match.gd").return_to_title=true
		get_tree().change_scene_to_file("res://main.tscn"));actions.add_child(back)
	message=UI.text(settings.error,17,UI.ACCENT);message.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;box.add_child(message)
	focus_order.assign([camera,zone,sound_level,motion,puck_cue,save,back])
	for i in range(focus_order.size()):
		var control:=focus_order[i];control.focus_mode=Control.FOCUS_ALL
		control.focus_next=control.get_path_to(focus_order[(i+1)%focus_order.size()])
		control.focus_previous=control.get_path_to(focus_order[(i-1+focus_order.size())%focus_order.size()])
		control.focus_neighbor_bottom=control.focus_next;control.focus_neighbor_top=control.focus_previous
	camera.focus_neighbor_right=camera.get_path_to(motion);zone.focus_neighbor_right=zone.get_path_to(motion);sound_level.focus_neighbor_right=sound_level.get_path_to(puck_cue)
	motion.focus_neighbor_left=motion.get_path_to(camera);puck_cue.focus_neighbor_left=puck_cue.get_path_to(sound_level)
	camera.grab_focus.call_deferred()
func save_preferences() -> void:
	message.text="Preferences saved." if settings.save_settings(camera.selected,zone.value,sound_level.value,motion.button_pressed,puck_cue.button_pressed) else settings.error
