extends SceneTree
const Season=preload("res://scripts/gm_season.gd")
const Management=preload("res://scripts/gm_management.gd")
const Session=preload("res://scripts/gm_session.gd")
var checks:=0
var failures:=0
func check(ok: bool, why: String) -> void:
	checks+=1
	if not ok: push_error(why);failures+=1
func _initialize() -> void: call_deferred("run")
func settle() -> void:
	for i in range(4): await process_frame
func run() -> void:
	var model:=Season.new()
	check(model.new_season(FileAccess.get_file_as_string(Season.Database.DEFAULT_PATH),"har",77),"Create economy season")
	var management: Dictionary=model.state.management
	check(management.market.size()==64 and management.contracts.size()==736,"64 free agents and every HL player contracted")
	check(model.validate(model.state),"Economy snapshot validates")
	for id_ in model.state.team_ids:
		check(Management.payroll(management,id_)<=Management.POLICY.ceiling,"Every initial club fits the cap")
	var old:=model.state.duplicate(true);old.erase("management")
	var restored:=Season.new()
	check(restored.load_state(old),"Legacy GM snapshot migrates in memory")
	check(restored.state.management==management and not old.has("management"),"Migration deterministic and input preserved")
	var world_hash: String=JSON.stringify(model.state.world).sha256_text()
	var market: Array=management.market.duplicate(true)
	market.sort_custom(func(a,b): return Management.ability(a.player)>Management.ability(b.player))
	var offer: Dictionary=market[0]
	var before:=model.state.duplicate(true)
	for invalid in [[0,1],[NAN,1],[INF,1],[offer.ask_aav,0],[offer.ask_aav,6],[offer.ask_aav,1.5],[offer.ask_aav-1,offer.ask_years],[Management.POLICY.max_player+1,3]]:
		check(not model.sign_free_agent(offer.player.id,invalid[0],invalid[1]),"Invalid offer rejected")
		check(model.state==before,"Rejected offer is atomic")
	check(not model.sign_free_agent("unknown",2000000,3),"Unknown player rejected")
	var payroll:=Management.payroll(management,"har")
	check(model.sign_free_agent(offer.player.id,offer.ask_aav,offer.ask_years),"Valid offer accepted")
	check(Management.payroll(management,"har")==payroll+int(offer.ask_aav),"Exact dollar payroll delta")
	check(management.transactions.size()==1 and Management.contract_count(management,"har")==24,"One contract and transaction recorded")
	check(model.match_roster("har").slice(0,20).any(func(p): return p.id==offer.player.id),"High-rated signing dresses in actual GM roster")
	var numbers: Dictionary={}
	for p in model.match_roster("har"):
		check(not numbers.has(p.number),"Unique jerseys after free-agent integration")
		numbers[p.number]=true
	check(model.match_roster("har").size()==23,"Match active roster retains 23-player limit")
	check(model.validate(model.state),"Signed career validates")
	check(not model.sign_free_agent(offer.player.id,offer.ask_aav,offer.ask_years),"Duplicate signing rejected")
	check(JSON.stringify(model.state.world).sha256_text()==world_hash,"Original 643-club snapshot stays unchanged")
	check(restored.load_state(model.state) and restored.match_roster("har")==model.match_roster("har"),"Save/resume preserves dressed signed player")
	for mutation in ["aav","years","club","market","policy","sequence","missing","extra","day"]:
		var bad:=model.state.duplicate(true)
		match mutation:
			"aav": bad.management.contracts[offer.player.id].aav+=1
			"years": bad.management.contracts[offer.player.id].years=9
			"club": bad.management.transactions[0].club="unknown"
			"market": bad.management.market[0].player.name="Tampered"
			"policy": bad.management.policy.ceiling=999999999
			"sequence": bad.management.transactions[0].sequence=5
			"missing": bad.management.contracts.erase(model.club("har").players[0].id)
			"extra": bad.management.contracts["ghost"]={"club":"har","aav":1000000,"years":1}
			"day": bad.management.transactions[0].day=62
		check(not model.validate(bad),"Reject corrupted management: "+mutation)
	# Fill cap headroom using legitimate transactions, then reject another max offer.
	for row in market.slice(1):
		if Management.payroll(management,"har")+Management.POLICY.max_player>Management.POLICY.ceiling: break
		check(model.sign_free_agent(row.player.id,Management.POLICY.max_player,3),"Legitimate high offer within remaining cap")
	var next: Dictionary=market.filter(func(r): return not management.contracts.has(r.player.id))[0]
	before=model.state.duplicate(true)
	check(not model.sign_free_agent(next.player.id,Management.POLICY.max_player,3) and model.error.contains("ceiling"),"Over-cap offer rejected with reason")
	check(model.state==before,"Cap rejection preserves complete season")
	check(model.validate(model.state),"Multiple transactions replay and validate")
	# Team-stat reconciliation and reliable record sorting, using saved finals only.
	check(model.simulate_day(),"Advance league day with signed team")
	var gf:=0;var ga:=0;var home_w:=0;var away_w:=0
	for row in model.team_statistics():
		gf+=row.gf;ga+=row.ga;home_w+=row.home_w;away_w+=row.away_w
		check(row.gp==1 and is_equal_approx(row.gf_gp,float(row.gf)),"Team per-game rates reconcile")
	check(gf==ga and home_w+away_w==16,"League goals and venue wins reconcile")
	var records:=model.season_records()
	check(records.size()==16,"One record per completed fixture")
	for i in range(1,records.size()): check(records[i-1].total>=records[i].total,"Records ordered by total goals")
	# Actual UI, worker save, duplicate guards, failure preservation and disk resume.
	Session.season=restored;Session.fixture_id="";Session.pending_result={}
	var original_path:=Session.slot_path;Session.slot_path="user://tests/gm-management.json"
	change_scene_to_file("res://gm_office.tscn");await settle()
	var screen=current_scene
	check(screen.rows.get_child_count()==63,"Native market excludes signed player")
	screen.sign_selected()
	check(Session.checkpoint_active and screen.sign_button.disabled,"Contract worker guards duplicate input")
	var current_count: int=Session.season.state.management.transactions.size()
	while screen.checkpoint_job!=null: await process_frame
	print("Contract worker outcome: ",screen.status," counts ",current_count," -> ",Session.season.state.management.transactions.size())
	check(Session.season.state.management.transactions.size()==current_count+1,"Successful save publishes one contract")
	check(Session.season.state.day==0,"Signing does not advance league calendar")
	check(Session.resume() and Session.season.state.management.transactions.size()==current_count+1,"Contract survives validated disk resume")
	var hash_before: String=JSON.stringify(Session.season.state).sha256_text()
	Session.slot_path="/proc/hawkey-management-no-write/slot.json"
	await screen.sign_selected()
	check(JSON.stringify(Session.season.state).sha256_text()==hash_before and not Session.checkpoint_active,"Failed contract save retains exact live season")
	check(screen.message.text.contains("write") or screen.message.text.contains("directory"),"Failed save visible to player")
	for mode in [1,2,3]:
		screen.tab=mode;screen.build();await settle()
		check(screen.rows.get_child_count()>0 if mode!=3 else true,"Functional front-office page populated")
	Session.slot_path="user://tests/gm-management.json"
	change_scene_to_file("res://gm.tscn");await settle()
	current_scene.play_game();await settle()
	check(current_scene.is_gm_match and current_scene.rosters[0].slice(0,20).any(func(p): return p.id==offer.player.id),"Signed stable identity reaches actual scheduled match")
	current_scene.queue_free();await process_frame;Session.season=null;Session.fixture_id=""
	Session.slot_path="user://tests/gm-management.json"
	for suffix in ["",".bak",".tmp",".bak.tmp"]:
		if FileAccess.file_exists(Session.slot_path+suffix): DirAccess.remove_absolute(Session.slot_path+suffix)
	Session.slot_path=original_path
	print("GM management: %d checks; %d failures"%[checks,failures]);quit(failures)
