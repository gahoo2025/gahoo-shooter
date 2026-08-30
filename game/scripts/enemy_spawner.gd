extends Node

## 一定間隔で画面上部のランダムなX座標に敵を出現させる。
## ステージごとに使用する敵パターン・出現間隔を変える（configure_for_stage）。
## start()/stop() はMain（ゲーム進行管理）から呼ばれる。

@export var enemy_scene: PackedScene = preload("res://scenes/enemy.tscn")
@export var spawn_interval: float = 1.2

var screen_size: Vector2
var active: bool = false
var available_patterns: Array[Enemy.Pattern] = [Enemy.Pattern.STRAIGHT]

@onready var timer: Timer = $Timer


func _ready() -> void:
	screen_size = get_viewport().get_visible_rect().size
	timer.wait_time = spawn_interval
	timer.timeout.connect(_on_timer_timeout)


## ステージ番号（1始まり）に応じて、出現させる敵パターンと出現間隔を設定する
func configure_for_stage(stage: int) -> void:
	match stage:
		1:
			available_patterns = [Enemy.Pattern.STRAIGHT]
			spawn_interval = 1.2
		2:
			available_patterns = [Enemy.Pattern.STRAIGHT, Enemy.Pattern.ZIGZAG]
			spawn_interval = 1.0
		_:
			available_patterns = [Enemy.Pattern.STRAIGHT, Enemy.Pattern.ZIGZAG, Enemy.Pattern.TRACKER]
			spawn_interval = 0.85
	timer.wait_time = spawn_interval


func start() -> void:
	active = true
	timer.start()


func stop() -> void:
	active = false
	timer.stop()


func _on_timer_timeout() -> void:
	if not active or enemy_scene == null:
		return
	var enemy: Enemy = enemy_scene.instantiate()
	var margin := 20.0
	enemy.position = Vector2(randf_range(margin, screen_size.x - margin), -32)
	enemy.pattern = available_patterns[randi() % available_patterns.size()]
	get_parent().get_node("EnemyContainer").add_child(enemy)
	enemy.defeated.connect(get_parent()._on_enemy_defeated)
