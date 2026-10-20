extends Control
const UI=preload("res://scripts/mode_ui.gd")
const Settings=preload("res://scripts/game_settings.gd")
var settings:=Settings.new()
var camera: OptionButton
var zone: HSlider
var value_label: Label
var message: Label
func _ready() -> void:
	settings.load_settings()
	var box:=UI.setup(self)
	box.add_child(UI.text("PREFERENCES",14,UI.ACCENT))
	box.add_child(UI.text("Make the ice yours",40))
	box.add_child(UI.text("Saved independently of your GM season.",18,UI.MUTED))
	var card:=UI.card(box)
	card.add_child(UI.text("Default match camera",22))
	camera=OptionButton.new()
	for value in ["Dynamic","Overhead","Broadcast","Full rink"]: camera.add_item(value)
	camera.select(int(settings.values.camera));card.add_child(camera)
	card.add_child(UI.text("Controller stick dead zone",22))
	value_label=UI.text("");card.add_child(value_label)
	zone=HSlider.new();zone.min_value=0.05;zone.max_value=0.4;zone.step=0.01;zone.value=settings.values.deadzone
	zone.custom_minimum_size.y=40;zone.value_changed.connect(func(value): value_label.text="%d%% · Increase to reduce stick drift"%roundi(value*100));card.add_child(zone)
	zone.value_changed.emit(zone.value)
	card.add_child(UI.text("Camera applies in Play Now and GM matches. Dead zone applies in matches and Practice.",16,UI.MUTED))
	var save:=UI.button("Save preferences",save_preferences);box.add_child(save)
	box.add_child(UI.button("Return to menu",func():
		load("res://scripts/match.gd").return_to_title=true
		get_tree().change_scene_to_file("res://main.tscn")))
	message=UI.text(settings.error,17,UI.ACCENT);box.add_child(message)
	save.grab_focus()
func save_preferences() -> void:
	message.text="Preferences saved." if settings.save_settings(camera.selected,zone.value) else settings.error
