class_name EnemyWave
extends Resource

@export var start_time: float = 0.0
@export var end_time: float = 90.0
@export var spawn_interval: float = 1.2
@export_range(0, 5) var enemy_frame: int = 0
@export var hp: float = 2.0
@export var speed: float = 180.0
@export_enum("straight", "sine", "dive") var path: String = "straight"
@export var score: int = 100

