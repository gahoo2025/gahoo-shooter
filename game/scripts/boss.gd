class_name Boss
extends Area2D

## ステージ末尾のボス。5ステージごとに4種類のタイプが切り替わり、
## 見た目・攻撃パターンが変わる（BossType参照）。
## 画面上部まで降りてきたら左右に往復移動しつつ、タイプごとの弾幕を一定間隔で発射する。
## 体力・移動速度・発射間隔・タイプはMain（main.gd）がステージ番号に応じて
## 生成時に設定する。自機の弾がmax_health回当たると撃破される。
##
## 見た目（2026-09-05）：タイプごとにGemini（AI画像生成）で作成した専用の
## 機体画像を使用（assets/sprites/boss_*.png、768x768）。
enum BossType { GUARDIAN, TWIN_CANNON, SWEEPER, OVERLORD }

signal defeated(score_value: int, position: Vector2)

const EXPLOSION_SCENE: PackedScene = preload("res://scenes/explosion.tscn")
const BULLET_SCENE: PackedScene = preload("res://scenes/boss_bullet.tscn")
const POWER_UP_SCENE: PackedScene = preload("res://scenes/power_up.tscn")
const FLASH_BRIGHTNESS := 2.0

## タイプごとの機体画像
const TYPE_TEXTURES: Dictionary = {
	BossType.GUARDIAN: preload("res://assets/sprites/boss_guardian.png"),
	BossType.TWIN_CANNON: preload("res://assets/sprites/boss_twin_cannon.png"),
	BossType.SWEEPER: preload("res://assets/sprites/boss_sweeper.png"),
	BossType.OVERLORD: preload("res://assets/sprites/boss_overlord.png"),
}

## 全方位弾幕（SWEEPER）の同時発射数・1回ごとの回転角
const SWEEPER_BULLET_COUNT := 8
const SWEEPER_ROTATION_STEP_DEG := 25.0
## 双砲（TWIN_CANNON）の左右の砲口オフセット
const TWIN_CANNON_OFFSET_X := 28.0

@export var boss_type: BossType = BossType.GUARDIAN
@export var max_health: int = 15
@export var score_value: int = 2000
@export var move_speed: float = 100.0
@export var fire_interval: float = 1.2
@export var entry_y: float = 120.0
## 自機狙いスプレッド弾（GUARDIAN・OVERLORD）の同時発射数
@export var bullet_spread_count: int = 1
@export var bullet_spread_angle_deg: float = 20.0

const BASE_TINT: Color = Color(1.0, 1.0, 1.0)

var health: int
var screen_size: Vector2
var direction: int = 1
var entered: bool = false
var sweeper_rotation_deg: float = 0.0

@onready var fire_timer: Timer = $FireTimer
@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	add_to_group("enemies")
	health = max_health
	screen_size = get_viewport().get_visible_rect().size
	sprite.texture = TYPE_TEXTURES.get(boss_type, TYPE_TEXTURES[BossType.GUARDIAN])
	sprite.modulate = BASE_TINT
	area_entered.connect(_on_area_entered)
	fire_timer.wait_time = fire_interval
	fire_timer.timeout.connect(_fire)


func _process(delta: float) -> void:
	if not entered:
		position.y += move_speed * delta
		if position.y >= entry_y:
			position.y = entry_y
			entered = true
			fire_timer.start()
	else:
		position.x += direction * move_speed * delta
		if position.x < 60.0:
			position.x = 60.0
			direction = 1
		elif position.x > screen_size.x - 60.0:
			position.x = screen_size.x - 60.0
			direction = -1


func _on_area_entered(area: Area2D) -> void:
	# collision_mask により、ここに来るのは自機の弾のみを想定
	area.queue_free()
	health -= 1
	_flash_hit()
	if health <= 0:
		_spawn_explosion()
		_spawn_power_up()
		defeated.emit(score_value, global_position)
		queue_free()


func _flash_hit() -> void:
	sprite.modulate = BASE_TINT * FLASH_BRIGHTNESS
	await get_tree().create_timer(0.08).timeout
	if is_instance_valid(sprite):
		sprite.modulate = BASE_TINT


## タイプごとに異なる弾幕パターンで発射する
func _fire() -> void:
	match boss_type:
		BossType.TWIN_CANNON:
			_fire_twin_cannon()
		BossType.SWEEPER:
			_fire_sweeper()
		_:
			# GUARDIAN・OVERLORDは自機狙いのスプレッド弾（bullet_spread_countで弾数が変わる）
			_fire_aimed_spread()


## 自機狙いの扇状スプレッド弾（GUARDIAN・OVERLORD用）
func _fire_aimed_spread() -> void:
	var player: Node = get_tree().get_first_node_in_group("player")
	if player == null:
		return
	var spawn_position: Vector2 = position + Vector2(0, 30)
	var base_dir: Vector2 = (player.global_position - spawn_position).normalized()
	var spread_angle: float = deg_to_rad(bullet_spread_angle_deg)
	for i in range(bullet_spread_count):
		var offset: float = 0.0
		if bullet_spread_count > 1:
			offset = -spread_angle * 0.5 + spread_angle * (float(i) / float(bullet_spread_count - 1))
		_spawn_bullet(spawn_position, base_dir.rotated(offset))


## 機体左右の2門から同時に自機狙いの単発弾を撃つ（TWIN_CANNON用）
func _fire_twin_cannon() -> void:
	var player: Node = get_tree().get_first_node_in_group("player")
	if player == null:
		return
	for offset_x in [-TWIN_CANNON_OFFSET_X, TWIN_CANNON_OFFSET_X]:
		var spawn_position: Vector2 = position + Vector2(offset_x, 30)
		var dir: Vector2 = (player.global_position - spawn_position).normalized()
		_spawn_bullet(spawn_position, dir)


## 自機を狙わず、全方位に回転する弾幕を撃つ（SWEEPER用）
func _fire_sweeper() -> void:
	var spawn_position: Vector2 = position + Vector2(0, 30)
	for i in range(SWEEPER_BULLET_COUNT):
		var angle: float = deg_to_rad(360.0 / SWEEPER_BULLET_COUNT * i) + deg_to_rad(sweeper_rotation_deg)
		_spawn_bullet(spawn_position, Vector2.DOWN.rotated(angle))
	sweeper_rotation_deg += SWEEPER_ROTATION_STEP_DEG


func _spawn_bullet(spawn_position: Vector2, velocity: Vector2) -> void:
	var bullet: Area2D = BULLET_SCENE.instantiate()
	bullet.position = spawn_position
	bullet.velocity = velocity
	get_parent().add_child(bullet)


func _spawn_explosion() -> void:
	var explosion: Node2D = EXPLOSION_SCENE.instantiate()
	explosion.position = position
	get_parent().add_child(explosion)


func _spawn_power_up() -> void:
	var power_up: PowerUp = POWER_UP_SCENE.instantiate()
	power_up.position = position
	power_up.power_type = PowerUp.Type.values()[randi() % PowerUp.Type.size()]
	get_parent().add_child(power_up)
