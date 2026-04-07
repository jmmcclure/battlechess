class_name ChessBoard
extends Node3D
## Manages the 3D chess board: piece placement, selection, move highlighting, and interaction.

signal piece_selected(piece: ChessPiece)
signal piece_deselected()
signal move_requested(from: Vector2i, to: Vector2i)

const SQUARE_SIZE: float = 2.0
const BOARD_SIZE: int = 8
const HIGHLIGHT_COLOR_MOVE := Color(0.2, 0.6, 0.2, 0.5)
const HIGHLIGHT_COLOR_CAPTURE := Color(0.8, 0.1, 0.1, 0.5)
const HIGHLIGHT_COLOR_SELECTED := Color(0.9, 0.8, 0.2, 0.6)
const HIGHLIGHT_COLOR_CHECK := Color(1.0, 0.0, 0.0, 0.7)

var engine: RefCounted  # ChessEngine
var pieces: Dictionary = {}  # Vector2i -> ChessPiece
var selected_piece: ChessPiece = null
var legal_moves: Array = []
var highlight_meshes: Array[MeshInstance3D] = []
var is_interactive: bool = true

# Piece scenes - loaded dynamically
var piece_scenes: Dictionary = {}

var camera: Camera3D
@onready var board_mesh: Node3D = $BoardMesh


func _ready() -> void:
	_create_board_mesh()
	EventBus.battle_finished.connect(_on_battle_finished)


func _unhandled_input(event: InputEvent) -> void:
	if not is_interactive:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# Get camera fresh each click in case it changed
		camera = get_viewport().get_camera_3d()
		if camera:
			_handle_click(event.position)


func initialize(chess_engine: RefCounted) -> void:
	engine = chess_engine
	_spawn_all_pieces()


func _handle_click(screen_pos: Vector2) -> void:
	var from := camera.project_ray_origin(screen_pos)
	var dir := camera.project_ray_normal(screen_pos)

	# Intersect with board plane (y=0)
	if abs(dir.y) < 0.001:
		return
	var t := -from.y / dir.y
	if t < 0:
		return
	var world_pos := from + dir * t
	var board_pos := world_to_board(world_pos)

	if board_pos.x < 0 or board_pos.x > 7 or board_pos.y < 0 or board_pos.y > 7:
		_deselect()
		return

	if selected_piece:
		# Check if clicking a valid move
		var is_legal := false
		for move in legal_moves:
			if move["to_sq"] == board_pos.y * 8 + board_pos.x:
				is_legal = true
				break
		if is_legal:
			move_requested.emit(selected_piece.board_position, board_pos)
			_deselect()
		elif pieces.has(board_pos) and pieces[board_pos].piece_color == selected_piece.piece_color:
			_deselect()
			_select_piece(board_pos)
		else:
			_deselect()
	else:
		if pieces.has(board_pos):
			var piece: ChessPiece = pieces[board_pos]
			# Only select own pieces
			if piece.piece_color == engine.side_to_move:
				_select_piece(board_pos)


func _select_piece(pos: Vector2i) -> void:
	if not pieces.has(pos):
		return
	selected_piece = pieces[pos]
	selected_piece.select()
	piece_selected.emit(selected_piece)

	# Get legal moves for this piece
	var sq := pos.y * 8 + pos.x
	legal_moves = []
	var all_moves: Array = engine.get_legal_moves()
	for move in all_moves:
		if move["from_sq"] == sq:
			legal_moves.append(move)

	_highlight_moves()
	_highlight_square(pos, HIGHLIGHT_COLOR_SELECTED)


func _deselect() -> void:
	if selected_piece:
		selected_piece.deselect()
		selected_piece = null
		legal_moves.clear()
		_clear_highlights()
		piece_deselected.emit()


