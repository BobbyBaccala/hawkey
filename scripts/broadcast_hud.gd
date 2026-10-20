extends CanvasLayer
## Broadcast-style match presentation: score bug, event banners, line panel,
## penalty strip, shot meter, controls overlay, pause menu and title screen.
## Typography uses Bahnschrift (bundled with Windows 10/11) with fallbacks.

signal resume_requested
signal camera_requested
signal restart_requested
signal quit_requested
signal play_requested
signal menu_requested
signal practice_requested

const INK := Color("#f2f5f8")
const MUTED := Color("#93a3b3")
const SLATE := Color("#0b1118")
const SLATE_2 := Color("#16212c")
const ACCENT := Color("#e8b83a")

var team_colors: Array[Color] = [Color("#1f5fbf"), Color("#b3162c")]
var team_codes: Array[String] = ["HOME", "AWAY"]
var team_names: Array[String] = ["HOME", "AWAY"]

var root_ui: Control
var bug: PanelContainer
var score_labels: Array[Label] = []
var code_labels: Array[Label] = []
var period_label: Label
var clock_label: Label
var strip: PanelContainer
var strip_label: Label
var sog_label: Label
var status_label: Label
var status_panel: PanelContainer
var banner: Control
var banner_title: Label
var banner_sub: Label
var banner_band: ColorRect
var banner_tween: Tween
var line_panel: PanelContainer
var line_title: Label
var line_rows: Array = []
var penalties_label: Label
var penalties_panel: PanelContainer
var power: ProgressBar
var hint_label: Label
var controls_panel: PanelContainer
var controls_label: Label
var pause_panel: Control
var pause_camera_button: Button
var team_choices: Array[OptionButton] = []
var choice_ids: Array[String] = []
var league_choice: OptionButton
var league_choice_ids: Array[String] = []
var available_teams: Array = []
var selection_error: Label
var results_panel: PanelContainer
var results_text: Label
var title_screen: Control

func font(weight := 600) -> Font:
	var f := SystemFont.new()
	f.font_names = PackedStringArray(["Bahnschrift", "DIN Alternate", "Barlow Condensed", "Roboto Condensed", "Arial Narrow", "Segoe UI", "Inter", "DejaVu Sans Condensed", "DejaVu Sans"])
	f.font_weight = weight
	f.font_stretch = 75
	f.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	f.hinting = TextServer.HINTING_LIGHT
	return f

func panel_style(color: Color, radius := 6, pad := Vector4(14, 8, 14, 8)) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(radius)
	s.content_margin_left = pad.x
	s.content_margin_top = pad.y
	s.content_margin_right = pad.z
	s.content_margin_bottom = pad.w
	return s

func label(text: String, size: int, color := INK, weight := 600) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font(weight))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l

func _ready() -> void:
	layer = 5
	root_ui = Control.new()
	root_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var theme := Theme.new()
	theme.default_font = font(600)
	root_ui.theme = theme
	add_child(root_ui)
	build_bug()
	build_status()
	build_banner()
	build_line_panel()
	build_power()
	build_hint()
	build_controls()
	build_pause()
	build_title()

