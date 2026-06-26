extends Node2D

const VIEW := Vector2(1280, 720)
const STAGE_END := 480.0
const PLAYER_SHEET := preload("res://assets/art/player-sheet.png")
const BG_TEXTURE := preload("res://assets/art/night-market-space.png")
const HUD_ICONS := preload("res://assets/art/hud-icons.png")
const Projectile := preload("res://scripts/projectile.gd")
const FormationTrackerScript := preload("res://scripts/formation_tracker.gd")
const EnemySpawnerScript := preload("res://scripts/enemy_spawner.gd")
const PLAYER_CONFIG: PlayerConfig = preload("res://data/player_config.tres")
const WAVES := [
	preload("res://data/waves/zone_1.tres"),
	preload("res://data/waves/zone_1_popcorn.tres"),
	preload("res://data/waves/zone_1_formation.tres"),
	preload("res://data/waves/zone_2.tres"),
	preload("res://data/waves/zone_2_arc.tres"),
	preload("res://data/waves/zone_2_shooter.tres"),
	preload("res://data/waves/zone_3.tres"),
	preload("res://data/waves/zone_3_formation.tres"),
	preload("res://data/waves/zone_3_shooter.tres")
]
const CHECKPOINTS := [
	preload("res://data/checkpoints/start.tres"),
	preload("res://data/checkpoints/zone_2.tres"),
	preload("res://data/checkpoints/zone_3.tres"),
	preload("res://data/checkpoints/boss.tres")
]
const WEAPONS := [
	preload("res://data/weapons/basic.tres"),
	preload("res://data/weapons/spread.tres"),
	preload("res://data/weapons/homing.tres"),
	preload("res://data/weapons/shield.tres"),
	preload("res://data/weapons/speed.tres")
]

enum State { TITLE, PLAYING, PAUSED, RESULT }

var state := State.TITLE
var ui_layer: CanvasLayer
var world: Node2D
var entity_layer: Node2D
var projectile_layer: Node2D
var pickup_layer: Node2D
var player: Sprite2D
var shield_ring: Line2D
var drag_target := Vector2(260, 360)
var dragging := false
var elapsed := 0.0
var checkpoint_time := 0.0
var hp := 3
var score := 0
var combo := 0
var multiplier := 1
var combo_timeout := 0.0
var special := 0.0
var invulnerable := 0.0
var fire_cooldown := 0.0
var spawn_cooldown := 0.0
var wave_cooldowns: Dictionary = {}
var enemies: Array[Dictionary] = []
var projectiles: Array[Node] = []
var pickups: Array[Dictionary] = []
var formation_tracker
var enemy_spawner
var formation_groups: Dictionary = {}
var weapon_levels := [1, 0, 0, 0, 0]
var kills := 0
var midboss_spawned := false
var boss_spawned := false
var stage_complete := false
var message_time := 0.0
var hp_label: Label
var score_label: Label
var combo_label: Label
var timer_label: Label
var special_bar: ProgressBar
var message_label: Label
var powerup_boxes: Array[TextureRect] = []
var boss_bar: ProgressBar
var scrolling_backgrounds: Array[TextureRect] = []

func _ready() -> void:
	formation_tracker = FormationTrackerScript.new()
	enemy_spawner = EnemySpawnerScript.new()
	formation_groups = formation_tracker.groups
	get_viewport().set_embedding_subwindows(false)
	show_title()
	var args := OS.get_cmdline_user_args()
	if "--qa-title" in args:
		call_deferred("capture_qa_screen", "title")
	elif "--qa-game" in args:
		call_deferred("start_qa_game")
	elif "--qa-boss" in args:
		call_deferred("start_qa_boss")

func start_qa_game() -> void:
	start_game()
	elapsed = 32.0
	special = 72.0
	weapon_levels = [3, 1, 1, 1, 1]
	score = 123456
	combo = 23
	multiplier = 5
	combo_timeout = 999.0
	shield_ring.visible = true
	for index in 3:
		spawn_enemy(index, 999.0, 0.0, "straight", 100)
		enemies.back().node.position = Vector2(790 + index * 150, 230 + index * 125)
	await get_tree().create_timer(2.5).timeout
	capture_qa_screen("gameplay")

func start_qa_boss() -> void:
	start_game()
	elapsed = 401.0
	special = PLAYER_CONFIG.special_max
	weapon_levels = [5, 3, 3, 2, 3]
	shield_ring.visible = true
	await get_tree().create_timer(3.0).timeout
	capture_qa_screen("boss")

