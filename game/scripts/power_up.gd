class_name PowerUp
extends Area2D

## パワーアップアイテム。画像を使わず、種類ごとの図形を描画する。
## ゆっくり下方向に落下し、自機が触れると取得される（player.gd参照）。
## 画面外に出ると自然消滅する。

enum Type { WEAPON, SHIELD, SPEED, LIFE }

@export var power_type: Type = Type.WEAPON
@export var fall_speed: float = 100.0

var screen_size: Vector2


func _ready() -> void:
	add_to_group("powerups")
	screen_size = get_viewport().get_visible_rect().size
	queue_redraw()


func _process(delta: float) -> void:
	position.y += fall_speed * delta
	if position.y > screen_size.y + 32:
		queue_free()


func _draw() -> void:
	match power_type:
		Type.WEAPON:
			_draw_star()
		Type.SHIELD:
			draw_circle(Vector2.ZERO, 13.0, Color(0.3, 0.85, 1.0, 0.9))
			draw_arc(Vector2.ZERO, 15.0, 0.0, TAU, 32, Color(1.0, 1.0, 1.0), 2.0)
		Type.SPEED:
			draw_polygon(
				PackedVector2Array([Vector2(0, -14), Vector2(12, 10), Vector2(-12, 10)]),
				PackedColorArray([Color(0.35, 1.0, 0.45)])
			)
		Type.LIFE:
			_draw_plus()


func _draw_star() -> void:
	var points := PackedVector2Array([
		Vector2(0, -14), Vector2(4, -4), Vector2(14, 0), Vector2(4, 4),
		Vector2(0, 14), Vector2(-4, 4), Vector2(-14, 0), Vector2(-4, -4),
	])
	draw_polygon(points, PackedColorArray([Color(1.0, 0.9, 0.2)]))


func _draw_plus() -> void:
	draw_rect(Rect2(-4, -14, 8, 28), Color(1.0, 0.35, 0.55))
	draw_rect(Rect2(-14, -4, 28, 8), Color(1.0, 0.35, 0.55))
