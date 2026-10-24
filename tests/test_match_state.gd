extends SceneTree
const Match = preload("res://scripts/match_state.gd")
var failures:=0
func check(ok:bool,message:String)->void:
	if not ok:push_error(message);failures+=1
func _initialize()->void:
	var m:=Match.new()
	check(m.count(0)==5 and m.count(1)==5,"Even strength must start five-on-five")
	m.advance(3)
	check(m.phase==Match.Phase.PLAY,"Faceoff must enter play")
	m.advance(1)
	check(is_equal_approx(m.clock,1196),"Game clock must count down at configured rate")
	m.minor(0,1,"Tripping",120)
	check(m.count(0)==4,"Minor must reduce penalized team")
	var clock:=m.clock
	m.advance(1)
	check(is_equal_approx(m.clock,clock),"Whistle must stop clock and penalty countdown")
	m.phase=Match.Phase.PLAY
	m.advance(10)
	check(is_equal_approx(m.penalties[0].remaining,80),"Minor must use game time")
	m.goal(1)
	check(m.penalties.is_empty() and m.count(0)==5,"Power-play goal releases one minor")
	m.phase=Match.Phase.PLAY
	m.minor(0,2,"Interference",3)
	m.phase=Match.Phase.PLAY
	m.minor(0,3,"Tripping",5)
	m.phase=Match.Phase.PLAY
	m.minor(0,4,"Charging",9)
	check(m.count(0)==3,"Never fewer than three skaters")
	check(not m.penalties[2].active,"Third minor must queue")
	m.phase=Match.Phase.PLAY
	m.advance(1)
	check(m.penalties.size()==2 and m.penalties[1].active,"Queued minor starts when first expires")
	check(m.penalties[1].remaining==9,"Queued timer must not tick before activation")
	m=Match.new()
	m.phase=Match.Phase.PLAY
	m.clock=1
	m.advance(1)
	check(m.phase==Match.Phase.INTERMISSION,"Period horn must stop play")
	m.advance(6)
	check(m.period==2 and m.clock==1200,"Next period resets clock")
	m.period=3
	m.phase=Match.Phase.PLAY
	m.clock=1
	m.advance(1)
	check(m.phase==Match.Phase.FINAL,"Third period must end match")
	print("Match-state failures: ",failures)
	quit(failures)
