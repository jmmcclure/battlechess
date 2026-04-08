class_name BattleManager
extends Node3D
## Orchestrates battle animations when a piece captures another.
## Manages camera choreography, gore VFX, and per-matchup battle sequences.

signal battle_complete(attacker: ChessPiece, defender: ChessPiece)

enum BattleState { IDLE, ENTERING, FIGHTING, FINISHING, EXITING }

var current_state: BattleState = BattleState.IDLE
var current_attacker: ChessPiece = null
var current_defender: ChessPiece = null
var battle_camera: Camera3D = null
var main_camera: Camera3D = null
var skip_requested: bool = false

@onready var gore_vfx: Node3D = $GoreVFX if has_node("GoreVFX") else null
@onready var battle_light: DirectionalLight3D = $BattleLight if has_node("BattleLight") else null

const BATTLE_CAMERA_DISTANCE: float = 4.0
const BATTLE_CAMERA_HEIGHT: float = 2.5
const CAMERA_TRANSITION_TIME: float = 1.0


func _ready() -> void:
	EventBus.battle_started.connect(start_battle)
	EventBus.battle_skipped.connect(_on_skip_requested)
	_setup_battle_camera()


func _unhandled_input(event: InputEvent) -> void:
	if current_state != BattleState.IDLE:
		if event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
			if GameManager.battle_skip_enabled:
				_on_skip_requested()
		if event is InputEventMouseButton and event.pressed:
			# Consume clicks during battle
			get_viewport().set_input_as_handled()


func _setup_battle_camera() -> void:
	battle_camera = Camera3D.new()
	battle_camera.name = "BattleCamera"
	battle_camera.current = false
	battle_camera.fov = 45.0
	add_child(battle_camera)


func start_battle(attacker: ChessPiece, defender: ChessPiece) -> void:
	if current_state != BattleState.IDLE:
		return

	current_attacker = attacker
	current_defender = defender
	skip_requested = false
	GameManager.enter_battle()

	current_state = BattleState.ENTERING
	await _transition_to_battle_view()

	if skip_requested:
		_finish_battle_immediately()
		return

	current_state = BattleState.FIGHTING
	await _play_battle_sequence()

	if skip_requested:
		_finish_battle_immediately()
		return

	current_state = BattleState.FINISHING
	await _play_death_sequence()

	current_state = BattleState.EXITING
	await _transition_to_board_view()

	_cleanup_battle()


func _transition_to_battle_view() -> void:
	if not is_instance_valid(current_attacker) or not is_instance_valid(current_defender):
		return
	if not current_attacker.is_inside_tree() or not current_defender.is_inside_tree():
		return

	# Find the midpoint between attacker and defender
	var atk_pos := current_attacker.position
	var def_pos := current_defender.position
	var mid_point := (atk_pos + def_pos) / 2.0
	var direction := (atk_pos - def_pos).normalized()
	var perpendicular := Vector3(-direction.z, 0, direction.x).normalized()

	# Position battle camera to the side
	battle_camera.global_position = mid_point + perpendicular * BATTLE_CAMERA_DISTANCE + Vector3.UP * BATTLE_CAMERA_HEIGHT
	battle_camera.look_at(mid_point + Vector3.UP * 0.5)

	# Store main camera ref
	main_camera = get_viewport().get_camera_3d()

	# Smooth transition
	var tween := create_tween()
	tween.tween_property(battle_camera, "global_position",
		battle_camera.global_position, CAMERA_TRANSITION_TIME).from(main_camera.global_position)
	battle_camera.current = true
	await tween.finished

	# Dramatic lighting
	if battle_light:
		battle_light.visible = true
		var light_tween := create_tween()
		light_tween.tween_property(battle_light, "light_energy", 1.5, 0.3).from(0.0)


func _transition_to_board_view() -> void:
	if main_camera:
		var tween := create_tween()
		tween.tween_property(battle_camera, "global_position",
			main_camera.global_position, CAMERA_TRANSITION_TIME * 0.7)
		await tween.finished
		main_camera.current = true
	battle_camera.current = false


