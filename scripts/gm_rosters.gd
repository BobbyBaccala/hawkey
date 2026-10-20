extends Control
## Read-only career snapshot browser. No simulated scouting/development claims.
const UI=preload("res://scripts/mode_ui.gd")
const Session=preload("res://scripts/gm_session.gd")
const PAGE_SIZE:=25
var entries: Array=[]
var filtered: Array=[]
var eligible: Dictionary={}
var teams_by_id: Dictionary={}
var leagues_by_id: Dictionary={}
var mode:=0
var page:=0
var league_ids: Array[String]=[""]
var team_ids: Array[String]=[""]
var league_choice: OptionButton
var team_choice: OptionButton
var source_choice: OptionButton
var search: LineEdit
var count_label: Label
var rows: VBoxContainer
var details: VBoxContainer
var previous: Button
var next: Button
var selected_id:=""

func _ready() -> void:
	if Session.season==null:
		get_tree().change_scene_to_file("res://gm.tscn")
		return
	var db=Session.season.database
	for league in db.leagues: leagues_by_id[league.id]=league
	for team in db.teams:
		teams_by_id[team.id]=team
		for player in team.players: entries.append({"player":player,"team":team})
	for player in db.draft_pool(): eligible[player.id]=true
	entries.sort_custom(func(a,b): return a.player.id<b.player.id)
	build()

func build() -> void:
	var box:=UI.setup(self)
	box.add_child(UI.text("GENERAL MANAGER  /  PEOPLE & DEVELOPMENT",14,UI.ACCENT))
	box.add_child(UI.text("The roster room",38))
	box.add_child(UI.text("Your saved world · 33 leagues · 643 clubs · 14,745 original players",17,UI.MUTED))
	var filters:=HBoxContainer.new();filters.add_theme_constant_override("separation",12);box.add_child(filters)
	source_choice=OptionButton.new()
	for title in ["Club rosters","My organization","Draft candidates"]: source_choice.add_item(title)
	source_choice.item_selected.connect(select_source);filters.add_child(source_choice)
	league_choice=OptionButton.new();league_choice.add_item("All leagues")
	for league in Session.season.database.leagues:
		league_choice.add_item(league.name);league_ids.append(league.id)
	league_choice.item_selected.connect(select_league);filters.add_child(league_choice)
	team_choice=OptionButton.new();team_choice.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	team_choice.item_selected.connect(func(_index): page=0;refresh());filters.add_child(team_choice)
	search=LineEdit.new();search.placeholder_text="Search name, club or position";search.max_length=64
	search.size_flags_horizontal=Control.SIZE_EXPAND_FILL;search.custom_minimum_size.y=44
	search.text_changed.connect(func(_value): page=0;refresh());box.add_child(search)
	var columns:=HBoxContainer.new();columns.add_theme_constant_override("separation",20)
	columns.size_flags_vertical=Control.SIZE_EXPAND_FILL;box.add_child(columns)
	var list:=UI.card(columns)
	count_label=UI.text("",16,UI.ACCENT);list.add_child(count_label)
	var header:=HBoxContainer.new();list.add_child(header)
	add_cells(header,"PLAYER / CLUB",["POS","AGE","SPD","SHT","POT"],UI.MUTED)
	var scroll:=ScrollContainer.new();scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;list.add_child(scroll)
	rows=VBoxContainer.new();rows.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.add_child(rows)
	var detail_card:=UI.card(columns);var panel: PanelContainer=detail_card.get_parent()
	panel.custom_minimum_size.x=410;panel.size_flags_horizontal=Control.SIZE_FILL
	var detail_scroll:=ScrollContainer.new();detail_scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;detail_card.add_child(detail_scroll)
	details=VBoxContainer.new();details.add_theme_constant_override("separation",9)
	details.size_flags_horizontal=Control.SIZE_EXPAND_FILL;detail_scroll.add_child(details)
	var actions:=HBoxContainer.new();actions.add_theme_constant_override("separation",12);box.add_child(actions)
	previous=UI.button("Previous",func(): page=maxi(page-1,0);refresh());actions.add_child(previous)
	next=UI.button("Next",func(): page+=1;refresh());actions.add_child(next)
	actions.add_child(UI.button("Return to season",func(): get_tree().change_scene_to_file("res://gm.tscn")))
	box.add_child(UI.text("Generated estimates, not scouting reports. No drafting, assignments or development simulation yet.",14,UI.MUTED))
	league_choice.select(league_ids.find("hl"));populate_teams()
	team_choice.select(team_ids.find(Session.season.state.club_id));refresh()
	source_choice.grab_focus()

func select_source(index: int) -> void:
	mode=index;page=0;selected_id=""
	league_choice.select(0);search.text="";populate_teams();refresh()

func select_league(_index: int) -> void:
	page=0;selected_id="";populate_teams();refresh()

func populate_teams() -> void:
	team_ids.assign([""]);team_choice.clear();team_choice.add_item("All clubs")
	var league: String=league_ids[league_choice.selected]
	for team in Session.season.database.teams:
		if league.is_empty() or team.league_id==league:
			team_choice.add_item(team.city+" "+team.name);team_ids.append(team.id)

func is_organization(entry: Dictionary) -> bool:
	var club: String=Session.season.state.club_id
	return entry.team.id==club or entry.team.get("affiliate_of")==club or entry.player.get("hl_rights_team_id")==club