func capture_qa_screen(label: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var directory := ProjectSettings.globalize_path("res://docs/screenshots")
	DirAccess.make_dir_recursive_absolute(directory)
	var image := get_viewport().get_texture().get_image()
	image.save_png(directory.path_join(label + ".png"))
	get_tree().quit()

func atlas(texture: Texture2D, columns: int, rows: int, index: int) -> AtlasTexture:
	var result := AtlasTexture.new()
	result.atlas = texture
	var cell := Vector2(texture.get_width() / columns, texture.get_height() / rows)
	result.region = Rect2(Vector2(index % columns, index / columns) * cell, cell)
	return result

func clear_root() -> void:
	for child in get_children():
		child.queue_free()
	enemies.clear()
	projectiles.clear()
	pickups.clear()
	if formation_tracker != null:
		formation_tracker.reset()
	powerup_boxes.clear()
	scrolling_backgrounds.clear()

func add_background(parent: Node, dim := 0.0) -> void:
	var bg := TextureRect.new()
	bg.texture = BG_TEXTURE
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.modulate = Color(1.0 - dim, 1.0 - dim, 1.0 - dim)
	parent.add_child(bg)

func add_scrolling_background(parent: Node) -> void:
	for index in 2:
		var bg := TextureRect.new()
		bg.texture = BG_TEXTURE
		bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		bg.position = Vector2(index * VIEW.x, 0)
		bg.size = VIEW
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(bg)
		scrolling_backgrounds.append(bg)

func update_background(delta: float) -> void:
	var scroll_speed: float = 96.0 + weapon_levels[4] * 12.0 + clampf(elapsed / STAGE_END, 0.0, 1.0) * 42.0
	for bg in scrolling_backgrounds:
		bg.position.x -= scroll_speed * delta
	for bg in scrolling_backgrounds:
		if bg.position.x <= -VIEW.x:
			var furthest_x := -INF
			for other in scrolling_backgrounds:
				if other != bg:
					furthest_x = maxf(furthest_x, other.position.x)
			bg.position.x = furthest_x + VIEW.x - 1.0

func make_theme() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = 24
	theme.set_color("font_color", "Label", Color.WHITE)
	theme.set_color("font_shadow_color", "Label", Color("#24104f"))
	theme.set_constant("shadow_offset_x", "Label", 3)
	theme.set_constant("shadow_offset_y", "Label", 3)
	return theme

func neon_button(text: String, size := Vector2(320, 68)) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = size
	button.add_theme_font_size_override("font_size", 28)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("#281052")
	normal.border_color = Color("#39f4ff")
	normal.set_border_width_all(4)
	normal.corner_radius_top_left = 18
	normal.corner_radius_top_right = 18
	normal.corner_radius_bottom_left = 18
	normal.corner_radius_bottom_right = 18
	var hover := normal.duplicate()
	hover.bg_color = Color("#ed218c")
	hover.border_color = Color.WHITE
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	return button

func show_title() -> void:
	clear_root()
	state = State.TITLE
	ui_layer = CanvasLayer.new()
	add_child(ui_layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.theme = make_theme()
	ui_layer.add_child(root)
	add_background(root, 0.18)
	var shade := ColorRect.new()
	shade.color = Color(0.04, 0.01, 0.15, 0.38)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(shade)
	var title := Label.new()
	title.text = "네온 야시장\n급배송"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 76)
	title.add_theme_color_override("font_color", Color("#fff25c"))
	title.position = Vector2(590, 105)
	title.size = Vector2(620, 190)
	root.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "로켓 고양이 배달 • 우주 야시장"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.position = Vector2(610, 292)
	subtitle.size = Vector2(580, 45)
	subtitle.add_theme_color_override("font_color", Color("#52f5ff"))
	root.add_child(subtitle)
	var menu := VBoxContainer.new()
	menu.position = Vector2(760, 380)
	menu.add_theme_constant_override("separation", 14)
	root.add_child(menu)
	var start := neon_button("배달 시작")
	start.pressed.connect(start_game)
	menu.add_child(start)
	var settings := neon_button("설정")
	settings.pressed.connect(show_settings)
	menu.add_child(settings)
	var high := Label.new()
	high.text = "최고 점수  %07d" % int(SaveManager.data.high_score)
	high.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu.add_child(high)

func show_settings() -> void:
	var modal := PanelContainer.new()
	modal.position = Vector2(400, 170)
	modal.size = Vector2(480, 390)
	var box := StyleBoxFlat.new()
	box.bg_color = Color("#160b3a")
	box.border_color = Color("#ff3eac")
	box.set_border_width_all(5)
	box.set_corner_radius_all(24)
	modal.add_theme_stylebox_override("panel", box)
	ui_layer.add_child(modal)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 24)
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 38)
	modal.add_child(content)
	var heading := Label.new()
	heading.text = "설정"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 40)
	content.add_child(heading)
	var music := CheckButton.new()
	music.text = "배경 음악"
	music.button_pressed = SaveManager.data.music_enabled
	music.toggled.connect(func(on): SaveManager.data.music_enabled = on; SaveManager.save_data(); AudioManager.refresh_settings())
	content.add_child(music)
	var sfx := CheckButton.new()
	sfx.text = "효과음"
	sfx.button_pressed = SaveManager.data.sfx_enabled
	sfx.toggled.connect(func(on): SaveManager.data.sfx_enabled = on; SaveManager.save_data(); AudioManager.refresh_settings())
	content.add_child(sfx)
	var close := neon_button("확인", Vector2(280, 58))
	close.pressed.connect(modal.queue_free)
	content.add_child(close)