func _play_battle_sequence() -> void:
	var attacker_type: int = current_attacker.piece_type
	var defender_type: int = current_defender.piece_type
	var sequence_key := "%d_%d" % [attacker_type, defender_type]

	# Face each other
	_face_opponent(current_attacker, current_defender)
	_face_opponent(current_defender, current_attacker)
	AudioManager.play_sfx_by_name("battle_grunt")
	await get_tree().create_timer(0.3).timeout

	# Play type-specific SFX
	match attacker_type:
		2: AudioManager.play_sfx_by_name("stone_step")      # Rook
		3: AudioManager.play_sfx_by_name("sword_draw")       # Knight
		4: AudioManager.play_sfx_by_name("magic_cast")       # Bishop
		_: AudioManager.play_sfx_by_name("sword_draw")       # Pawn/Queen/King

	# Play attack sequence based on matchup
	match sequence_key:
		"1_1": await _battle_pawn_vs_pawn()
		"1_2": await _battle_pawn_vs_rook()
		"1_3": await _battle_pawn_vs_knight()
		"1_4": await _battle_pawn_vs_bishop()
		"1_5": await _battle_pawn_vs_queen()
		"1_6": await _battle_pawn_vs_king()
		"2_1": await _battle_rook_vs_pawn()
		"2_2": await _battle_rook_vs_rook()
		"2_3": await _battle_rook_vs_knight()
		"2_4": await _battle_rook_vs_bishop()
		"2_5": await _battle_rook_vs_queen()
		"2_6": await _battle_rook_vs_king()
		"3_1": await _battle_knight_vs_pawn()
		"3_2": await _battle_knight_vs_rook()
		"3_3": await _battle_knight_vs_knight()
		"3_4": await _battle_knight_vs_bishop()
		"3_5": await _battle_knight_vs_queen()
		"3_6": await _battle_knight_vs_king()
		"4_1": await _battle_bishop_vs_pawn()
		"4_2": await _battle_bishop_vs_rook()
		"4_3": await _battle_bishop_vs_knight()
		"4_4": await _battle_bishop_vs_bishop()
		"4_5": await _battle_bishop_vs_queen()
		"4_6": await _battle_bishop_vs_king()
		"5_1": await _battle_queen_vs_pawn()
		"5_2": await _battle_queen_vs_rook()
		"5_3": await _battle_queen_vs_knight()
		"5_4": await _battle_queen_vs_bishop()
		"5_5": await _battle_queen_vs_queen()
		"5_6": await _battle_queen_vs_king()
		"6_1": await _battle_king_vs_pawn()
		"6_2": await _battle_king_vs_rook()
		"6_3": await _battle_king_vs_knight()
		"6_4": await _battle_king_vs_bishop()
		"6_5": await _battle_king_vs_queen()
		"6_6": await _battle_king_vs_king()
		_: await _battle_generic()


func _play_death_sequence() -> void:
	if not is_instance_valid(current_defender) or not current_defender.is_inside_tree():
		return
	AudioManager.play_sfx_by_name("sword_clash")
	current_defender.play_death()
	_spawn_blood_effect(current_defender.position)
	AudioManager.play_sfx_by_name("death_scream")
	await get_tree().create_timer(0.5 / GameManager.animation_speed).timeout
	AudioManager.play_sfx_by_name("blood_splatter")
	await get_tree().create_timer(1.0 / GameManager.animation_speed).timeout


func _finish_battle_immediately() -> void:
	current_defender.die_immediately()
	if main_camera:
		main_camera.current = true
	battle_camera.current = false
	_cleanup_battle()


func _cleanup_battle() -> void:
	current_state = BattleState.IDLE
	if battle_light:
		battle_light.visible = false
	GameManager.exit_battle()
	battle_complete.emit(current_attacker, current_defender)
	current_attacker = null
	current_defender = null


func _on_skip_requested() -> void:
	skip_requested = true


func _face_opponent(piece: ChessPiece, target: ChessPiece) -> void:
	if not is_instance_valid(piece) or not is_instance_valid(target):
		return
	if not piece.is_inside_tree() or not target.is_inside_tree():
		return
	var direction := (target.position - piece.position).normalized()
	var angle := atan2(direction.x, direction.z)
	var tween := create_tween()
	tween.tween_property(piece, "rotation:y", angle, 0.2)


