extends Area2D

## 雑魚敵（第1弾は直進のみの1種類）。
## 自機の弾に当たると消滅してスコアを加算する。画面下に抜けると自然消滅する。

signal defeated(score_value: int)

@export var speed: float = 160.0
@export var score_value: int = 100

var screen_size: Vector2


func _ready() -> void:
	add_to_group("enemies")
	screen_size = get_viewport().get_visible_rect().size
	area_entered.connect(_on_area_entered)


func _process(delta: float) -> void:
	position.y += speed * delta
	if position.y > screen_size.y + 32:
		queue_free()


func _on_area_entered(area: Area2D) -> void:
	# collision_mask により、ここに来るのは自機の弾のみを想定
	area.queue_free()
	defeated.emit(score_value)
	queue_free()
