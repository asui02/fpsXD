extends Control

@onready var host_button: Button = $VBoxContainer/HostButton
@onready var join_button: Button = $VBoxContainer/JoinButton
@onready var address_edit: LineEdit = $VBoxContainer/AddressEdit
@onready var status_label: Label = $VBoxContainer/StatusLabel

var network_manager: NetworkManager

func _ready() -> void:
	host_button.pressed.connect(_on_host_pressed)
	join_button.pressed.connect(_on_join_pressed)
	
	# Find network manager
	network_manager = get_node_or_null("/root/Main/NetworkManager")
	
	if network_manager:
		network_manager.connection_succeeded.connect(_on_connection_succeeded)
		network_manager.connection_failed.connect(_on_connection_failed)

func _on_host_pressed() -> void:
	if network_manager:
		status_label.text = "Hosting..."
		var error = network_manager.host_game()
		if error == OK:
			status_label.text = "Server running!"
			_hide_menu()
		else:
			status_label.text = "Failed to host (error %d)" % error

func _on_join_pressed() -> void:
	if network_manager:
		var address = address_edit.text.strip_edges()
		if address.is_empty():
			address = "localhost"
		
		status_label.text = "Connecting to %s..." % address
		var error = network_manager.join_game(address)
		if error != OK:
			status_label.text = "Failed to connect (error %d)" % error

func _on_connection_succeeded() -> void:
	status_label.text = "Connected!"
	_hide_menu()

func _on_connection_failed() -> void:
	status_label.text = "Connection failed!"

func _hide_menu() -> void:
	# Hide menu after connection
	set_process(false)
	visible = false

func _input(event: InputEvent) -> void:
	# Show menu with Escape if hidden
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if not visible:
			visible = true
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			set_process(true)
