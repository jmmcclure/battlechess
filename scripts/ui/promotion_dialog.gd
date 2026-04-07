extends Control
## Promotion dialog — shows piece choices when a pawn reaches the final rank.

signal promotion_selected(piece_type: int)

const QUEEN := 5
const ROOK := 2
const BISHOP := 4
const KNIGHT := 3

@onready var queen_button: Button = $Panel/VBoxContainer/ButtonRow/QueenButton
@onready var rook_button: Button = $Panel/VBoxContainer/ButtonRow/RookButton
@onready var bishop_button: Button = $Panel/VBoxContainer/ButtonRow/BishopButton
@onready var knight_button: Button = $Panel/VBoxContainer/ButtonRow/KnightButton


func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS

	queen_button.pressed.connect(_on_piece_selected.bind(QUEEN))
	rook_button.pressed.connect(_on_piece_selected.bind(ROOK))
	bishop_button.pressed.connect(_on_piece_selected.bind(BISHOP))
	knight_button.pressed.connect(_on_piece_selected.bind(KNIGHT))


func show_dialog() -> void:
	visible = true
	get_tree().paused = true


func _on_piece_selected(piece_type: int) -> void:
	visible = false
	get_tree().paused = false
	promotion_selected.emit(piece_type)
