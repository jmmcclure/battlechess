extends Node3D
## Main game controller. Wires together the chess engine, board, battle system, and UI.

var engine: ChessEngine
var ai: AIPlayer
var notation: ChessNotation
var current_move_data: Dictionary = {}

var ai_thread: Thread = null

@onready var chess_board: ChessBoard = $ChessBoard
@onready var battle_manager: BattleManager = $BattleManager
@onready var game_camera: Camera3D = $GameCamera
@onready var environment_light: DirectionalLight3D = $DirectionalLight3D
@onready var hud: Control = $UI/HUD

var ai_thinking: bool = false


func _ready() -> void:
	engine = ChessEngine.new()
	ai = AIPlayer.new()
	notation = ChessNotation.new()

	engine.setup_starting_position()
	chess_board.initialize(engine)

	# Connect signals
	chess_board.move_requested.connect(_on_move_requested)
	battle_manager.battle_complete.connect(_on_battle_complete)
	EventBus.game_started.connect(_on_game_started)

	# Start game based on mode
	_setup_camera()
	_setup_lighting()
	_setup_environment()

	# Pre-instantiate pause menu (it handles its own ESC toggle)
	var pause_scene := load("res://scenes/ui/pause_menu.tscn")
	if pause_scene:
		var pause_menu: Control = pause_scene.instantiate()
		$UI.add_child(pause_menu)


func _setup_camera() -> void:
	# More eye-level angle — looking across the board
	game_camera.position = Vector3(0, 10, 16)
	game_camera.rotation_degrees = Vector3(-30, 0, 0)
	game_camera.fov = 45.0


func _setup_lighting() -> void:
	environment_light.rotation_degrees = Vector3(-40, -25, 0)
	environment_light.light_energy = 0.5
	environment_light.shadow_enabled = true
	environment_light.light_color = Color(1.0, 0.95, 0.9)

	# Ambient lighting via WorldEnvironment
	var env := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.02, 0.02, 0.04)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.12, 0.1, 0.08)
	environment.ambient_light_energy = 0.5
	environment.tonemap_mode = 3  # ACES
	environment.glow_enabled = true
	environment.glow_intensity = 0.4
	environment.glow_bloom = 0.3
	environment.ssao_enabled = true
	environment.ssao_radius = 2.0
	environment.ssao_intensity = 1.5
	environment.ssr_enabled = true
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.06, 0.04, 0.03)
	environment.fog_density = 0.005
	env.environment = environment
	env.name = "WorldEnvironment"
	add_child(env)


func _setup_environment() -> void:
	# === Castle floor ===
	var floor_mesh := MeshInstance3D.new()
	var floor_plane := PlaneMesh.new()
	floor_plane.size = Vector2(60, 60)
	floor_mesh.mesh = floor_plane
	floor_mesh.position.y = -0.15
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.1, 0.08, 0.06)
	floor_mat.roughness = 0.9
	floor_mesh.material_override = floor_mat
	floor_mesh.name = "CastleFloor"
	add_child(floor_mesh)

	# === Castle walls — push further back, no mortar slabs ===
	var wall_height: float = 14.0
	var wall_thickness: float = 1.0
	var wall_dist: float = 24.0

	_add_wall(Vector3(0, wall_height / 2.0, -wall_dist),
		Vector3(wall_dist * 2.5, wall_height, wall_thickness), "BackWall")
	_add_wall(Vector3(-wall_dist, wall_height / 2.0, 0),
		Vector3(wall_thickness, wall_height, wall_dist * 2.5), "LeftWall")
	_add_wall(Vector3(wall_dist, wall_height / 2.0, 0),
		Vector3(wall_thickness, wall_height, wall_dist * 2.5), "RightWall")

	# === Flaming wall torches ===
	var torch_positions := [
		Vector3(-10, 6, -wall_dist + 1.5),
		Vector3(0, 6, -wall_dist + 1.5),
		Vector3(10, 6, -wall_dist + 1.5),
		Vector3(-wall_dist + 1.5, 6, -8),
		Vector3(-wall_dist + 1.5, 6, 8),
		Vector3(wall_dist - 1.5, 6, -8),
		Vector3(wall_dist - 1.5, 6, 8),
	]
	for i in range(torch_positions.size()):
		_add_torch(torch_positions[i], i)

	# === Corner pillars ===
	for cx in [-1, 1]:
		for cz in [-1, 1]:
			var pillar := MeshInstance3D.new()
			var pillar_cyl := CylinderMesh.new()
			pillar_cyl.top_radius = 0.7
			pillar_cyl.bottom_radius = 0.9
			pillar_cyl.height = wall_height
			pillar.mesh = pillar_cyl
			pillar.position = Vector3(cx * wall_dist, wall_height / 2.0, cz * wall_dist)
			var pmat := StandardMaterial3D.new()
			pmat.albedo_color = Color(0.14, 0.12, 0.1)
			pmat.roughness = 0.85
			pillar.material_override = pmat
			pillar.name = "Pillar_%d_%d" % [cx, cz]
			add_child(pillar)

	# === Dark ceiling ===
	var ceiling := MeshInstance3D.new()
	var ceil_plane := PlaneMesh.new()
	ceil_plane.size = Vector2(60, 60)
	ceiling.mesh = ceil_plane
	ceiling.position.y = wall_height
	ceiling.rotation_degrees.x = 180
	var ceil_mat := StandardMaterial3D.new()
	ceil_mat.albedo_color = Color(0.03, 0.02, 0.02)
	ceil_mat.roughness = 1.0
	ceiling.material_override = ceil_mat
	ceiling.name = "Ceiling"
	add_child(ceiling)

	# === Subtle fill light ===
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-15, 180, 0)
	fill.light_energy = 0.1
	fill.light_color = Color(0.5, 0.6, 0.8)
	fill.name = "MoonFill"
	add_child(fill)


