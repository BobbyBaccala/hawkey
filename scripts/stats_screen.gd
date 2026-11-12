extends PanelContainer
## Intermission / final stats card in the score-bug style (broadcast_hud.gd):
## slate panel, team-colour stripes and score boxes, gold period tag; goals by
## period, then game totals through the period just played (shots, hits,
## faceoffs, power play, penalty minutes) with a team-colour split bar under
## each row. Data comes from scripts/game_stats.gd.
##
## Built once by broadcast_hud.gd build_stats_screen(); match.gd calls
## hud.show_stats(...) at END OF PERIOD / FINAL and hud.hide_stats() after.

const WIDTH := 760.0
const VALUE_W := 150.0
const LABEL_W := 300.0

var hud  # broadcast_hud.gd (fonts, colours, panel styles)
var title_label: Label
var tag_label: Label
var team_cells: Array = []  # [{name, score, stripe, box_style}]
var period_head: Array[Label] = []
var period_cells: Array = [[], []]  # [team][0..3] (1ST 2ND 3RD T)
var period_code_labels: Array[Label] = []
var period_stripes: Array[ColorRect] = []
var section_label: Label
var stat_rows: Array = []  # [{name, left, right, bar_left, bar_right}]
var footer_label: Label
var tween: Tween
## What the card currently shows ("" hidden, "intermission" or "final").
var mode := ""
## Full-screen darkening behind the card (broadcast_hud.gd), faded with it.
var dim: ColorRect:
	set(value):
		dim = value
		dim.visible = visible
		dim.modulate.a = modulate.a

func build(hud_) -> void:
	hud = hud_
	name = "StatsScreen"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	custom_minimum_size = Vector2(WIDTH, 0)
	offset_left = -WIDTH * 0.5
	offset_right = WIDTH * 0.5
	add_theme_stylebox_override("panel", hud.panel_style(Color(hud.SLATE, 0.95), 8, Vector4(0, 0, 0, 0)))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 0)
	add_child(column)
	column.add_child(_header())
	var rule := ColorRect.new()
	rule.color = hud.ACCENT
	rule.custom_minimum_size = Vector2(0, 3)
	column.add_child(rule)
	column.add_child(_score_row())
	column.add_child(_period_table())
	column.add_child(_stats_block())
	column.add_child(_footer())
	visible = false
	modulate.a = 0.0

func _header() -> Control:
	var head := PanelContainer.new()
	head.add_theme_stylebox_override("panel", hud.panel_style(hud.SLATE_2, 0, Vector4(24, 10, 24, 8)))
	var row := HBoxContainer.new()
	head.add_child(row)
	title_label = hud.label("END OF 1ST", 34, hud.INK, 700)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(title_label)
	tag_label = hud.label("INTERMISSION REPORT", 16, hud.ACCENT, 700)
	tag_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(tag_label)
	return head

## TOR [score]   [score] MTL, with the team stripes on the outside edges
## like the score bug.
func _score_row() -> Control:
	var pad := MarginContainer.new()
	for side in ["left", "right"]: pad.add_theme_constant_override("margin_" + side, 24)
	pad.add_theme_constant_override("margin_top", 18)
	pad.add_theme_constant_override("margin_bottom", 10)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 0)
	pad.add_child(row)
	for team in range(2):
		var cell := HBoxContainer.new()
		cell.add_theme_constant_override("separation", 0)
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.alignment = BoxContainer.ALIGNMENT_BEGIN if team == 0 else BoxContainer.ALIGNMENT_END
		var stripe := ColorRect.new()
		stripe.custom_minimum_size = Vector2(8, 62)
		var name_label: Label = hud.label("TORONTO", 30, hud.INK, 700)
		name_label.custom_minimum_size = Vector2(200, 62)
		name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var box := PanelContainer.new()
		var box_style: StyleBoxFlat = hud.panel_style(Color.BLACK, 0, Vector4(0, 0, 0, 0))
		box.add_theme_stylebox_override("panel", box_style)
		var score: Label = hud.label("0", 40, hud.INK, 700)
		score.custom_minimum_size = Vector2(70, 62)
		score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		score.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		box.add_child(score)
		var name_back := PanelContainer.new()
		name_back.add_theme_stylebox_override("panel", hud.panel_style(Color(hud.SLATE_2, 1.0), 0, Vector4(0, 0, 0, 0)))
		name_back.add_child(name_label)
		if team == 0:
			cell.add_child(stripe); cell.add_child(name_back); cell.add_child(box)
		else:
			cell.add_child(box); cell.add_child(name_back); cell.add_child(stripe)
		row.add_child(cell)
		if team == 0:
			var dash: Label = hud.label("–", 34, hud.MUTED, 600)
			dash.custom_minimum_size = Vector2(56, 62)
			dash.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			dash.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			row.add_child(dash)
		team_cells.append({"name": name_label, "score": score, "stripe": stripe, "box_style": box_style})
	return pad