func start_game() -> void:
	clear_root()
	state = State.PLAYING
	elapsed = 0.0
	checkpoint_time = 0.0
	hp = PLAYER_CONFIG.max_hp
	score = 0
	combo = 0
	multiplier = 1
	special = 0.0
	kills = 0
	wave_cooldowns.clear()
	formation_tracker.reset()
	midboss_spawned = false
	boss_spawned = false
	stage_complete = false
	weapon_levels = [1, 0, 0, 0, 0]
	world = Node2D.new()
	add_child(world)
	var bg_canvas := CanvasLayer.new()
	bg_canvas.layer = -10
	world.add_child(bg_canvas)
	var bg_root := Control.new()
	bg_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg_canvas.add_child(bg_root)
	add_scrolling_background(bg_root)
	entity_layer = Node2D.new()
	projectile_layer = Node2D.new()
	pickup_layer = Node2D.new()
	world.add_child(entity_layer)
	world.add_child(projectile_layer)
	world.add_child(pickup_layer)
	enemy_spawner.setup(entity_layer, enemies, formation_tracker)
	create_player()
	create_hud()
	AudioManager.play_music()
	AudioManager.play_sfx("menu")
	show_message("야시장 입구", 2.5)

func create_player() -> void:
	player = Sprite2D.new()
	player.texture = PLAYER_SHEET
	player.hframes = 3
	player.vframes = 2
	player.frame = 0
	player.scale = Vector2(0.47, 0.47)
	player.position = Vector2(250, 360)
	entity_layer.add_child(player)
	drag_target = player.position
	shield_ring = Line2D.new()
	shield_ring.width = 6.0
	shield_ring.default_color = Color("#62ffd1")
	shield_ring.closed = true
	for i in 32:
		var a := TAU * i / 32.0
		shield_ring.add_point(Vector2(cos(a), sin(a)) * 68.0)
	shield_ring.visible = false
	player.add_child(shield_ring)