func _add_wall(pos: Vector3, size: Vector3, wall_name: String) -> void:
	var wall := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	wall.mesh = box
	wall.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.13, 0.11, 0.09)
	mat.roughness = 0.92
	wall.material_override = mat
	wall.name = wall_name
	add_child(wall)


func _add_torch(pos: Vector3, idx: int) -> void:
	# Wooden handle
	var handle := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.06
	cyl.bottom_radius = 0.08
	cyl.height = 1.0
	handle.mesh = cyl
	handle.position = pos
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.22, 0.13, 0.05)
	wood.roughness = 0.85
	handle.material_override = wood
	handle.name = "TorchHandle_%d" % idx
	add_child(handle)

	# Fire particles
	var fire := GPUParticles3D.new()
	fire.position = pos + Vector3(0, 0.6, 0)
	fire.amount = 25
	fire.lifetime = 0.6
	fire.emitting = true
	fire.name = "TorchFire_%d" % idx
	var fmat := ParticleProcessMaterial.new()
	fmat.direction = Vector3(0, 1, 0)
	fmat.spread = 12.0
	fmat.initial_velocity_min = 0.3
	fmat.initial_velocity_max = 1.0
	fmat.gravity = Vector3(0, 1.5, 0)
	fmat.scale_min = 0.06
	fmat.scale_max = 0.15
	fmat.color = Color(1.0, 0.6, 0.1)
	fire.process_material = fmat
	var sphere := SphereMesh.new()
	sphere.radius = 0.06
	sphere.height = 0.12
	fire.draw_pass_1 = sphere
	var emat := StandardMaterial3D.new()
	emat.albedo_color = Color(1.0, 0.5, 0.05)
	emat.emission_enabled = true
	emat.emission = Color(1.0, 0.4, 0.05)
	emat.emission_energy_multiplier = 3.0
	emat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fire.material_override = emat
	add_child(fire)

	# Warm light
	var light := OmniLight3D.new()
	light.position = pos + Vector3(0, 0.8, 0)
	light.light_color = Color(1.0, 0.55, 0.15)
	light.light_energy = 3.0
	light.omni_range = 18.0
	light.omni_attenuation = 1.3
	light.shadow_enabled = false  # Too many shadow casters kills perf
	light.name = "TorchLight_%d" % idx
	add_child(light)


func _on_game_started(_mode: String) -> void:
	engine.setup_starting_position()
	notation.clear()
	chess_board.initialize(engine)


func _on_move_requested(from: Vector2i, to: Vector2i) -> void:
	var from_sq := from.y * 8 + from.x
	var to_sq := to.y * 8 + to.x

	# Find the matching legal move
	var legal_moves: Array = engine.get_legal_moves()
	var move_data: Dictionary = {}
	for move in legal_moves:
		if move["from_sq"] == from_sq and move["to_sq"] == to_sq:
			move_data = move
			break

	if move_data.is_empty():
		return

	var flags: int = move_data.get("flags", 0)

	# Check for promotion
	if flags & 240:  # 16|32|64|128 — any promotion flag
		if GameManager.is_ai_turn(engine.side_to_move):
			# AI auto-selects queen
			_execute_move_with_promotion(from, to, move_data, ChessEngine.PieceType.QUEEN)
		else:
			_show_promotion_dialog(from, to, move_data)
		return

	_execute_confirmed_move(from, to, move_data)


