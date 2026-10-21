extends Control
## Functional management pages. Each transaction is published only after a durable save.
const UI=preload("res://scripts/mode_ui.gd")
const Session=preload("res://scripts/gm_session.gd")
const Management=preload("res://scripts/gm_management.gd")
var tab:=0
var stats_sort:=0
var records_sort:=0
var scouting_id:=""
var scouting_rows: VBoxContainer
var scouting_detail: VBoxContainer
var scout_page:=0
var scout_query:=""
var transaction_notice:=""
var selected_id:=""
var selected_position:="All positions"
var box: VBoxContainer
var rows: VBoxContainer
var details: VBoxContainer
var aav: SpinBox
var years: SpinBox
var message: Label
var sign_button: Button
var offer_controls: VBoxContainer
var checkpoint_job: RefCounted
var candidate: RefCounted
var status:=""

func _ready() -> void:
	if Session.season==null:
		get_tree().change_scene_to_file("res://gm.tscn");return
	build()

func money(value: int) -> String: return "$%.2fM"%[value/1000000.0]

func build() -> void:
	for child in get_children(): remove_child(child);child.queue_free()
	box=UI.setup(self)
	box.add_child(UI.text("GENERAL MANAGER  /  HOCKEY OPERATIONS",14,UI.ACCENT))
	var club: Dictionary=Session.season.club(Session.season.state.club_id)
	box.add_child(UI.text(club.city+" · Front office",38))
	var nav:=HBoxContainer.new();nav.add_theme_constant_override("separation",12);box.add_child(nav)
	for i in range(5):
		var b:=UI.button(["Free agents","Contracts","Team statistics","Season records","Junior scouting"][i],func(): tab=i;build())
		b.disabled=i==tab
		if i==tab:
			b.add_theme_color_override("font_disabled_color",UI.ACCENT)
			var selected:=UI.style(Color("#173c48"));selected.border_color=UI.ACCENT;selected.set_border_width_all(1);b.add_theme_stylebox_override("disabled",selected)
		nav.add_child(b)
	var management: Dictionary=Session.season.state.management
	var payroll:=Management.payroll(management,club.id)
	box.add_child(UI.text("PAYROLL %s   /   CEILING %s   /   SPACE %s   /   %d OF 50 CONTRACTS"%[money(payroll),money(Management.POLICY.ceiling),money(Management.POLICY.ceiling-payroll),Management.contract_count(management,club.id)],17,UI.ACCENT))
	if tab==0: build_market()
	elif tab==1: build_contracts()
	elif tab==2: build_statistics()
	elif tab==3: build_records()
	else: build_scouting()
	message=UI.text(status,16,UI.ACCENT);message.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;box.add_child(message)
	var back:=UI.button("Return to season",func(): get_tree().change_scene_to_file("res://gm.tscn"));box.add_child(back)
	box.add_child(UI.text("HL alpha rules · fictional contracts · simplified salary cap · offseason pending.",14,UI.MUTED))
	var fields:=box.find_children("*","OptionButton",true,false)
	if not fields.is_empty(): fields[0].grab_focus()
	else: back.grab_focus()

func scroll_rows(parent: Node) -> VBoxContainer:
	var scroll:=ScrollContainer.new();scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;parent.add_child(scroll)
	var list:=VBoxContainer.new();list.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.add_child(list)
	return list

func scroll_detail(parent: Node, width: int) -> VBoxContainer:
	var card:=UI.card(parent)
	var panel: PanelContainer=card.get_parent();panel.custom_minimum_size.x=width;panel.size_flags_horizontal=Control.SIZE_FILL
	var scroll:=ScrollContainer.new();scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;scroll.size_flags_horizontal=Control.SIZE_EXPAND_FILL;card.add_child(scroll)
	var content:=VBoxContainer.new();content.size_flags_horizontal=Control.SIZE_EXPAND_FILL;content.add_theme_constant_override("separation",10);scroll.add_child(content)
	return content