func matches(entry: Dictionary) -> bool:
	if mode==1 and not is_organization(entry): return false
	if mode==2 and not eligible.has(entry.player.id): return false
	var league: String=league_ids[league_choice.selected]
	var team: String=team_ids[team_choice.selected]
	if not league.is_empty() and entry.team.league_id!=league: return false
	if not team.is_empty() and entry.team.id!=team: return false
	var query:=search.text.strip_edges().to_lower()
	return query.is_empty() or query in (entry.player.name+" "+entry.team.city+" "+entry.team.name+" "+entry.player.position).to_lower()

func refresh() -> void:
	filtered=entries.filter(matches)
	page=clampi(page,0,maxi(0,ceili(filtered.size()/float(PAGE_SIZE))-1))
	for child in rows.get_children(): rows.remove_child(child);child.queue_free()
	var first:=page*PAGE_SIZE
	var last:=mini(first+PAGE_SIZE,filtered.size())
	var suffix: String=" · Eligible on "+str(Session.season.database.draft_policy.date) if mode==2 else " · Ages on "+Session.season.database.as_of
	count_label.text="%d players · %d–%d%s"%[filtered.size(),first+1 if last>0 else 0,last,suffix]
	previous.disabled=page==0;next.disabled=last>=filtered.size()
	if not filtered.is_empty():
		var selected: Array=filtered.filter(func(entry): return entry.player.id==selected_id)
		show_player(selected[0] if not selected.is_empty() else filtered[first])
	else:
		clear_details();details.add_child(UI.text("No matching players",24))
	for i in range(first,last):
		var entry: Dictionary=filtered[i]
		var player: Dictionary=entry.player
		var b:=UI.button("",func(): select_player(entry.player.id))
		b.set_meta("player_id",player.id)
		b.custom_minimum_size.y=44
		if player.id==selected_id:
			var highlighted:=UI.style(Color("#25455d"));highlighted.border_color=UI.ACCENT;highlighted.set_border_width_all(1)
			b.add_theme_stylebox_override("normal",highlighted)
		rows.add_child(b)
		var content:=HBoxContainer.new();content.mouse_filter=Control.MOUSE_FILTER_IGNORE
		content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);content.offset_left=12;content.offset_right=-12;b.add_child(content)
		var age: int=Session.season.database.age_at(player.birth_date,Session.season.database.as_of)
		add_cells(content,player.name+" / "+entry.team.code,[player.position,str(age),str(int(player.ratings.speed)),"—" if player.position=="G" else str(int(player.ratings.shot_accuracy)),str(int(player.potential))],UI.ACCENT if player.id==selected_id else UI.INK)

func add_cells(parent: HBoxContainer, name_: String, values: Array, color: Color) -> void:
	var name_label:=UI.text(name_,16,color);name_label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	name_label.custom_minimum_size.x=295;name_label.clip_text=true;name_label.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS;name_label.mouse_filter=Control.MOUSE_FILTER_IGNORE;parent.add_child(name_label)
	for value in values:
		var l:=UI.text(value,15,color);l.custom_minimum_size.x=45;l.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
		l.mouse_filter=Control.MOUSE_FILTER_IGNORE;parent.add_child(l)

func clear_details() -> void:
	for child in details.get_children(): details.remove_child(child);child.queue_free()

func detail(value: String, size: int=16, color: Color=UI.INK) -> void:
	var l:=UI.text(value,size,color);l.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;details.add_child(l)

func show_player(entry: Dictionary) -> void:
	clear_details()
	var p: Dictionary=entry.player;var team: Dictionary=entry.team
	selected_id=p.id
	detail(p.name,28,UI.ACCENT)
	detail(team.city+" "+team.name+" · "+leagues_by_id[team.league_id].name,17)
	detail("%s · #%d · %s shot · %d cm / %d kg"%[p.position,p.jersey_number,p.shoots,p.height_cm,p.weight_kg],16,UI.MUTED)
	detail("Born "+p.birth_date+" · "+p.nationality,16,UI.MUTED)
	var rights: String="Unowned" if p.hl_rights_team_id==null else teams_by_id[p.hl_rights_team_id].city+" "+teams_by_id[p.hl_rights_team_id].name
	detail("HL rights: "+rights,16)
	if team.get("affiliate_of")!=null: detail("Affiliate of "+teams_by_id[team.affiliate_of].city,16)
	detail("ESTIMATED POTENTIAL  %d / 100"%p.potential,17,UI.ACCENT)
	detail("Generated, uncalibrated estimates. Potential is data, not a promise of future growth.",14,UI.MUTED)
	if eligible.has(p.id): detail("Draft candidate · "+Session.season.database.draft_policy.date,16,UI.ACCENT)
	for key in p.ratings:
		var row:=HBoxContainer.new();details.add_child(row)
		var label:=UI.text(str(key).replace("_"," ").capitalize(),15,UI.MUTED);label.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(label)
		row.add_child(UI.text(str(int(p.ratings[key])),15))
	for route in Session.season.database.development_routes:
		if route.from_league_id==team.league_id:
			var names: Array=[]
			for id_ in route.to_league_ids: names.append(leagues_by_id[id_].name)
			detail("Development routes: "+", ".join(names),14,UI.MUTED)
			break
	detail("Player ID: "+p.id,13,UI.MUTED)

func select_player(id_: String) -> void:
	selected_id=id_;refresh()
	for button in rows.get_children():
		if button.get_meta("player_id")==id_: button.grab_focus()