func create_hud() -> void:
	ui_layer = CanvasLayer.new()
	ui_layer.layer = 20
	add_child(ui_layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.theme = make_theme()
	ui_layer.add_child(root)
	var top := PanelContainer.new()
	top.position = Vector2(18, 16)
	top.size = Vector2(1120, 82)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.02, 0.18, 0.82)
	style.border_color = Color("#4cf4ff")
	style.set_border_width_all(3)
	style.set_corner_radius_all(22)
	top.add_theme_stylebox_override("panel", style)
	root.add_child(top)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 22)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 14)
	top.add_child(row)
	var heart_icon := TextureRect.new()
	heart_icon.texture = atlas(HUD_ICONS, 4, 2, 0)
	heart_icon.custom_minimum_size = Vector2(48, 48)
	heart_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	heart_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(heart_icon)
	hp_label = Label.new()
	hp_label.custom_minimum_size.x = 90
	row.add_child(hp_label)
	score_label = Label.new()
	score_label.custom_minimum_size.x = 190
	row.add_child(score_label)
	combo_label = Label.new()
	combo_label.custom_minimum_size.x = 125
	combo_label.add_theme_color_override("font_color", Color("#fff25c"))
	row.add_child(combo_label)
	for i in 5:
		var icon := TextureRect.new()
		icon.texture = atlas(HUD_ICONS, 4, 2, i + 1)
		icon.custom_minimum_size = Vector2(52, 52)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.modulate = Color(0.35, 0.35, 0.45)
		row.add_child(icon)
		powerup_boxes.append(icon)
	timer_label = Label.new()
	timer_label.custom_minimum_size.x = 100
	row.add_child(timer_label)
	var pause_icon := Sprite2D.new()
	pause_icon.texture = atlas(HUD_ICONS, 4, 2, 7)
	pause_icon.position = Vector2(1204, 57)
	pause_icon.scale = Vector2(0.15, 0.15)
	root.add_child(pause_icon)
	var pause_button := Button.new()
	pause_button.flat = true
	pause_button.position = Vector2(1165, 18)
	pause_button.size = Vector2(78, 78)
	pause_button.pressed.connect(toggle_pause)
	root.add_child(pause_button)
	var special_icon := Sprite2D.new()
	special_icon.texture = atlas(HUD_ICONS, 4, 2, 6)
	special_icon.position = Vector2(1190, 632)
	special_icon.scale = Vector2(0.23, 0.23)
	root.add_child(special_icon)
	var special_button := Button.new()
	special_button.flat = true
	special_button.position = Vector2(1128, 570)
	special_button.size = Vector2(125, 125)
	special_button.pressed.connect(use_special)
	root.add_child(special_button)
	special_bar = ProgressBar.new()
	special_bar.position = Vector2(1104, 682)
	special_bar.size = Vector2(155, 22)
	special_bar.max_value = PLAYER_CONFIG.special_max
	special_bar.show_percentage = false
	root.add_child(special_bar)
	boss_bar = ProgressBar.new()
	boss_bar.position = Vector2(330, 112)
	boss_bar.size = Vector2(620, 24)
	boss_bar.visible = false
	boss_bar.show_percentage = false
	root.add_child(boss_bar)
	message_label = Label.new()
	message_label.position = Vector2(280, 275)
	message_label.size = Vector2(720, 120)
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	message_label.add_theme_font_size_override("font_size", 54)
	message_label.add_theme_color_override("font_color", Color("#fff25c"))
	root.add_child(message_label)
	update_hud()

func _process(delta: float) -> void:
	if state != State.PLAYING:
		return
	if Input.is_action_just_pressed("pause_game"):
		toggle_pause()
	if Input.is_action_just_pressed("special_delivery"):
		use_special()
	if Input.is_action_just_pressed("debug_skip"):
		elapsed = minf(elapsed + 90.0, 401.0)
		show_message("개발용 구간 이동", 1.0)
	elapsed += delta
	update_background(delta)
	invulnerable = maxf(0.0, invulnerable - delta)
	if invulnerable > 0.0:
		player.modulate.a = 0.35 + absf(sin(Time.get_ticks_msec() * 0.025)) * 0.65
	else:
		player.modulate.a = 1.0
	combo_timeout -= delta
	if combo_timeout <= 0.0 and combo > 0:
		combo = 0
		multiplier = 1
	message_time -= delta
	if message_time <= 0.0:
		message_label.text = ""
	update_player(delta)
	update_stage(delta)
	update_enemies(delta)
	update_projectiles(delta)
	update_pickups(delta)
	handle_collisions()
	update_hud()

func update_player(delta: float) -> void:
	var speed: float = PLAYER_CONFIG.base_speed * (1.0 + weapon_levels[4] * 0.12)
	var keyboard_direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if keyboard_direction.length_squared() > 0.0:
		player.position += keyboard_direction * speed * delta
		drag_target = player.position
	else:
		player.position = player.position.move_toward(drag_target, speed * delta)
	player.position.x = clampf(player.position.x, 90.0, 1080.0)
	player.position.y = clampf(player.position.y, 125.0, 650.0)
	drag_target = player.position if keyboard_direction.length_squared() > 0.0 else drag_target
	fire_cooldown -= delta
	if fire_cooldown <= 0.0:
		fire_player_weapon()
		fire_cooldown = PLAYER_CONFIG.fire_interval * (1.0 - weapon_levels[0] * 0.035)

