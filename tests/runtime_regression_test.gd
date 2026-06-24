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
	if audio_manager.sfx_streams.size() < 8:
		failures.append("Expected gameplay sound effects were not created")

	if failures.is_empty():
		print("RUNTIME_REGRESSION_PASS")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)
