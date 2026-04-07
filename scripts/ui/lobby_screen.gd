extends Control
## Online multiplayer lobby screen. Create or join a game room.

signal game_started(color: int)

@onready var title_label: Label = $VBoxContainer/TitleLabel
@onready var create_button: Button = $VBoxContainer/CreateButton
@onready var join_container: HBoxContainer = $VBoxContainer/JoinContainer
@onready var code_input: LineEdit = $VBoxContainer/JoinContainer/CodeInput
@onready var join_button: Button = $VBoxContainer/JoinContainer/JoinButton
@onready var status_label: Label = $VBoxContainer/StatusLabel
@onready var lobby_code_label: Label = $VBoxContainer/LobbyCodeLabel
@onready var waiting_label: Label = $VBoxContainer/WaitingLabel
@onready var back_button: Button = $VBoxContainer/BackButton
@onready var server_input: LineEdit = $VBoxContainer/ServerContainer/ServerInput

var network: Node = null


func _ready() -> void:
	_setup_theme()
	create_button.pressed.connect(_on_create)
	join_button.pressed.connect(_on_join)
	back_button.pressed.connect(_on_back)
	lobby_code_label.visible = false
	waiting_label.visible = false

	# Try to find or create NetworkManager
	if has_node("/root/NetworkManager"):
		network = get_node("/root/NetworkManager")
	else:
		network = load("res://scripts/network/network_manager.gd").new()
		network.name = "NetworkManager"
		get_tree().root.add_child(network)

	network.lobby_created.connect(_on_lobby_created)
	network.lobby_joined.connect(_on_lobby_joined)
	network.opponent_connected.connect(_on_opponent_connected)
	network.error_occurred.connect(_on_error)


func _setup_theme() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.03, 0.05)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.z_index = -1
	bg.name = "Background"
	add_child(bg)
	move_child(bg, 0)


func _on_create() -> void:
	var url := server_input.text.strip_edges()
	if url.is_empty():
		url = "ws://localhost:8080"
	status_label.text = "Connecting..."
	network.connect_to_server(url)
	# Small delay for connection
	await get_tree().create_timer(0.5).timeout
	network.create_lobby(GameManager.player_white_name)


func _on_join() -> void:
	var code := code_input.text.strip_edges().to_upper()
	if code.length() < 4:
		status_label.text = "Enter a valid lobby code"
		return
	var url := server_input.text.strip_edges()
	if url.is_empty():
		url = "ws://localhost:8080"
	status_label.text = "Joining lobby %s..." % code
	network.connect_to_server(url)
	await get_tree().create_timer(0.5).timeout
	network.join_lobby(code, GameManager.player_black_name)


func _on_lobby_created(code: String) -> void:
	lobby_code_label.text = "LOBBY CODE: %s" % code
	lobby_code_label.visible = true
	waiting_label.text = "Waiting for opponent..."
	waiting_label.visible = true
	status_label.text = "Lobby created!"
	create_button.disabled = true
	join_button.disabled = true


func _on_lobby_joined(code: String) -> void:
	lobby_code_label.text = "JOINED: %s" % code
	lobby_code_label.visible = true
	status_label.text = "Joined lobby!"


func _on_opponent_connected(opp_name: String) -> void:
	status_label.text = "Opponent connected: %s" % opp_name
	waiting_label.text = "Starting game..."
	# Start the game after a brief delay
	await get_tree().create_timer(1.0).timeout
	GameManager.start_game(GameManager.GameMode.ONLINE_MP)
	get_tree().change_scene_to_file("res://scenes/game_board.tscn")


func _on_error(msg: String) -> void:
	status_label.text = "Error: %s" % msg
	status_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3))


func _on_back() -> void:
	if network:
		network.disconnect_from_server()
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
