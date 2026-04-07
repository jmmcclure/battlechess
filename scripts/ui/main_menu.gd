extends Control
## Main menu with dark medieval aesthetic.

@onready var title_label: Label = $VBoxContainer/TitleLabel
@onready var vs_ai_button: Button = $VBoxContainer/VsAIButton
@onready var local_mp_button: Button = $VBoxContainer/LocalMPButton
@onready var online_mp_button: Button = $VBoxContainer/OnlineMPButton
@onready var settings_button: Button = $VBoxContainer/SettingsButton
@onready var quit_button: Button = $VBoxContainer/QuitButton


func _ready() -> void:
	_setup_theme()
	vs_ai_button.pressed.connect(_on_vs_ai)
	local_mp_button.pressed.connect(_on_local_mp)
	online_mp_button.pressed.connect(_on_online_mp)
	settings_button.pressed.connect(_on_settings)
	quit_button.pressed.connect(_on_quit)


func _setup_theme() -> void:
	# Dark medieval theme
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.03, 0.05)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.z_index = -1
	bg.name = "Background"
	add_child(bg)
	move_child(bg, 0)


func _on_vs_ai() -> void:
	GameManager.start_game(GameManager.GameMode.VS_AI)
	_go_to_game()


func _on_local_mp() -> void:
	GameManager.start_game(GameManager.GameMode.LOCAL_MP)
	_go_to_game()


func _on_online_mp() -> void:
	GameManager.start_game(GameManager.GameMode.ONLINE_MP)
	# TODO: Show lobby screen first
	_go_to_game()


func _on_settings() -> void:
	var settings_scene: PackedScene = load("res://scenes/ui/settings_panel.tscn")
	var settings: Control = settings_scene.instantiate()
	add_child(settings)
	settings.settings_closed.connect(func(): settings.queue_free())


func _on_quit() -> void:
	get_tree().quit()


func _go_to_game() -> void:
	get_tree().change_scene_to_file("res://scenes/game_board.tscn")
