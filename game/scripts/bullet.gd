extends Area2D

## 自機の弾。まっすぐ上方向へ進み、画面外に出たら消える。

@export var speed: float = 900.0


func _ready() -> void:
	queue_redraw()


func _process(delta: float) -> void:
	position.y -= speed * delta
	if position.y < -32:
		queue_free()


func _draw() -> void:
	draw_circle(Vector2.ZERO, 4, Color(1, 1, 0.4))
