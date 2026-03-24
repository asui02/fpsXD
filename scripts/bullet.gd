extends Area3D
class_name Bullet

@export var damage: float = 25.0
@export var speed: float = 300.0
@export var lifetime: float = 3.0

@onready var bulletModel: MeshInstance3D = $CollisionShape3D/MeshInstance3D

var velocity: Vector3 = Vector3.ZERO
# ID игрока, который выстрелил (чтобы не убить самого себя)
var shooter_id: int = 0 
var startPos: Vector3
var startScale: Vector3 = Vector3.ZERO

func _ready() -> void:
	startScale = bulletModel.scale
	startPos = position
	# Уничтожить пулю через время, если не попала
	get_tree().create_timer(lifetime).timeout.connect(queue_free)
	
	# Если врезались во что-то
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
func _process(delta: float) -> void:
	var distance = (startPos - position).length()
	bulletModel.scale = Vector3.ONE/10 * distance/2.5
	
func _physics_process(delta: float) -> void:
	velocity.y -= 9.8 * delta  # Или: velocity += Vector3.DOWN * 9.8 * delta
	
	# 2. Потом применяем скорость к ПОЗИЦИИ
	position += velocity * delta

func initialize(dir: Vector3, shooter: int) -> void:
	velocity = dir * speed
	shooter_id = shooter

func _on_body_entered(body: Node3D) -> void:
	# Игнорируем стрелка (опционально, если пуля вылетает изнутри модели)
	if body is MultiplayerPlayer and body.multiplayer_id == shooter_id:
		return
		
	# Наносим урон
	if body.has_method("take_damage"):
		body.take_damage(damage, shooter_id)
	
	queue_free()

func _on_area_entered(area: Area3D) -> void:
	# Проверка на попадание в хитбоксы противников
	if area.has_method("take_damage"):
		area.take_damage(damage, shooter_id)
	queue_free()
