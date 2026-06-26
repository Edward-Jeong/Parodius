extends SceneTree

func _init() -> void:
	var failures: Array[String] = []
	var player: PlayerConfig = load("res://data/player_config.tres")
	if player.max_hp != 3:
		failures.append("Player max_hp must be 3")
	if player.special_max != 100.0:
		failures.append("Special meter must cap at 100")
	var weapon_paths := [
		"res://data/weapons/basic.tres",
		"res://data/weapons/spread.tres",
		"res://data/weapons/homing.tres",
		"res://data/weapons/shield.tres",
		"res://data/weapons/speed.tres"
	]
	var kinds: Array[String] = []
	for path in weapon_paths:
		var weapon: WeaponData = load(path)
		kinds.append(weapon.kind)
	if kinds != ["basic", "spread", "homing", "shield", "speed"]:
		failures.append("Five upgrade kinds are not configured in order")
	var checkpoints: Array[float] = []
	for path in [
		"res://data/checkpoints/start.tres",
		"res://data/checkpoints/zone_2.tres",
		"res://data/checkpoints/zone_3.tres",
		"res://data/checkpoints/boss.tres"
	]:
		var checkpoint: CheckpointData = load(path)
		checkpoints.append(checkpoint.time_seconds)
	if checkpoints != [0.0, 105.0, 235.0, 400.0]:
		failures.append("Checkpoint timeline is invalid")
	var wave_paths := [
		"res://data/waves/zone_1.tres",
		"res://data/waves/zone_1_popcorn.tres",
		"res://data/waves/zone_1_formation.tres",
		"res://data/waves/zone_2.tres",
		"res://data/waves/zone_2_arc.tres",
		"res://data/waves/zone_2_shooter.tres",
		"res://data/waves/zone_3.tres",
		"res://data/waves/zone_3_formation.tres",
		"res://data/waves/zone_3_shooter.tres"
	]
	var reward_formations := 0
	for path in wave_paths:
		var wave: EnemyWave = load(path)
		if wave == null:
			failures.append("Wave did not load: " + path)
			continue
		if wave.formation_size < 1 or wave.formation_size > 8:
			failures.append("Wave formation_size out of range: " + path)
		if wave.spawn_interval <= 0.0:
			failures.append("Wave spawn_interval must be positive: " + path)
		if wave.reward_on_clear:
			reward_formations += 1
			if wave.formation_size != 5:
				failures.append("Reward formation must use five enemies: " + path)
	if reward_formations < 3:
		failures.append("Expected at least three reward formations")
	for action in ["move_left", "move_right", "move_up", "move_down"]:
		if not InputMap.has_action(action):
			failures.append("Missing PC movement action: " + action)
	Input.action_press("move_right")
	if Input.get_vector("move_left", "move_right", "move_up", "move_down").x < 0.9:
		failures.append("Right-arrow movement vector is not available")
	Input.action_press("move_up")
	var diagonal := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if diagonal.x < 0.6 or diagonal.y > -0.6:
		failures.append("Diagonal movement vector is not available")
	Input.action_release("move_right")
	Input.action_release("move_up")
	if failures.is_empty():
		print("SMOKE_TEST_PASS")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)
