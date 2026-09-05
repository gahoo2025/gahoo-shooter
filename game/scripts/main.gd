extends Node2D

## gahoo-shooter ゲーム進行管理
## タイトル → (ステージ1〜10：雑魚敵の波 → ボス) → 全ステージクリア → タイトル
## 実装計画（gamedev/gahoo-shooter-plan-01.md〜plan-04.md）に対応。
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
const SHIELD_DURATION := 5.0

## 連続撃破ボーナス：COMBO_WINDOW秒以内に次の雑魚敵を倒し続けるとコンボが継続し、
## コンボ数に応じたボーナススコアが加算される（被弾・撃破が途切れるとリセット）
const COMBO_WINDOW := 1.5
const COMBO_BONUS_STEP := 20

const BOSS_SCENE: PackedScene = preload("res://scenes/boss.tscn")
const SCORE_POPUP_SCENE: PackedScene = preload("res://scenes/score_popup.tscn")
const HIGH_SCORE_FILE := "user://highscore.cfg"

var state: State = State.TITLE
var score: int = 0
var lives: int = MAX_LIVES
var current_stage: int = 1
var defeated_count: int = 0
var invincible: bool = false
var boss_active: bool = false
var shake_time_left: float = 0.0
var stage_transition_time_left: float = 0.0
var shield_time_left: float = 0.0
var high_score: int = 0
var combo_count: int = 0
var combo_time_left: float = 0.0
## 上下ボタンは左右両方の列にあるため、方向ごとの押下数を数えて管理する
var dpad_press_counts: Dictionary = {"up": 0, "down": 0, "left": 0, "right": 0}

@onready var player: Area2D = $Player
@onready var enemy_spawner: Node = $EnemySpawner
@onready var enemy_container: Node2D = $EnemyContainer
@onready var bullet_container: Node2D = $BulletContainer
@onready var score_label: Label = $UI/ScoreLabel
@onready var lives_label: Label = $UI/LivesLabel
@onready var high_score_label: Label = $UI/HighScoreLabel
@onready var combo_label: Label = $UI/ComboLabel
@onready var stage_label: Label = $UI/StageLabel
@onready var dpad: Control = $UI/DPad
@onready var title_screen: Control = $UI/TitleScreen
@onready var title_high_score_label: Label = $UI/TitleScreen/HighScoreLabel
@onready var game_over_screen: Control = $UI/GameOverScreen
@onready var game_over_record_label: Label = $UI/GameOverScreen/NewRecordLabel
@onready var clear_screen: Control = $UI/ClearScreen
@onready var clear_record_label: Label = $UI/ClearScreen/NewRecordLabel
@onready var invincible_timer: Timer = $InvincibleTimer


func _ready() -> void:
	high_score = _load_high_score()
	high_score_label.text = "HIGH SCORE: %d" % high_score
	title_high_score_label.text = "HIGH SCORE: %d" % high_score
	player.hit.connect(_on_player_hit)
	player.powerup_collected.connect(_on_powerup_collected)
	title_screen.get_node("PlayButton").pressed.connect(start_game)
	game_over_screen.get_node("RestartButton").pressed.connect(start_game)
	clear_screen.get_node("RestartButton").pressed.connect(start_game)
	invincible_timer.wait_time = INVINCIBLE_TIME
	invincible_timer.one_shot = true
	invincible_timer.timeout.connect(func() -> void:
		invincible = false
		player.set_blinking(false)
	)
	# 上下は左右それぞれの列にボタンがあるため、片方を離してももう片方が
	# 押されていれば移動を継続できるよう、方向ごとに押下数を数えて判定する
	_connect_dpad_button("UpButtonLeft", "up")
	_connect_dpad_button("UpButtonRight", "up")
	_connect_dpad_button("DownButtonLeft", "down")
	_connect_dpad_button("DownButtonRight", "down")
	_connect_dpad_button("LeftButton", "left")
	_connect_dpad_button("RightButton", "right")
	_show_title()


## D-padの各ボタンについて、押している間だけ自機に方向を伝えるよう接続する。
## 同じ方向に複数のボタン（上下は左右両方の列にある）が対応する場合があるため、
## 押下数をカウントし、1つでも押されていればその方向をONにする
func _connect_dpad_button(button_name: String, direction: String) -> void:
	var button: BaseButton = dpad.get_node(button_name)
	button.button_down.connect(func() -> void: _on_dpad_button_pressed(direction, true))
	button.button_up.connect(func() -> void: _on_dpad_button_pressed(direction, false))


func _on_dpad_button_pressed(direction: String, pressed: bool) -> void:
	if pressed:
		dpad_press_counts[direction] = dpad_press_counts.get(direction, 0) + 1
	else:
		dpad_press_counts[direction] = maxi(0, dpad_press_counts.get(direction, 0) - 1)
	player.set_dpad(direction, dpad_press_counts[direction] > 0)


## 画面切り替えでD-padが非表示になる際、押しっぱなしのまま切り替わって
## 状態が残ってしまわないよう、押下数と自機側の方向をリセットする
func _reset_dpad() -> void:
	for direction in dpad_press_counts.keys():
		dpad_press_counts[direction] = 0
		player.set_dpad(direction, false)


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

	if shield_time_left > 0.0:
		shield_time_left -= delta
		if shield_time_left <= 0.0:
			player.set_blinking(false)

	if combo_time_left > 0.0:
		combo_time_left -= delta
		if combo_time_left <= 0.0:
			_reset_combo()


