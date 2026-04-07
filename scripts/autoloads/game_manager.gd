extends Node
## Manages overall game state, modes, and flow.

enum GameMode { VS_AI, LOCAL_MP, ONLINE_MP }
enum GameState { MENU, PLAYING, BATTLE_ANIM, PAUSED, GAME_OVER }

var current_mode: GameMode = GameMode.VS_AI
var current_state: GameState = GameState.MENU
var ai_difficulty: int = 2

# Player settings
var player_white_name: String = "White"
var player_black_name: String = "Black"
var gore_enabled: bool = true
var animation_speed: float = 1.0
var battle_skip_enabled: bool = true


func start_game(mode: GameMode) -> void:
	current_mode = mode
	current_state = GameState.PLAYING
	EventBus.game_started.emit(GameMode.keys()[mode])


func end_game(result: String, winner: int) -> void:
	current_state = GameState.GAME_OVER
	EventBus.game_ended.emit(result, winner)


func pause_game() -> void:
	current_state = GameState.PAUSED
	get_tree().paused = true


func resume_game() -> void:
	current_state = GameState.PLAYING
	get_tree().paused = false


func enter_battle() -> void:
	current_state = GameState.BATTLE_ANIM


func exit_battle() -> void:
	current_state = GameState.PLAYING
	EventBus.battle_finished.emit()


func is_playing() -> bool:
	return current_state == GameState.PLAYING


func is_ai_turn(color: int) -> bool:
	return current_mode == GameMode.VS_AI and color == 1  # Black = AI