# ------------------------------------------------------------ score bug
func build_bug() -> void:
	bug = PanelContainer.new()
	bug.position = Vector2(36, 28)
	bug.add_theme_stylebox_override("panel", panel_style(Color(SLATE, 0.94), 6, Vector4(0, 0, 0, 0)))
	root_ui.add_child(bug)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 0)
	bug.add_child(column)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 0)
	column.add_child(row)
	for team in range(2):
		var cell := HBoxContainer.new()
		cell.add_theme_constant_override("separation", 0)
		var stripe := ColorRect.new()
		stripe.color = team_colors[team]
		stripe.custom_minimum_size = Vector2(6, 44)
		cell.add_child(stripe)
		var code := label(team_codes[team], 22, INK, 600)
		code.custom_minimum_size = Vector2(62, 44)
		code.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		code.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		cell.add_child(code)
		code_labels.append(code)
		var score_box := PanelContainer.new()
		score_box.add_theme_stylebox_override("panel", panel_style(Color(team_colors[team].darkened(0.35), 0.95), 0, Vector4(0, 0, 0, 0)))
		var score := label("0", 26, INK, 700)
		score.custom_minimum_size = Vector2(42, 44)
		score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		score.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		score_box.add_child(score)
		cell.add_child(score_box)
		score_labels.append(score)
		row.add_child(cell)
	var time_box := PanelContainer.new()
	time_box.add_theme_stylebox_override("panel", panel_style(SLATE_2, 0, Vector4(16, 0, 16, 0)))
	var time_row := HBoxContainer.new()
	time_row.add_theme_constant_override("separation", 14)
	period_label = label("1ST", 20, ACCENT, 700)
	period_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	period_label.custom_minimum_size.y = 44
	clock_label = label("20:00", 24, INK, 600)
	clock_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	clock_label.custom_minimum_size = Vector2(66, 44)
	time_row.add_child(period_label)
	time_row.add_child(clock_label)
	time_box.add_child(time_row)
	row.add_child(time_box)
	strip = PanelContainer.new()
	strip.add_theme_stylebox_override("panel", panel_style(Color(ACCENT, 0.95), 0, Vector4(12, 3, 12, 3)))
	strip_label = label("", 15, SLATE, 700)
	strip.add_child(strip_label)
	strip.visible = false
	column.add_child(strip)
	var sog_box := PanelContainer.new()
	sog_box.add_theme_stylebox_override("panel", panel_style(Color(SLATE, 0.80), 0, Vector4(12, 3, 12, 4)))
	sog_label = label("SOG  0 – 0", 14, MUTED, 600)
	sog_box.add_child(sog_label)
	column.add_child(sog_box)

func update_bug(scores: Array, period: int, clock: String, strength: Array, power_play: String, shots: Array) -> void:
	for team in range(2):
		score_labels[team].text = str(scores[team])
	var names := ["1ST", "2ND", "3RD"]
	period_label.text = names[clampi(period - 1, 0, 2)] if period <= 3 else "OT"
	clock_label.text = clock
	strip.visible = not power_play.is_empty()
	strip_label.text = power_play
	sog_label.text = "SOG   %s %d  –  %d %s" % [team_codes[0], shots[0], shots[1], team_codes[1]]

# ------------------------------------------------------------ status line
func build_status() -> void:
	status_panel = PanelContainer.new()
	status_panel.position = Vector2(36, 112)
	status_panel.add_theme_stylebox_override("panel", panel_style(Color(SLATE, 0.78), 4, Vector4(12, 5, 12, 6)))
	status_label = label("", 15, INK, 500)
	status_panel.add_child(status_label)
	root_ui.add_child(status_panel)
	penalties_panel = PanelContainer.new()
	penalties_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	penalties_panel.offset_left = -300
	penalties_panel.offset_right = -36
	penalties_panel.offset_top = 28
	penalties_panel.add_theme_stylebox_override("panel", panel_style(Color(SLATE, 0.88), 6, Vector4(14, 8, 14, 10)))
	penalties_label = label("", 15, INK, 500)
	penalties_panel.add_child(penalties_label)
	root_ui.add_child(penalties_panel)

func set_status(text: String) -> void:
	status_label.text = text
	status_panel.visible = not text.is_empty()

# ------------------------------------------------------------ banners
func build_banner() -> void:
	banner = Control.new()
	banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	banner.offset_top = -270
	banner.offset_bottom = -170
	banner.offset_left = -360
	banner.offset_right = 360
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.pivot_offset = Vector2(360, 50)
	root_ui.add_child(banner)
	var back := ColorRect.new()
	back.color = Color(SLATE, 0.92)
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	banner.add_child(back)
	banner_band = ColorRect.new()
	banner_band.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	banner_band.offset_right = 14
	banner.add_child(banner_band)
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", -4)
	banner.add_child(box)
	banner_title = label("GOAL", 54, INK, 700)
	banner_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner_sub = label("", 18, MUTED, 600)
	banner_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(banner_title)
	box.add_child(banner_sub)
	banner.visible = false

