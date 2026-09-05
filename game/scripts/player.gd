extends Area2D

## 自機（プレイヤー機）
## 操作方法：画面上の方向ボタン（モバイル向け主要操作）、タップ/ドラッグ、矢印キー/WASD（デバッグ用）

signal hit
## シールド・残機+1（ゲーム進行の状態に関わる）はmain.gd側で処理するため、
## 取得をシグナルで通知する。武器強化・スピードアップは自機側で完結する
signal powerup_collected(power_type: int)

@export var move_speed: float = 350.0
@export var fire_interval: float = 0.3
@export var bullet_scene: PackedScene = preload("res://scenes/bullet.tscn")
@export var weapon_spread_angle_deg: float = 18.0
@export var speed_boost_multiplier: float = 1.5

const BLINK_INTERVAL := 0.1
const SCORE_POPUP_SCENE: PackedScene = preload("res://scenes/score_popup.tscn")
const PICKUP_RING_SCENE: PackedScene = preload("res://scenes/pickup_ring.tscn")

var screen_size: Vector2
var target_position: Vector2
var is_dragging: bool = false
var blinking: bool = false
var _blink_elapsed: float = 0.0
var weapon_powered: bool = false
var _base_move_speed: float

# 画面上の方向ボタン（D-pad）の押下状態。main.gdのDPadボタンから設定される
var dpad_up: bool = false
var dpad_down: bool = false
var dpad_left: bool = false
var dpad_right: bool = false

@onready var fire_timer: Timer = $AutoFireTimer
@onready var weapon_timer: Timer = $WeaponTimer
@onready var speed_timer: Timer = $SpeedTimer
@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	add_to_group("player")
	screen_size = get_viewport().get_visible_rect().size
	target_position = position
	_base_move_speed = move_speed
	fire_timer.wait_time = fire_interval
	fire_timer.timeout.connect(_on_fire_timer_timeout)
	weapon_timer.timeout.connect(func() -> void: weapon_powered = false)
	speed_timer.timeout.connect(func() -> void: move_speed = _base_move_speed)
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
	var spawn_position: Vector2 = position + Vector2(0, -20)
	var bullet_container: Node = get_parent().get_node("BulletContainer")
	if weapon_powered:
		# 武器強化中は3方向（3WAY）に発射する
		var spread: float = deg_to_rad(weapon_spread_angle_deg)
		for offset in [-spread, 0.0, spread]:
			var bullet: Area2D = bullet_scene.instantiate()
			bullet.position = spawn_position
			bullet.velocity = Vector2.UP.rotated(offset)
			bullet_container.add_child(bullet)
	else:
		var bullet: Area2D = bullet_scene.instantiate()
		bullet.position = spawn_position
		bullet_container.add_child(bullet)


func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("enemies"):
		hit.emit()
	elif area.is_in_group("enemy_bullets"):
		area.queue_free()
		hit.emit()
	elif area.is_in_group("powerups"):
		var power_type: int = (area as PowerUp).power_type
		area.queue_free()
		_collect_powerup(power_type)


## 武器強化・スピードアップは自機側で完結させ、シールド・残機+1は
## ゲーム進行の状態に関わるためmain.gdへシグナルで通知する
func _collect_powerup(power_type: int) -> void:
	_spawn_pickup_effect(power_type)
	match power_type:
		PowerUp.Type.WEAPON:
			weapon_powered = true
			weapon_timer.start()
		PowerUp.Type.SPEED:
			move_speed = _base_move_speed * speed_boost_multiplier
			speed_timer.start()
		_:
			powerup_collected.emit(power_type)


## アイテム取得時、種類ごとの色でリング＋ラベルのフィードバックを表示する（爆発以外の演出強化）
func _spawn_pickup_effect(power_type: int) -> void:
	var info: Dictionary = _pickup_info(power_type)
	var ring: PickupRing = PICKUP_RING_SCENE.instantiate()
	ring.position = position
	get_parent().add_child(ring)
	ring.setup(info["color"])

	var popup: ScorePopup = SCORE_POPUP_SCENE.instantiate()
	popup.position = position + Vector2(0, -20)
	get_parent().add_child(popup)
	popup.setup(info["text"], info["color"])


func _pickup_info(power_type: int) -> Dictionary:
	match power_type:
		PowerUp.Type.WEAPON:
			return {"text": "WEAPON UP!", "color": Color(1.0, 0.9, 0.2)}
		PowerUp.Type.SHIELD:
			return {"text": "SHIELD!", "color": Color(0.3, 0.85, 1.0)}
		PowerUp.Type.SPEED:
			return {"text": "SPEED UP!", "color": Color(0.35, 1.0, 0.45)}
		PowerUp.Type.LIFE:
			return {"text": "+1 LIFE", "color": Color(1.0, 0.35, 0.55)}
		_:
			return {"text": "", "color": Color(1.0, 1.0, 1.0)}


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
	weapon_powered = false
	weapon_timer.stop()
	move_speed = _base_move_speed
	speed_timer.stop()
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
