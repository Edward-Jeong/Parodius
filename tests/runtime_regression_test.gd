extends SceneTree

func clear_test_enemies(game) -> void:
	for enemy in game.enemies:
		if is_instance_valid(enemy.node):
			enemy.node.queue_free()
	game.enemies.clear()
	game.formation_tracker.reset()

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
	var ui_theme: Theme = game.make_theme()
	if ui_theme.default_font == null or not ui_theme.default_font.has_char("한".unicode_at(0)):
		failures.append("UI font does not contain Korean glyphs")
	if audio_manager.music_player.stream == null:
		failures.append("Music stream was not created")
	elif audio_manager.music_player.stream.data.is_empty():
		failures.append("Music stream has no PCM data")
	if audio_manager.sfx_streams.size() < 11:
		failures.append("Expected gameplay sound effects were not created")
	if not audio_manager.sfx_streams.has("formation"):
		failures.append("Formation warning sound was not created")
	if not audio_manager.sfx_streams.has("level_up"):
		failures.append("Level-up sound was not created")
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

	clear_test_enemies(game)
	game.wave_cooldowns.clear()
	game.midboss_spawned = false
	game.midboss_alive = false
	game.boss_spawned = false
	game.boss_alive = false
	game.level_elapsed = 89.9
	game.update_stage(0.0)
	if game.midboss_spawned:
		failures.append("Midboss spawned before 90 seconds")
	clear_test_enemies(game)
	game.level_elapsed = 90.0
	game.update_stage(0.0)
	if not game.midboss_spawned or not game.midboss_alive:
		failures.append("Midboss did not spawn at 90 seconds")
	game.level_elapsed = 180.0
	game.update_stage(0.0)
	if game.boss_spawned:
		failures.append("Final boss spawned while midboss was still alive")
	var timed_midboss: Dictionary
	for enemy in game.enemies:
		if bool(enemy.get("midboss", false)):
			timed_midboss = enemy
			break
	if timed_midboss.is_empty():
		failures.append("Timed midboss entity was not created")
	else:
		game.destroy_enemy(timed_midboss)
	game.update_stage(0.0)
	if not game.boss_spawned or not game.boss_alive:
		failures.append("Final boss did not spawn at 180 seconds after midboss defeat")

	var level_one_boss: Dictionary
	for enemy in game.enemies:
		if bool(enemy.get("stage_boss", false)):
			level_one_boss = enemy
			break
	game.hp = 2
	game.special = 40.0
	game.weapon_levels = [3, 1, 1, 0, 1]
	var weapons_before_level_up: Array = game.weapon_levels.duplicate()
	var score_before_level_up: int = game.score
	if level_one_boss.is_empty():
		failures.append("Level-one boss entity was not created")
	else:
		game.destroy_enemy(level_one_boss)
	if game.state != game.State.PLAYING or game.level != 2:
		failures.append("Boss defeat did not continue into level two")
	if game.level_elapsed != 0.0:
		failures.append("Level timer did not reset after boss defeat")
	if game.hp != 3:
		failures.append("Level-up did not recover exactly one health up to the maximum")
	if game.weapon_levels != weapons_before_level_up:
		failures.append("Weapon upgrades were not preserved after level-up")
	if game.special < 40.0:
		failures.append("Special meter was not preserved after level-up")
	if game.score <= score_before_level_up:
		failures.append("Boss score was not preserved after level-up")
	var level_two_difficulty: Dictionary = game.difficulty_for_level(2)
	if not is_equal_approx(float(level_two_difficulty.health), 1.18):
		failures.append("Level-two health multiplier is incorrect")
	if not is_equal_approx(float(level_two_difficulty.speed), 1.05):
		failures.append("Level-two speed multiplier is incorrect")
	if not is_equal_approx(float(level_two_difficulty.spawn_interval), 0.93):
		failures.append("Level-two spawn interval multiplier is incorrect")
	if not is_equal_approx(float(level_two_difficulty.shot_interval), 0.94):
		failures.append("Level-two shot interval multiplier is incorrect")
	if not is_equal_approx(float(level_two_difficulty.projectile_speed), 1.06):
		failures.append("Level-two projectile speed multiplier is incorrect")
	var capped_difficulty: Dictionary = game.difficulty_for_level(30)
	if float(capped_difficulty.health) > 3.0 or float(capped_difficulty.speed) > 1.5:
		failures.append("High-level difficulty exceeded its cap")

	clear_test_enemies(game)
	game.spawn_enemy(0, 10.0, 100.0, "shooter", 100, "", 0, Vector2(64.0, 0.0), "center", 1.0)
	var scaled_enemy: Dictionary = game.enemies.back()
	if not is_equal_approx(float(scaled_enemy.max_hp), 11.8):
		failures.append("Enemy spawner did not apply the level health multiplier")
	if not is_equal_approx(float(scaled_enemy.speed), 105.0):
		failures.append("Enemy spawner did not apply the level speed multiplier")
	if int(scaled_enemy.score) != 120:
		failures.append("Enemy spawner did not apply the level score multiplier")
	if not is_equal_approx(float(scaled_enemy.shot_rate), 0.94):
		failures.append("Enemy spawner did not apply the level shot interval multiplier")
	game.fire_enemy(Vector2(1000.0, 360.0), false)
	var scaled_projectile = game.projectiles.back()
	if not is_equal_approx(scaled_projectile.velocity.length(), 254.4):
		failures.append("Enemy projectile speed did not scale with the level")

	var save_manager = root.get_node("SaveManager")
	if not save_manager.data.has("highest_level"):
		failures.append("Save data does not provide a default highest level")
	save_manager.data.high_score = 0
	save_manager.data.highest_level = 1
	game.score = 43210
	game.level = 3
	game.hp = 1
	game.invulnerable = 0.0
	game.weapon_levels[3] = 0
	game.damage_player()
	if game.state != game.State.RESULT:
		failures.append("Zero health did not end the run")
	if int(save_manager.data.high_score) != 43210 or int(save_manager.data.highest_level) != 3:
		failures.append("Game over did not save the high score and highest level")

	if failures.is_empty():
		print("RUNTIME_REGRESSION_PASS")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)
