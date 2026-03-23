extends Node
class_name NetworkManager

signal connection_succeeded
signal connection_failed
signal player_connected(id: int)
signal player_disconnected(id: int)

const PLAYER_SCENE := preload("res://scenes/multiplayer_player.tscn")

var server_port: int = 7777
var max_players: int = 8
var players: Dictionary = {}

func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)

func host_game() -> Error:
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(server_port, max_players)
	
	if error == OK:
		multiplayer.multiplayer_peer = peer
		print("Server started on port %d" % server_port)
		
		# Create local player
		_create_player(true)
		
	return error

func join_game(address: String, port: int = 7777) -> Error:
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_client(address, port)
	
	if error == OK:
		multiplayer.multiplayer_peer = peer
		print("Connecting to %s:%d..." % [address, port])
		
	return error

func _create_player(is_local: bool) -> CharacterBody3D:
	var player = PLAYER_SCENE.instantiate()
	player.is_local_player = is_local
	
	if is_local:
		player.name = "LocalPlayer"
		player.set_multiplayer_id(multiplayer.get_unique_id())
	else:
		player.name = "Player_%d" % multiplayer.get_remote_sender_id()
	
	add_child(player)
	players[multiplayer.get_unique_id()] = player
	
	if is_local:
		# Notify other players about this player
		for peer_id in players:
			if peer_id != multiplayer.get_unique_id():
				player.rpc("set_multiplayer_id", multiplayer.get_unique_id())
	
	return player

func _on_peer_connected(id: int) -> void:
	print("Player %d connected" % id)
	player_connected.emit(id)
	
	# Spawn player for the new peer (on server)
	if multiplayer.is_server():
		var player = _create_player(false)
		player.set_multiplayer_id(id)
		player.name = "Player_%d" % id

func _on_peer_disconnected(id: int) -> void:
	print("Player %d disconnected" % id)
	player_disconnected.emit(id)
	
	# Remove player
	if players.has(id):
		players[id].queue_free()
		players.erase(id)

func _on_connected_to_server() -> void:
	print("Connected to server!")
	connection_succeeded.emit()
	
	# Create local player for client
	_create_player(true)

func _on_connection_failed() -> void:
	print("Connection failed!")
	connection_failed.emit()

func stop_network() -> void:
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	
	# Remove all players
	for player in players.values():
		player.queue_free()
	players.clear()