func build_market() -> void:
	var filter:=OptionButton.new()
	for title in ["All positions","C","LW","RW","D","G"]: filter.add_item(title)
	filter.select(["All positions","C","LW","RW","D","G"].find(selected_position))
	filter.item_selected.connect(func(i): selected_position=filter.get_item_text(i);selected_id="";build());box.add_child(filter)
	var columns:=HBoxContainer.new();columns.add_theme_constant_override("separation",20);columns.size_flags_vertical=Control.SIZE_EXPAND_FILL;box.add_child(columns)
	var market:=UI.card(columns)
	var available: Array=Session.season.state.management.market.filter(func(r): return not Session.season.state.management.contracts.has(r.player.id) and (selected_position=="All positions" or r.player.position==selected_position))
	available.sort_custom(func(a,b): return Management.ability(a.player)>Management.ability(b.player) if Management.ability(a.player)!=Management.ability(b.player) else a.player.id<b.player.id)
	market.add_child(UI.text("Available professionals · %d"%available.size(),24))
	market.add_child(UI.text("PLAYER                              POS        EST.        ASK / YEAR",14,UI.MUTED))
	rows=scroll_rows(market)
	if selected_id.is_empty() and not available.is_empty(): selected_id=available[0].player.id
	for row in available:
		var player: Dictionary=row.player
		var b:=UI.button("%s   ·   %s   ·   %.0f   ·   %s"%[player.name,player.position,Management.ability(player),money(row.ask_aav)],func(): selected_id=player.id;show_offer())
		b.alignment=HORIZONTAL_ALIGNMENT_LEFT;rows.add_child(b)
	details=scroll_detail(columns,420)
	offer_controls=VBoxContainer.new();offer_controls.add_theme_constant_override("separation",8);details.get_parent().get_parent().add_child(offer_controls)
	show_offer()

func show_offer() -> void:
	for child in details.get_children(): details.remove_child(child);child.queue_free()
	for child in offer_controls.get_children(): offer_controls.remove_child(child);child.queue_free()
	var found: Array=Session.season.state.management.market.filter(func(row): return row.player.id==selected_id)
	if found.is_empty(): details.add_child(UI.text("No available players",23));return
	var row: Dictionary=found[0];var p: Dictionary=row.player
	details.add_child(UI.text(p.name,28))
	details.add_child(UI.text("%s  ·  AGE %d  ·  %s SHOT"%[p.position,Session.season.database.age_at(p.birth_date,Session.season.database.as_of),p.shoots],17,UI.ACCENT))
	details.add_child(UI.text("Estimated ability %.0f · potential %d\nFictional player; estimated ratings."%[Management.ability(p),p.potential],15,UI.MUTED))
	var active: Dictionary=Management.active_team(Session.season.state.management,Session.season.club(Session.season.state.club_id))
	var position_players: Array=active.players.filter(func(v): return v.position==p.position)
	details.add_child(UI.text("Current %s depth: %.0f–%.0f\nTop ratings dress automatically.\nAll contracts count against this preset's cap."%[p.position,Management.ability(position_players[-1]),Management.ability(position_players[0])],16,UI.MUTED))
	details.add_child(UI.text("REQUEST  %s / year · %d+ years"%[money(row.ask_aav),row.ask_years],18,UI.ACCENT))
	offer_controls.add_child(UI.text("Annual salary ($M)  /  Term (years)",16))
	var inputs:=HBoxContainer.new();inputs.add_theme_constant_override("separation",12);offer_controls.add_child(inputs)
	aav=SpinBox.new();aav.min_value=1;aav.max_value=20.8;aav.step=0.05;aav.value=float(row.ask_aav)/1000000.0;aav.size_flags_horizontal=Control.SIZE_EXPAND_FILL;inputs.add_child(aav)
	years=SpinBox.new();years.min_value=1;years.max_value=5;years.step=1;years.value=row.ask_years;years.custom_minimum_size.x=110;inputs.add_child(years)
	sign_button=UI.button("Sign & save contract",sign_selected);offer_controls.add_child(sign_button)
	sign_button.disabled=Session.checkpoint_active or not Session.pending_result.is_empty() or not Session.fixture_id.is_empty() or Session.season.state.day>=62 or not Session.season.current_fixture().result.is_empty()
	details.add_child(UI.text("Flat annual salary. Immediate acceptance\nwhen salary and term meet the request.\nNo bidding AI or contract clauses yet.",14,UI.MUTED))