func execute_move(from: Vector2i, to: Vector2i, move_data: Dictionary) -> void:
	is_interactive = false
	var moving_piece: ChessPiece = pieces[from]

	# Handle capture
	var captured_piece: ChessPiece = null
	if move_data.get("piece_captured", 0) > 0:
		var capture_pos := to
		# En passant: captured pawn is not on target square
		if move_data.get("flags", 0) & 2:  # EN_PASSANT
			var ep_rank := to.y + (1 if moving_piece.piece_color == 0 else -1)
			capture_pos = Vector2i(to.x, ep_rank)
		if pieces.has(capture_pos):
			captured_piece = pieces[capture_pos]

	if captured_piece:
		# Trigger battle animation
		EventBus.battle_started.emit(moving_piece, captured_piece)
		pieces.erase(captured_piece.board_position)
	else:
		# No capture, just move
		pieces.erase(from)
		moving_piece.move_to(to)
		await moving_piece.animation_finished
		pieces[to] = moving_piece
		is_interactive = true

	# Handle castling rook movement
	var flags: int = move_data.get("flags", 0)
	if flags & 4:  # CASTLE_KINGSIDE
		var rook_from := Vector2i(7, from.y)
		var rook_to := Vector2i(5, from.y)
		if pieces.has(rook_from):
			var rook: ChessPiece = pieces[rook_from]
			pieces.erase(rook_from)
			rook.move_to(rook_to)
			pieces[rook_to] = rook
	elif flags & 8:  # CASTLE_QUEENSIDE
		var rook_from := Vector2i(0, from.y)
		var rook_to := Vector2i(3, from.y)
		if pieces.has(rook_from):
			var rook: ChessPiece = pieces[rook_from]
			pieces.erase(rook_from)
			rook.move_to(rook_to)
			pieces[rook_to] = rook

	# Handle promotion
	if flags & (16 | 32 | 64 | 128):
		var promo_type := 5  # Queen by default
		if flags & 32:
			promo_type = 2  # Rook
		elif flags & 64:
			promo_type = 4  # Bishop
		elif flags & 128:
			promo_type = 3  # Knight
		_promote_piece(moving_piece, promo_type)


func finish_capture_move(attacker: ChessPiece, defender: ChessPiece) -> void:
	## Called after battle animation completes.
	defender.die_immediately()
	defender.queue_free()
	var to := defender.board_position if not (pieces.has(defender.board_position) and pieces[defender.board_position] == defender) else defender.board_position
	pieces.erase(attacker.board_position)
	attacker.move_to(defender.board_position)
	await attacker.animation_finished
	pieces[defender.board_position] = attacker
	is_interactive = true


func _promote_piece(piece: ChessPiece, new_type: int) -> void:
	piece.piece_type = new_type
	# Swap the 3D model to match the new piece type
	var old_model := piece.get_node_or_null("Model")
	if old_model:
		old_model.queue_free()
	# Try to load 3D model for the promoted type
	var type_names := ["", "pawn", "rook", "knight", "bishop", "queen", "king"]
	var model_path := "res://assets/models/pieces/%s.glb" % type_names[new_type]
	if ResourceLoader.exists(model_path):
		var model_scene: PackedScene = load(model_path)
		var model_instance: Node3D = model_scene.instantiate()
		model_instance.name = "Model"
		piece.add_child(model_instance)
		_apply_color_material(model_instance, piece.piece_color)
	else:
		_create_placeholder_mesh(piece, new_type, piece.piece_color)
	EventBus.piece_promoted.emit(piece, new_type)


func _spawn_all_pieces() -> void:
	for rank in range(BOARD_SIZE):
		for file in range(BOARD_SIZE):
			var sq := rank * 8 + file
			var piece_val: int = engine.board[sq]
			if piece_val == 0:
				continue
			var piece_type: int = piece_val & 7
			var piece_color: int = (piece_val >> 3) & 1
			var pos := Vector2i(file, rank)
			_spawn_piece(piece_type, piece_color, pos)