## Goals by period: header 1ST 2ND 3RD T, one row per team.
func _period_table() -> Control:
	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_left", 180)
	pad.add_theme_constant_override("margin_right", 180)
	pad.add_theme_constant_override("margin_bottom", 14)
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 0)
	grid.add_theme_constant_override("v_separation", 2)
	pad.add_child(grid)
	grid.add_child(hud.label("GOALS", 13, hud.MUTED, 600))
	for text in ["1ST", "2ND", "3RD", "T"]:
		var h: Label = hud.label(text, 13, hud.MUTED, 600)
		h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		h.custom_minimum_size = Vector2(66, 0)
		grid.add_child(h)
		period_head.append(h)
	for team in range(2):
		var code_row := HBoxContainer.new()
		code_row.add_theme_constant_override("separation", 8)
		var stripe := ColorRect.new()
		stripe.custom_minimum_size = Vector2(4, 24)
		code_row.add_child(stripe)
		period_stripes.append(stripe)
		var code: Label = hud.label("TOR", 18, hud.INK, 600)
		code.custom_minimum_size = Vector2(70, 26)
		code.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		code_row.add_child(code)
		period_code_labels.append(code)
		grid.add_child(code_row)
		for i in range(4):
			var cell: Label = hud.label("–", 20, hud.INK, 700 if i == 3 else 600)
			cell.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			cell.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			grid.add_child(cell)
			period_cells[team].append(cell)
	return pad

## Totals through the period: value | NAME + split bar | value.
func _stats_block() -> Control:
	var back := PanelContainer.new()
	back.add_theme_stylebox_override("panel", hud.panel_style(Color(hud.SLATE_2, 0.75), 0, Vector4(24, 10, 24, 14)))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	back.add_child(column)
	section_label = hud.label("GAME STATS", 13, hud.MUTED, 600)
	section_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(section_label)
	for i in range(5):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		var left: Label = hud.label("0", 24, hud.INK, 700)
		left.custom_minimum_size = Vector2(VALUE_W, 0)
		left.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		left.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		var middle := VBoxContainer.new()
		middle.add_theme_constant_override("separation", 3)
		middle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var stat_name: Label = hud.label("SHOTS", 16, hud.INK, 600)
		stat_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		middle.add_child(stat_name)
		var bar := HBoxContainer.new()
		bar.add_theme_constant_override("separation", 2)
		bar.custom_minimum_size = Vector2(LABEL_W, 5)
		var bar_left := ColorRect.new()
		var bar_right := ColorRect.new()
		for b in [bar_left, bar_right]:
			b.custom_minimum_size = Vector2(0, 5)
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			bar.add_child(b)
		middle.add_child(bar)
		var right: Label = hud.label("0", 24, hud.INK, 700)
		right.custom_minimum_size = Vector2(VALUE_W, 0)
		right.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		right.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(left)
		row.add_child(middle)
		row.add_child(right)
		column.add_child(row)
		stat_rows.append({"name": stat_name, "left": left, "right": right, "bar_left": bar_left, "bar_right": bar_right})
	return back