func sign_selected() -> void:
	if Session.checkpoint_active or checkpoint_job!=null or not Session.pending_result.is_empty() or not Session.fixture_id.is_empty(): return
	candidate=Session.Season.new()
	# Isolate only this finite edit; the worker validates the complete saved snapshot.
	candidate.state=Session.season.state.duplicate(true);candidate.database=Session.season.database
	if not candidate.sign_free_agent(selected_id,int(round(aav.value*1000000)),int(years.value)):
		status=candidate.error;message.text=status;candidate=null;return
	transaction_notice="Contract saved. Organization depth, game roster and cap space updated."
	await save_candidate()

func save_candidate() -> void:
	checkpoint_job=preload("res://scripts/gm_checkpoint_job.gd").new()
	if checkpoint_job.start(candidate.state,candidate.strengths,Session.slot_path,false)!=OK:
		checkpoint_job=null;candidate=null;message.text="Could not start contract save.";return
	Session.checkpoint_active=true
	for button in box.find_children("*","BaseButton",true,false): button.disabled=true
	if tab==0: aav.editable=false;years.editable=false
	message.text="SAVING — changes take effect only after the checkpoint succeeds."
	while is_inside_tree() and checkpoint_job!=null and not checkpoint_job.completed(): await get_tree().process_frame
	if not is_inside_tree(): return
	apply_checkpoint();build()

func apply_checkpoint() -> void:
	if checkpoint_job==null: return
	var result: Dictionary=checkpoint_job.finish()
	Session.checkpoint_active=false
	if result.get("ok",false):
		Session.season.state=result.state;Session.season.cache_strengths()
		status=transaction_notice
		Session.notice=status;Session.error="";selected_id=""
	else: status=result.get("error","Contract save failed; previous market retained.")
	checkpoint_job=null;candidate=null

func _exit_tree() -> void: apply_checkpoint()

func build_contracts() -> void:
	var card:=UI.card(box);card.get_parent().size_flags_vertical=Control.SIZE_EXPAND_FILL
	card.add_child(UI.text("Organization contracts",24))
	table_line(card,["PLAYER","POS","AAV","YEARS","DEPTH"],[270,65,130,100,150],UI.MUTED,14)
	rows=scroll_rows(card)
	var model=Session.season;var managed: Dictionary=model.club(model.state.club_id)
	var active: Dictionary=Management.active_team(model.state.management,managed)
	var dressed: Array=model.database.match_roster(active).slice(0,20).map(func(p): return p.id)
	for p in Management.organization(model.state.management,managed):
		var c: Dictionary=model.state.management.contracts[p.id]
		var label:="DRESSED" if p.id in dressed else "RESERVE"
		table_line(rows,[p.name,p.position,money(c.aav),str(c.years),label],[270,65,130,100,150],UI.INK if p.id in dressed else UI.MUTED,18)
	card.add_child(UI.text("Reserve is an automatic depth designation, not a simulated farm assignment.\nTerm is stored; expiry and offseason renewals arrive with multi-season support.",15,UI.MUTED))