func _spawn_piece(type: int, color: int, pos: Vector2i) -> void:
	var piece := ChessPiece.new()
	piece.name = _piece_name(type, color, pos)
	add_child(piece)
	piece.setup(type, color, pos)

	# Try to load 3D model
	var type_names := ["", "pawn", "rook", "knight", "bishop", "queen", "king"]
	var model_path := "res://assets/models/pieces/%s.glb" % type_names[type]
	if ResourceLoader.exists(model_path):
		var model_scene: PackedScene = load(model_path)
		var model_instance: Node3D = model_scene.instantiate()
		model_instance.name = "Model"
		# Scale models down and lift above board — AI-generated models vary in size
		model_instance.scale = Vector3(0.5, 0.5, 0.5)
		model_instance.position.y = 0.0
		piece.add_child(model_instance)
		# Adjust Y position based on model bounds
		_adjust_model_height(model_instance)
		# Apply color tint
		_apply_color_material(model_instance, color)
	else:
		# Placeholder: colored box
		_create_placeholder_mesh(piece, type, color)

	pieces[pos] = piece


func _create_placeholder_mesh(piece: ChessPiece, type: int, color: int) -> void:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "Model"

	var heights := [0.0, 0.6, 1.2, 0.9, 1.0, 1.4, 1.5]
	var widths := [0.0, 0.3, 0.45, 0.35, 0.35, 0.4, 0.45]
	var height: float = heights[type]
	var width: float = widths[type]

	var box := BoxMesh.new()
	box.size = Vector3(width, height, width)
	mesh_instance.mesh = box
	mesh_instance.position.y = height / 2.0

	var mat := StandardMaterial3D.new()
	if color == 0:
		mat.albedo_color = Color(0.85, 0.82, 0.78)
	else:
		mat.albedo_color = Color(0.15, 0.12, 0.1)
	mat.metallic = 0.3
	mat.roughness = 0.6
	mesh_instance.material_override = mat

	piece.add_child(mesh_instance)


func _apply_color_material(model: Node3D, color: int) -> void:
	var tint: Color
	if color == 0:
		tint = Color(0.85, 0.82, 0.78)  # Bright silver/steel for white
	else:
		tint = Color(0.1, 0.08, 0.06)  # Dark obsidian for black

	_tint_recursive(model, tint, color)


func _tint_recursive(node: Node, tint: Color, color: int) -> void:
	if node is MeshInstance3D:
		var mesh_node: MeshInstance3D = node
		# Create a new material with the tint color
		var mat := StandardMaterial3D.new()
		mat.albedo_color = tint
		mat.metallic = 0.4 if color == 0 else 0.2
		mat.roughness = 0.5 if color == 0 else 0.7
		mesh_node.material_override = mat
	for child in node.get_children():
		_tint_recursive(child, tint, color)


func _create_board_mesh() -> void:
	for rank in range(BOARD_SIZE):
		for file in range(BOARD_SIZE):
			var square := MeshInstance3D.new()
			var plane := PlaneMesh.new()
			plane.size = Vector2(SQUARE_SIZE, SQUARE_SIZE)
			square.mesh = plane

			var mat := StandardMaterial3D.new()
			if (rank + file) % 2 == 0:
				mat.albedo_color = Color(0.15, 0.12, 0.1)  # Dark squares
			else:
				mat.albedo_color = Color(0.35, 0.3, 0.28)  # Light squares
			mat.metallic = 0.1
			mat.roughness = 0.8
			square.material_override = mat

			square.position = Vector3(
				(file - 3.5) * SQUARE_SIZE,
				0.0,
				(rank - 3.5) * SQUARE_SIZE
			)
			square.name = "Square_%d_%d" % [file, rank]
			add_child(square)

	# Board border — thin rim below the squares
	var border := MeshInstance3D.new()
	var border_mesh := BoxMesh.new()
	border_mesh.size = Vector3(SQUARE_SIZE * 8 + 0.8, 0.05, SQUARE_SIZE * 8 + 0.8)
	border.mesh = border_mesh
	border.position.y = -0.025
	var border_mat := StandardMaterial3D.new()
	border_mat.albedo_color = Color(0.15, 0.12, 0.08)
	border_mat.metallic = 0.3
	border_mat.roughness = 0.6
	border.material_override = border_mat
	border.name = "BoardBorder"
	add_child(border)
	# Board labels removed — they render as black lines on the board surface


