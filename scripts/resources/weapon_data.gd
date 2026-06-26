class_name WeaponData
extends Resource

@export_enum("basic", "spread", "homing", "shield", "speed") var kind: String = "basic"
@export var display_name: String = "강화"
@export var max_level: int = 5
@export var damage_bonus: float = 0.25
@export var color: Color = Color.WHITE