func build_statistics() -> void:
	var sort_choice:=OptionButton.new()
	for title in ["Sort: standings points","Sort: goals per game","Sort: fewest goals against per game","Sort: goal difference","Sort: shutouts"]: sort_choice.add_item(title)
	sort_choice.select(stats_sort);sort_choice.item_selected.connect(func(i): stats_sort=i;build());box.add_child(sort_choice)
	var card:=UI.card(box);card.get_parent().size_flags_vertical=Control.SIZE_EXPAND_FILL
	card.add_child(UI.text("HL team statistics",24))
	table_line(card,["CLUB","GP","PTS","GF","GA","DIFF","GF/GP","GA/GP","PTS%","HOME W","AWAY W","SO"],[205,74,74,74,74,74,74,74,74,74,74,74],UI.MUTED,14,true)
	rows=scroll_rows(card)
	var statistics: Array=Session.season.team_statistics()
	if stats_sort>0:
		var key: String=["pts","gf_gp","ga_gp","gd","shutouts"][stats_sort]
		statistics.sort_custom(func(a,b):
			if a[key]==b[key]: return a.id<b.id
			return a[key]<b[key] if stats_sort==2 else a[key]>b[key])
	for row in statistics:
		var line:=HBoxContainer.new();rows.add_child(line)
		var color: Color=UI.ACCENT if row.id==Session.season.state.club_id else UI.MUTED
		var name_label:=UI.text(Session.season.club(row.id).city,16,color);name_label.custom_minimum_size.x=205;line.add_child(name_label)
		for value in [str(row.gp),str(row.pts),str(row.gf),str(row.ga),str(row.gd),"%.2f"%row.gf_gp,"%.2f"%row.ga_gp,"%.1f"%(row.pts_pct*100),str(row.home_w),str(row.away_w),str(row.shutouts)]:
			var cell:=UI.text(value,16,color);cell.custom_minimum_size.x=74;cell.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT;line.add_child(cell)
	card.add_child(UI.text("SO = team shutout wins. Derived from saved finals; includes the deciding shootout goal.\nPlayer box scores and special-team statistics are not recorded yet.",14,UI.MUTED))

func build_records() -> void:
	var sort_choice:=OptionButton.new();sort_choice.add_item("Highest-scoring games");sort_choice.add_item("Largest winning margins");sort_choice.select(records_sort)
	sort_choice.item_selected.connect(func(i): records_sort=i;build());box.add_child(sort_choice)
	var card:=UI.card(box);card.get_parent().size_flags_vertical=Control.SIZE_EXPAND_FILL
	card.add_child(UI.text(("Highest-scoring games" if records_sort==0 else "Largest winning margins")+" · this season",24))
	rows=scroll_rows(card)
	var records: Array=Session.season.season_records()
	if records_sort==1: records.sort_custom(func(a,b): return a.margin>b.margin if a.margin!=b.margin else a.fixture.id<b.fixture.id)
	if records.is_empty(): rows.add_child(UI.text("Play or simulate a league day to start the record book.",20,UI.MUTED))
	for record in records.slice(0,50):
		var f: Dictionary=record.fixture
		rows.add_child(UI.text("DAY %02d    %s %d–%d %s    ·    %s    ·    %d GOALS / %d MARGIN"%[int(f.day)+1,Session.season.club(f.home).city,f.result.home,f.result.away,Session.season.club(f.away).city,f.result.decision,record.total,record.margin],18))
	card.add_child(UI.text("Completed games from your saved season.\nCareer records arrive with multi-season history.",15,UI.MUTED))

func build_scouting() -> void:
	var pool: Dictionary=Management.Scouting.candidates(Session.season.state.world)
	var jobs: Array=Session.season.state.management.scouting_jobs
	var pending: int=jobs.filter(func(job): return job.day==Session.season.state.day).size()
	box.add_child(UI.text("%d eligible junior prospects · %d / 3 scouts assigned today · reports after next league day"%[pool.size(),pending],17,UI.MUTED))
	var search:=LineEdit.new();search.placeholder_text="Search junior player name or position";search.text=scout_query
	search.text_changed.connect(func(value): scout_query=value;scout_page=0;refresh_scouting())
	box.add_child(search)
	var columns:=HBoxContainer.new();columns.size_flags_vertical=Control.SIZE_EXPAND_FILL;columns.add_theme_constant_override("separation",20);box.add_child(columns)
	var list:=UI.card(columns);scouting_rows=scroll_rows(list)
	scouting_detail=scroll_detail(columns,430)
	var pages:=HBoxContainer.new();box.add_child(pages)
	pages.add_child(UI.button("Previous prospects",func(): scout_page=maxi(scout_page-1,0);refresh_scouting()))
	pages.add_child(UI.button("Next prospects",func(): scout_page+=1;refresh_scouting()))
	refresh_scouting()

