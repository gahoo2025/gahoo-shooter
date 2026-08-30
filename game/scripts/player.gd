extends Area2D

## 自機（プレイヤー機）
## 操作方法：タップ/ドラッグ（モバイル向け主要操作）、矢印キー/WASD（デバッグ用）

signal hit

@export var move_speed: float = 800.0
@export var fire_interval: float = 0.3
@export var bullet_scene: PackedScene = preload("res://scenes/bullet.tscn")

var screen_size: Vector2
var target_position: Vector2
var is_dragging: bool = false

@onready var fire_timer: Timer = $AutoFireTimer


func _ready() -> void:
	screen_size = get_viewport().get_visible_rect().size
	target_position = position
	fire_timer.wait_time = fire_interval
	fire_timer.timeout.connect(_on_fire_timer_timeout)
	area_entered.connect(_on_area_entered)
	queue_redraw()


func _process(delta: float) -> void:
	var keyboard_dir := Vector2(
		Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left"),
		Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up")
	)
	if keyboard_dir != Vector2.ZERO:
		position += keyboard_dir.normalized() * move_speed * delta
	elif is_dragging:
		position = position.move_toward(target_position, move_speed * delta)
	position.x = clamp(position.x, 16, screen_size.x - 16)
	position.y = clamp(position.y, 16, screen_size.y - 16)


func _input(event: InputEvent) -> void:
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


## ゲームの状態（タイトル/プレイ中/ゲームオーバー/クリア）に応じて
## 自機の入力受付・見た目・自動発射を切り替える
func set_active(active: bool) -> void:
	set_process(active)
	set_process_input(active)
	monitoring = active
	visible = active
	is_dragging = false
	if active:
		fire_timer.start()
	else:
		fire_timer.stop()


func _draw() -> void:
	draw_polygon(
		PackedVector2Array([Vector2(0, -18), Vector2(14, 16), Vector2(-14, 16)]),
		PackedColorArray([Color(0.3, 0.9, 0.4)])
	)
