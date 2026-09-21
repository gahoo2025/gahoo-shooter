extends Area2D

## 自機の弾。velocityの向きへ進み、画面外に出たら消える。
## 通常は直進（上向き）だが、武器強化パワーアップ取得中は3方向に
## 角度をつけて発射される（player.gd参照）。

@export var speed: float = 900.0

var velocity: Vector2 = Vector2.UP


func _ready() -> void:
	queue_redraw()


func _process(delta: float) -> void:
	position += velocity * speed * delta
	var screen_size: Vector2 = get_viewport().get_visible_rect().size
	if position.y < -32 or position.x < -32 or position.x > screen_size.x + 32:
		queue_free()


func _draw() -> void:
	draw_circle(Vector2.ZERO, 4, Color(1, 1, 0.4))