func _spawn_blood_effect(pos: Vector3) -> void:
	if not GameManager.gore_enabled:
		return
	# Create particle burst
	var particles := GPUParticles3D.new()
	particles.name = "BloodBurst"
	particles.one_shot = true
	particles.amount = 50
	particles.lifetime = 1.5
	particles.position = pos + Vector3.UP * 0.5

	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 60.0
	mat.initial_velocity_min = 2.0
	mat.initial_velocity_max = 5.0
	mat.gravity = Vector3(0, -9.8, 0)
	mat.color = Color(0.5, 0.0, 0.0)
	mat.scale_min = 0.05
	mat.scale_max = 0.15
	particles.process_material = mat

	var sphere := SphereMesh.new()
	sphere.radius = 0.05
	sphere.height = 0.1
	particles.draw_pass_1 = sphere

	add_child(particles)
	particles.emitting = true
	# Auto-cleanup
	get_tree().create_timer(3.0).timeout.connect(particles.queue_free)

	# Blood decal on ground
	_spawn_blood_decal(Vector3(pos.x, 0.01, pos.z))


func _spawn_blood_decal(pos: Vector3) -> void:
	if not GameManager.gore_enabled:
		return
	var decal := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(1.5, 1.5)
	decal.mesh = plane
	decal.position = pos

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 0.0, 0.0, 0.8)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	decal.material_override = mat
	decal.name = "BloodDecal"
	add_child(decal)


# ============================================================
# BATTLE SEQUENCES - 36 unique matchups
# Each method choreographs a unique fight animation.
# Timing is scaled by GameManager.animation_speed.
# ============================================================

func _t(seconds: float) -> float:
	return seconds / GameManager.animation_speed


func _battle_step(attacker: ChessPiece, offset: Vector3, duration: float) -> void:
	## Move attacker by offset over duration, used for choreography steps.
	var tween := create_tween()
	tween.tween_property(attacker, "position", attacker.position + offset, _t(duration))
	await tween.finished


# --- Pawn attacks ---

func _battle_pawn_vs_pawn() -> void:
	# Sword duel: two strikes exchanged, attacker wins with disembowel
	await _battle_step(current_attacker, Vector3(0, 0, -0.5), 0.3)
	current_attacker.play_attack()
	await get_tree().create_timer(_t(0.5)).timeout
	await _battle_step(current_attacker, Vector3(0, 0, -0.3), 0.2)
	_spawn_blood_effect(current_defender.position)


func _battle_pawn_vs_rook() -> void:
	# David vs Goliath: dodge and stab through eye
	await _battle_step(current_attacker, Vector3(0.5, 0, -0.5), 0.4)
	await _battle_step(current_attacker, Vector3(-0.5, 0.8, -0.3), 0.3)
	_spawn_blood_effect(current_defender.position + Vector3.UP * 1.5)
	await get_tree().create_timer(_t(0.5)).timeout


func _battle_pawn_vs_knight() -> void:
	# Roll under horse, slash rider off
	await _battle_step(current_attacker, Vector3(0, -0.3, -0.8), 0.4)
	await _battle_step(current_attacker, Vector3(0, 0.3, 0), 0.2)
	current_attacker.play_attack()
	_spawn_blood_effect(current_defender.position + Vector3.UP)
	await get_tree().create_timer(_t(0.5)).timeout


func _battle_pawn_vs_bishop() -> void:
	# Charge through magic, decapitate
	await _battle_step(current_attacker, Vector3(0, 0, -1.0), 0.5)
	current_attacker.play_attack()
	_spawn_blood_effect(current_defender.position + Vector3.UP * 1.2)
	await get_tree().create_timer(_t(0.6)).timeout


func _battle_pawn_vs_queen() -> void:
	# Desperate lunge, impale through chest
	await get_tree().create_timer(_t(0.5)).timeout
	await _battle_step(current_attacker, Vector3(0, 0, -1.2), 0.3)
	_spawn_blood_effect(current_defender.position)
	await get_tree().create_timer(_t(0.5)).timeout


func _battle_pawn_vs_king() -> void:
	# Peasant uprising: tackle and pommel beat
	await _battle_step(current_attacker, Vector3(0, 0, -0.8), 0.3)
	await _battle_step(current_attacker, Vector3(0, 0.3, -0.3), 0.2)
	current_attacker.play_attack()
	_spawn_blood_effect(current_defender.position)
	await get_tree().create_timer(_t(0.8)).timeout

# --- Rook attacks ---

func _battle_rook_vs_pawn() -> void:
	# Stomp pawn flat
	await _battle_step(current_attacker, Vector3(0, 0.5, -0.5), 0.4)
	await _battle_step(current_attacker, Vector3(0, -0.5, -0.3), 0.15)
	_spawn_blood_effect(current_defender.position)
	await get_tree().create_timer(_t(0.5)).timeout


