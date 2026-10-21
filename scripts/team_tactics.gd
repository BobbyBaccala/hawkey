extends RefCounted
## Pure team-coordinate planner. All movement still goes through Skating.step.
const Arena=preload("res://scripts/arena.gd")
const OPTIONS={
	"offense":["Cycle", "Overload", "Crash the net"],
	"defense":["Protect the slot", "Tight point", "Man coverage"],
	"forecheck":["1-2-2", "2-1-2", "1-3-1"],
	"breakout":["Wide support", "Center swing", "Stretch"],
	"powerplay":["1-3-1", "Umbrella", "Overload"],
	"penaltykill":["Box", "Diamond", "Pressure"]}
static var choices: Array = [defaults(), defaults()]
static func defaults() -> Dictionary:
	return {"offense":0,"defense":0,"forecheck":0,"breakout":0,"powerplay":0,"penaltykill":0}
static func set_choice(team: int,key: String,index: int) -> bool:
	if team<0 or team>1 or not OPTIONS.has(key) or index<0 or index>=OPTIONS[key].size(): return false
	choices[team][key]=index
	return true
static func local_point(p: Vector3, attack: float) -> Vector3:
	return Vector3(p.x,0,p.z*attack)
static func bounded(p: Vector3) -> Vector3:
	p.y=0
	p.z=clampf(p.z,-Arena.HALF_LENGTH+1.2,Arena.HALF_LENGTH-1.2)
	p.x=clampf(p.x,-Arena.corner_half_width(absf(p.z))+1.2,Arena.corner_half_width(absf(p.z))-1.2)
	return p
