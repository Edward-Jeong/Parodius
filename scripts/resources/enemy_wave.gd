class_name EnemyWave
extends Resource

@export var start_time: float = 0.0
@export var end_time: float = 90.0
@export var spawn_interval: float = 1.2
@export_range(0, 5) var enemy_frame: int = 0
@export var hp: float = 2.0
@export var speed: float = 180.0
@export_enum("straight", "sine", "dive", "lane", "arc", "shooter", "popcorn") var path: String = "straight"
@export var score: int = 100
@export_range(1, 8) var formation_size: int = 1
@export var formation_spacing: Vector2 = Vector2(64.0, 0.0)
@export_enum("center", "spread", "top", "bottom", "arc_top", "arc_bottom") var lane_pattern: String = "center"
@export var reward_on_clear: bool = false
@export var shot_rate: float = 0.0
@export var enemy_scale: float = 0.18
