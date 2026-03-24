extends Control

@onready var host_button: Button = $VBoxContainer/HostButton
@onready var join_button: Button = $VBoxContainer/JoinButton
@onready var status_label: Label = $VBoxContainer/StatusLabel
@onready var lobby_list: VBoxContainer = $VBoxContainer/LobbyList

var network_manager: NetworkManager
var connection_manager: ConnectionManager
var http: HTTPRequest

const API_URL := "https://game.vibe-family.org"

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	host_button.pressed.connect(_on_host_pressed)
	join_button.pressed.connect(_on_join_pressed)
	
	network_manager = get_node_or_null("/root/Main/NetworkManager")
	connection_manager = get_node_or_null("/root/Main/ConnectionManager")
	
	if connection_manager == null:
		print("ConnectionManager not found, creating...")
		
		var script = load("res://scripts/connection_manager.gd")
		connection_manager = script.new()
		connection_manager.name = "ConnectionManager"
		
		get_node("/root/Main").add_child(connection_manager)
	
	# 🔥 ВАЖНО: подключаем ТОЛЬКО после создания
	connection_manager.connected.connect(_on_connected)
	connection_manager.failed.connect(_on_failed)
	connection_manager.state_changed.connect(_on_state_changed)
	
	http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_request_completed)

# ------------------------
# HOST
# ------------------------
func _on_host_pressed():
	status_label.text = "Starting host..."
	host_button.disabled = true
	join_button.disabled = true
	
	network_manager.host_game()
	
	_register_lobby()

func _register_lobby():
	var data = {
		"name": "VIBE Server",
		"port": 7777,
		"max_players": 8,
		"game_version": "1.0",
		"map_name": "default"
	}
	
	http.request(
		API_URL + "/create_lobby",
		["Content-Type: application/json"],
		HTTPClient.METHOD_POST,
		JSON.stringify(data)
	)

# ------------------------
# JOIN
# ------------------------
func _on_join_pressed():
	status_label.text = "Loading lobbies..."
	lobby_list.visible = true
	
	http.request(API_URL + "/lobbies")

# ------------------------
# SHOW LOBBIES
# ------------------------
func _show_lobbies(lobbies: Array):
	for c in lobby_list.get_children():
		c.queue_free()
	
	if lobbies.is_empty():
		status_label.text = "No lobbies"
		return
	
	for lobby in lobbies:
		var btn = Button.new()
		
		var name = lobby.get("name", "Server")
		var players = lobby.get("players", 1)
		var max_players = lobby.get("max", 8)
		
		btn.text = "%s (%d/%d)" % [name, players, max_players]
		
		btn.pressed.connect(func():
			status_label.text = "Connecting..."
			connection_manager.connect_to_lobby(lobby)
		)
		
		lobby_list.add_child(btn)

# ------------------------
# HTTP
# ------------------------
func _on_request_completed(result, code, headers, body):
	if code != 200:
		status_label.text = "HTTP Error"
		return
	
	var data = JSON.parse_string(body.get_string_from_utf8())
	
	if data.has("lobbies"):
		_show_lobbies(data["lobbies"])

# ------------------------
# CONNECTION UI
# ------------------------
func _on_state_changed(state):
	match state:
		ConnectionManager.State.REQUESTING:
			status_label.text = "Requesting connection..."
		ConnectionManager.State.PUNCH_REGISTER:
			status_label.text = "Registering network..."
		ConnectionManager.State.PUNCHING:
			status_label.text = "Opening connection..."
		ConnectionManager.State.CONNECTING:
			status_label.text = "Connecting to host..."
		ConnectionManager.State.RELAY:
			status_label.text = "Using relay..."
		ConnectionManager.State.CONNECTED:
			status_label.text = "Connected!"
		ConnectionManager.State.FAILED:
			status_label.text = "Connection failed"

func _on_connected():
	_hide_menu()

func _on_failed(reason):
	status_label.text = "Failed: " + reason
	host_button.disabled = false
	join_button.disabled = false

# ------------------------
# UI
# ------------------------
func _hide_menu():
	visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _input(event):
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		visible = not visible
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if visible else Input.MOUSE_MODE_CAPTURED