static func plan(actors: Array, opponents: Array, puck: Vector3, owner: int, attack: float, config: Dictionary, strength: Vector2i=Vector2i.ZERO) -> Dictionary:
	# actor dictionaries: id, slot, position. owner is a teammate id or -1.
	var result:={}
	if actors.is_empty(): return result
	var p:=local_point(puck,attack)
	var own:=owner>=0
	var nearest: int=int(actors[0].id)
	var distance:=INF
	for actor in actors:
		var d: float=actor.position.distance_squared_to(puck)
		if d<distance: distance=d;nearest=int(actor.id)
	var own_count:=actors.size() if strength==Vector2i.ZERO else strength.x
	var opponent_count:=opponents.size() if strength==Vector2i.ZERO else strength.y
	var special:=own_count!=opponent_count
	var phase:="Offensive zone" if p.z>Arena.BLUE_LINE else ("Breakout" if p.z< -Arena.BLUE_LINE else "Transition")
	if not own: phase="Defensive zone" if p.z< -Arena.BLUE_LINE else "Forecheck"
	if special: phase="Power play" if own_count>opponent_count else "Penalty kill"
	var side:=1.0 if p.x>=0 else -1.0
	var marking: Array=opponents.duplicate()
	marking.sort_custom(func(a,b): return a.position.distance_squared_to(puck)<b.position.distance_squared_to(puck))
	if not marking.is_empty(): marking.pop_front() # Puck threat is covered by the pressure player.
	var rank:=0
	var support_rank:=0
	for actor in actors:
		var target:=Vector3.ZERO
		var role:="Support"
		var slot: int=int(actor.slot)
		var i:=rank;rank+=1
		var supporting:=int(actor.id)!=owner if own else int(actor.id)!=nearest
		var support:=support_rank
		if supporting: support_rank+=1
		if int(actor.id)==owner:
			role="Puck carrier"
			target=Vector3(clampf(p.x*0.6,-7,7),0,Arena.GOAL_LINE-6)
			if special and own_count<opponent_count:
				role="PK outlet / clear";target=Vector3(side*9,0,p.z+6)
			elif own and p.z< -Arena.BLUE_LINE:
				role="Breakout carrier";target=Vector3(p.x*0.7,0,p.z+7)
		elif special and own_count<opponent_count:
			var pk: int=int(config.penaltykill)
			var pts: Array=[Vector3(-3.8,0,-16),Vector3(3.8,0,-16),Vector3(-3.1,0,-22),Vector3(3.1,0,-22)]
			if pk==1: pts=[Vector3(0,0,-13),Vector3(-5,0,-19),Vector3(5,0,-19),Vector3(0,0,-23)]
			if actors.size()<=3: pts=[Vector3(0,0,-15),Vector3(-3.5,0,-22),Vector3(3.5,0,-22)]
			target=pts[i%pts.size()]+Vector3(p.x*0.12,0,0)
			role="PK lane / crease"
			if not own and int(actor.id)==nearest and (pk==2 or actor.position.distance_to(puck)<3):
				target=p;role="PK pressure"
		elif special and own and p.z>Arena.BLUE_LINE:
			var pp: int=int(config.powerplay)
			var pts: Array=[Vector3(0,0,10),Vector3(-7,0,17),Vector3(7,0,17),Vector3(0,0,19),Vector3(0,0,24)]
			if pp==1: pts=[Vector3(0,0,10),Vector3(-7,0,12),Vector3(7,0,12),Vector3(-3,0,23),Vector3(3,0,23)]
			if pp==2: pts=[Vector3(-side*3,0,10),Vector3(side*8,0,16),Vector3(side*7,0,23),Vector3(side*2,0,20),Vector3(0,0,24)]
			# Remaining ranks occupy distinct stations, excluding nearest station to carrier.
			var used:=0;var carrier_station:=0;var best:=INF
			for j in range(pts.size()):
				if pts[j].distance_squared_to(p)<best: best=pts[j].distance_squared_to(p);carrier_station=j
			for previous in actors:
				if previous.id==actor.id: break
				if previous.id!=owner: used+=1
			var station:=used if used<carrier_station else used+1
			target=pts[station%pts.size()];role="PP station / passing lane"
		elif not own and int(actor.id)==nearest:
			target=p;role="Pressure / recover"
		elif own and p.z< -Arena.BLUE_LINE:
			var b: int=int(config.breakout)
			var pts: Array=[Vector3(0,0,p.z+7),Vector3(-10,0,p.z+5),Vector3(10,0,p.z+5),Vector3(-5,0,p.z-3),Vector3(5,0,p.z-3)]
			if b==1: pts[0]=Vector3(side*2,0,p.z+3);pts[1]=Vector3(-8,0,p.z+10);pts[2]=Vector3(8,0,p.z+10)
			if b==2: pts[0]=Vector3(0,0,minf(5,p.z+22));pts[1].z=p.z+12;pts[2].z=p.z+12
			target=pts[slot];role="Breakout outlet"
		elif own:
			var o: int=int(config.offense)
			var pts: Array=[Vector3(0,0,p.z+4),Vector3(-7,0,p.z+1),Vector3(7,0,p.z+1),Vector3(-5,0,p.z-7),Vector3(5,0,p.z-7)]
			if p.z>Arena.BLUE_LINE:
				pts=[Vector3(0,0,22),Vector3(-8,0,20),Vector3(8,0,20),Vector3(-5,0,10),Vector3(5,0,10)]
				if o==1: pts[0]=Vector3(side*3,0,23);pts[1]=Vector3(side*8,0,18);pts[2]=Vector3(side*7,0,24)
				if o==2: pts[0]=Vector3(0,0,24);pts[1]=Vector3(-2.6,0,23);pts[2]=Vector3(2.6,0,23)
			if actors.size()==3:
				pts=[Vector3(-side*6,0,p.z+1),Vector3(0,0,p.z-7)]
				target=pts[support%2]
			elif actors.size()==4:
				pts=[Vector3(-6,0,p.z+1),Vector3(6,0,p.z+1),Vector3(0,0,p.z-7)]
				target=pts[support%3]
			else: target=pts[slot]
			role="Attack support" if slot<3 else "Point / safety"
		elif p.z< -Arena.BLUE_LINE:
			var d: int=int(config.defense)
			var pts: Array=[Vector3(-5,0,-16),Vector3(5,0,-16),Vector3(-3,0,-22),Vector3(3,0,-22)]
			if d==1: pts[0]=Vector3(-7,0,-10);pts[1]=Vector3(7,0,-10)
			target=pts[support%pts.size()]+Vector3(p.x*0.15,0,0);role="Zone coverage"
			if d==2 and not marking.is_empty():
				# Stable slot-to-opponent matching; no multiple nearest-opponent chasing.
				var mark: Vector3=local_point(marking[support%marking.size()].position,attack)
				target=mark.lerp(Vector3(0,0,-Arena.GOAL_LINE),0.18);role="Man coverage"
		else:
			var f: int=int(config.forecheck)
			var pts: Array=[Vector3(-6,0,p.z-5),Vector3(6,0,p.z-5),Vector3(-5,0,p.z-12),Vector3(5,0,p.z-12)]
			if f==1: pts=[Vector3(-side*3,0,p.z-1),Vector3(0,0,p.z-6),Vector3(-5,0,p.z-11),Vector3(5,0,p.z-11)]
			if f==2: pts=[Vector3(-8,0,p.z-7),Vector3(0,0,p.z-7),Vector3(8,0,p.z-7),Vector3(0,0,p.z-15)]
			if actors.size()<=3: pts=[Vector3(-5,0,p.z-5),Vector3(5,0,p.z-12)]
			elif actors.size()==4: pts=[Vector3(0,0,p.z-5),Vector3(-5,0,p.z-12),Vector3(5,0,p.z-12)]
			target=pts[support%pts.size()]+Vector3(p.x*0.2,0,0);role="Forecheck lane / safety"

		# Hold support onside during controlled entries; carrier/recovery may cross.
		if own and int(actor.id)!=owner and p.z<Arena.BLUE_LINE-0.4:
			target.z=minf(target.z,Arena.BLUE_LINE-0.65)
		result[actor.id]={"target":bounded(local_point(target,attack)),"role":role,"phase":phase}
	return result