func _battle_rook_vs_rook() -> void:
	# Two golems collide, winner tears head off
	await _battle_step(current_attacker, Vector3(0, 0, -0.8), 0.5)
	await get_tree().create_timer(_t(0.3)).timeout
	current_attacker.play_attack()
	_spawn_blood_effect(current_defender.position + Vector3.UP * 1.5)
	await get_tree().create_timer(_t(0.8)).timeout


func _battle_rook_vs_knight() -> void:
	# Catch horse mid-charge, crush
	await get_tree().create_timer(_t(0.4)).timeout
	await _battle_step(current_attacker, Vector3(0, 0, -0.5), 0.3)
	_spawn_blood_effect(current_defender.position)
	await get_tree().create_timer(_t(0.7)).timeout


func _battle_rook_vs_bishop() -> void:
	# Walk through spells, bear hug
	await _battle_step(current_attacker, Vector3(0, 0, -0.3), 0.3)
	await _battle_step(current_attacker, Vector3(0, 0, -0.3), 0.3)
	await _battle_step(current_attacker, Vector3(0, 0, -0.3), 0.2)
	_spawn_blood_effect(current_defender.position)
	await get_tree().create_timer(_t(0.5)).timeout


func _battle_rook_vs_queen() -> void:
	# Grab and slam
	await _battle_step(current_attacker, Vector3(0, 0, -0.6), 0.4)
	current_attacker.play_attack()
	await get_tree().create_timer(_t(0.3)).timeout
	_spawn_blood_effect(current_defender.position)
	await get_tree().create_timer(_t(0.5)).timeout


func _battle_rook_vs_king() -> void:
	# Crumble onto king, bury in rubble
	await _battle_step(current_attacker, Vector3(0, 0.8, -0.5), 0.5)
	await _battle_step(current_attacker, Vector3(0, -0.8, -0.3), 0.2)
	_spawn_blood_effect(current_defender.position)
	await get_tree().create_timer(_t(0.8)).timeout

# --- Knight attacks ---

func _battle_knight_vs_pawn() -> void:
	# Lance charge, skewer and ride past
	await _battle_step(current_attacker, Vector3(0, 0, -1.5), 0.4)
	_spawn_blood_effect(current_defender.position)
	await get_tree().create_timer(_t(0.5)).timeout


func _battle_knight_vs_rook() -> void:
	# Leap onto golem's back, drive sword into skull
	await _battle_step(current_attacker, Vector3(0, 1.0, -0.5), 0.4)
	await _battle_step(current_attacker, Vector3(0, -0.2, -0.3), 0.2)
	_spawn_blood_effect(current_defender.position + Vector3.UP * 1.5)
	await get_tree().create_timer(_t(0.6)).timeout


func _battle_knight_vs_knight() -> void:
	# Jousting clash, loser unhorsed and trampled
	await _battle_step(current_attacker, Vector3(0, 0, -1.0), 0.3)
	_spawn_blood_effect(current_defender.position)
	await get_tree().create_timer(_t(0.5)).timeout
	await _battle_step(current_attacker, Vector3(0, 0, -0.5), 0.3)
	_spawn_blood_effect(current_defender.position)
	await get_tree().create_timer(_t(0.3)).timeout


func _battle_knight_vs_bishop() -> void:
	# Gallop circles, throw sword through bishop
	await _battle_step(current_attacker, Vector3(1.0, 0, -0.5), 0.3)
	await _battle_step(current_attacker, Vector3(-1.0, 0, -0.5), 0.3)
	_spawn_blood_effect(current_defender.position)
	await get_tree().create_timer(_t(0.5)).timeout


func _battle_knight_vs_queen() -> void:
	# Mounted duel, lasso drag
	await _battle_step(current_attacker, Vector3(0, 0, -0.5), 0.3)
	current_attacker.play_attack()
	await get_tree().create_timer(_t(0.4)).timeout
	_spawn_blood_effect(current_defender.position)
	await get_tree().create_timer(_t(0.5)).timeout


func _battle_knight_vs_king() -> void:
	# Ride king down, horse kicks crown off
	await _battle_step(current_attacker, Vector3(0, 0, -1.2), 0.4)
	_spawn_blood_effect(current_defender.position + Vector3.UP)
	await get_tree().create_timer(_t(0.3)).timeout
	current_attacker.play_attack()
	await get_tree().create_timer(_t(0.5)).timeout

