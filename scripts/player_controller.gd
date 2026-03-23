extends CharacterBody3D
class_name PlayerController

@export_group("Player")
@export var speed: float = 5.0
@export var jump_velocity: float = 4.5
@export var mouse_sensitivity: float = 0.002

@export_group("Camera")
@export var camera_height: float = 1.6
@export var camera_fov: float = 75.0

var camera_pivot: Node3D
var camera: Camera3D
var capsule: CollisionShape3D

# Mouse capture
var mouse_captured: bool = true

func _ready() -> void:
	# Setup camera pivot
	camera_pivot = Node3D.new()
	camera_pivot.name = "CameraPivot"
	camera_pivot.position.y = camera_height
	add_child(camera_pivot)
	
	# Setup camera
	camera = Camera3D.new()
	camera.name = "Camera"
	camera.fov = camera_fov
	camera_pivot.add_child(camera)
	
	# Make camera current
	camera.current = true
	
	# Setup capsule collision
	capsule = CollisionShape3D.new()
	capsule.name = "CapsuleCollision"
	var capsule_shape = CapsuleShape3D.new()
	capsule_shape.radius = 0.4
	capsule_shape.height = 1.8
	capsule.shape = capsule_shape
	capsule.position.y = 0.9
	add_child(capsule)
	
	# Capture mouse
	if mouse_captured:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _input(event: InputEvent) -> void:
	if not mouse_captured:
		return
	
	# Mouse look
	if event is InputEventMouseMotion:
		var mouse_delta = event.relative
		rotate_y(-mouse_delta.x * mouse_sensitivity)
		camera_pivot.rotate_x(-mouse_delta.y * mouse_sensitivity)
		# Clamp camera pitch
		camera_pivot.rotation.x = clamp(camera_pivot.rotation.x, -PI/2, PI/2)

func _physics_process(delta: float) -> void:
	# Add gravity
	if not is_on_floor():
		velocity.y -= ProjectSettings.get_setting("physics/3d/default_gravity") * delta
	
	# Handle jump
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity
	
	# Get input direction (WASD)
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	
	# Calculate movement direction relative to player rotation
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	# Apply movement
	if direction:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)
	
	move_and_slide()

func _unhandled_input(event: InputEvent) -> void:
	# Toggle mouse capture with Escape
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if mouse_captured:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			mouse_captured = false
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			mouse_captured = true
