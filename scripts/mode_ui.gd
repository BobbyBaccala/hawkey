extends RefCounted
## Shared native controls for functional mode pages; existing arena art untouched.
const Fonts=preload("res://scripts/interface_font.gd")
const INK=Color("#f2f5f8")
const MUTED=Color("#aabbd0")
const ACCENT=Color("#63e6cf")
static func style(color: Color, radius: int=14) -> StyleBoxFlat:
	var s:=StyleBoxFlat.new()
	s.bg_color=color
	s.corner_radius_top_left=radius;s.corner_radius_top_right=radius
	s.corner_radius_bottom_left=radius;s.corner_radius_bottom_right=radius
	s.content_margin_left=22;s.content_margin_right=22;s.content_margin_top=16;s.content_margin_bottom=16
	return s
static func setup(root: Control) -> VBoxContainer:
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var backdrop:=ColorRect.new();backdrop.color=Color("#07121f");backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);root.add_child(backdrop)
	var theme:=Theme.new();theme.default_font=Fonts.get_font();theme.default_font_size=17
	theme.set_color("font_color","Label",INK)
	for type_ in ["Button","OptionButton"]:
		theme.set_stylebox("normal",type_,style(Color("#152b40")))
		theme.set_stylebox("hover",type_,style(Color("#25455d")))
		theme.set_stylebox("pressed",type_,style(Color("#25455d")))
		theme.set_stylebox("disabled",type_,style(Color("#112234")))
		theme.set_color("font_disabled_color",type_,Color("#76899e"))
		var focused:=style(Color("#25455d"));focused.border_color=ACCENT;focused.set_border_width_all(2);theme.set_stylebox("focus",type_,focused)
		theme.set_font("font",type_,Fonts.get_font(true))
	theme.set_stylebox("normal","LineEdit",style(Color("#102338")))
	var entry_focus:=style(Color("#152b40"));entry_focus.border_color=ACCENT;entry_focus.set_border_width_all(1)
	theme.set_stylebox("focus","LineEdit",entry_focus)
	theme.set_color("font_color","LineEdit",INK)
	theme.set_color("font_placeholder_color","LineEdit",MUTED)
	theme.set_color("caret_color","LineEdit",ACCENT)
	theme.set_stylebox("panel","PopupMenu",style(Color("#102338")))
	theme.set_stylebox("hover","PopupMenu",style(Color("#25455d")))
	theme.set_constant("v_separation","PopupMenu",12)
	root.theme=theme
	var margin:=MarginContainer.new();margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+side,32)
	root.add_child(margin)
	var box:=VBoxContainer.new();box.add_theme_constant_override("separation",14);margin.add_child(box)
	return box
static func text(value: String, size: int=17, color: Color=INK) -> Label:
	var l:=Label.new();l.text=value;l.add_theme_font_size_override("font_size",size);l.add_theme_color_override("font_color",color)
	if size>=26: l.add_theme_font_override("font",Fonts.get_font(true))
	return l
static func button(value: String, action: Callable) -> Button:
	var b:=Button.new();b.text=value;b.pressed.connect(action);return b
static func card(parent: Node) -> VBoxContainer:
	var panel:=PanelContainer.new();panel.add_theme_stylebox_override("panel",style(Color("#102338")))
	panel.size_flags_horizontal=Control.SIZE_EXPAND_FILL;parent.add_child(panel)
	var box:=VBoxContainer.new();box.add_theme_constant_override("separation",10);panel.add_child(box);return box
