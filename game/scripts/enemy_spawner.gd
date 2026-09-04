extends Node

## 一定間隔で画面上部のランダムなX座標に敵を出現させる。
## ステージ番号（1〜10）から難易度を式で算出する（configure_for_stage）：
## 出現間隔・敵の移動速度・使用パターンの構成・射撃可否がステージが
## 進むごとに上がっていく。start()/stop() はMain（ゲーム進行管理）から呼ばれる。

const MIN_SPAWN_INTERVAL := 0.5
const BASE_SPAWN_INTERVAL := 1.2
const SPAWN_INTERVAL_STEP := 0.08

const BASE_ENEMY_SPEED := 160.0
const ENEMY_SPEED_STEP := 13.0
const MAX_ENEMY_SPEED := 280.0

const ENEMY_SHOOTING_START_STAGE := 7
const ENEMY_SHOOT_INTERVAL := 1.8

@export var enemy_scene: PackedScene = preload("res://scenes/enemy.tscn")
@export var spawn_interval: float = BASE_SPAWN_INTERVAL

var screen_size: Vector2
var active: bool = false
var available_patterns: Array[Enemy.Pattern] = [Enemy.Pattern.STRAIGHT]
var current_enemy_speed: float = BASE_ENEMY_SPEED
var current_can_shoot: bool = false

@onready var timer: Timer = $Timer


func _ready() -> void:
	screen_size = get_viewport().get_visible_rect().size
	timer.wait_time = spawn_interval
	timer.timeout.connect(_on_timer_timeout)


## ステージ番号（1始まり）に応じて、出現間隔・敵速度・パターン構成・射撃可否を算出する
func configure_for_stage(stage: int) -> void:
	spawn_interval = maxf(MIN_SPAWN_INTERVAL, BASE_SPAWN_INTERVAL - (stage - 1) * SPAWN_INTERVAL_STEP)
	timer.wait_time = spawn_interval
	current_enemy_speed = minf(MAX_ENEMY_SPEED, BASE_ENEMY_SPEED + (stage - 1) * ENEMY_SPEED_STEP)
	current_can_shoot = stage >= ENEMY_SHOOTING_START_STAGE
	available_patterns = _patterns_for_stage(stage)


func _patterns_for_stage(stage: int) -> Array[Enemy.Pattern]:
	if stage <= 1:
		return [Enemy.Pattern.STRAIGHT]
	elif stage <= 3:
		return [Enemy.Pattern.STRAIGHT, Enemy.Pattern.ZIGZAG]
	elif stage <= 6:
		return [Enemy.Pattern.STRAIGHT, Enemy.Pattern.ZIGZAG, Enemy.Pattern.TRACKER]
	else:
		# 終盤は直進を外し、避けにくいパターンの比率を上げる
		return [Enemy.Pattern.ZIGZAG, Enemy.Pattern.TRACKER, Enemy.Pattern.TRACKER]


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
	enemy.speed = current_enemy_speed
	enemy.can_shoot = current_can_shoot
	enemy.shoot_interval = ENEMY_SHOOT_INTERVAL
	get_parent().get_node("EnemyContainer").add_child(enemy)
	enemy.defeated.connect(get_parent()._on_enemy_defeated)
