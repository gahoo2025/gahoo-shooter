class_name PowerUp
extends Area2D

## パワーアップアイテム。Gemini（AI画像生成）で作成した種類ごとのアイコン画像を使用。
## ゆっくり下方向に落下し、自機が触れると取得される（player.gd参照）。
## 画面外に出ると自然消滅する。

enum Type { WEAPON, SHIELD, SPEED, LIFE }

## 種類ごとのアイコン画像（assets/sprites/powerups/、Gemini生成→透過処理済み256x256）
const TEXTURES: Dictionary = {
	Type.WEAPON: preload("res://assets/sprites/powerups/weapon.png"),
	Type.SHIELD: preload("res://assets/sprites/powerups/shield.png"),
	Type.SPEED: preload("res://assets/sprites/powerups/speed.png"),
	Type.LIFE: preload("res://assets/sprites/powerups/life.png"),
}

@export var power_type: Type = Type.WEAPON
@export var fall_speed: float = 100.0

var screen_size: Vector2

@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	add_to_group("powerups")
	screen_size = get_viewport().get_visible_rect().size
	sprite.texture = TEXTURES[power_type]


func _process(delta: float) -> void:
	position.y += fall_speed * delta
	if position.y > screen_size.y + 32:
		queue_free()
