extends Control
## Full-screen game-over overlay shown after checkmate, stalemate, or draw.

@onready var result_label: Label = $Overlay/Panel/VBoxContainer/ResultLabel
@onready var icon_label: Label = $Overlay/Panel/VBoxContainer/IconLabel
@onready var rematch_button: Button = $Overlay/Panel/VBoxContainer/ButtonRow/RematchButton
@onready var menu_button: Button = $Overlay/Panel/VBoxContainer/ButtonRow/MenuButton

var _last_mode: GameManager.GameMode


func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS

	EventBus.game_ended.connect(_on_game_ended)
	rematch_button.pressed.connect(_on_rematch)
	menu_button.pressed.connect(_on_main_menu)


func _on_game_ended(result: String, winner: int) -> void:
	_last_mode = GameManager.current_mode

	match result:
		"checkmate":
			var winner_name := "White" if winner == 0 else "Black"
			result_label.text = "CHECKMATE — %s Wins!" % winner_name
			icon_label.text = "♚"
		"stalemate":
			result_label.text = "STALEMATE — Draw!"
			icon_label.text = "½"
		"draw":
			result_label.text = "DRAW"
			icon_label.text = "="
		_:
			result_label.text = result.to_upper()
			icon_label.text = "⚔"

	visible = true
	get_tree().paused = true


func _on_rematch() -> void:
	visible = false
	get_tree().paused = false
	GameManager.start_game(_last_mode)
	get_tree().change_scene_to_file("res://scenes/game_board.tscn")


func _on_main_menu() -> void:
	visible = false
	get_tree().paused = false
	GameManager.current_state = GameManager.GameState.MENU
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
