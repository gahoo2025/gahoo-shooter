extends Node2D

## gahoo-shooter ゲーム進行管理（タイトル → プレイ → ゲームオーバー/クリア → タイトル）
## 実装計画（gamedev/gahoo-shooter-plan-01.md）のミニマム動作版に対応。

enum State { TITLE, PLAYING, GAME_OVER, CLEAR }

const MAX_LIVES := 3
const ENEMIES_TO_CLEAR := 10
const INVINCIBLE_TIME := 1.5

var state: State = State.TITLE
var score: int = 0
var lives: int = MAX_LIVES
var defeated_count: int = 0
var invincible: bool = false

@onready var player: Area2D = $Player
@onready var enemy_spawner: Node = $EnemySpawner
@onready var enemy_container: Node2D = $EnemyContainer
@onready var bullet_container: Node2D = $BulletContainer
@onready var score_label: Label = $UI/ScoreLabel
@onready var lives_label: Label = $UI/LivesLabel
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
	invincible_timer.timeout.connect(func() -> void: invincible = false)
	_show_title()


func start_game() -> void:
	score = 0
	lives = MAX_LIVES
	defeated_count = 0
	invincible = false
	state = State.PLAYING
	_clear_container(enemy_container)
	_clear_container(bullet_container)
	player.position = Vector2(screen_center_x(), get_viewport().get_visible_rect().size.y - 100)
	player.set_active(true)
	enemy_spawner.start()
	_update_labels()
	title_screen.visible = false
	game_over_screen.visible = false
	clear_screen.visible = false


func _on_enemy_defeated(score_value: int) -> void:
	if state != State.PLAYING:
		return
	score += score_value
	defeated_count += 1
	_update_labels()
	if defeated_count >= ENEMIES_TO_CLEAR:
		_show_clear()


func _on_player_hit() -> void:
	if state != State.PLAYING or invincible:
		return
	lives -= 1
	_update_labels()
	invincible = true
	invincible_timer.start()
	if lives <= 0:
		_show_game_over()


func _show_title() -> void:
	state = State.TITLE
	player.set_active(false)
	enemy_spawner.stop()
	title_screen.visible = true
	game_over_screen.visible = false
	clear_screen.visible = false


func _show_game_over() -> void:
	state = State.GAME_OVER
	player.set_active(false)
	enemy_spawner.stop()
	game_over_screen.visible = true


func _show_clear() -> void:
	state = State.CLEAR
	player.set_active(false)
	enemy_spawner.stop()
	clear_screen.visible = true


func _update_labels() -> void:
	score_label.text = "SCORE: %d" % score
	lives_label.text = "LIVES: %d" % lives


func _clear_container(container: Node) -> void:
	for child in container.get_children():
		child.queue_free()


func screen_center_x() -> float:
	return get_viewport().get_visible_rect().size.x / 2.0