# --- Bishop attacks ---

func _battle_bishop_vs_pawn() -> void:
	# Telekinetic tear apart
	await get_tree().create_timer(_t(0.5)).timeout
	# Pawn levitates
	var tween := create_tween()
	tween.tween_property(current_defender, "position:y", 1.5, 0.4)
	await tween.finished
	_spawn_blood_effect(current_defender.position)
	_spawn_blood_effect(current_defender.position + Vector3.RIGHT * 0.5)
	await get_tree().create_timer(_t(0.5)).timeout


func _battle_bishop_vs_rook() -> void:
	# Lightning shatters golem
	await get_tree().create_timer(_t(0.3)).timeout
	_spawn_blood_effect(current_defender.position + Vector3.UP)
	await get_tree().create_timer(_t(0.3)).timeout
	_spawn_blood_effect(current_defender.position)
	await get_tree().create_timer(_t(0.5)).timeout


func _battle_bishop_vs_knight() -> void:
	# Phantom spooks horse, magic finishes rider
	await get_tree().create_timer(_t(0.4)).timeout
	var tween := create_tween()
	tween.tween_property(current_defender, "rotation:z", 0.5, 0.3)
	await tween.finished
	_spawn_blood_effect(current_defender.position + Vector3.UP)
	await get_tree().create_timer(_t(0.5)).timeout


func _battle_bishop_vs_bishop() -> void:
	# Wizard duel, beams collide
	await get_tree().create_timer(_t(0.3)).timeout
	await _battle_step(current_attacker, Vector3(0, 0.2, -0.3), 0.3)
	await get_tree().create_timer(_t(0.5)).timeout
	await _battle_step(current_attacker, Vector3(0, 0, -0.3), 0.2)
	_spawn_blood_effect(current_defender.position)
	await get_tree().create_timer(_t(0.5)).timeout


func _battle_bishop_vs_queen() -> void:
	# Dark tendrils bind, drain life
	await get_tree().create_timer(_t(0.5)).timeout
	_spawn_blood_effect(current_defender.position)
	await get_tree().create_timer(_t(0.8)).timeout
	_spawn_blood_effect(current_defender.position)
	await get_tree().create_timer(_t(0.3)).timeout


func _battle_bishop_vs_king() -> void:
	# Spectral blade through king
	await get_tree().create_timer(_t(0.5)).timeout
	await _battle_step(current_attacker, Vector3(0, 0.3, 0), 0.2)
	_spawn_blood_effect(current_defender.position)
	await get_tree().create_timer(_t(0.7)).timeout

# --- Queen attacks ---

func _battle_queen_vs_pawn() -> void:
	# Dual blade flurry, cuts pawn to pieces
	await _battle_step(current_attacker, Vector3(0, 0, -0.8), 0.3)
	current_attacker.play_attack()
	_spawn_blood_effect(current_defender.position)
	await get_tree().create_timer(_t(0.3)).timeout
	_spawn_blood_effect(current_defender.position + Vector3.RIGHT * 0.3)
	await get_tree().create_timer(_t(0.3)).timeout
	_spawn_blood_effect(current_defender.position + Vector3.LEFT * 0.3)
	await get_tree().create_timer(_t(0.3)).timeout


func _battle_queen_vs_rook() -> void:
	# Acrobatic assault, carve through stone joints
	await _battle_step(current_attacker, Vector3(0.5, 0.5, -0.5), 0.3)
	await _battle_step(current_attacker, Vector3(-0.5, -0.2, -0.3), 0.2)
	_spawn_blood_effect(current_defender.position)
	current_attacker.play_attack()
	await get_tree().create_timer(_t(0.5)).timeout


func _battle_queen_vs_knight() -> void:
	# Sidestep lance, hamstring horse, behead rider
	await _battle_step(current_attacker, Vector3(0.8, 0, 0), 0.2)
	await _battle_step(current_attacker, Vector3(-0.8, 0, -0.8), 0.3)
	_spawn_blood_effect(current_defender.position)
	await get_tree().create_timer(_t(0.3)).timeout
	_spawn_blood_effect(current_defender.position + Vector3.UP * 1.2)
	await get_tree().create_timer(_t(0.3)).timeout