func refresh_scouting() -> void:
	for child in scouting_rows.get_children(): scouting_rows.remove_child(child);child.queue_free()
	var pool: Dictionary=Management.Scouting.candidates(Session.season.state.world)
	var ids: Array=pool.keys();ids.sort()
	ids=ids.filter(func(id_): return scout_query.is_empty() or scout_query.to_lower() in (pool[id_].player.name+" "+pool[id_].player.position).to_lower())
	scout_page=clampi(scout_page,0,maxi((ids.size()-1)/25,0))
	if scouting_id not in ids: scouting_id=ids[0] if not ids.is_empty() else ""
	scouting_rows.add_child(UI.text("%d matches · page %d / %d"%[ids.size(),scout_page+1,maxi(ceili(ids.size()/25.0),1)],16,UI.ACCENT))
	for id_ in ids.slice(scout_page*25,(scout_page+1)*25):
		var p: Dictionary=pool[id_].player
		var jobs: Array=Session.season.state.management.scouting_jobs.filter(func(j): return j.player==id_)
		var label: String="UNSCOUTED" if jobs.is_empty() else ("ASSIGNED" if jobs[0].day==Session.season.state.day else "REPORT READY")
		scouting_rows.add_child(UI.button("%s · %s · %s"%[p.name,p.position,label],func(): scouting_id=id_;show_scouting()))
	show_scouting()

func show_scouting() -> void:
	for child in scouting_detail.get_children(): scouting_detail.remove_child(child);child.queue_free()
	if scouting_id.is_empty(): scouting_detail.add_child(UI.text("No matching prospects",24));return
	var row: Dictionary=Management.Scouting.candidates(Session.season.state.world)[scouting_id]
	var p: Dictionary=row.player
	scouting_detail.add_child(UI.text(p.name,28))
	scouting_detail.add_child(UI.text("%s · %s · AGE %d"%[p.position,Session.season.club(row.team).code,Session.season.database.age_at(p.birth_date,Session.season.database.as_of)],18,UI.ACCENT))
	var report: Dictionary=Session.season.scouting_report(scouting_id)
	if not report.is_empty():
		scouting_detail.add_child(UI.text("PRELIMINARY REPORT · DAY %d"%[int(report.observed_day)+1],16,UI.ACCENT))
		for field in ["speed","primary_skill","potential"]:
			scouting_detail.add_child(UI.text("%s     %d–%d"%[report.primary_label if field=="primary_skill" else field.capitalize(),report[field][0],report[field][1]],22))
	else: scouting_detail.add_child(UI.text("Assign one of three scouts.
A report returns after advancing
the league day.",18,UI.MUTED))
	var reason: String=Management.Scouting.rejection(Session.season.state.management.scouting_jobs,scouting_id,int(Session.season.state.day),Management.Scouting.candidates(Session.season.state.world))
	var button:=UI.button("Assign scout & save",assign_selected_scout);button.disabled=not reason.is_empty() or Session.checkpoint_active or not Session.pending_result.is_empty() or not Session.fixture_id.is_empty();scouting_detail.add_child(button)
	if not reason.is_empty():
		var reason_label:=UI.text(reason,14,UI.MUTED);reason_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;scouting_detail.add_child(reason_label)
	scouting_detail.add_child(UI.text("Ranges include observation uncertainty.
Generated ratings are uncalibrated estimates.
The roster room remains a full-data browser.
Draft picks and development are still pending.",14,UI.MUTED))

func assign_selected_scout() -> void:
	if Session.checkpoint_active or checkpoint_job!=null or not Session.pending_result.is_empty() or not Session.fixture_id.is_empty(): return
	candidate=Session.Season.new();candidate.state=Session.season.state.duplicate(true);candidate.database=Session.season.database;candidate.strengths=Session.season.strengths.duplicate(true)
	if not candidate.assign_scout(scouting_id): message.text=candidate.error;candidate=null;return
	transaction_notice="Scout assignment saved. Advance the league day to receive the report."
	await save_candidate()

func table_line(parent: Node, values: Array, widths: Array, color: Color, font_size: int, align_numbers: bool=false) -> void:
	var line:=HBoxContainer.new();parent.add_child(line)
	for i in range(values.size()):
		var cell:=UI.text(str(values[i]),font_size,color);cell.custom_minimum_size.x=widths[i]
		if align_numbers and i>0: cell.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
		line.add_child(cell)