func show_banner(title: String, sub: String, color: Color, seconds := 2.6) -> void:
	banner_title.text = title
	banner_sub.text = sub
	banner_band.color = color
	banner.visible = true
	banner.modulate.a = 0.0
	banner.scale = Vector2(0.92, 0.92)
	if banner_tween: banner_tween.kill()
	banner_tween = create_tween()
	banner_tween.tween_property(banner, "modulate:a", 1.0, 0.18)
	banner_tween.parallel().tween_property(banner, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	banner_tween.tween_interval(seconds)
	banner_tween.tween_property(banner, "modulate:a", 0.0, 0.3)
	banner_tween.tween_callback(func(): banner.visible = false)

# ------------------------------------------------------------ line panel
func build_line_panel() -> void:
	line_panel = PanelContainer.new()
	line_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	line_panel.offset_left = 36
	line_panel.offset_top = -150
	line_panel.offset_bottom = -32
	line_panel.offset_right = 300
	line_panel.add_theme_stylebox_override("panel", panel_style(Color(SLATE, 0.86), 6, Vector4(14, 10, 14, 10)))
	root_ui.add_child(line_panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 5)
	line_panel.add_child(column)
	line_title = label("LINE 1  ·  D PAIR 1", 14, ACCENT, 700)
	column.add_child(line_title)
	for i in range(3):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var number := label("#17", 15, MUTED, 600)
		number.custom_minimum_size.x = 34
		var name_ := label("Player", 16, INK, 600)
		name_.custom_minimum_size.x = 110
		var bar := ProgressBar.new()
		bar.show_percentage = false
		bar.max_value = 1.0
		bar.custom_minimum_size = Vector2(80, 6)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var fill := StyleBoxFlat.new()
		fill.bg_color = Color("#3ec27a")
		fill.set_corner_radius_all(3)
		var bg := StyleBoxFlat.new()
		bg.bg_color = Color(1, 1, 1, 0.12)
		bg.set_corner_radius_all(3)
		bar.add_theme_stylebox_override("fill", fill)
		bar.add_theme_stylebox_override("background", bg)
		row.add_child(number)
		row.add_child(name_)
		row.add_child(bar)
		column.add_child(row)
		line_rows.append([number, name_, bar, fill])

func update_line(line_index: int, pair: int, players: Array) -> void:
	line_title.text = "%s  ·  LINE %d  ·  D PAIR %d" % [team_codes[0], line_index + 1, pair + 1]
	for i in range(line_rows.size()):
		var row: Array = line_rows[i]
		var visible_ := i < players.size()
		for node in row.slice(0, 3):
			node.visible = visible_
		if not visible_:
			continue
		var p: Dictionary = players[i]
		row[0].text = "#%d" % p.number
		row[1].text = str(p.name).to_upper() + ("  ›" if p.changing else "")
		row[2].value = p.stamina
		row[3].bg_color = Color("#3ec27a") if p.stamina > 0.6 else (ACCENT if p.stamina > 0.35 else Color("#e0533d"))

# ------------------------------------------------------------ shot power, hints, controls
func build_power() -> void:
	power = ProgressBar.new()
	power.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	power.offset_left = -110
	power.offset_right = 110
	power.offset_top = -64
	power.offset_bottom = -56
	power.show_percentage = false
	power.max_value = 1
	var fill := StyleBoxFlat.new()
	fill.bg_color = ACCENT
	fill.set_corner_radius_all(4)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(SLATE, 0.8)
	bg.set_corner_radius_all(4)
	power.add_theme_stylebox_override("fill", fill)
	power.add_theme_stylebox_override("background", bg)
	power.visible = false
	root_ui.add_child(power)

func build_hint() -> void:
	var hint_box := PanelContainer.new()
	hint_box.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	hint_box.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	hint_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	hint_box.offset_right = -36
	hint_box.offset_bottom = -32
	hint_box.add_theme_stylebox_override("panel", panel_style(Color(SLATE, 0.7), 4, Vector4(12, 4, 12, 5)))
	hint_label = label("", 14, MUTED, 500)
	hint_box.add_child(hint_label)
	root_ui.add_child(hint_box)

func build_controls() -> void:
	controls_panel = PanelContainer.new()
	controls_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	controls_panel.offset_left = -330
	controls_panel.offset_right = 330
	controls_panel.offset_top = -190
	controls_panel.offset_bottom = 190
	controls_panel.add_theme_stylebox_override("panel", panel_style(Color(SLATE, 0.96), 8, Vector4(28, 22, 28, 22)))
	controls_label = label("", 17, INK, 500)
	controls_panel.add_child(controls_label)
	controls_panel.visible = false
	root_ui.add_child(controls_panel)

func set_controls_text(controller: bool) -> void:
	if controller:
		controls_label.text = "CONTROLLER\n\nLeft stick      Skate and aim\nRight stick     Stickhandle\nRT / R2         Hold to charge, release to shoot\nLT / L2         Lift the shot\nRB / R1         Pass          Y / △   Saucer pass\nA / ×           Switch player\nB / ○  Check     X / □  Poke\nL3  Burst        R3  Stop\nD-pad           Lines and defence pairs\nStart           Pause"
	else:
		controls_label.text = "KEYBOARD AND MOUSE\n\nW A S D         Skate (screen relative)\nMouse           Aim\nLeft button     Hold to charge, release to shoot\nAlt             Lift the shot\nRight button    Pass       Shift + right  Saucer\nSpace           Switch player\nE  Poke          F  Check\nShift  Burst     Ctrl  Stop\n1–4  Lines       Q  Defence pair\nC  Camera        Wheel  Zoom        Esc  Pause"

# ------------------------------------------------------------ menus
func menu_button(text: String, handler: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(300, 48)
	b.add_theme_font_override("font", font(600))
	b.add_theme_font_size_override("font_size", 22)
	b.add_theme_color_override("font_color", INK)
	b.add_theme_color_override("font_focus_color", SLATE)
	b.add_theme_color_override("font_hover_color", SLATE)
	var normal := panel_style(Color(1, 1, 1, 0.06), 4, Vector4(18, 6, 18, 6))
	var hot := panel_style(INK, 4, Vector4(18, 6, 18, 6))
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hot)
	b.add_theme_stylebox_override("focus", hot)
	b.add_theme_stylebox_override("pressed", panel_style(ACCENT, 4, Vector4(18, 6, 18, 6)))
	b.pressed.connect(handler)
	b.mouse_entered.connect(func(): b.grab_focus())
	return b

func build_pause() -> void:
	pause_panel = Control.new()
	pause_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.03, 0.05, 0.62)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pause_panel.add_child(shade)
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
	box.offset_left = 120
	box.offset_top = -170
	box.offset_bottom = 170
	box.add_theme_constant_override("separation", 10)
	pause_panel.add_child(box)
	box.add_child(label("PAUSED", 44, INK, 700))
	box.add_child(menu_button("Resume", func(): resume_requested.emit()))
	pause_camera_button = menu_button("Camera: Dynamic", func(): camera_requested.emit())
	box.add_child(pause_camera_button)
	box.add_child(menu_button("Controls", func(): controls_panel.visible = not controls_panel.visible))
	box.add_child(menu_button("Restart game", func(): restart_requested.emit()))
	box.add_child(menu_button("Return to menu", func(): menu_requested.emit()))
	box.add_child(menu_button("Quit", func(): quit_requested.emit()))
	pause_panel.visible = false
	root_ui.add_child(pause_panel)