func _highlight_moves() -> void:
	for move in legal_moves:
		var to_sq: int = move["to_sq"]
		var pos := Vector2i(to_sq % 8, to_sq / 8)
		var color := HIGHLIGHT_COLOR_CAPTURE if move.get("piece_captured", 0) > 0 else HIGHLIGHT_COLOR_MOVE
		_highlight_square(pos, color)


func _highlight_square(pos: Vector2i, color: Color) -> void:
	var highlight := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(SQUARE_SIZE * 0.9, SQUARE_SIZE * 0.9)
	highlight.mesh = plane

	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.no_depth_test = true
	highlight.material_override = mat

	highlight.position = Vector3(
		(pos.x - 3.5) * SQUARE_SIZE,
		0.02,
		(pos.y - 3.5) * SQUARE_SIZE
	)
	highlight.name = "Highlight_%d_%d" % [pos.x, pos.y]
	add_child(highlight)
	highlight_meshes.append(highlight)


func _clear_highlights() -> void:
	for mesh in highlight_meshes:
		if is_instance_valid(mesh):
			mesh.queue_free()
	highlight_meshes.clear()


func world_to_board(world_pos: Vector3) -> Vector2i:
	var file := int(round(world_pos.x / SQUARE_SIZE + 3.5))
	var rank := int(round(world_pos.z / SQUARE_SIZE + 3.5))
	return Vector2i(clampi(file, 0, 7), clampi(rank, 0, 7))


func _piece_name(type: int, color: int, pos: Vector2i) -> String:
	var type_names := ["", "Pawn", "Rook", "Knight", "Bishop", "Queen", "King"]
	var color_names := ["White", "Black"]
	return "%s%s_%d%d" % [color_names[color], type_names[type], pos.x, pos.y]


func _on_battle_finished() -> void:
	is_interactive = true


func _adjust_model_height(model: Node3D) -> void:
	# Find the lowest point of the model and shift up so it sits on the board
	var min_y: float = 0.0
	for child in model.get_children():
		if child is MeshInstance3D:
			var aabb: AABB = child.get_aabb()
			var child_min_y: float = (aabb.position.y * model.scale.y)
			if child_min_y < min_y:
				min_y = child_min_y
	model.position.y = -min_y


func _create_board_labels() -> void:
	var file_letters := ["a", "b", "c", "d", "e", "f", "g", "h"]
	var label_offset := SQUARE_SIZE * 4 + 0.6

	for i in range(BOARD_SIZE):
		# File labels (a-h) along bottom and top edges
		for side in [-1, 1]:
			var file_label := Label3D.new()
			file_label.text = file_letters[i]
			file_label.font_size = 48
			file_label.pixel_size = 0.01
			file_label.modulate = Color(0.6, 0.55, 0.5)
			file_label.position = Vector3(
				(i - 3.5) * SQUARE_SIZE,
				0.01,
				side * label_offset
			)
			file_label.rotation_degrees = Vector3(-90, 0, 0)
			file_label.name = "FileLabel_%s_%d" % [file_letters[i], side]
			add_child(file_label)

		# Rank labels (1-8) along left and right edges
		for side in [-1, 1]:
			var rank_label := Label3D.new()
			rank_label.text = str(i + 1)
			rank_label.font_size = 48
			rank_label.pixel_size = 0.01
			rank_label.modulate = Color(0.6, 0.55, 0.5)
			rank_label.position = Vector3(
				side * label_offset,
				0.01,
				(i - 3.5) * SQUARE_SIZE
			)
			rank_label.rotation_degrees = Vector3(-90, 0, 0)
			rank_label.name = "RankLabel_%d_%d" % [i + 1, side]
			add_child(rank_label)
