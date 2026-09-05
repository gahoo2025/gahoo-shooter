extends Node

## 一定間隔で画面上部のランダムなX座標に敵を出現させる。
## ステージ番号（1〜10）から難易度を式で算出する（configure_for_stage）：
## 出現間隔・敵の移動速度・使用パターンの構成・射撃可否がステージが
## 進むごとに上がっていく。start()/stop() はMain（ゲーム進行管理）から呼ばれる。
## ステージ3以降は、通常の単機出現とは別枠でFormationTimerが一定間隔ごとに
## 「編隊（複数機が隊列を組んで登場）」を追加で発生させる。

enum FormationType { LINE, V_SHAPE }

const MIN_SPAWN_INTERVAL := 0.5
const BASE_SPAWN_INTERVAL := 1.2
const SPAWN_INTERVAL_STEP := 0.08

const BASE_ENEMY_SPEED := 160.0
const ENEMY_SPEED_STEP := 13.0
const MAX_ENEMY_SPEED := 280.0

const ENEMY_SHOOTING_START_STAGE := 7
const ENEMY_SHOOT_INTERVAL := 1.8

## 編隊（隊列出現）関連。ステージ3以降で登場し、ステージが進むほど
## 出現間隔が短く・隊列の機数が多くなる
const FORMATION_START_STAGE := 3
const BASE_FORMATION_INTERVAL := 8.0
const FORMATION_INTERVAL_STEP := 0.3
const MIN_FORMATION_INTERVAL := 4.5
const FORMATION_BASE_SIZE := 3
const FORMATION_MAX_SIZE := 5
const FORMATION_STAGES_PER_EXTRA := 3
const FORMATION_SPACING := 56.0
const FORMATION_V_DEPTH := 46.0

@export var enemy_scene: PackedScene = preload("res://scenes/enemy.tscn")
@export var spawn_interval: float = BASE_SPAWN_INTERVAL

var screen_size: Vector2
var active: bool = false
var available_patterns: Array[Enemy.Pattern] = [Enemy.Pattern.STRAIGHT]
var current_enemy_speed: float = BASE_ENEMY_SPEED
var current_can_shoot: bool = false
var formation_enabled: bool = false
var formation_size: int = FORMATION_BASE_SIZE

@onready var timer: Timer = $Timer
@onready var formation_timer: Timer = $FormationTimer


func _ready() -> void:
	screen_size = get_viewport().get_visible_rect().size
	timer.wait_time = spawn_interval
	timer.timeout.connect(_on_timer_timeout)
	formation_timer.timeout.connect(_on_formation_timer_timeout)


## ステージ番号（1始まり）に応じて、出現間隔・敵速度・パターン構成・射撃可否・
## 編隊出現の可否と間隔・機数を算出する
func configure_for_stage(stage: int) -> void:
	spawn_interval = maxf(MIN_SPAWN_INTERVAL, BASE_SPAWN_INTERVAL - (stage - 1) * SPAWN_INTERVAL_STEP)
	timer.wait_time = spawn_interval
	current_enemy_speed = minf(MAX_ENEMY_SPEED, BASE_ENEMY_SPEED + (stage - 1) * ENEMY_SPEED_STEP)
	current_can_shoot = stage >= ENEMY_SHOOTING_START_STAGE
	available_patterns = _patterns_for_stage(stage)
	formation_enabled = stage >= FORMATION_START_STAGE
	formation_timer.wait_time = maxf(
		MIN_FORMATION_INTERVAL, BASE_FORMATION_INTERVAL - (stage - 1) * FORMATION_INTERVAL_STEP
	)
	formation_size = clampi(
		FORMATION_BASE_SIZE + (stage - FORMATION_START_STAGE) / FORMATION_STAGES_PER_EXTRA,
		FORMATION_BASE_SIZE,
		FORMATION_MAX_SIZE
	)


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
	if formation_enabled:
		formation_timer.start()


func stop() -> void:
	active = false
	timer.stop()
	formation_timer.stop()


func _on_timer_timeout() -> void:
	if not active or enemy_scene == null:
		return
	var margin := 20.0
	var spawn_position := Vector2(randf_range(margin, screen_size.x - margin), -32.0)
	var pattern: Enemy.Pattern = available_patterns[randi() % available_patterns.size()]
	_create_enemy(spawn_position, pattern)


## 編隊（複数機が隊列を組んで登場）を発生させる。通常の単機出現とは別枠のタイマーで、
## 一定間隔ごとに追加でまとまった数の敵が隊列を組んで現れる
func _on_formation_timer_timeout() -> void:
	if not active or enemy_scene == null:
		return
	var formation_type: FormationType = FormationType.values()[randi() % FormationType.size()]
	var offsets: Array[Vector2] = _formation_offsets(formation_type, formation_size)

	var margin := 20.0
	var min_offset_x: float = 0.0
	var max_offset_x: float = 0.0
	for offset in offsets:
		min_offset_x = minf(min_offset_x, offset.x)
		max_offset_x = maxf(max_offset_x, offset.x)
	var left_bound: float = margin - min_offset_x
	var right_bound: float = screen_size.x - margin - max_offset_x
	var center_x: float = screen_size.x / 2.0
	if left_bound < right_bound:
		center_x = randf_range(left_bound, right_bound)

	# 隊列を保つため、編隊内の敵は全機同じ直進パターンで出現させる
	for offset in offsets:
		var spawn_position := Vector2(center_x + offset.x, -32.0 + offset.y)
		_create_enemy(spawn_position, Enemy.Pattern.STRAIGHT)


## 縦横の隊列オフセット（中心を原点とした相対座標）を計算する
func _formation_offsets(formation_type: FormationType, size: int) -> Array[Vector2]:
	var offsets: Array[Vector2] = []
	var center: float = float(size - 1) / 2.0
	for i in range(size):
		var x_offset: float = (float(i) - center) * FORMATION_SPACING
		var y_offset: float = 0.0
		if formation_type == FormationType.V_SHAPE:
			# 中央の機体が先頭、両端が後方に下がるV字（雁行）隊列にする
			y_offset = -absf(float(i) - center) * FORMATION_V_DEPTH
		offsets.append(Vector2(x_offset, y_offset))
	return offsets


func _create_enemy(spawn_position: Vector2, pattern: Enemy.Pattern) -> void:
	var enemy: Enemy = enemy_scene.instantiate()
	enemy.position = spawn_position
	enemy.pattern = pattern
	enemy.speed = current_enemy_speed
	enemy.can_shoot = current_can_shoot
	enemy.shoot_interval = ENEMY_SHOOT_INTERVAL
	get_parent().get_node("EnemyContainer").add_child(enemy)
	enemy.defeated.connect(get_parent()._on_enemy_defeated)
