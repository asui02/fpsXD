extends CharacterBody3D
class_name MultiplayerPlayer

@export_group("Player")
@export var speed: float = 5.0
@export var jump_velocity: float = 4.5
@export var mouse_sensitivity: float = 0.002

@export_group("Camera")
@export var camera_height: float = 1.6
@export var camera_fov: float = 75.0

@export_group("Network")
# ✅ Метод определения оставлен как в старой версии (через экспорт)
@export var is_local_player: bool = false

# Ссылки на узлы, которые теперь создаются в сцене
@onready var camera_pivot: Node3D = $CameraPivot
@onready var camera: Camera3D = $CameraPivot/Camera
@onready var mesh: MeshInstance3D = $CapsuleMesh
@onready var weapon_socket: Node3D = $CameraPivot/WeaponSocket
@onready var weapon_model: Node3D = $WeaponModelPivot
# Коллизия настраивается в редакторе (CollisionShape3D)

# --- ОРУЖИЕ ---
@export_group("Weapon")
const BULLET_SCENE: PackedScene = preload("res://units/Bullet.tscn")

var time: float = 0.0
var health: float = 100.0

var can_shoot: bool = true
var fire_rate: float = 0.08  # Задержка между выстрелами

var multiplayer_id: int = 1

var WeaponPivotStartPos: Vector3
var WeaponPivotStartRot: Vector3

# Network sync
var network_position: Vector3
var network_rotation: Vector3
var position_smooth: float = 0.1

func _ready() -> void:
	WeaponPivotStartPos = weapon_model.position
	multiplayer_id = multiplayer.get_unique_id()

	# Настройка камеры
	camera.fov = camera_fov
	camera_pivot.position.y = camera_height

	if is_local_player:
		# Локальный игрок
		camera.current = true
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		# Скрываем меш, чтобы не видеть себя изнутри
		if mesh:
			mesh.visible = false
	else:
		# Удалённый игрок (только визуал)
		camera.current = false
		if mesh:
			mesh.visible = true

func _input(event: InputEvent) -> void:
	# ✅ Проверка локального игрока как в старой версии
	if not is_local_player:
		return
	
	# Mouse look
	if event is InputEventMouseMotion:
		var mouse_delta = event.relative
		rotate_y(-mouse_delta.x * mouse_sensitivity)
		camera_pivot.rotate_x(-mouse_delta.y * mouse_sensitivity)
		camera_pivot.rotation.x = clamp(camera_pivot.rotation.x, -PI/2, PI/2)
		weapon_model.rotation = lerp(weapon_model.rotation, camera_pivot.rotation - Vector3.UP * -mouse_delta.x, 0.001)
		
		rpc("sync_rotation", rotation.y, camera_pivot.rotation.x)

func _process(delta: float) -> void:
		
	if weapon_model.rotation != camera_pivot.rotation:
		weapon_model.rotation = lerp(weapon_model.rotation, camera_pivot.rotation, delta * 10)
		
	if not is_local_player:
		return
	
	# ✅ Автоматическая стрельба: проверяем каждый кадр
	if Input.is_action_pressed("shoot") and can_shoot:
		shoot()

func _physics_process(delta: float) -> void:
	if not is_local_player:
		# Remote player: smooth interpolation
		global_position = lerp(global_position, network_position, position_smooth)
		rotation.y = lerp_angle(rotation.y, network_rotation.y, position_smooth)
		if camera_pivot:
			camera_pivot.rotation.x = lerp(camera_pivot.rotation.x, network_rotation.x, position_smooth)
		return
	
	# Local player physics
	if not is_on_floor():
		velocity.y -= ProjectSettings.get_setting("physics/3d/default_gravity") * delta
	
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity
	
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	if direction:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
		time += delta  # Увеличиваем время каждый кадр
		var value = sin(time) 
		weapon_model.position.y = lerp(weapon_model.position.y, WeaponPivotStartPos.y + (abs(sin(time*7)*0.05)), delta * 10)
		weapon_model.position.x = lerp(weapon_model.position.x, WeaponPivotStartPos.x + (cos(time*7)*0.05), delta * 10)
		print_debug(sin(time))
	else:
		weapon_model.position = lerp(weapon_model.position, WeaponPivotStartPos, delta * 10)
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)
	
	move_and_slide()
	
	# Send position to other players
	rpc("sync_position", global_position)

func shoot() -> void:
	can_shoot = false
	get_tree().create_timer(fire_rate).timeout.connect(func(): can_shoot = true)
	
	var shoot_dir = -camera.global_transform.basis.z
	spawn_bullet(shoot_dir)
	
	rpc_id(multiplayer_id, "rpc_spawn_bullet", shoot_dir)
	animShoot()
	
func animShoot() -> void:
	weapon_model.position.z = WeaponPivotStartPos.z + 0.1
	weapon_model.rotation = weapon_model.rotation - Vector3.LEFT * 0.02
	

@rpc("any_peer", "call_remote", "unreliable")
func rpc_spawn_bullet(dir: Vector3) -> void:
	spawn_bullet(dir)

func spawn_bullet(dir: Vector3) -> void:
	var bullet = BULLET_SCENE.instantiate()
	
	# Если WeaponSocket не найден — спавним у камеры
	var spawn_pos = weapon_socket.global_position if weapon_socket else camera_pivot.global_position
	
	bullet.global_position = spawn_pos
	bullet.initialize(dir, multiplayer_id)
	
	get_tree().current_scene.add_child(bullet)
	
func take_damage(amount: float, from_id: int) -> void:
	health -= amount
	print("Player ", multiplayer_id, " got damage. Health: ", health)
	
	if health <= 0:
		die(from_id)

func die(killer_id: int) -> void:
	print("Player ", multiplayer_id, " was killed by ", killer_id)
	# Логика смерти (респаун, счет и т.д.)
	queue_free() # Или отключить управление
	
# RPC functions for network sync
# ✅ Вернул "reliable" как в старой версии
@rpc("any_peer", "call_remote", "reliable")
func sync_position(pos: Vector3) -> void:
	if is_local_player:
		return
	network_position = pos

@rpc("any_peer", "call_remote", "reliable")
func sync_rotation(rot_y: float, pitch: float) -> void:
	if is_local_player:
		return
	network_rotation = Vector3(0, rot_y, 0)
	if camera_pivot:
		camera_pivot.rotation.x = pitch

@rpc("any_peer", "call_remote", "reliable")
func set_multiplayer_id(id: int) -> void:
	multiplayer_id = id
