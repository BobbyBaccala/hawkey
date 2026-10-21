extends SceneTree
const T=preload("res://scripts/team_tactics.gd")
const Arena=preload("res://scripts/arena.gd")
var checks:=0
var failures:=0
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok: failures+=1;push_error(message)
func squad(count_: int,base: int=0) -> Array:
	var a: Array=[]
	for i in range(count_): a.append({"id":base+i,"slot":i,"position":Vector3((i-2)*3,0,0)})
	return a
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var a:=squad(5);var b:=squad(5,10);var c:=T.defaults()
	for key in T.OPTIONS:
		var puck:=Vector3(4,0,18)
		var owner:=0
		var aa:=a;var bb:=b
		if key=="defense": puck.z=-18;owner=-1
		if key=="forecheck": puck.z=10;owner=-1
		if key=="breakout": puck.z=-18
		if key=="powerplay": bb=squad(4,10)
		if key=="penaltykill": aa=squad(4);puck.z=-18;owner=-1
		var signatures: Array=[]
		for option in range(3):
			c=T.defaults();c[key]=option
			var plan:=T.plan(aa,bb,puck,owner,1,c)
			check(plan.size()==aa.size(),key+" assigns every active player")
			var signature: Array=[]
			for actor in aa:
				var target: Vector3=plan[actor.id].target
				check(target.is_finite() and absf(target.x)<Arena.corner_half_width(absf(target.z)) and absf(target.z)<Arena.HALF_LENGTH,key+" finite legal ice targets")
				signature.append(target)
			check(not signatures.has(signature),key+" changes actual assignments")
			signatures.append(signature)
	# A defenseman becoming F1 must not remove the second safety player.
	var rotating:=squad(5)
	rotating[4].position=Vector3(0,0,12)
	var forecheck:=T.plan(rotating,b,Vector3(0,0,12),-1,1,T.defaults())
	var safeties:=0
	for actor in rotating:
		if forecheck[actor.id].target.z<2: safeties+=1
	check(safeties==2,"1-2-2 retains two safeties when a defenseman pressures")
	var three:=T.plan(squad(3),squad(3,10),Vector3(0,0,18),0,1,T.defaults())
	check(three[2].target.z<18,"Three-on-three possession retains a high safety")
	# Reverse ends mirrors z, including special teams.
	for count_ in [3,4,5]:
		var aa:=squad(count_)
		for other_count in [3,4,5]:
			var bb:=squad(other_count,10)
			for own in [-1,0]:
				for z in [-29.0,-18.0,0.0,18.0,29.0]:
					var forward:=T.plan(aa,bb,Vector3(4,0,z),own,1,T.defaults())
					var backward:=T.plan(aa,bb,Vector3(4,0,-z),own,-1,T.defaults())
					for actor in aa:
						var expected: Vector3=forward[actor.id].target;expected.z=-expected.z
						check(expected.is_equal_approx(backward[actor.id].target),"End reversal symmetry")
	# Support does not initiate offsides on entries.
	var entry:=T.plan(a,b,Vector3(0,0,6),0,1,T.defaults())
	for id in [1,2,3,4]: check(entry[id].target.z<Arena.BLUE_LINE,"Support holds onside")
	var recovery:=T.plan(a,b,Vector3(0,0,-29),-1,1,T.defaults())
	check(recovery[2].target.z< -Arena.GOAL_LINE,"Pursuer can recover behind own net")
	var pk:=T.plan(squad(3),b,Vector3(0,0,-18),-1,1,T.defaults())
	check(pk.size()==3,"Three-man PK degrades to triangle")
	var bench_gap:=T.plan(squad(4),b,Vector3(0,0,18),0,1,T.defaults(),Vector2i(5,5))
	check(bench_gap[1].phase!="Penalty kill","Bench transit is not special teams")
	check(T.plan([],b,Vector3.ZERO,-1,1,T.defaults()).is_empty(),"No active players is safe")
	check(not T.set_choice(-1,"offense",0) and not T.set_choice(0,"invalid",0) and not T.set_choice(1,"offense",9),"Invalid coaching selection rejected")
	print("Team tactics: %d checks; %d failures"%[checks,failures]);quit(failures)
