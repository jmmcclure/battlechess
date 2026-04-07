extends Node
## Global signal bus for decoupled communication between systems.

# Game flow
signal game_started(mode: String)
signal game_ended(result: String, winner: int)
signal turn_changed(color: int)

# Piece interaction
signal piece_selected(piece: Node3D)
signal piece_deselected()
signal piece_moved(piece: Node3D, from: Vector2i, to: Vector2i)
signal piece_captured(attacker: Node3D, defender: Node3D)
signal piece_promoted(piece: Node3D, new_type: int)

# Battle system
signal battle_started(attacker: Node3D, defender: Node3D)
signal battle_finished()
signal battle_skipped()

# Board state
signal check_declared(color: int)
signal checkmate_declared(loser_color: int)
signal stalemate_declared()
signal draw_declared(reason: String)
signal castling_performed(color: int, side: String)
signal en_passant_performed(piece: Node3D, captured: Node3D)

# UI
signal move_added_to_history(notation: String)
signal captured_piece_added(piece_type: int, color: int)
signal timer_updated(color: int, time_remaining: float)

# Multiplayer
signal player_connected(player_id: int)
signal player_disconnected(player_id: int)
signal lobby_created(code: String)
signal lobby_joined(code: String)
signal remote_move_received(from: Vector2i, to: Vector2i, promotion: int)

# Promotion
signal promotion_requested(from: Vector2i, to: Vector2i, move_data: Dictionary)
signal promotion_completed(piece_type: int)

# Game actions
signal resign_requested(color: int)
signal draw_offered(color: int)
signal draw_accepted()
signal game_restarted()
signal pause_toggled(paused: bool)

# Settings
signal settings_changed(key: String, value: Variant)
