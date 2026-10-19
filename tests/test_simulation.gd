extends SceneTree
const Skating = preload("res://scripts/skating.gd")
func _initialize() -> void:
	var good := Vector3.ZERO
	var elite := Vector3.ZERO
	for i in range(120):
		good = Skating.step(good, Vector3.FORWARD, 55, false, 1.0 / 120)
		elite = Skating.step(elite, Vector3.FORWARD, 95, false, 1.0 / 120)
	assert(elite.length() > good.length(), "Ratings must change measurable skating speed")
	assert(Skating.step(good, Vector3.ZERO, 55, false, 0.1).length() < good.length())
	assert(Skating.goal_crossing(Vector3(0, 0.1, -24), Vector3(0, 0.1, -26)))
	assert(not Skating.goal_crossing(Vector3(0, 0.1, -26), Vector3(0, 0.1, -24)), "No scoring from back")
	assert(not Skating.goal_crossing(Vector3(2, 0.1, -24), Vector3(2, 0.1, -26)))
	assert(not Skating.goal_crossing(Vector3(0, 2, -24), Vector3(0, 2, -26)))
	print("PASS: rating acceleration, deceleration, front-mouth goal, back entry, wide and high misses")
	quit()
