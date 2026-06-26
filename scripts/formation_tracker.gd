class_name FormationTracker
extends RefCounted

var groups: Dictionary = {}
var sequence := 0

func reset() -> void:
	groups.clear()
	sequence = 0

func begin(size: int, reward_on_clear: bool) -> String:
	sequence += 1
	var group_id := "formation_%d" % sequence
	groups[group_id] = {
		"remaining": size,
		"failed": false,
		"reward": reward_on_clear,
		"kind": (sequence - 1) % 5
	}
	return group_id

func size_for(group_id: String) -> int:
	if group_id == "" or not groups.has(group_id):
		return 1
	return int(groups[group_id].remaining)

func resolve(group_id: String, killed: bool) -> Dictionary:
	if group_id == "" or not groups.has(group_id):
		return {"completed": false, "reward": false, "kind": -1}
	var group: Dictionary = groups[group_id]
	if not killed:
		group.failed = true
	group.remaining = maxi(0, int(group.remaining) - 1)
	if group.remaining <= 0:
		var result := {
			"completed": true,
			"reward": bool(group.reward) and not bool(group.failed),
			"kind": int(group.kind)
		}
		groups.erase(group_id)
		return result
	groups[group_id] = group
	return {"completed": false, "reward": false, "kind": -1}
