class_name NeonProjectile
extends Node2D

var velocity := Vector2.ZERO
var friendly := true
var damage := 1.0
var radius := 10.0
var homing := false
var tint := Color("#45f6ff")

func _ready() -> void:
	queue_redraw()

func _process(delta: float) -> void:
	position += velocity * delta
	rotation = velocity.angle()
	if position.x < -80 or position.x > 1360 or position.y < -80 or position.y > 800:
		queue_free()

func _draw() -> void:
	var outer := tint
	outer.a = 0.25
	draw_circle(Vector2.ZERO, radius * 1.8, outer)
	draw_circle(Vector2.ZERO, radius, tint)
	draw_circle(Vector2(radius * 0.2, -radius * 0.25), radius * 0.28, Color.WHITE)