func show_pause(on: bool, camera_name: String) -> void:
	pause_panel.visible = on
	pause_camera_button.text = "Camera: " + camera_name.capitalize()
	if not on:
		controls_panel.visible = false
	elif pause_panel.get_child(1).get_child(1) is Button:
		pause_panel.get_child(1).get_child(1).grab_focus()

func build_title() -> void:
	title_screen = Control.new()
	title_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var side := ColorRect.new()
	side.color = Color(0.03, 0.05, 0.08, 0.86)
	side.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	side.offset_right = 560
	title_screen.add_child(side)
	var edge := ColorRect.new()
	edge.color = ACCENT
	edge.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	edge.offset_left = 560
	edge.offset_right = 564
	title_screen.add_child(edge)
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
	box.offset_left = 96
	box.offset_top = -370
	box.offset_bottom = 250
	box.add_theme_constant_override("separation", 8)
	title_screen.add_child(box)
	var mark := label("HAWKEY", 96, INK, 700)
	box.add_child(mark)
	box.add_child(label("SIMULATION HOCKEY", 20, ACCENT, 600))
	var gap := Control.new()
	gap.custom_minimum_size.y = 10
	box.add_child(gap)
	var play := menu_button("Play Now", func(): play_requested.emit())
	box.add_child(play)
	box.add_child(menu_button("Practice", func(): practice_requested.emit()))
	box.add_child(menu_button("Controls", func(): controls_panel.visible = not controls_panel.visible))
	box.add_child(menu_button("Quit", func(): quit_requested.emit()))
	var gap2 := Control.new()
	gap2.custom_minimum_size.y = 4
	box.add_child(gap2)
	box.add_child(label("League", 16, MUTED, 500))
	league_choice = OptionButton.new()
	league_choice.custom_minimum_size = Vector2(360, 34)
	league_choice.item_selected.connect(select_league)
	box.add_child(league_choice)
	for side_name in ["Home", "Away"]:
		box.add_child(label(side_name, 16, MUTED, 500))
		var choice := OptionButton.new()
		choice.custom_minimum_size = Vector2(360, 34)
		box.add_child(choice)
		team_choices.append(choice)
	selection_error = label("Fictional identities · estimated ratings\n3 × 20:00 · fixed prototype rules", 14, MUTED, 500)
	box.add_child(selection_error)
	title_screen.visible = false
	root_ui.add_child(title_screen)

