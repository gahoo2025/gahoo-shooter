extends Node2D

## gahoo-shooter ゲーム進行管理
## タイトル → (ステージ1〜10：雑魚敵の波 → ボス) → 全ステージクリア → タイトル
## 実装計画（gamedev/gahoo-shooter-plan-01.md・plan-02.md・plan-03.md）に対応。
## ステージが進むごとに雑魚敵・ボスの難易度が式で上がっていく（下記定数参照）。

enum State { TITLE, PLAYING, GAME_OVER, CLEAR }

const MAX_LIVES := 3
const TOTAL_STAGES := 10
const STAGE_BASE_ENEMY_COUNT := 8
const STAGE_ENEMY_INCREMENT := 2
const STAGE_TRANSITION_DURATION := 1.5
const INVINCIBLE_TIME := 1.5
const SHAKE_DURATION := 0.25
const SHAKE_STRENGTH := 6.0

const BOSS_BASE_HEALTH := 15
const BOSS_HEALTH_STEP := 3
const BOSS_BASE_FIRE_INTERVAL := 1.2
const BOSS_FIRE_INTERVAL_STEP := 0.07
const BOSS_MIN_FIRE_INTERVAL := 0.5
const BOSS_BASE_SPEED := 100.0
const BOSS_SPEED_STEP := 10.0
const BOSS_MAX_SPEED := 220.0
const BOSS_SPREAD_COUNT_FINAL_STAGE := 3

const BOSS_SCENE: PackedScene = preload("res://scenes/boss.tscn")

var state: State = State.TITLE
var score: int = 0
var lives: int = MAX_LIVES
var current_stage: int = 1
var defeated_count: int = 0
var invincible: bool = false
var boss_active: bool = false
var shake_time_left: float = 0.0
var stage_transition_time_left: float = 0.0

@onready var player: Area2D = $Player
@onready var enemy_spawner: Node = $EnemySpawner
@onready var enemy_container: Node2D = $EnemyContainer
@onready var bullet_container: Node2D = $BulletContainer
@onready var score_label: Label = $UI/ScoreLabel
@onready var lives_label: Label = $UI/LivesLabel
@onready var stage_label: Label = $UI/StageLabel
@onready var dpad: Control = $UI/DPad
@onready var title_screen: Control = $UI/TitleScreen
@onready var game_over_screen: Control = $UI/GameOverScreen
@onready var clear_screen: Control = $UI/ClearScreen
@onready var invincible_timer: Timer = $InvincibleTimer


func _ready() -> void:
	player.hit.connect(_on_player_hit)
	title_screen.get_node("PlayButton").pressed.connect(start_game)
	game_over_screen.get_node("RestartButton").pressed.connect(start_game)
	clear_screen.get_node("RestartButton").pressed.connect(start_game)
	invincible_timer.wait_time = INVINCIBLE_TIME
	invincible_timer.one_shot = true
	invincible_timer.timeout.connect(func() -> void:
		invincible = false
		player.set_blinking(false)
	)
	_connect_dpad_button("UpButton", "up")
	_connect_dpad_button("DownButton", "down")
	_connect_dpad_button("LeftButton", "left")
	_connect_dpad_button("RightButton", "right")
	_show_title()


## D-padの各ボタンについて、押している間だけ自機に方向を伝えるよう接続する
func _connect_dpad_button(button_name: String, direction: String) -> void:
	var button: BaseButton = dpad.get_node(button_name)
	button.button_down.connect(func() -> void: player.set_dpad(direction, true))
	button.button_up.connect(func() -> void: player.set_dpad(direction, false))


func _process(delta: float) -> void:
	if shake_time_left > 0.0:
		shake_time_left -= delta
		if shake_time_left > 0.0:
			position = Vector2(randf_range(-SHAKE_STRENGTH, SHAKE_STRENGTH), randf_range(-SHAKE_STRENGTH, SHAKE_STRENGTH))
		else:
			position = Vector2.ZERO

	if stage_transition_time_left > 0.0:
		stage_transition_time_left -= delta
		if stage_transition_time_left <= 0.0:
			stage_label.visible = false
			enemy_spawner.configure_for_stage(current_stage)
			enemy_spawner.start()