func _battle_queen_vs_bishop() -> void:
	# Deflect spells with blades, cross swords through neck
	await _battle_step(current_attacker, Vector3(0, 0, -0.3), 0.2)
	await _battle_step(current_attacker, Vector3(0, 0, -0.3), 0.2)
	await _battle_step(current_attacker, Vector3(0, 0, -0.3), 0.15)
	current_attacker.play_attack()
	_spawn_blood_effect(current_defender.position + Vector3.UP * 1.2)
	await get_tree().create_timer(_t(0.5)).timeout


func _battle_queen_vs_queen() -> void:
	# Epic dual-blade duel
	await _battle_step(current_attacker, Vector3(0, 0, -0.5), 0.2)
	current_attacker.play_attack()
	await get_tree().create_timer(_t(0.3)).timeout
	await _battle_step(current_attacker, Vector3(0.3, 0, -0.2), 0.15)
	await get_tree().create_timer(_t(0.2)).timeout
	await _battle_step(current_attacker, Vector3(-0.3, 0, -0.2), 0.15)
	_spawn_blood_effect(current_defender.position)
	_spawn_blood_effect(current_defender.position + Vector3.UP * 0.5)
	await get_tree().create_timer(_t(0.5)).timeout


func _battle_queen_vs_king() -> void:
	# Theatrical execution: disarm then slow finish
	await _battle_step(current_attacker, Vector3(0, 0, -0.5), 0.3)
	current_attacker.play_attack()
	await get_tree().create_timer(_t(0.5)).timeout
	await _battle_step(current_attacker, Vector3(0, 0, -0.3), 0.3)
	await get_tree().create_timer(_t(0.5)).timeout
	_spawn_blood_effect(current_defender.position)
	await get_tree().create_timer(_t(0.5)).timeout

# --- King attacks ---

func _battle_king_vs_pawn() -> void:
	# Single devastating greatsword cleave
	await _battle_step(current_attacker, Vector3(0, 0.3, -0.5), 0.4)
	await _battle_step(current_attacker, Vector3(0, -0.3, -0.3), 0.15)
	_spawn_blood_effect(current_defender.position)
	await get_tree().create_timer(_t(0.5)).timeout


func _battle_king_vs_rook() -> void:
	# Overhead strike cracks golem down the middle
	await _battle_step(current_attacker, Vector3(0, 0, -0.6), 0.3)
	await _battle_step(current_attacker, Vector3(0, 0.5, 0), 0.3)
	await _battle_step(current_attacker, Vector3(0, -0.5, -0.2), 0.15)
	_spawn_blood_effect(current_defender.position + Vector3.UP)
	await get_tree().create_timer(_t(0.7)).timeout


func _battle_king_vs_knight() -> void:
	# Sidestep charge, greatsword through horse and rider
	await _battle_step(current_attacker, Vector3(0.8, 0, 0), 0.2)
	await get_tree().create_timer(_t(0.3)).timeout
	await _battle_step(current_attacker, Vector3(-0.8, 0, -0.8), 0.3)
	_spawn_blood_effect(current_defender.position)
	await get_tree().create_timer(_t(0.5)).timeout


func _battle_king_vs_bishop() -> void:
	# Power through magic, greatsword splits bishop
	await _battle_step(current_attacker, Vector3(0, 0, -0.3), 0.3)
	await _battle_step(current_attacker, Vector3(0, 0, -0.3), 0.3)
	await _battle_step(current_attacker, Vector3(0, 0, -0.3), 0.2)
	current_attacker.play_attack()
	_spawn_blood_effect(current_defender.position)
	await get_tree().create_timer(_t(0.5)).timeout


func _battle_king_vs_queen() -> void:
	# Parry dual blades, overpower, crushing blow
	await _battle_step(current_attacker, Vector3(0, 0, -0.4), 0.2)
	await get_tree().create_timer(_t(0.4)).timeout
	await _battle_step(current_attacker, Vector3(0, 0, -0.3), 0.2)
	current_attacker.play_attack()
	await get_tree().create_timer(_t(0.3)).timeout
	_spawn_blood_effect(current_defender.position)
	await get_tree().create_timer(_t(0.5)).timeout


func _battle_king_vs_king() -> void:
	# Should never happen in legal chess — dramatic standoff
	await get_tree().create_timer(_t(2.0)).timeout


func _battle_generic() -> void:
	# Fallback: simple attack animation
	await _battle_step(current_attacker, Vector3(0, 0, -0.8), 0.4)
	current_attacker.play_attack()
	_spawn_blood_effect(current_defender.position)
	await get_tree().create_timer(_t(0.8)).timeout
