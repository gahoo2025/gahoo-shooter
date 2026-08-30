extends Area2D

## ボスが発射する弾。自機に向かって直進し、画面外に出たら消える。

@export var speed: float = 240.0

var velocity: Vector2 = Vector2.DOWN


func _ready() -> void:
	add_to_group("enemy_bullets")


func _process(delta: float) -> void:
	position += velocity * speed * delta
	var screen_size: Vector2 = get_viewport().get_visible_rect().size
	if position.y > screen_size.y + 32 or position.y < -32 or position.x < -32 or position.x > screen_size.x + 32:
		queue_free()


func _draw() -> void:
	draw_circle(Vector2.ZERO, 5, Color(1.0, 0.25, 0.25))