func start_game() -> void:
	score = 0
	lives = MAX_LIVES
	current_stage = 1
	defeated_count = 0
	invincible = false
	boss_active = false
	stage_transition_time_left = 0.0
	stage_label.visible = false
	state = State.PLAYING
	_clear_container(enemy_container)
	_clear_container(bullet_container)
	player.position = Vector2(screen_center_x(), get_viewport().get_visible_rect().size.y - 100)
	player.set_active(true)
	dpad.visible = true
	enemy_spawner.configure_for_stage(current_stage)
	enemy_spawner.start()
	_update_labels()
	title_screen.visible = false
	game_over_screen.visible = false
	clear_screen.visible = false


func _on_enemy_defeated(score_value: int) -> void:
	if state != State.PLAYING or boss_active:
		return
	score += score_value
	defeated_count += 1
	_update_labels()
	if defeated_count >= _enemies_needed_for_stage(current_stage):
		_spawn_boss()


func _on_boss_defeated(score_value: int) -> void:
	if state != State.PLAYING:
		return
	score += score_value
	boss_active = false
	_update_labels()
	if current_stage >= TOTAL_STAGES:
		_show_clear()
	else:
		current_stage += 1
		defeated_count = 0
		_start_stage_transition()


func _on_player_hit() -> void:
	if state != State.PLAYING or invincible:
		return
	lives -= 1
	_update_labels()
	invincible = true
	invincible_timer.start()
	player.set_blinking(true)
	shake_time_left = SHAKE_DURATION
	if lives <= 0:
		_show_game_over()


func _spawn_boss() -> void:
	boss_active = true
	enemy_spawner.stop()
	var boss: Boss = BOSS_SCENE.instantiate()
	boss.position = Vector2(screen_center_x(), -80)
	boss.max_health = _boss_health_for_stage(current_stage)
	boss.fire_interval = _boss_fire_interval_for_stage(current_stage)
	boss.move_speed = _boss_speed_for_stage(current_stage)
	boss.bullet_spread_count = BOSS_SPREAD_COUNT_FINAL_STAGE if current_stage >= TOTAL_STAGES else 1
	enemy_container.add_child(boss)
	boss.defeated.connect(_on_boss_defeated)


func _start_stage_transition() -> void:
	enemy_spawner.stop()
	stage_label.text = "STAGE %d" % current_stage
	stage_label.visible = true
	stage_transition_time_left = STAGE_TRANSITION_DURATION


func _enemies_needed_for_stage(stage: int) -> int:
	return STAGE_BASE_ENEMY_COUNT + (stage - 1) * STAGE_ENEMY_INCREMENT


func _boss_health_for_stage(stage: int) -> int:
	return BOSS_BASE_HEALTH + (stage - 1) * BOSS_HEALTH_STEP


func _boss_fire_interval_for_stage(stage: int) -> float:
	return maxf(BOSS_MIN_FIRE_INTERVAL, BOSS_BASE_FIRE_INTERVAL - (stage - 1) * BOSS_FIRE_INTERVAL_STEP)


func _boss_speed_for_stage(stage: int) -> float:
	return minf(BOSS_MAX_SPEED, BOSS_BASE_SPEED + (stage - 1) * BOSS_SPEED_STEP)


func _show_title() -> void:
	state = State.TITLE
	player.set_active(false)
	dpad.visible = false
	enemy_spawner.stop()
	stage_label.visible = false
	title_screen.visible = true
	game_over_screen.visible = false
	clear_screen.visible = false


func _show_game_over() -> void:
	state = State.GAME_OVER
	player.set_active(false)
	dpad.visible = false
	enemy_spawner.stop()
	stage_label.visible = false
	_clear_container(enemy_container)
	_clear_container(bullet_container)
	game_over_screen.visible = true


func _show_clear() -> void:
	state = State.CLEAR
	player.set_active(false)
	dpad.visible = false
	enemy_spawner.stop()
	stage_label.visible = false
	_clear_container(enemy_container)
	_clear_container(bullet_container)
	clear_screen.visible = true


func _update_labels() -> void:
	score_label.text = "SCORE: %d" % score
	lives_label.text = "LIVES: %d" % lives


func _clear_container(container: Node) -> void:
	for child in container.get_children():
		child.queue_free()


func screen_center_x() -> float:
	return get_viewport().get_visible_rect().size.x / 2.0
