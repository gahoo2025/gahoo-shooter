class_name Boss
extends Area2D

## ステージ末尾のボス。専用の宇宙船デザイン（紫系）を使用。
## 画面上部まで降りてきたら左右に往復移動しつつ、自機を狙う弾を一定間隔で発射する。
## 体力・移動速度・発射間隔・弾数（スプレッド）はMain（main.gd）が
## ステージ番号に応じて生成時に設定する。自機の弾がmax_health回当たると撃破される。

signal defeated(score_value: int, position: Vector2)

const EXPLOSION_SCENE: PackedScene = preload("res://scenes/explosion.tscn")
const BULLET_SCENE: PackedScene = preload("res://scenes/boss_bullet.tscn")
const POWER_UP_SCENE: PackedScene = preload("res://scenes/power_up.tscn")
const BASE_TINT: Color = Color(1.0, 1.0, 1.0)
const FLASH_TINT: Color = Color(2.0, 2.0, 2.0)

@export var max_health: int = 15
@export var score_value: int = 2000
@export var move_speed: float = 100.0
@export var fire_interval: float = 1.2
@export var entry_y: float = 120.0
## 同時に発射する弾の数（2以上で扇状に広がるスプレッド弾になる。最終ステージ用）
@export var bullet_spread_count: int = 1
@export var bullet_spread_angle_deg: float = 20.0

var health: int
var screen_size: Vector2
var direction: int = 1
var entered: bool = false

@onready var fire_timer: Timer = $FireTimer
@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	add_to_group("enemies")
	health = max_health
	screen_size = get_viewport().get_visible_rect().size
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
	sprite.modulate = FLASH_TINT
	await get_tree().create_timer(0.08).timeout
	if is_instance_valid(sprite):
		sprite.modulate = BASE_TINT


func _fire() -> void:
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
		var bullet: Area2D = BULLET_SCENE.instantiate()
		bullet.position = spawn_position
		bullet.velocity = base_dir.rotated(offset)
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