func update_stage(delta: float) -> void:
	for wave: EnemyWave in WAVES:
		if elapsed >= wave.start_time and elapsed < wave.end_time:
			var key := wave.resource_path
			var cooldown := float(wave_cooldowns.get(key, 0.0)) - delta
			if cooldown <= 0.0:
				spawn_wave(wave)
				var pressure := 1.0 - clampf(elapsed / STAGE_END, 0.0, 1.0) * 0.18
				wave_cooldowns[key] = maxf(0.32, wave.spawn_interval * pressure)
			else:
				wave_cooldowns[key] = cooldown
	if elapsed >= 205.0 and not midboss_spawned:
		midboss_spawned = true
		clear_hostile_projectiles()
		spawn_midboss()
		show_message("중간 보스 • 야시장 수레", 2.0)
	if elapsed >= 400.0 and not boss_spawned:
		boss_spawned = true
		clear_hostile_projectiles()
		spawn_boss()
		show_message("호떡 궤도", 2.0)
	for cp: CheckpointData in CHECKPOINTS:
		if elapsed >= cp.time_seconds and cp.time_seconds > checkpoint_time:
			checkpoint_time = cp.time_seconds
			show_message(cp.label, 1.4)
	if elapsed >= STAGE_END and not boss_spawned:
		boss_spawned = true
		spawn_boss()

func spawn_wave(wave: EnemyWave) -> void:
	var spawned_formation: bool = enemy_spawner.spawn_wave(wave)
	if spawned_formation and wave.reward_on_clear:
		AudioManager.play_sfx("formation")
		show_message("연속 배달 편대!", 0.55)

func spawn_enemy(frame: int, enemy_hp: float, speed: float, path: String, value: int, group_id := "", formation_index := 0, formation_spacing := Vector2(64.0, 0.0), lane_pattern := "center", shot_rate := 0.0, enemy_scale := 0.18) -> void:
	enemy_spawner.spawn_enemy(frame, enemy_hp, speed, path, value, group_id, formation_index, formation_spacing, lane_pattern, shot_rate, enemy_scale)

func spawn_midboss() -> void:
	var enemy: Dictionary = enemy_spawner.spawn_midboss()
	boss_bar.max_value = 260.0
	boss_bar.value = enemy.max_hp
	boss_bar.visible = true

func spawn_boss() -> void:
	var enemy: Dictionary = enemy_spawner.spawn_boss()
	boss_bar.max_value = 650.0
	boss_bar.value = enemy.max_hp
	boss_bar.visible = true

func update_enemies(delta: float) -> void:
	for enemy in enemies.duplicate():
		var node: Sprite2D = enemy.node
		if not is_instance_valid(node):
			enemies.erase(enemy)
			continue
		enemy.age += delta
		enemy.shoot -= delta
		match enemy.path:
			"straight":
				node.position.x -= enemy.speed * delta
			"sine":
				node.position.x -= enemy.speed * delta
				node.position.y += sin(enemy.age * 4.0) * 120.0 * delta
			"dive":
				node.position.x -= enemy.speed * delta
				node.position.y += sin(enemy.age * 2.2) * 210.0 * delta
				if node.position.x < 920.0:
					var dive_aim := (player.position - node.position).normalized()
					node.position += dive_aim * enemy.speed * 0.42 * delta
			"lane":
				node.position.x -= enemy.speed * delta
			"arc":
				node.position.x -= enemy.speed * delta
				var arc_sign := -1.0 if int(enemy.formation_index) % 2 == 0 else 1.0
				node.position.y = float(enemy.base_y) + sin(enemy.age * 2.4 + enemy.formation_index * 0.55) * 115.0 * arc_sign
			"shooter":
				node.position.x -= enemy.speed * delta
				node.position.y = float(enemy.base_y) + sin(enemy.age * 1.8) * 58.0
			"popcorn":
				node.position.x -= enemy.speed * delta
				node.position.y += sin(enemy.age * 7.0 + enemy.formation_index) * 70.0 * delta
			"midboss":
				node.position.x = move_toward(node.position.x, 1010.0, enemy.speed * delta)
				node.position.y = 350.0 + sin(enemy.age * 1.4) * 175.0
				enemy.summon = float(enemy.get("summon", 4.0)) - delta
				if enemy.summon <= 0.0 and node.position.x < 1180.0:
					spawn_midboss_minions(node.position)
					enemy.summon = 4.8
			"boss":
				node.position.x = move_toward(node.position.x, 970.0, enemy.speed * delta)
				node.position.y = 360.0 + sin(enemy.age * 0.85) * 150.0
		if enemy.shoot <= 0.0 and node.position.x < 1200:
			fire_enemy(node.position, enemy.boss)
			var configured_rate := float(enemy.get("shot_rate", 0.0))
			enemy.shoot = 0.72 if enemy.boss else (configured_rate if configured_rate > 0.0 else randf_range(1.5, 2.8))
		if node.position.x < -160:
			resolve_formation_enemy(enemy, false, node.position)
			node.queue_free()
			enemies.erase(enemy)

