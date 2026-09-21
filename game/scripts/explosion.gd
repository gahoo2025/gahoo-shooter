extends Node2D

## 敵撃破時の爆発エフェクト。画像を使わず、広がりながらフェードアウトする
## 円をいくつか重ねて描画するだけの簡易パーティクル。再生が終わると自動で消える。

const DURATION: float = 0.4
const MAX_RADIUS: float = 28.0
const RING_COUNT: int = 3

var _elapsed: float = 0.0


func _process(delta: float) -> void:
	_elapsed += delta
	queue_redraw()
	if _elapsed >= DURATION:
		queue_free()


func _draw() -> void:
	var progress: float = clampf(_elapsed / DURATION, 0.0, 1.0)
	for i in range(RING_COUNT):
		# リングごとに開始タイミングをずらし、内側から次々広がる見た目にする
		var local_progress: float = clampf(progress - i * 0.15, 0.0, 1.0)
		if local_progress <= 0.0:
			continue
		var radius: float = MAX_RADIUS * local_progress
		var alpha: float = 1.0 - local_progress
		var color: Color = Color(1.0, 0.6 - i * 0.15, 0.1, alpha)
		draw_circle(Vector2.ZERO, radius, color)
