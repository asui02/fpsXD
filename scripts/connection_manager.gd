extends Node
class_name ConnectionManager

signal state_changed(state)
signal connected
signal failed(reason)

enum State {
	IDLE,
	REQUESTING,
	PUNCH_REGISTER,
	PUNCHING,
	CONNECTING,
	RELAY,
	CONNECTED,
	FAILED
}

var state: State = State.IDLE

var network_manager: NetworkManager
var http: HTTPRequest

var current_ticket: Dictionary = {}

# UDP punch
var udp := PacketPeerUDP.new()
var punch_ip := ""
var punch_port := 0

# retry
var retries := 0
const MAX_RETRIES := 2

func _ready():
	network_manager = get_node("/root/Main/NetworkManager")
	
	http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_http_completed)
	
	network_manager.connection_succeeded.connect(_on_connected)
	network_manager.connection_failed.connect(_on_failed)

# ------------------------
# PUBLIC API
# ------------------------
func connect_to_lobby(lobby: Dictionary):
	_set_state(State.REQUESTING)
	
	var data = {
		"lobby_id": lobby.get("id", "")
	}
	
	http.request(
		"https://game.vibe-family.org/connect",
		["Content-Type: application/json"],
		HTTPClient.METHOD_POST,
		JSON.stringify(data)
	)

# ------------------------
# HTTP
# ------------------------
func _on_http_completed(result, code, headers, body):
	if code != 200:
		_fail("HTTP error %d" % code)
		return
	
	var data = JSON.parse_string(body.get_string_from_utf8())
	current_ticket = data
	
	_register_punch()

# ------------------------
# PUNCH REGISTER
# ------------------------
func _register_punch():
	_set_state(State.PUNCH_REGISTER)
	
	udp = PacketPeerUDP.new()
	udp.bind(0)
	
	var punch = current_ticket.get("punch", {})
	punch_ip = punch.get("ip", "")
	punch_port = punch.get("port", 0)
	
	if punch_ip == "":
		_try_direct()
		return
	
	udp.set_dest_address(punch_ip, punch_port)
	
	var msg = "REGISTER %s" % multiplayer.get_unique_id()
	udp.put_packet(msg.to_utf8_buffer())
	
	await get_tree().create_timer(0.5).timeout
	
	_request_punch()

# ------------------------
# REQUEST PUNCH
# ------------------------
func _request_punch():
	_set_state(State.PUNCHING)
	
	var host_id = current_ticket.get("host", {}).get("id", 1)
	
	var msg = "PUNCH_REQUEST %s %s" % [multiplayer.get_unique_id(), host_id]
	udp.put_packet(msg.to_utf8_buffer())

# ------------------------
# PROCESS UDP
# ------------------------
func _process(delta):
	if udp and udp.get_available_packet_count() > 0:
		var packet = udp.get_packet().get_string_from_utf8()
		_handle_punch(packet)

# ------------------------
# HANDLE PUNCH
# ------------------------
func _handle_punch(packet: String):
	var parts = packet.split(" ")
	
	match parts[0]:
		"PUNCH_INFO":
			punch_ip = parts[1]
			punch_port = int(parts[2])
			_start_hole_punch()

# ------------------------
# HOLE PUNCH
# ------------------------
func _start_hole_punch():
	print("Punching %s:%d" % [punch_ip, punch_port])
	
	for i in range(25):
		udp.set_dest_address(punch_ip, punch_port)
		udp.put_packet("PING".to_utf8_buffer())
		await get_tree().create_timer(0.03).timeout
	
	_try_direct()

# ------------------------
# DIRECT CONNECT
# ------------------------
func _try_direct():
	_set_state(State.CONNECTING)
	
	var host = current_ticket.get("host", {})
	
	var err = network_manager.join_game(
		host.get("ip", ""),
		host.get("port", 7777)
	)
	
	if err != OK:
		_try_relay()
		return

# ------------------------
# RELAY
# ------------------------
func _try_relay():
	_set_state(State.RELAY)
	
	var relay = current_ticket.get("relay", {})
	
	var err = network_manager.join_game(
		relay.get("ip", ""),
		relay.get("port", 7777)
	)
	
	if err != OK:
		_fail("Relay failed")

# ------------------------
# NETWORK CALLBACKS
# ------------------------
func _on_connected():
	_set_state(State.CONNECTED)
	connected.emit()

func _on_failed():
	if retries < MAX_RETRIES:
		retries += 1
		print("Retrying... ", retries)
		_try_direct()
	else:
		_try_relay()

# ------------------------
# UTILS
# ------------------------
func _fail(reason: String):
	_set_state(State.FAILED)
	failed.emit(reason)

func _set_state(s):
	state = s
	state_changed.emit(state)
