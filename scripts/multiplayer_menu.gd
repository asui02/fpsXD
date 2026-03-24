extends Control

@onready var host_button: Button = $VBoxContainer/HostButton
@onready var join_button: Button = $VBoxContainer/JoinButton
@onready var status_label: Label = $VBoxContainer/StatusLabel
@onready var lobby_list: VBoxContainer = $VBoxContainer/LobbyList

var network_manager: NetworkManager
var http: HTTPRequest

const API_URL := "https://game.vibe-family.org"

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	host_button.pressed.connect(_on_host_pressed)
	join_button.pressed.connect(_on_join_pressed)
	
	network_manager = get_node_or_null("/root/Main/NetworkManager")
	
	if network_manager:
		network_manager.connection_succeeded.connect(_on_connection_succeeded)
		network_manager.connection_failed.connect(_on_connection_failed)
	
	# HTTP
	http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_request_completed)

# ------------------------
# HOST
# ------------------------
func _on_host_pressed() -> void:
	status_label.text = "Hosting..."
	host_button.disabled = true
	join_button.disabled = true
	
	network_manager.host_game()
	_register_lobby()
	_start_heartbeat()

func _register_lobby() -> void:
	var ip = _get_local_ip()
	
	var data = {
		"name": "VIBE Server",
		"ip": ip,
		"port": 7777,
		"max_players": 8,
		"game_version": "1.0",
		"map_name": "default"
	}
	
	var json = JSON.stringify(data)
	
	http.request(
		API_URL + "/create_lobby",
		["Content-Type: application/json"],
		HTTPClient.METHOD_POST,
		json
	)
	
var heartbeat_timer: Timer

func _start_heartbeat():
	heartbeat_timer = Timer.new()
	heartbeat_timer.wait_time = 5.0
	heartbeat_timer.autostart = true
	heartbeat_timer.timeout.connect(_send_heartbeat)
	add_child(heartbeat_timer)

func _send_heartbeat():
	var ip = _get_local_ip()
	
	http.request(
		API_URL + "/heartbeat?ip=%s" % ip,
		[],
		HTTPClient.METHOD_POST
	)
# ------------------------
# JOIN → список лобби
# ------------------------
func _on_join_pressed() -> void:
	status_label.text = "Loading lobbies..."
	lobby_list.visible = true
	
	http.request(API_URL + "/lobbies")

func update_players(count: int):
	var ip = _get_local_ip()
	
	var data = {
		"ip": ip,
		"players": count
	}
	
	var json = JSON.stringify(data)
	
	http.request(
		API_URL + "/lobby/%s" % ip,
		["Content-Type: application/json"],
		HTTPClient.METHOD_PUT,
		json
	)
# ------------------------
# HTTP RESPONSE
# ------------------------
func _on_request_completed(result, response_code, headers, body):
	if response_code != 200:
		status_label.text = "HTTP Error: %d" % response_code
		return
	
	var text = body.get_string_from_utf8()
	var data = JSON.parse_string(text)
	
	if data.has("lobbies"):
		_show_lobbies(data["lobbies"])
	else:
		print("Server response:", data)

# ------------------------
# SHOW LOBBIES
# ------------------------
func _show_lobbies(lobbies: Array) -> void:
	# очистка
	for child in lobby_list.get_children():
		child.queue_free()
	
	if lobbies.is_empty():
		status_label.text = "No lobbies found"
		return
	
	for lobby in lobbies:
		var button = Button.new()
		
		var name = lobby.get("name", "Server")
		var ip = lobby.get("ip", "unknown")
		var port = lobby.get("port", 7777)
		var players = lobby.get("players", 1)
		var max_players = lobby.get("max", 8)
		
		button.text = "%s (%d/%d)" % [name, players, max_players]
		
		button.pressed.connect(func():
			status_label.text = "Connecting to %s..." % ip
			network_manager.join_game(ip)
		)
		
		lobby_list.add_child(button)

# ------------------------
# NETWORK SIGNALS
# ------------------------
func _on_connection_succeeded() -> void:
	status_label.text = "Connected!"
	_hide_menu()

func _on_connection_failed() -> void:
	status_label.text = "Connection failed!"
	host_button.disabled = false
	join_button.disabled = false

# ------------------------
# UI
# ------------------------
func _hide_menu() -> void:
	visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		visible = not visible
		
		if visible:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

# ------------------------
# UTIL
# ------------------------
func _get_local_ip() -> String:
	for ip in IP.get_local_addresses():
		if ip.begins_with("192.") or ip.begins_with("10."):
			return ip
	return "127.0.0.1"