func spawn_midboss_minions(origin: Vector2) -> void:
	enemy_spawner.spawn_midboss_minions(origin)

func fire_player_weapon() -> void:
	var damage: float = 1.0 + weapon_levels[0] * 0.35
	AudioManager.play_sfx("shot")
	spawn_projectile(player.position + Vector2(75, 0), Vector2(850, 0), true, damage, Color("#45f6ff"), 8)
	if weapon_levels[0] >= 3:
		spawn_projectile(player.position + Vector2(60, -24), Vector2(820, 0), true, damage * 0.8, Color("#45f6ff"), 7)
	if weapon_levels[1] > 0:
		for direction in [-1, 1]:
			spawn_projectile(player.position + Vector2(58, direction * 12), Vector2(780, direction * 150 * weapon_levels[1]), true, damage * 0.65, Color("#ff43b4"), 7)
	if weapon_levels[2] > 0 and kills % maxi(1, 5 - weapon_levels[2]) == 0:
		var shot := spawn_projectile(player.position + Vector2(35, -30), Vector2(610, -90), true, damage * 1.2, Color("#ffe04d"), 10)
		shot.homing = true

func fire_enemy(origin: Vector2, boss: bool) -> void:
	var aim := (player.position - origin).normalized()
	AudioManager.play_sfx("enemy_shot")
	spawn_projectile(origin, aim * (300.0 if boss else 240.0), false, 1.0, Color("#ff3b9f"), 11)
	if boss:
		for angle in [-0.45, -0.22, 0.22, 0.45]:
			spawn_projectile(origin, aim.rotated(angle) * 285.0, false, 1.0, Color("#ffcc35"), 10)

func spawn_projectile(origin: Vector2, velocity: Vector2, friendly: bool, damage: float, color: Color, radius: float) -> NeonProjectile:
	var shot: NeonProjectile = Projectile.new()
	shot.position = origin
	shot.velocity = velocity
	shot.friendly = friendly
	shot.damage = damage
	shot.tint = color
	shot.radius = radius
	projectile_layer.add_child(shot)
	projectiles.append(shot)
	return shot

func update_projectiles(delta: float) -> void:
	for index in range(projectiles.size() - 1, -1, -1):
		var shot = projectiles[index]
		if not is_instance_valid(shot) or shot.is_queued_for_deletion():
			projectiles.remove_at(index)
			continue
		if shot.homing and shot.friendly:
			var target := nearest_enemy(shot.position)
			if target != null:
				var desired: Vector2 = (target.position - shot.position).normalized() * shot.velocity.length()
				shot.velocity = shot.velocity.lerp(desired, delta * 3.5)

func nearest_enemy(from: Vector2) -> Sprite2D:
	var best: Sprite2D
	var best_distance := INF
	for enemy in enemies:
		var node: Sprite2D = enemy.node
		if is_instance_valid(node):
			var distance := from.distance_squared_to(node.position)
			if distance < best_distance:
				best_distance = distance
				best = node
	return best

func handle_collisions() -> void:
	for shot in projectiles.duplicate():
		if not is_instance_valid(shot) or shot.is_queued_for_deletion():
			continue
		if shot.friendly:
			for enemy in enemies.duplicate():
				var node: Sprite2D = enemy.node
				if is_instance_valid(node) and shot.position.distance_to(node.position) < shot.radius + enemy.radius:
					enemy.hp -= shot.damage
					shot.queue_free()
					if enemy.boss:
						boss_bar.value = enemy.hp
					if enemy.hp <= 0.0:
						destroy_enemy(enemy)
					break
		elif shot.position.distance_to(player.position) < shot.radius + 38.0:
			shot.queue_free()
			damage_player()
	for enemy in enemies.duplicate():
		var node: Sprite2D = enemy.node
		if is_instance_valid(node) and node.position.distance_to(player.position) < enemy.radius + 40.0:
			damage_player()
			resolve_formation_enemy(enemy, false, node.position)
			enemy.group_id = ""
			enemy.hp -= 6.0
			if enemy.hp <= 0.0:
				destroy_enemy(enemy)

func resolve_formation_enemy(enemy: Dictionary, killed: bool, death_position: Vector2) -> void:
	var group_id := String(enemy.get("group_id", ""))
	var result: Dictionary = formation_tracker.resolve(group_id, killed)
	if bool(result.reward):
		spawn_pickup(death_position, int(result.kind))

