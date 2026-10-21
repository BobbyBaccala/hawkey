extends RefCounted
## Original HL economy preset. Not a verified NHL CBA implementation.
const Scouting=preload("res://scripts/gm_scouting.gd")
const POLICY={"id":"hl-alpha-1","ceiling":104000000,"minimum":1000000,"max_term":5,"contract_limit":50,"max_player":20800000}
const FIRST=["Adrian","Bennett","Caleb","Dorian","Ellis","Felix","Gareth","Hugo","Isaac","Jonas","Kieran","Luca","Marek","Nolan","Oscar","Pavel"]
const LAST=["Ashcombe","Briar","Colborne","Dunvale"]

static func equivalent(a: Variant, b: Variant) -> bool:
	# JSON numbers reload as floats; preserve numeric value without coercing strings/bools.
	if (a is int or a is float) and (b is int or b is float): return is_finite(float(a)) and is_finite(float(b)) and float(a)==float(b)
	if typeof(a)!=typeof(b): return false
	if a is Dictionary:
		if a.size()!=b.size(): return false
		for key in a:
			if not b.has(key) or not equivalent(a[key],b[key]): return false
		return true
	if a is Array:
		if a.size()!=b.size(): return false
		for i in range(a.size()):
			if not equivalent(a[i],b[i]): return false
		return true
	return a==b

static func ability(player: Dictionary) -> float:
	var keys: Array=["reflexes","positioning","rebound_control"] if player.position=="G" else ["speed","passing","shot_accuracy","defensive_awareness"]
	var total:=0.0
	for key in keys: total+=float(player.ratings[key])
	return total/keys.size()

static func initial(world: Dictionary) -> Dictionary:
	var result: Dictionary={"version":1,"policy":POLICY.duplicate(true),"market":[],"contracts":{},"transactions":[],"scouting_jobs":[]}
	var templates: Array=[]
	for team in world.teams:
		if team.league_id!="hl": continue
		for p in team.players:
			templates.append(p)
			var n: int=p.id.sha256_text().substr(0,7).hex_to_int()
			result.contracts[p.id]={"club":team.id,"aav":2000000+(n%41)*50000,"years":1+n%5}
	for i in range(64):
		var p: Dictionary=templates[i].duplicate(true)
		p.id="generated:hl-market:%03d"%i
		p.name=FIRST[i%16]+" "+LAST[i/16]
		p.birth_date="%d-04-12"%[1992+i%12]
		p.hl_rights_team_id=null
		p.identity_kind="generated"
		p.potential=95
		for key in p.ratings: p.ratings[key]=68+(i*7+str(key).length()*3)%23
		p.rating_metadata={"kind":"estimate","method":"original HL market alpha v1; uncalibrated","confidence":"unassessed"}
		p.skill_rating_metadata=p.rating_metadata.duplicate(true)
		result.market.append({"player":p,"ask_aav":1250000+int(ability(p)-68)*150000,"ask_years":1+i%3})
	return result

static func payroll(management: Dictionary, club: String) -> int:
	var total:=0
	for contract in management.contracts.values():
		if contract.club==club: total+=int(contract.aav)
	return total

static func contract_count(management: Dictionary, club: String) -> int:
	return management.contracts.values().filter(func(c): return c.club==club).size()

static func rejection(management: Dictionary, club: String, id_: String, aav: Variant, years: Variant, whole: Callable) -> String:
	var offers: Array=management.market.filter(func(row): return row.player.id==id_)
	if offers.is_empty(): return "Player is not in this free-agent market."
	if management.contracts.has(id_): return "Player has already signed."
	if not whole.call(aav,POLICY.minimum,POLICY.max_player): return "Annual salary must be whole dollars within the HL limits."
	if not whole.call(years,1,POLICY.max_term): return "HL alpha contracts run from one to five years."
	if aav<offers[0].ask_aav or years<offers[0].ask_years: return "Offer declined: meet the requested annual salary and minimum term."
	if contract_count(management,club)>=POLICY.contract_limit: return "The organization has reached 50 contracts."
	if payroll(management,club)+aav>POLICY.ceiling: return "Offer exceeds the HL salary ceiling."
	return ""

static func validate(data: Variant, world: Dictionary, ids: Array, day: int, whole: Callable) -> bool:
	if not data is Dictionary or data.keys().size()!=6 or data.get("version")!=1 or not equivalent(data.get("policy"),POLICY): return false
	if not data.get("market") is Array or not data.get("contracts") is Dictionary or not data.get("transactions") is Array: return false
	if not Scouting.validate(data.get("scouting_jobs"),world,day,whole): return false
	var expected:=initial(world)
	if not equivalent(data.market,expected.market) or data.transactions.size()>64: return false
	for key in expected.contracts:
		if not equivalent(data.contracts.get(key),expected.contracts[key]): return false
	var replay: Dictionary=expected
	for tx in data.transactions:
		if not tx is Dictionary or tx.keys().size()!=6 or tx.get("club") not in ids or not tx.get("player") is String: return false
		if tx.get("sequence")!=replay.transactions.size()+1 or not whole.call(tx.get("day"),0,mini(day,61)): return false
		if not replay.transactions.is_empty() and tx.day<replay.transactions[-1].day: return false
		if not rejection(replay,tx.club,tx.player,tx.get("aav"),tx.get("years"),whole).is_empty(): return false
		replay.contracts[tx.player]={"club":tx.club,"aav":tx.aav,"years":tx.years}
		replay.transactions.append(tx)
	return equivalent(replay.contracts,data.contracts)

static func organization(management: Dictionary, team: Dictionary) -> Array:
	var result: Array=team.players.duplicate(true)
	for row in management.market:
		var contract: Dictionary=management.contracts.get(row.player.id,{})
		if contract.get("club")==team.id:
			var p: Dictionary=row.player.duplicate(true)
			p.hl_rights_team_id=team.id
			result.append(p)
	return result

static func active_team(management: Dictionary, team: Dictionary) -> Dictionary:
	# Original automatic depth selection; waiver/assignment rules are not implemented.
	var result: Dictionary=team.duplicate(true)
	var all:=organization(management,team)
	if all.size()==team.players.size(): return result
	result.players=[]
	for position in ["C","LW","RW","D","G"]:
		var players: Array=all.filter(func(p): return p.position==position)
		players.sort_custom(func(a,b): return ability(a)>ability(b) if ability(a)!=ability(b) else a.id<b.id)
		var slots: int={"C":4,"LW":5,"RW":5,"D":7,"G":2}[position]
		result.players.append_array(players.slice(0,slots))
	# Resolve jersey conflicts in the match copy; retain original profiles in the save.
	var numbers: Dictionary={}
	for p in result.players:
		var number: int=int(p.jersey_number)
		while numbers.has(number): number=number%99+1
		numbers[number]=true;p.jersey_number=number
	return result
