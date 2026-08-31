extends Area2D

## 自機（プレイヤー機）
## 操作方法：画面上の方向ボタン（モバイル向け主要操作）、タップ/ドラッグ、矢印キー/WASD（デバッグ用）

signal hit

@export var move_speed: float = 350.0
@export var fire_interval: float = 0.3
@export var bullet_scene: PackedScene = preload("res://scenes/bullet.tscn")

const BLINK_INTERVAL := 0.1

var screen_size: Vector2
var target_position: Vector2
var is_dragging: bool = false
var blinking: bool = false
var _blink_elapsed: float = 0.0

# 画面上の方向ボタン（D-pad）の押下状態。main.gdのDPadボタンから設定される
var dpad_up: bool = false
var dpad_down: bool = false
var dpad_left: bool = false
var dpad_right: bool = false

@onready var fire_timer: Timer = $AutoFireTimer
@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	add_to_group("player")
	screen_size = get_viewport().get_visible_rect().size
	target_position = position
	fire_timer.wait_time = fire_interval
	fire_timer.timeout.connect(_on_fire_timer_timeout)
	area_entered.connect(_on_area_entered)


func _process(delta: float) -> void:
	var keyboard_dir := Vector2(
		Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left"),
		Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up")
	)
	var dpad_dir := Vector2(
		(1.0 if dpad_right else 0.0) - (1.0 if dpad_left else 0.0),
		(1.0 if dpad_down else 0.0) - (1.0 if dpad_up else 0.0)
	)
	if keyboard_dir != Vector2.ZERO:
		position += keyboard_dir.normalized() * move_speed * delta
	elif dpad_dir != Vector2.ZERO:
		position += dpad_dir.normalized() * move_speed * delta
	elif is_dragging:
		position = position.move_toward(target_position, move_speed * delta)
	position.x = clamp(position.x, 16, screen_size.x - 16)
	position.y = clamp(position.y, 16, screen_size.y - 16)

	if blinking:
		_blink_elapsed += delta
		if _blink_elapsed >= BLINK_INTERVAL:
			_blink_elapsed = 0.0
			sprite.visible = not sprite.visible


## _unhandled_inputを使うことで、D-padボタン等UIが既に処理した入力
## （タップ）はここに届かず、ドラッグ移動と競合しない
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		is_dragging = event.pressed
		target_position = event.position
	elif event is InputEventScreenDrag:
		target_position = event.position
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		is_dragging = event.pressed
		target_position = event.position
	elif event is InputEventMouseMotion and is_dragging:
		target_position = event.position


func _on_fire_timer_timeout() -> void:
	if bullet_scene == null:
		return
	var bullet: Area2D = bullet_scene.instantiate()
	bullet.position = position + Vector2(0, -20)
	get_parent().get_node("BulletContainer").add_child(bullet)


func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("enemies"):
		hit.emit()
	elif area.is_in_group("enemy_bullets"):
		area.queue_free()
		hit.emit()


## ゲームの状態（タイトル/プレイ中/ゲームオーバー/クリア）に応じて
## 自機の入力受付・見た目・自動発射を切り替える
func set_active(active: bool) -> void:
	set_process(active)
	set_process_unhandled_input(active)
	monitoring = active
	visible = active
	is_dragging = false
	dpad_up = false
	dpad_down = false
	dpad_left = false
	dpad_right = false
	set_blinking(false)
	if active:
		fire_timer.start()
	else:
		fire_timer.stop()


## main.gdの方向ボタン（D-pad）から呼ばれる。direction: "up"/"down"/"left"/"right"
func set_dpad(direction: String, pressed: bool) -> void:
	match direction:
		"up":
			dpad_up = pressed
		"down":
			dpad_down = pressed
		"left":
			dpad_left = pressed
		"right":
			dpad_right = pressed


## 被弾後の無敵時間中、機体を点滅させて「今は無敵」だと分かるようにする
func set_blinking(value: bool) -> void:
	blinking = value
	_blink_elapsed = 0.0
	sprite.visible = true