func destroy_enemy(enemy: Dictionary) -> void:
	var node: Sprite2D = enemy.node
	var death_position := node.position
	var was_boss: bool = enemy.boss
	var was_midboss: bool = bool(enemy.get("midboss", false))
	var was_stage_boss: bool = bool(enemy.get("stage_boss", false))
	node.queue_free()
	enemies.erase(enemy)
	resolve_formation_enemy(enemy, true, death_position)
	combo += 1
	combo_timeout = 2.2
	multiplier = clampi(1 + combo / 5, 1, 9)
	score += int(enemy.score) * multiplier
	special = minf(PLAYER_CONFIG.special_max, special + (28.0 if was_midboss else (16.0 if was_boss else 4.0)))
	kills += 1
	AudioManager.play_sfx("explode")
	if not was_boss and kills % 18 == 0:
		spawn_pickup(death_position, (kills / 18 - 1) % 5)
	if was_boss:
		boss_bar.visible = false
		if was_midboss:
			spawn_pickup(death_position + Vector2(-35.0, 0.0), kills % 5)
			show_message("중간 보스 격파!", 1.2)
		if was_stage_boss:
			stage_complete = true
			finish_game(true)

func spawn_pickup(at: Vector2, kind: int) -> void:
	var icon := Sprite2D.new()
	icon.texture = atlas(HUD_ICONS, 4, 2, kind + 1)
	icon.scale = Vector2(0.24, 0.24)
	icon.position = at
	pickup_layer.add_child(icon)
	pickups.append({"node": icon, "kind": kind, "age": 0.0})

func update_pickups(delta: float) -> void:
	for item in pickups.duplicate():
		var node: Sprite2D = item.node
		if not is_instance_valid(node):
			pickups.erase(item)
			continue
		item.age += delta
		node.position.x -= 90.0 * delta
		node.position.y += sin(item.age * 5.0) * 35.0 * delta
		if node.position.distance_to(player.position) < 60.0:
			collect_pickup(item)
		elif node.position.x < -80:
			node.queue_free()
			pickups.erase(item)

func collect_pickup(item: Dictionary) -> void:
	var kind: int = item.kind
	if kind == 3:
		weapon_levels[kind] = mini(2, weapon_levels[kind] + 1)
	else:
		weapon_levels[kind] = mini(WEAPONS[kind].max_level, weapon_levels[kind] + 1)
	item.node.queue_free()
	pickups.erase(item)
	shield_ring.visible = weapon_levels[3] > 0
	AudioManager.play_sfx("pickup")
	show_message(WEAPONS[kind].display_name.to_upper(), 0.8)

func damage_player() -> void:
	if invulnerable > 0.0:
		return
	if weapon_levels[3] > 0:
		weapon_levels[3] -= 1
		shield_ring.visible = weapon_levels[3] > 0
		invulnerable = 0.7
		AudioManager.play_sfx("shield")
		show_message("보호막 방어 성공!", 0.7)
		return
	hp -= 1
	combo = 0
	multiplier = 1
	invulnerable = PLAYER_CONFIG.invulnerability_seconds
	AudioManager.play_sfx("hit")
	player.frame = 3
	get_tree().create_timer(0.25).timeout.connect(func(): if is_instance_valid(player): player.frame = 0)
	if hp <= 0:
		restart_checkpoint()

func restart_checkpoint() -> void:
	for enemy in enemies:
		if is_instance_valid(enemy.node):
			enemy.node.queue_free()
	enemies.clear()
	formation_tracker.reset()
	wave_cooldowns.clear()
	clear_hostile_projectiles()
	elapsed = checkpoint_time
	hp = PLAYER_CONFIG.checkpoint_hp
	special = maxf(0.0, special - 25.0)
	player.position = Vector2(250, 360)
	drag_target = player.position
	invulnerable = 2.0
	midboss_spawned = elapsed > 205.0
	boss_spawned = elapsed >= 400.0
	show_message("중간 지점 • 배달 재개", 1.8)
	if boss_spawned:
		spawn_boss()

func use_special() -> void:
	if state != State.PLAYING or special < PLAYER_CONFIG.special_max:
		return
	special = 0.0
	AudioManager.play_sfx("special")
	player.frame = 4
	invulnerable = 1.2
	clear_hostile_projectiles()
	for enemy in enemies.duplicate():
		enemy.hp -= 18.0
		if enemy.hp <= 0.0:
			destroy_enemy(enemy)
	show_message("고양이 급배송!", 0.8)
	var tween := create_tween()
	tween.tween_property(player, "position:x", minf(player.position.x + 300.0, 1040.0), 0.22)
	tween.tween_property(player, "position:x", drag_target.x, 0.32)
	tween.finished.connect(func(): if is_instance_valid(player): player.frame = 0)