func show_title(on: bool) -> void:
	title_screen.visible = on
	for node in [bug, status_panel, line_panel, penalties_panel, hint_label.get_parent()]:
		node.visible = not on
	if on:
		(title_screen.get_child(2).get_child(3) as Button).grab_focus()
	else:
		controls_panel.visible = false

func configure_teams(teams: Array, selected: Array[String], leagues: Array = []) -> void:
	available_teams = teams
	league_choice.clear()
	league_choice_ids.clear()
	for league in leagues:
		if league.get("play_now", true):
			league_choice_ids.append(league.id)
			league_choice.add_item(league.name)
	if leagues.is_empty():
		league_choice_ids.append(str(teams[0].league_id))
		league_choice.add_item("Fictional exhibition")
	var selected_league: String = str(teams[0].league_id)
	for team in teams:
		if team.id == selected[0]: selected_league = team.league_id
	var league_index := maxi(0, league_choice_ids.find(selected_league))
	league_choice.select(league_index)
	select_league(league_index)
	for i in range(2):
		team_choices[i].select(maxi(0, choice_ids.find(selected[i])))

func select_league(index: int) -> void:
	choice_ids.clear()
	for choice in team_choices: choice.clear()
	for team in available_teams:
		if team.league_id != league_choice_ids[index]: continue
		choice_ids.append(team.id)
		for choice in team_choices: choice.add_item(team.city + " " + team.name)
	if choice_ids.size() >= 2:
		team_choices[0].select(0)
		team_choices[1].select(1)
	if is_instance_valid(selection_error):
		selection_error.text = "Original players · estimated ratings\n3 × 20:00 · fixed exhibition rules"

func selected_ids() -> Array[String]:
	return [choice_ids[team_choices[0].selected], choice_ids[team_choices[1].selected]]

func show_results(scores: Array[int], shots: Array[int]) -> void:
	if is_instance_valid(results_panel): return
	if banner_tween: banner_tween.kill()
	banner.visible = false
	results_panel = PanelContainer.new()
	results_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	results_panel.offset_left = -320
	results_panel.offset_right = 320
	results_panel.offset_top = -130
	results_panel.offset_bottom = 130
	results_panel.add_theme_stylebox_override("panel", panel_style(SLATE, 8, Vector4(30, 24, 30, 24)))
	root_ui.add_child(results_panel)
	var box := VBoxContainer.new()
	results_panel.add_child(box)
	box.add_child(label("FINAL", 32, INK, 700))
	results_text = label("%s %d – %d %s\nShots: %d – %d" % [team_names[0], scores[0], scores[1], team_names[1], shots[0], shots[1]], 22)
	box.add_child(results_text)
	if scores[0] == scores[1]:
		box.add_child(label("Draw · overtime/shootout not implemented", 16, MUTED))
	var rematch := menu_button("Rematch", func(): restart_requested.emit())
	box.add_child(rematch)
	box.add_child(menu_button("Return to menu", func(): menu_requested.emit()))
	rematch.grab_focus()
