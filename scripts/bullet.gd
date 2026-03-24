extends Area3D
class_name Bullet

@export var damage: float = 25.0
@export var speed: float = 1000.0  # ✅ Очень высокая скорость
@export var lifetime: float = 3.0
@export var raycast_length: float = 1.0  # Длина луча вперёд

@onready var raycast: RayCast3D = $RayCast3D
const BULLET_HOLE: PackedScene = preload("res://units/decalBulletHole.tscn")

var velocity: Vector3 = Vector3.ZERO
var shooter_id: int = 0
var previous_position: Vector3  # ✅ Позиция в предыдущем кадре
var has_hit: bool = false

@onready var bulletModel: MeshInstance3D = $CollisionShape3D/MeshInstance3D
var startPos: Vector3
var startScale: Vector3 = Vector3.ZERO

func _ready() -> void:
	startScale = bulletModel.scale
	startPos = position
	
	# Настройка луча
	raycast.target_position = Vector3(0, 0, -raycast_length)
	raycast.force_raycast_update()
	
	# Запоминаем стартовую позицию
	previous_position = global_position
	
	get_tree().create_timer(lifetime).timeout.connect(queue_free)

func _process(delta: float) -> void:
	var distance = (startPos - position).length()
	bulletModel.scale = Vector3.ONE/10 * distance/1.8 + Vector3.FORWARD * 5
	
func _physics_process(delta: float) -> void:
	if has_hit:
		return
	
	# ✅ 1. Запоминаем позицию ДО движения
	previous_position = global_position
	
	# ✅ 2. Применяем физику
	velocity.y -= 9.8 * delta
	position += velocity * delta
	
	# ✅ 3. Проверка лучом вперёд (быстрая)
	raycast.force_raycast_update()
	if raycast.is_colliding():
		var collider = raycast.get_collider()
		var hit_pos = raycast.get_collision_point()
		var hit_normal = raycast.get_collision_normal()
		_handle_hit(collider, hit_pos, hit_normal)
		return
	
	# ✅ 4. ДОПОЛНИТЕЛЬНО: Raycast от предыдущей к текущей позиции (для очень быстрых пуль)
	# Это гарантирует попадание, даже если пуля пролетела объект за один кадр
	var travel_distance = previous_position.distance_to(global_position)
	if travel_distance > raycast_length:
		_check_long_distance_hit()

func _check_long_distance_hit() -> void:
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(
		previous_position, 
		global_position,
		0xFFFFFFFF,  # Collision mask (все слои)
		[self]       # Исключаем саму пулю
	)
	
	var result = space_state.intersect_ray(query)
	
	if result:
		var collider = result.collider
		var hit_pos = result.position
		var hit_normal = result.normal
		_handle_hit(collider, hit_pos, hit_normal)

func _handle_hit(collider: Node3D, hit_pos: Vector3, hit_normal: Vector3) -> void:
	if has_hit:
		return
	has_hit = true
	
	# Игнорируем стрелка
	if collider is MultiplayerPlayer and collider.multiplayer_id == shooter_id:
		queue_free()
		return
	
	# Создаём декаль
	_spawn_decal(hit_pos, hit_normal)
	
	# Наносим урон
	if collider.has_method("take_damage"):
		collider.take_damage(damage, shooter_id)
	
	queue_free()

func _spawn_decal(pos: Vector3, normal: Vector3) -> void:
	if not BULLET_HOLE:
		return
	
	var decal = BULLET_HOLE.instantiate()
	get_tree().current_scene.add_child(decal)
	
	decal.global_position = pos + normal * 0.01
	decal.look_at(pos + normal, Vector3.UP)

func initialize(dir: Vector3, shooter: int) -> void:
	velocity = dir * speed
	shooter_id = shooter
	look_at(global_position + dir, Vector3.UP)
	previous_position = global_position  # ✅ Важно для первого кадра
