class_name EnemySpawner
extends RefCounted

const ENEMY_SHEET := preload("res://assets/art/enemy-sheet.png")
const BOSS_TEXTURE := preload("res://assets/art/boss.png")

var entity_layer: Node2D
var enemies: Array[Dictionary]
var formation_tracker
var health_multiplier := 1.0
var speed_multiplier := 1.0
var shot_interval_multiplier := 1.0
var score_multiplier := 1.0

func setup(layer: Node2D, enemy_list: Array[Dictionary], tracker) -> void:
	entity_layer = layer
	enemies = enemy_list
	formation_tracker = tracker

func set_difficulty(difficulty: Dictionary) -> void:
	health_multiplier = float(difficulty.get("health", 1.0))
	speed_multiplier = float(difficulty.get("speed", 1.0))
	shot_interval_multiplier = float(difficulty.get("shot_interval", 1.0))
	score_multiplier = float(difficulty.get("score", 1.0))

func spawn_wave(wave: EnemyWave) -> bool:
	if wave.formation_size <= 1:
		spawn_enemy(wave.enemy_frame, wave.hp, wave.speed, wave.path, wave.score, "", 0, wave.formation_spacing, wave.lane_pattern, wave.shot_rate, wave.enemy_scale)
		return false
	var group_id: String = formation_tracker.begin(wave.formation_size, wave.reward_on_clear)
	for index in wave.formation_size:
		spawn_enemy(wave.enemy_frame, wave.hp, wave.speed, wave.path, wave.score, group_id, index, wave.formation_spacing, wave.lane_pattern, wave.shot_rate, wave.enemy_scale)
	return true

func formation_spawn_position(index: int, size: int, spacing: Vector2, lane_pattern: String) -> Vector2:
	var y := 360.0
	match lane_pattern:
		"spread":
			y = 210.0 + index * (300.0 / maxf(1.0, size - 1.0))
		"top":
			y = 170.0 + index * 32.0
		"bottom":
			y = 610.0 - index * 32.0
		"arc_top":
			y = 175.0 + sin(float(index) / maxf(1.0, size - 1.0) * PI) * 185.0
		"arc_bottom":
			y = 625.0 - sin(float(index) / maxf(1.0, size - 1.0) * PI) * 185.0
		_:
			y = 360.0 + (index - (size - 1) * 0.5) * spacing.y
	return Vector2(1350.0 + index * spacing.x, clampf(y, 145.0, 650.0))

func spawn_enemy(frame: int, enemy_hp: float, speed: float, path: String, value: int, group_id := "", formation_index := 0, formation_spacing := Vector2(64.0, 0.0), lane_pattern := "center", shot_rate := 0.0, enemy_scale := 0.18) -> Dictionary:
	var sprite := Sprite2D.new()
	sprite.texture = ENEMY_SHEET
	sprite.hframes = 3
	sprite.vframes = 2
	sprite.frame = frame
	sprite.scale = Vector2(enemy_scale, enemy_scale)
	var formation_size: int = formation_tracker.size_for(group_id)
	sprite.position = formation_spawn_position(formation_index, formation_size, formation_spacing, lane_pattern) if group_id != "" else Vector2(1350, randf_range(150, 650))
	entity_layer.add_child(sprite)
	var scaled_hp := enemy_hp * health_multiplier
	var enemy := {
		"node": sprite, "hp": scaled_hp, "max_hp": scaled_hp, "speed": speed * speed_multiplier,
		"path": path, "age": 0.0, "score": roundi(value * score_multiplier), "radius": 45.0 * (enemy_scale / 0.18),
		"shoot": randf_range(0.8, 2.2) * shot_interval_multiplier, "boss": false, "midboss": false, "stage_boss": false,
		"group_id": group_id, "formation_index": formation_index, "shot_rate": shot_rate * shot_interval_multiplier,
		"shot_interval_multiplier": shot_interval_multiplier,
		"base_y": sprite.position.y
	}
	enemies.append(enemy)
	return enemy

func spawn_midboss() -> Dictionary:
	var sprite := Sprite2D.new()
	sprite.texture = ENEMY_SHEET
	sprite.hframes = 3
	sprite.vframes = 2
	sprite.frame = 5
	sprite.scale = Vector2(0.34, 0.34)
	sprite.position = Vector2(1450, 360)
	entity_layer.add_child(sprite)
	var scaled_hp := 260.0 * health_multiplier
	var enemy := {
		"node": sprite, "hp": scaled_hp, "max_hp": scaled_hp, "speed": 105.0 * speed_multiplier,
		"path": "midboss", "age": 0.0, "score": roundi(7500 * score_multiplier), "radius": 86.0,
		"shoot": 1.2 * shot_interval_multiplier, "boss": true, "midboss": true, "stage_boss": false,
		"group_id": "", "formation_index": 0, "shot_rate": 0.0,
		"shot_interval_multiplier": shot_interval_multiplier, "summon": 4.0 * shot_interval_multiplier
	}
	enemies.append(enemy)
	return enemy

func spawn_boss() -> Dictionary:
	var sprite := Sprite2D.new()
	sprite.texture = BOSS_TEXTURE
	sprite.scale = Vector2(0.33, 0.33)
	sprite.position = Vector2(1450, 360)
	entity_layer.add_child(sprite)
	var scaled_hp := 650.0 * health_multiplier
	var enemy := {
		"node": sprite, "hp": scaled_hp, "max_hp": scaled_hp, "speed": 85.0 * speed_multiplier,
		"path": "boss", "age": 0.0, "score": roundi(25000 * score_multiplier), "radius": 145.0,
		"shoot": 1.4 * shot_interval_multiplier, "boss": true, "midboss": false, "stage_boss": true,
		"group_id": "", "formation_index": 0, "shot_rate": 0.0,
		"shot_interval_multiplier": shot_interval_multiplier
	}
	enemies.append(enemy)
	return enemy

func spawn_midboss_minions(origin: Vector2) -> void:
	for index in 5:
		var y := origin.y - 120.0 + index * 60.0
		var enemy := spawn_enemy(index % 3, 1.5, 255.0, "popcorn", 80, "", index, Vector2.ZERO, "center", 0.0, 0.13)
		enemy.node.position = Vector2(origin.x + 70.0 + index * 18.0, clampf(y, 145.0, 650.0))
