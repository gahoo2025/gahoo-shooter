class_name Enemy
extends Area2D

## 雑魚敵。直進・ジグザグ（左右蛇行）・トラッカー（自機狙い）の3パターンに対応。
## ステージ7以降は自機を狙わない直進弾を撃つ個体も出現する（can_shoot）。
## 自機の弾に当たると消滅してスコアを加算する。画面下に抜けると自然消滅する。

enum Pattern { STRAIGHT, ZIGZAG, TRACKER }

signal defeated(score_value: int)

const EXPLOSION_SCENE: PackedScene = preload("res://scenes/explosion.tscn")
const BULLET_SCENE: PackedScene = preload("res://scenes/boss_bullet.tscn")

@export var pattern: Pattern = Pattern.STRAIGHT
@export var speed: float = 160.0
@export var score_value: int = 100
@export var zigzag_amplitude: float = 60.0
@export var zigzag_frequency: float = 2.0
@export var tracker_turn_speed: float = 80.0
@export var can_shoot: bool = false
@export var shoot_interval: float = 1.8

var screen_size: Vector2
var _elapsed: float = 0.0
var _base_x: float = 0.0

@onready var shoot_timer: Timer = $ShootTimer


func _ready() -> void:
	add_to_group("enemies")
	screen_size = get_viewport().get_visible_rect().size
	_base_x = position.x
	area_entered.connect(_on_area_entered)
	if can_shoot:
		shoot_timer.wait_time = shoot_interval
		shoot_timer.timeout.connect(_fire)
		shoot_timer.start()


func _process(delta: float) -> void:
	_elapsed += delta
	position.y += speed * delta

	match pattern:
		Pattern.ZIGZAG:
			position.x = clampf(
				_base_x + sin(_elapsed * zigzag_frequency) * zigzag_amplitude,
				16.0,
				screen_size.x - 16.0
			)
		Pattern.TRACKER:
			var player: Node = get_tree().get_first_node_in_group("player")
			if player:
				var target_x: float = player.global_position.x
				position.x = move_toward(position.x, target_x, tracker_turn_speed * delta)

	if position.y > screen_size.y + 32:
		queue_free()


func _on_area_entered(area: Area2D) -> void:
	# collision_mask により、ここに来るのは自機の弾のみを想定
	area.queue_free()
	_spawn_explosion()
	defeated.emit(score_value)
	queue_free()


func _spawn_explosion() -> void:
	var explosion: Node2D = EXPLOSION_SCENE.instantiate()
	explosion.position = position
	get_parent().add_child(explosion)


func _fire() -> void:
	var bullet: Area2D = BULLET_SCENE.instantiate()
	bullet.position = position + Vector2(0, 20)
	bullet.velocity = Vector2.DOWN
	get_parent().add_child(bullet)