func start_game() -> void:
	score = 0
	lives = MAX_LIVES
	current_stage = 1
	defeated_count = 0
	invincible = false
	boss_active = false
	stage_transition_time_left = 0.0
	shield_time_left = 0.0
	stage_label.visible = false
	_reset_combo()
	state = State.PLAYING
	_clear_container(enemy_container)
	_clear_container(bullet_container)
	player.position = Vector2(screen_center_x(), get_viewport().get_visible_rect().size.y - 100)
	player.set_active(true)
	_reset_dpad()
	dpad.visible = true
	enemy_spawner.configure_for_stage(current_stage)
	enemy_spawner.start()
	_update_labels()
	title_screen.visible = false
	game_over_screen.visible = false
	clear_screen.visible = false


func _on_enemy_defeated(score_value: int, enemy_position: Vector2) -> void:
	if state != State.PLAYING or boss_active:
		return
	combo_count += 1
	combo_time_left = COMBO_WINDOW
	var bonus: int = (combo_count - 1) * COMBO_BONUS_STEP
	score += score_value + bonus
	defeated_count += 1
	_update_labels()
	_update_combo_label()
	_show_score_popup(enemy_position, score_value + bonus, bonus > 0)
	if defeated_count >= _enemies_needed_for_stage(current_stage):
		_spawn_boss()


func _on_boss_defeated(score_value: int, boss_position: Vector2) -> void:
	if state != State.PLAYING:
		return
	score += score_value
	boss_active = false
	_update_labels()
	_show_score_popup(boss_position, score_value, false)
	# ボス戦は連続撃破のリズムとは別枠なので、コンボはここで一区切りにする
	_reset_combo()
	if current_stage >= TOTAL_STAGES:
		_show_clear()
	else:
		current_stage += 1
		defeated_count = 0
		_start_stage_transition()


func _on_player_hit() -> void:
	if state != State.PLAYING or invincible or shield_time_left > 0.0:
		return
	lives -= 1
	_update_labels()
	_reset_combo()
	invincible = true
	invincible_timer.start()
	player.set_blinking(true)
	shake_time_left = SHAKE_DURATION
	if lives <= 0:
		_show_game_over()


## シールド・残機+1（ゲーム進行の状態）を取得したときの処理。
## 武器強化・スピードアップは自機側（player.gd）で完結するのでここには来ない
func _on_powerup_collected(power_type: int) -> void:
	if state != State.PLAYING:
		return
	match power_type:
		PowerUp.Type.SHIELD:
			shield_time_left = SHIELD_DURATION
			player.set_blinking(true)
		PowerUp.Type.LIFE:
			lives += 1
			_update_labels()


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
	_reset_dpad()
	dpad.visible = false
	enemy_spawner.stop()
	stage_label.visible = false
	title_high_score_label.text = "HIGH SCORE: %d" % high_score
	title_screen.visible = true
	game_over_screen.visible = false
	clear_screen.visible = false


## scoreがhigh_scoreを上回っていれば更新・保存する。更新した場合はtrueを返す（NEW RECORD表示用）
func _try_update_high_score() -> bool:
	if score <= high_score:
		return false
	high_score = score
	high_score_label.text = "HIGH SCORE: %d" % high_score
	_save_high_score(high_score)
	return true


## ハイスコアを保存する。user://はHTML5書き出しでもIndexedDBに永続化される
func _load_high_score() -> int:
	var config := ConfigFile.new()
	var err: int = config.load(HIGH_SCORE_FILE)
	if err != OK:
		return 0
	return int(config.get_value("scores", "high_score", 0))


func _save_high_score(value: int) -> void:
	var config := ConfigFile.new()
	config.set_value("scores", "high_score", value)
	config.save(HIGH_SCORE_FILE)


func _reset_combo() -> void:
	combo_count = 0
	combo_time_left = 0.0
	combo_label.visible = false


## コンボ数の表示を更新し、増えた瞬間だけ軽く拡大させて気づきやすくする
func _update_combo_label() -> void:
	if combo_count < 2:
		combo_label.visible = false
		return
	combo_label.text = "COMBO x%d" % combo_count
	combo_label.visible = true
	combo_label.scale = Vector2(1.3, 1.3)
	var tween: Tween = create_tween()
	tween.tween_property(combo_label, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## 撃破位置に「+スコア」を表示する（コンボボーナスが乗っている場合は色を変える）
func _show_score_popup(popup_position: Vector2, amount: int, is_bonus: bool) -> void:
	var popup: ScorePopup = SCORE_POPUP_SCENE.instantiate()
	popup.position = popup_position
	add_child(popup)
	var color: Color = Color(1.0, 0.85, 0.2) if is_bonus else Color(1.0, 1.0, 1.0)
	popup.setup("+%d" % amount, color)


func _show_game_over() -> void:
	state = State.GAME_OVER
	player.set_active(false)
	_reset_dpad()
	dpad.visible = false
	enemy_spawner.stop()
	stage_label.visible = false
	_clear_container(enemy_container)
	_clear_container(bullet_container)
	game_over_record_label.visible = _try_update_high_score()
	game_over_screen.visible = true


func _show_clear() -> void:
	state = State.CLEAR
	player.set_active(false)
	_reset_dpad()
	dpad.visible = false
	enemy_spawner.stop()
	stage_label.visible = false
	_clear_container(enemy_container)
	_clear_container(bullet_container)
	clear_record_label.visible = _try_update_high_score()
	clear_screen.visible = true


func _update_labels() -> void:
	score_label.text = "SCORE: %d" % score
	lives_label.text = "LIVES: %d" % lives


func _clear_container(container: Node) -> void:
	for child in container.get_children():
		child.queue_free()


func screen_center_x() -> float:
	return get_viewport().get_visible_rect().size.x / 2.0