func clear_hostile_projectiles() -> void:
	for shot in projectiles:
		if is_instance_valid(shot) and not shot.friendly:
			shot.queue_free()

func update_hud() -> void:
	if hp_label == null:
		return
	hp_label.text = "%d / %d" % [hp, PLAYER_CONFIG.max_hp]
	score_label.text = "%07d" % score
	combo_label.text = "x%d  %02d" % [multiplier, combo]
	timer_label.text = "%d:%02d" % [int(elapsed) / 60, int(elapsed) % 60]
	special_bar.value = special
	for i in powerup_boxes.size():
		powerup_boxes[i].modulate = Color.WHITE if weapon_levels[i] > 0 else Color(0.28, 0.28, 0.4, 0.65)

func show_message(text: String, duration: float) -> void:
	if message_label != null:
		message_label.text = text
		message_time = duration

func toggle_pause() -> void:
	if state == State.PLAYING:
		state = State.PAUSED
		get_tree().paused = true
		show_pause_menu()
	elif state == State.PAUSED:
		get_tree().paused = false
		state = State.PLAYING
		for child in ui_layer.get_children():
			if child.name == "PauseMenu":
				child.queue_free()

func show_pause_menu() -> void:
	var panel := PanelContainer.new()
	panel.name = "PauseMenu"
	panel.process_mode = Node.PROCESS_MODE_ALWAYS
	panel.position = Vector2(420, 190)
	panel.size = Vector2(440, 350)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#160b3a")
	style.border_color = Color("#45f6ff")
	style.set_border_width_all(5)
	style.set_corner_radius_all(24)
	panel.add_theme_stylebox_override("panel", style)
	ui_layer.add_child(panel)
	var menu := VBoxContainer.new()
	menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 35)
	menu.add_theme_constant_override("separation", 18)
	panel.add_child(menu)
	var heading := Label.new()
	heading.text = "배달 일시정지"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 36)
	menu.add_child(heading)
	var resume := neon_button("계속하기", Vector2(320, 60))
	resume.process_mode = Node.PROCESS_MODE_ALWAYS
	resume.pressed.connect(toggle_pause)
	menu.add_child(resume)
	var quit := neon_button("타이틀로 나가기", Vector2(320, 60))
	quit.process_mode = Node.PROCESS_MODE_ALWAYS
	quit.pressed.connect(func(): get_tree().paused = false; show_title())
	menu.add_child(quit)

func finish_game(completed: bool) -> void:
	if state == State.RESULT:
		return
	state = State.RESULT
	SaveManager.record_result(score, completed)
	var result := PanelContainer.new()
	result.position = Vector2(345, 155)
	result.size = Vector2(590, 440)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#160b3a")
	style.border_color = Color("#ff43b4")
	style.set_border_width_all(6)
	style.set_corner_radius_all(28)
	result.add_theme_stylebox_override("panel", style)
	ui_layer.add_child(result)
	var content := VBoxContainer.new()
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 38)
	content.add_theme_constant_override("separation", 20)
	result.add_child(content)
	var title := Label.new()
	title.text = "배달 완료!" if completed else "배달 종료"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 44)
	title.add_theme_color_override("font_color", Color("#fff25c"))
	content.add_child(title)
	var stats := Label.new()
	stats.text = "점수  %07d\n최고 점수  %07d\n최고 배율  x%d" % [score, int(SaveManager.data.high_score), multiplier]
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats.add_theme_font_size_override("font_size", 28)
	content.add_child(stats)
	var retry := neon_button("다시 배달하기", Vector2(350, 62))
	retry.pressed.connect(start_game)
	content.add_child(retry)
	var title_button := neon_button("타이틀로", Vector2(350, 62))
	title_button.pressed.connect(show_title)
	content.add_child(title_button)

func _input(event: InputEvent) -> void:
	if state != State.PLAYING:
		return
	if event is InputEventScreenTouch:
		if event.position.y < 110.0 or event.position.x > 1100.0:
			return
		dragging = event.pressed
		if event.pressed:
			drag_target = event.position
	elif event is InputEventScreenDrag:
		if event.position.y < 110.0 or event.position.x > 1100.0:
			return
		dragging = true
		drag_target = event.position
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.position.y < 110.0 or event.position.x > 1100.0:
			return
		dragging = event.pressed
		if dragging:
			drag_target = event.position
	elif event is InputEventMouseMotion and dragging:
		drag_target = event.position
