extends Area3D
class_name Bullet

@export var damage: float = 25.0
@export var speed: float = 100.0
@export var lifetime: float = 3.0

var velocity: Vector3 = Vector3.ZERO
# ID игрока, который выстрелил (чтобы не убить самого себя)
var shooter_id: int = 0 

func _ready() -> void:
	# Уничтожить пулю через время, если не попала
	get_tree().create_timer(lifetime).timeout.connect(queue_free)
	
	# Если врезались во что-то
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

func _physics_process(delta: float) -> void:
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
