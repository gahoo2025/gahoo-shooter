extends Node

## 一定間隔で画面上部のランダムなX座標に敵を出現させる。
## start()/stop() はMain（ゲーム進行管理）から呼ばれる。

@export var enemy_scene: PackedScene = preload("res://scenes/enemy.tscn")
@export var spawn_interval: float = 1.2

var screen_size: Vector2
var active: bool = false

@onready var timer: Timer = $Timer


func _ready() -> void:
	screen_size = get_viewport().get_visible_rect().size
	timer.wait_time = spawn_interval
	timer.timeout.connect(_on_timer_timeout)


func start() -> void:
	active = true
	timer.start()


func stop() -> void:
	active = false
	timer.stop()


func _on_timer_timeout() -> void:
	if not active or enemy_scene == null:
		return
	var enemy: Area2D = enemy_scene.instantiate()
	var margin := 20.0
	enemy.position = Vector2(randf_range(margin, screen_size.x - margin), -32)
	get_parent().get_node("EnemyContainer").add_child(enemy)
	enemy.defeated.connect(get_parent()._on_enemy_defeated)
