class_name PickupRing
extends Node2D

## アイテム取得時に、その場から広がって消えるリング演出。
## 敵撃破の爆発エフェクト（explosion.gd）とは別枠の、取得フィードバック用の演出。

const DURATION := 0.35
const START_RADIUS := 6.0
const END_RADIUS := 34.0

var life_left: float = DURATION
var ring_color: Color = Color(1.0, 1.0, 1.0)


func setup(color: Color) -> void:
	ring_color = color


func _process(delta: float) -> void:
	life_left -= delta
	queue_redraw()
	if life_left <= 0.0:
		queue_free()


func _draw() -> void:
	var t: float = 1.0 - clampf(life_left / DURATION, 0.0, 1.0)
	var radius: float = lerpf(START_RADIUS, END_RADIUS, t)
	var c: Color = ring_color
	c.a = 1.0 - t
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, c, 3.0)
