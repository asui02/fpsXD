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
@export var is_local_player: bool = false

var camera_pivot: Node3D
var camera: Camera3D
var mesh: MeshInstance3D
var multiplayer_id: int = 1

# Network sync
var network_position: Vector3
var network_rotation: Vector3
var position_smooth: float = 0.1

func _ready() -> void:
	multiplayer_id = multiplayer.get_unique_id()

	# ✅ ВСЕГДА создаём коллизию
	var collision = CollisionShape3D.new()
	var capsule_shape = CapsuleShape3D.new()
	capsule_shape.radius = 0.4
	capsule_shape.height = 1.0
	collision.shape = capsule_shape

	var total_height = capsule_shape.height + capsule_shape.radius * 2
	collision.position.y = total_height / 2

	add_child(collision)

	# Camera
	camera_pivot = Node3D.new()
	camera_pivot.position.y = camera_height
	add_child(camera_pivot)

	camera = Camera3D.new()
	camera_pivot.add_child(camera)

	if is_local_player:
		camera.current = true
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	else:
		# только визуал
		mesh = MeshInstance3D.new()
		var capsule_mesh = CapsuleMesh.new()
		capsule_mesh.radius = 0.4
		capsule_mesh.height = 1.0
		mesh.mesh = capsule_mesh
		mesh.position.y = total_height / 2
		add_child(mesh)

func _input(event: InputEvent) -> void:
	if not is_local_player:
		return
	
	# Mouse look
	if event is InputEventMouseMotion:
		var mouse_delta = event.relative
		rotate_y(-mouse_delta.x * mouse_sensitivity)
		camera_pivot.rotate_x(-mouse_delta.y * mouse_sensitivity)
		camera_pivot.rotation.x = clamp(camera_pivot.rotation.x, -PI/2, PI/2)
		
		# Send rotation to other players
		rpc("sync_rotation", rotation.y, camera_pivot.rotation.x)

func _physics_process(delta: float) -> void:
	if not is_local_player:
		# Remote player: smooth interpolation
		position = lerp(position, network_position, position_smooth)
		rotation.y = lerp_angle(rotation.y, network_rotation.y, position_smooth)
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
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)
	
	move_and_slide()
	
	# Send position to other players
	rpc("sync_position", global_position)

# RPC functions for network sync
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
	camera_pivot.rotation.x = pitch

@rpc("any_peer", "call_remote", "reliable")
func set_multiplayer_id(id: int) -> void:
	multiplayer_id = id
