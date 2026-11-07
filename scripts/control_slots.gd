extends RefCounted
## Who controls each player position: the Play Now seat model.
##
## Hawkey has one game mode, PLAY NOW, built so it can go online later: every
## position on both teams (C, LW, RW, LD, RD, G) is a SEAT. A CPU holds every
## seat until a human claims it, and gets it back when the human leaves, so a
## game always has 12 players whatever the number of people. Today one local
## human plays; the same claim/release calls are what a network lobby will
## make for remote players (owner ids like "net:<peer>").
##
## Control styles for a human:
## - TEAM: classic console hockey. The human controls whichever skater on his
##   team is best placed (switch player), CPUs play the rest.
## - POSITION: the human IS one position (online-style, like a pro); no
##   switching. When lines change, he controls whoever plays that position.
##
## Pure data (no scene), so it can be tested and serialised for the network.

const MODES := ["play_now"]
const POSITIONS := ["C", "LW", "RW", "LD", "RD", "G"]
const GOALIE := 5
const CPU := ""
const STYLE_TEAM := "team"
const STYLE_POSITION := "position"
## Order a joining human is given an open seat in (goalie last).
const JOIN_ORDER := [0, 1, 2, 3, 4, 5]

var mode := "play_now"
## owners[team][position] = "" (CPU) or a human owner id.
var owners: Array = []
## Human owner id -> {"team", "position", "style"}.
var humans := {}

func _init() -> void:
	owners = [[], []]
	for team in range(2):
		for i in range(POSITIONS.size()):
			owners[team].append(CPU)

static func position_name(position: int) -> String:
	return POSITIONS[clampi(position, 0, POSITIONS.size() - 1)]

func is_cpu(team: int, position: int) -> bool:
	return owners[team][position] == CPU

func owner(team: int, position: int) -> String:
	return owners[team][position]

## Claim a seat for a human. Only a CPU-held seat can be claimed (a human
## never bumps another human). A human holds one seat at a time: claiming
## another releases the old one back to the CPU.
func claim(human: String, team: int, position: int, style := STYLE_POSITION) -> bool:
	if human == CPU or team < 0 or team > 1 or position < 0 or position >= POSITIONS.size():
		return false
	if not is_cpu(team, position) and owners[team][position] != human:
		return false
	release(human)
	owners[team][position] = human
	humans[human] = {"team": team, "position": position, "style": style}
	return true

## Join a team: take the first open seat in JOIN_ORDER (skaters before the
## goalie). Returns the position or -1 when the team is full of humans.
func join(human: String, team: int, style := STYLE_TEAM) -> int:
	if humans.has(human) and int(humans[human].team) == team:
		return int(humans[human].position)
	for position in JOIN_ORDER:
		if is_cpu(team, position):
			claim(human, team, position, style)
			return position
	return -1

## A human leaves (or drops from the network): the CPU takes the seat back.
func release(human: String) -> void:
	if not humans.has(human):
		return
	var seat: Dictionary = humans[human]
	if owners[seat.team][seat.position] == human:
		owners[seat.team][seat.position] = CPU
	humans.erase(human)

## TEAM style: the human's seat follows the skater he switched to.
func move(human: String, position: int) -> bool:
	if not humans.has(human):
		return false
	var seat: Dictionary = humans[human]
	if int(seat.position) == position:
		return true
	if not is_cpu(int(seat.team), position):
		return false
	var style: String = seat.style
	return claim(human, int(seat.team), position, style)

func seat_of(human: String) -> Dictionary:
	return humans.get(human, {})

func team_of(human: String) -> int:
	return int(humans[human].team) if humans.has(human) else -1

func human_count(team := -1) -> int:
	var count := 0
	for seat in humans.values():
		if team < 0 or int(seat.team) == team:
			count += 1
	return count

func cpu_count(team := -1) -> int:
	var count := 0
	for t in range(2):
		if team >= 0 and t != team:
			continue
		for position in range(POSITIONS.size()):
			if is_cpu(t, position):
				count += 1
	return count

## Network snapshot / restore (lobby state for every client).
func to_dict() -> Dictionary:
	return {"mode": mode, "owners": owners.duplicate(true), "humans": humans.duplicate(true)}

func from_dict(data: Dictionary) -> void:
	mode = str(data.get("mode", "play_now"))
	owners = (data.get("owners", owners) as Array).duplicate(true)
	humans = (data.get("humans", {}) as Dictionary).duplicate(true)

## Human-readable line for the HUD: "TOR: YOU C · CPU 4" style.
func summary(team: int, local_human := "") -> String:
	var parts := []
	for position in range(POSITIONS.size()):
		var who: String = owners[team][position]
		if who == CPU:
			continue
		parts.append(("YOU " if who == local_human else "P ") + position_name(position))
	parts.append("CPU %d" % cpu_count(team))
	return "  ·  ".join(parts)
