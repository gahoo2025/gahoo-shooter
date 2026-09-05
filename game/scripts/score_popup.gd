class_name ScorePopup
extends Node2D

## 撃破スコア・コンボボーナス・アイテム取得時のフィードバックとして、
## その場から上に浮かびながらフェードアウトするテキスト。
## 爆発エフェクトとは別枠の演出強化（main.gd・player.gdから呼ばれる）。

const DURATION := 0.7
const RISE_SPEED := 55.0

var life_left: float = DURATION

@onready var label: Label = $Label


func setup(text: String, color: Color) -> void:
	label.text = text
	label.modulate = color


func _process(delta: float) -> void:
	life_left -= delta
	position.y -= RISE_SPEED * delta
	label.modulate.a = clampf(life_left / DURATION, 0.0, 1.0)
	if life_left <= 0.0:
		queue_free()
