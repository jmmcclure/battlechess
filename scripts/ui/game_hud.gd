extends Control
## In-game HUD: move history, captured pieces, turn indicator, game state.

@onready var turn_label: Label = $MarginContainer/VBoxContainer/TurnLabel
@onready var move_list: RichTextLabel = $MarginContainer/VBoxContainer/MoveList
@onready var white_captures: HBoxContainer = $MarginContainer/VBoxContainer/WhiteCaptures
@onready var black_captures: HBoxContainer = $MarginContainer/VBoxContainer/BlackCaptures
@onready var status_label: Label = $MarginContainer/VBoxContainer/StatusLabel
@onready var skip_button: Button = $SkipButton

var move_count: int = 0
var piece_symbols := {1: "♟", 2: "♜", 3: "♞", 4: "♝", 5: "♛", 6: "♚"}


func _ready() -> void:
	EventBus.turn_changed.connect(_on_turn_changed)
	EventBus.move_added_to_history.connect(_on_move_added)
	EventBus.captured_piece_added.connect(_on_piece_captured)
	EventBus.check_declared.connect(_on_check)
	EventBus.checkmate_declared.connect(_on_checkmate)
	EventBus.stalemate_declared.connect(_on_stalemate)
	EventBus.draw_declared.connect(_on_draw)
	EventBus.battle_started.connect(_on_battle_started)
	EventBus.battle_finished.connect(_on_battle_finished)

	skip_button.visible = false
	skip_button.pressed.connect(func(): EventBus.battle_skipped.emit())

	status_label.text = ""
	_update_turn_display(0)


func _on_turn_changed(color: int) -> void:
	_update_turn_display(color)
	status_label.text = ""


func _update_turn_display(color: int) -> void:
	var color_name := "White" if color == 0 else "Black"
	turn_label.text = "%s to move" % color_name
	turn_label.add_theme_color_override("font_color",
		Color(0.9, 0.85, 0.8) if color == 0 else Color(0.6, 0.5, 0.4))


func _on_move_added(san: String) -> void:
	move_count += 1
	if move_count % 2 == 1:
		move_list.append_text("%d. %s " % [ceili(move_count / 2.0), san])
	else:
		move_list.append_text("%s\n" % san)
	# Auto-scroll to bottom
	move_list.scroll_to_line(move_list.get_line_count() - 1)


func _on_piece_captured(piece_type: int, color: int) -> void:
	var symbol: String = piece_symbols.get(piece_type, "?")
	var label := Label.new()
	label.text = symbol
	label.add_theme_font_size_override("font_size", 24)

	if color == 0:  # White piece was captured (show in black's captures)
		label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.8))
		black_captures.add_child(label)
	else:  # Black piece was captured
		label.add_theme_color_override("font_color", Color(0.4, 0.35, 0.3))
		white_captures.add_child(label)


func _on_check(color: int) -> void:
	var name := "White" if color == 0 else "Black"
	status_label.text = "⚔ %s is in CHECK!" % name
	status_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3))


func _on_checkmate(loser_color: int) -> void:
	var winner := "White" if loser_color == 1 else "Black"
	status_label.text = "💀 CHECKMATE! %s wins!" % winner
	status_label.add_theme_color_override("font_color", Color(1, 0.8, 0.2))


func _on_stalemate() -> void:
	status_label.text = "⚖ STALEMATE — Draw!"
	status_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))


func _on_draw(reason: String) -> void:
	status_label.text = "⚖ DRAW — %s" % reason
	status_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))


func _on_battle_started(_attacker: Node3D, _defender: Node3D) -> void:
	skip_button.visible = GameManager.battle_skip_enabled


func _on_battle_finished() -> void:
	skip_button.visible = false