func _footer() -> Control:
	var foot := PanelContainer.new()
	foot.add_theme_stylebox_override("panel", hud.panel_style(Color(0, 0, 0, 0), 0, Vector4(24, 9, 24, 11)))
	footer_label = hud.label("", 14, hud.MUTED, 600)
	footer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	foot.add_child(footer_label)
	return foot

static func ordinal(period: int) -> String:
	return ["1ST", "2ND", "3RD"][clampi(period - 1, 0, 2)]

## Fills the card. `period` is the period that just ended; `final` for the
## end of the game. Stats are totals through that period.
func fill(stats, score: Array, period: int, final: bool) -> void:
	var through := clampi(period, 1, 3)
	title_label.text = "FINAL" if final else "END OF " + ordinal(period)
	tag_label.text = "GAME SUMMARY" if final else "INTERMISSION REPORT"
	section_label.text = "GAME STATS" if final else "GAME STATS  ·  THROUGH " + ordinal(period)
	for team in range(2):
		var c: Dictionary = team_cells[team]
		var color: Color = hud.team_colors[team]
		c.name.text = hud.team_names[team]
		c.score.text = str(score[team])
		c.stripe.color = color
		c.box_style.bg_color = Color(color.darkened(0.35), 0.95)
		# The winning (or leading) side's name stays bright, the other dims a touch.
		c.name.add_theme_color_override("font_color", hud.INK if score[team] >= score[1 - team] else hud.MUTED)
		period_code_labels[team].text = hud.team_codes[team]
		period_stripes[team].color = color
		for i in range(3):
			period_cells[team][i].text = str(stats.in_period("goals", team, i + 1)) if i < through else "–"
			period_cells[team][i].add_theme_color_override("font_color", hud.INK if i < through else hud.MUTED)
		period_cells[team][3].text = str(score[team])
	for i in range(3):
		period_head[i].add_theme_color_override("font_color", hud.ACCENT if i == through - 1 and not final else hud.MUTED)
	var rows: Array = stats.rows(through)
	for i in range(mini(rows.size(), stat_rows.size())):
		var r: Array = rows[i]
		var w: Dictionary = stat_rows[i]
		w.name.text = r[0]
		w.left.text = r[1]
		w.right.text = r[2]
		var a := float(r[3])
		var b := float(r[4])
		if a + b <= 0.0:
			a = 1.0; b = 1.0
		w.bar_left.size_flags_stretch_ratio = maxf(a, 0.001)
		w.bar_right.size_flags_stretch_ratio = maxf(b, 0.001)
		w.bar_left.color = hud.team_colors[0] if float(r[3]) + float(r[4]) > 0.0 else Color(hud.MUTED, 0.35)
		w.bar_right.color = hud.team_colors[1] if float(r[3]) + float(r[4]) > 0.0 else Color(hud.MUTED, 0.35)
	if final:
		footer_label.text = "ESC / START   PAUSE MENU   ·   NEW GAME"
	else:
		footer_label.text = ordinal(period + 1) + " PERIOD STARTS SHORTLY   ·   ENDS SWITCH"

func show_card(stats, score: Array, period: int, final: bool) -> void:
	fill(stats, score, period, final)
	mode = "final" if final else "intermission"
	visible = true
	pivot_offset = size * 0.5
	if tween: tween.kill()
	modulate.a = 0.0
	scale = Vector2(0.96, 0.96)
	if dim: dim.modulate.a = 0.0
	tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.25)
	tween.parallel().tween_property(self, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if dim:
		dim.visible = true
		tween.parallel().tween_property(dim, "modulate:a", 1.0, 0.25)

func hide_card() -> void:
	if mode == "": return
	mode = ""
	if tween: tween.kill()
	tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.25)
	if dim: tween.parallel().tween_property(dim, "modulate:a", 0.0, 0.25)
	tween.tween_callback(func():
		visible = false
		if dim: dim.visible = false)