func _show_promotion_dialog(from: Vector2i, to: Vector2i, move_data: Dictionary) -> void:
	var dialog_scene := load("res://scenes/ui/promotion_dialog.tscn")
	if not dialog_scene:
		# Fallback: auto-queen if scene missing
		_execute_move_with_promotion(from, to, move_data, ChessEngine.PieceType.QUEEN)
		return
	var dialog: Control = dialog_scene.instantiate()
	$UI.add_child(dialog)
	chess_board.is_interactive = false
	dialog.show_dialog()

	var choice: int = await dialog.promotion_selected
	dialog.queue_free()

	_execute_move_with_promotion(from, to, move_data, choice)


func _execute_move_with_promotion(from: Vector2i, to: Vector2i, move_data: Dictionary, piece_type: int) -> void:
	# Find the legal move matching the chosen promotion type
	var flag_map := {
		ChessEngine.PieceType.QUEEN: ChessEngine.MoveFlag.PROMOTE_QUEEN,
		ChessEngine.PieceType.ROOK: ChessEngine.MoveFlag.PROMOTE_ROOK,
		ChessEngine.PieceType.BISHOP: ChessEngine.MoveFlag.PROMOTE_BISHOP,
		ChessEngine.PieceType.KNIGHT: ChessEngine.MoveFlag.PROMOTE_KNIGHT,
	}
	var desired_flag: int = flag_map.get(piece_type, ChessEngine.MoveFlag.PROMOTE_QUEEN)

	var from_sq := from.y * 8 + from.x
	var to_sq := to.y * 8 + to.x
	var legal_moves: Array = engine.get_legal_moves()
	for move in legal_moves:
		if move["from_sq"] == from_sq and move["to_sq"] == to_sq and (move["flags"] & desired_flag):
			_execute_confirmed_move(from, to, move)
			return

	# Fallback: use the original move_data
	_execute_confirmed_move(from, to, move_data)


func _execute_confirmed_move(from: Vector2i, to: Vector2i, move_data: Dictionary) -> void:
	# Record notation before making the move
	var san := notation.add_move(move_data, engine)
	EventBus.move_added_to_history.emit(san)

	# Make the move in the engine
	engine.make_move(move_data)

	# Execute on the board (handles animation + battle)
	chess_board.execute_move(from, to, move_data)
	current_move_data = move_data

	# Check game state after move
	_check_game_state()


func _on_battle_complete(attacker: ChessPiece, defender: ChessPiece) -> void:
	chess_board.finish_capture_move(attacker, defender)

	# Add captured piece to UI
	EventBus.captured_piece_added.emit(defender.piece_type, defender.piece_color)

	# After battle, check if it's AI's turn
	_check_ai_turn()


func _check_game_state() -> void:
	if engine.is_checkmate():
		var loser: int = engine.side_to_move
		var winner: int = 1 - loser
		EventBus.checkmate_declared.emit(loser)
		GameManager.end_game("checkmate", winner)
		_show_game_over_screen()
		return

	if engine.is_stalemate():
		EventBus.stalemate_declared.emit()
		GameManager.end_game("stalemate", -1)
		_show_game_over_screen()
		return

	if engine.is_draw():
		var reason := "threefold repetition" if engine.is_threefold_repetition() else "50-move rule or insufficient material"
		EventBus.draw_declared.emit(reason)
		GameManager.end_game("draw", -1)
		_show_game_over_screen()
		return

	if engine.is_in_check(engine.side_to_move):
		EventBus.check_declared.emit(engine.side_to_move)

	EventBus.turn_changed.emit(engine.side_to_move)

	# Check if AI should move
	_check_ai_turn()


func _check_ai_turn() -> void:
	if ai_thinking:
		return
	if not GameManager.is_playing():
		return
	if GameManager.is_ai_turn(engine.side_to_move):
		_do_ai_move()


func _do_ai_move() -> void:
	ai_thinking = true
	chess_board.is_interactive = false

	# Run AI in a thread to keep UI responsive
	ai_thread = Thread.new()
	ai_thread.start(_ai_think)


func _ai_think() -> void:
	var best_move: Dictionary = ai.get_best_move(engine, GameManager.ai_difficulty)

	# Call back to main thread
	call_deferred("_ai_move_ready", best_move)


func _ai_move_ready(move: Dictionary) -> void:
	# Clean up the AI thread
	if ai_thread:
		ai_thread.wait_to_finish()
		ai_thread = null

	ai_thinking = false
	if move.is_empty():
		return

	var from := Vector2i(move["from_sq"] % 8, move["from_sq"] / 8)
	var to := Vector2i(move["to_sq"] % 8, move["to_sq"] / 8)

	# Small delay so the player sees the board state
	await get_tree().create_timer(0.5).timeout

	_on_move_requested(from, to)


func _show_game_over_screen() -> void:
	var scene := load("res://scenes/ui/game_over_screen.tscn")
	if scene:
		var screen: Control = scene.instantiate()
		$UI.add_child(screen)
