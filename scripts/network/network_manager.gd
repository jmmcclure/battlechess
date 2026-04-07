class_name NetworkManager
extends Node
## Handles online multiplayer via WebSocket connection.
## Supports lobby creation/joining, move synchronization, and game state sync.

signal connected_to_server
signal disconnected_from_server
signal lobby_created(code: String)
signal lobby_joined(code: String)
signal opponent_connected(name: String)
signal opponent_disconnected()
signal move_received(from_sq: int, to_sq: int, flags: int)
signal chat_received(message: String)
signal error_occurred(message: String)

enum ConnectionState { DISCONNECTED, CONNECTING, CONNECTED, IN_LOBBY, IN_GAME }

var state: ConnectionState = ConnectionState.DISCONNECTED
var socket: WebSocketPeer = WebSocketPeer.new()
var lobby_code: String = ""
var player_color: int = -1  # 0=white, 1=black
var opponent_name: String = ""
var server_url: String = "wss://your-server.com/ws"  # Configure per deployment

var _poll_timer: float = 0.0
const POLL_INTERVAL: float = 0.05


func _process(delta: float) -> void:
	if state == ConnectionState.DISCONNECTED:
		return

	socket.poll()
	var sock_state := socket.get_ready_state()

	match sock_state:
		WebSocketPeer.STATE_OPEN:
			while socket.get_available_packet_count() > 0:
				var packet := socket.get_packet()
				_handle_message(packet.get_string_from_utf8())
		WebSocketPeer.STATE_CLOSING:
			pass
		WebSocketPeer.STATE_CLOSED:
			var code := socket.get_close_code()
			var reason := socket.get_close_reason()
			print("WebSocket closed: %d %s" % [code, reason])
			state = ConnectionState.DISCONNECTED
			disconnected_from_server.emit()


func connect_to_server(url: String = "") -> void:
	if url.length() > 0:
		server_url = url
	state = ConnectionState.CONNECTING
	var err := socket.connect_to_url(server_url)
	if err != OK:
		state = ConnectionState.DISCONNECTED
		error_occurred.emit("Failed to connect: %d" % err)
		return
	state = ConnectionState.CONNECTED
	connected_to_server.emit()


func create_lobby(player_name: String = "Player") -> void:
	_send({
		"type": "create_lobby",
		"player_name": player_name
	})


func join_lobby(code: String, player_name: String = "Player") -> void:
	_send({
		"type": "join_lobby",
		"code": code,
		"player_name": player_name
	})


func send_move(from_sq: int, to_sq: int, flags: int = 0) -> void:
	_send({
		"type": "move",
		"from": from_sq,
		"to": to_sq,
		"flags": flags
	})


func send_resign() -> void:
	_send({"type": "resign"})


func send_draw_offer() -> void:
	_send({"type": "draw_offer"})


func send_rematch_request() -> void:
	_send({"type": "rematch"})


func disconnect_from_server() -> void:
	if state != ConnectionState.DISCONNECTED:
		socket.close()
		state = ConnectionState.DISCONNECTED


func _send(data: Dictionary) -> void:
	if socket.get_ready_state() != WebSocketPeer.STATE_OPEN:
		error_occurred.emit("Not connected to server")
		return
	socket.send_text(JSON.stringify(data))


func _handle_message(text: String) -> void:
	var json := JSON.new()
	var err := json.parse(text)
	if err != OK:
		print("Failed to parse server message: %s" % text)
		return

	var data: Dictionary = json.data
	var msg_type: String = data.get("type", "")

	match msg_type:
		"lobby_created":
			lobby_code = data["code"]
			player_color = data.get("color", 0)
			state = ConnectionState.IN_LOBBY
			lobby_created.emit(lobby_code)
			EventBus.lobby_created.emit(lobby_code)

		"lobby_joined":
			lobby_code = data["code"]
			player_color = data.get("color", 1)
			state = ConnectionState.IN_LOBBY
			lobby_joined.emit(lobby_code)
			EventBus.lobby_joined.emit(lobby_code)

		"opponent_connected":
			opponent_name = data.get("name", "Opponent")
			state = ConnectionState.IN_GAME
			opponent_connected.emit(opponent_name)
			EventBus.player_connected.emit(0)

		"opponent_disconnected":
			opponent_disconnected.emit()
			EventBus.player_disconnected.emit(0)

		"move":
			var from: int = data["from"]
			var to: int = data["to"]
			var flags: int = data.get("flags", 0)
			move_received.emit(from, to, flags)
			EventBus.remote_move_received.emit(
				Vector2i(from % 8, from / 8),
				Vector2i(to % 8, to / 8),
				flags
			)

		"error":
			error_occurred.emit(data.get("message", "Unknown error"))

		"chat":
			chat_received.emit(data.get("message", ""))
