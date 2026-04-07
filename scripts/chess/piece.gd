class_name ChessPiece
extends Node3D
## Visual representation of a chess piece on the 3D board.

signal animation_finished

@export var piece_type: int = 0  # ChessEngine.PieceType
@export var piece_color: int = 0  # ChessEngine.PieceColor
@export var board_position: Vector2i = Vector2i.ZERO

var is_selected: bool = false
var is_alive: bool = true
var has_moved: bool = false

@onready var model: Node3D = $Model if has_node("Model") else null
@onready var animation_player: AnimationPlayer = $AnimationPlayer if has_node("AnimationPlayer") else null
@onready var selection_highlight: Node3D = $SelectionHighlight if has_node("SelectionHighlight") else null

const SQUARE_SIZE: float = 2.0
const MOVE_SPEED: float = 4.0
const MOVE_HEIGHT: float = 0.5


func _ready() -> void:
	if selection_highlight:
		selection_highlight.visible = false


func setup(type: int, color: int, pos: Vector2i) -> void:
	piece_type = type
	piece_color = color
	board_position = pos
	position = board_to_world(pos)
	if color == 1:  # Black
		rotation.y = PI


func select() -> void:
	is_selected = true
	if selection_highlight:
		selection_highlight.visible = true
	# Subtle hover animation
	var tween := create_tween()
	tween.tween_property(self, "position:y", 0.3, 0.2).set_ease(Tween.EASE_OUT)


func deselect() -> void:
	is_selected = false
	if selection_highlight:
		selection_highlight.visible = false
	var tween := create_tween()
	tween.tween_property(self, "position:y", 0.0, 0.2).set_ease(Tween.EASE_OUT)


func move_to(target_pos: Vector2i) -> void:
	board_position = target_pos
	has_moved = true
	var target_world := board_to_world(target_pos)
	var distance := position.distance_to(target_world)
	var duration := distance / MOVE_SPEED

	var tween := create_tween()
	tween.set_parallel(true)
	# Lift up
	tween.tween_property(self, "position:y", MOVE_HEIGHT, duration * 0.3).set_ease(Tween.EASE_OUT)
	# Move horizontally
	tween.tween_property(self, "position:x", target_world.x, duration).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "position:z", target_world.z, duration).set_ease(Tween.EASE_IN_OUT)
	tween.set_parallel(false)
	# Set down
	tween.tween_property(self, "position:y", 0.0, duration * 0.3).set_ease(Tween.EASE_IN)
	tween.tween_callback(_on_move_finished)

	# Rotate to face movement direction
	var direction := (target_world - position).normalized()
	if direction.length() > 0.01:
		var target_rot := atan2(direction.x, direction.z)
		tween.parallel().tween_property(self, "rotation:y", target_rot, duration * 0.3)

	if animation_player and animation_player.has_animation("walk"):
		animation_player.play("walk")


func play_idle() -> void:
	if animation_player and animation_player.has_animation("idle"):
		animation_player.play("idle")


func play_attack() -> void:
	if animation_player and animation_player.has_animation("attack"):
		animation_player.play("attack")
		await animation_player.animation_finished
		animation_finished.emit()


func play_death() -> void:
	is_alive = false
	if animation_player and animation_player.has_animation("death"):
		animation_player.play("death")
		await animation_player.animation_finished
	# Fall over if no death animation
	else:
		var tween := create_tween()
		tween.tween_property(self, "rotation:x", PI / 2.0, 0.5)
		tween.parallel().tween_property(self, "position:y", -0.5, 0.5)
		await tween.finished
	animation_finished.emit()


func die_immediately() -> void:
	is_alive = false
	visible = false


func board_to_world(pos: Vector2i) -> Vector3:
	return Vector3(
		(pos.x - 3.5) * SQUARE_SIZE,
		0.0,
		(pos.y - 3.5) * SQUARE_SIZE
	)


func get_piece_name() -> String:
	var names := ["None", "Pawn", "Rook", "Knight", "Bishop", "Queen", "King"]
	var colors := ["White", "Black"]
	if piece_type > 0 and piece_type < names.size():
		return colors[piece_color] + " " + names[piece_type]
	return "Unknown"


func _on_move_finished() -> void:
	if animation_player and animation_player.has_animation("idle"):
		animation_player.play("idle")
	animation_finished.emit()
