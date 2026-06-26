extends SceneTree

func _init() -> void:
	call_deferred("run")

func run() -> void:
	var failures: Array[String] = []
	var scene: PackedScene = load("res://main.tscn")
	var game = scene.instantiate()
	root.add_child(game)
	await process_frame
	game.start_game()
	await process_frame

	var start_position: Vector2 = game.player.position
	Input.action_press("move_right")
	Input.action_press("move_up")
	game.update_player(0.1)
	Input.action_release("move_right")
	Input.action_release("move_up")
	if game.player.position.x <= start_position.x or game.player.position.y >= start_position.y:
		failures.append("Player did not move diagonally up-right")

	var background_start: float = game.scrolling_backgrounds[0].position.x
	game.update_background(1.0)
	if game.scrolling_backgrounds[0].position.x >= background_start:
		failures.append("Background did not scroll left")

	var audio_manager = root.get_node("AudioManager")
	if audio_manager.music_player.stream == null:
		failures.append("Music stream was not created")
	elif audio_manager.music_player.stream.data.is_empty():
		failures.append("Music stream has no PCM data")
	if audio_manager.sfx_streams.size() < 10:
		failures.append("Expected gameplay sound effects were not created")
	if not audio_manager.sfx_streams.has("formation"):
		failures.append("Formation warning sound was not created")
	var played_sfx: Array[String] = []
	audio_manager.sfx_played.connect(func(name: String): played_sfx.append(name))

	var formation_wave: EnemyWave = load("res://data/waves/zone_1_formation.tres")
	game.enemies.clear()
	game.pickups.clear()
	game.formation_tracker.reset()
	played_sfx.clear()
	game.spawn_wave(formation_wave)
	if game.enemies.size() != 5:
		failures.append("Reward formation did not spawn five enemies")
	if played_sfx.count("formation") != 1:
		failures.append("Reward formation did not play its warning sound exactly once")
	for enemy in game.enemies.duplicate():
		game.destroy_enemy(enemy)
	if game.pickups.size() != 1:
		failures.append("Cleared five-enemy formation did not create exactly one pickup")

	var non_reward_wave: EnemyWave = load("res://data/waves/zone_1_popcorn.tres")
	game.enemies.clear()
	game.formation_tracker.reset()
	played_sfx.clear()
	game.spawn_wave(non_reward_wave)
	if played_sfx.has("formation") or played_sfx.has("boss"):
		failures.append("Non-reward formation played a formation or boss warning sound")
	for enemy in game.enemies:
		enemy.node.queue_free()

	game.enemies.clear()
	game.pickups.clear()
	game.formation_tracker.reset()
	game.spawn_wave(formation_wave)
	var escaped_enemy: Dictionary = game.enemies[0]
	game.resolve_formation_enemy(escaped_enemy, false, escaped_enemy.node.position)
	escaped_enemy.node.queue_free()
	game.enemies.erase(escaped_enemy)
	for enemy in game.enemies.duplicate():
		game.destroy_enemy(enemy)
	if game.pickups.size() != 0:
		failures.append("Failed formation still created a reward pickup")

	game.enemies.clear()
	game.pickups.clear()
	game.spawn_midboss()
	if not game.boss_bar.visible:
		failures.append("Midboss did not show a health bar")
	for enemy in game.enemies.duplicate():
		if bool(enemy.get("midboss", false)):
			game.destroy_enemy(enemy)
			break
	if game.boss_bar.visible:
		failures.append("Midboss health bar did not hide after defeat")
	if game.stage_complete:
		failures.append("Midboss defeat incorrectly completed the stage")
	if game.pickups.size() == 0:
		failures.append("Midboss defeat did not create a guaranteed pickup")

	if failures.is_empty():
		print("RUNTIME_REGRESSION_PASS")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)
