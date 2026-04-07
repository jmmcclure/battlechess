class_name AIPlayer
extends RefCounted

# =============================================================================
# Piece values (centipawns)
# =============================================================================

const PIECE_VALUES: Array[int] = [
	0,      # NONE
	100,    # PAWN
	500,    # ROOK
	320,    # KNIGHT
	330,    # BISHOP
	900,    # QUEEN
	20000,  # KING
]

# =============================================================================
# Piece-square tables (from White's perspective, index 0 = a1)
# =============================================================================

const PST_PAWN: Array[int] = [
	 0,  0,  0,  0,  0,  0,  0,  0,
	 5, 10, 10,-20,-20, 10, 10,  5,
	 5, -5,-10,  0,  0,-10, -5,  5,
	 0,  0,  0, 20, 20,  0,  0,  0,
	 5,  5, 10, 25, 25, 10,  5,  5,
	10, 10, 20, 30, 30, 20, 10, 10,
	50, 50, 50, 50, 50, 50, 50, 50,
	 0,  0,  0,  0,  0,  0,  0,  0,
]

const PST_KNIGHT: Array[int] = [
	-50,-40,-30,-30,-30,-30,-40,-50,
	-40,-20,  0,  5,  5,  0,-20,-40,
	-30,  0, 10, 15, 15, 10,  0,-30,
	-30,  5, 15, 20, 20, 15,  5,-30,
	-30,  0, 15, 20, 20, 15,  0,-30,
	-30,  5, 10, 15, 15, 10,  5,-30,
	-40,-20,  0,  0,  0,  0,-20,-40,
	-50,-40,-30,-30,-30,-30,-40,-50,
]

const PST_BISHOP: Array[int] = [
	-20,-10,-10,-10,-10,-10,-10,-20,
	-10,  5,  0,  0,  0,  0,  5,-10,
	-10, 10, 10, 10, 10, 10, 10,-10,
	-10,  0, 10, 10, 10, 10,  0,-10,
	-10,  5,  5, 10, 10,  5,  5,-10,
	-10,  0,  5, 10, 10,  5,  0,-10,
	-10,  0,  0,  0,  0,  0,  0,-10,
	-20,-10,-10,-10,-10,-10,-10,-20,
]

const PST_ROOK: Array[int] = [
	 0,  0,  0,  5,  5,  0,  0,  0,
	-5,  0,  0,  0,  0,  0,  0, -5,
	-5,  0,  0,  0,  0,  0,  0, -5,
	-5,  0,  0,  0,  0,  0,  0, -5,
	-5,  0,  0,  0,  0,  0,  0, -5,
	-5,  0,  0,  0,  0,  0,  0, -5,
	 5, 10, 10, 10, 10, 10, 10,  5,
	 0,  0,  0,  0,  0,  0,  0,  0,
]

const PST_QUEEN: Array[int] = [
	-20,-10,-10, -5, -5,-10,-10,-20,
	-10,  0,  0,  0,  0,  0,  0,-10,
	-10,  5,  5,  5,  5,  5,  0,-10,
	 -5,  0,  5,  5,  5,  5,  0, -5,
	  0,  0,  5,  5,  5,  5,  0, -5,
	-10,  0,  5,  5,  5,  5,  0,-10,
	-10,  0,  0,  0,  0,  0,  0,-10,
	-20,-10,-10, -5, -5,-10,-10,-20,
]

const PST_KING_MG: Array[int] = [
	 20, 30, 10,  0,  0, 10, 30, 20,
	 20, 20,  0,  0,  0,  0, 20, 20,
	-10,-20,-20,-20,-20,-20,-20,-10,
	-20,-30,-30,-40,-40,-30,-30,-20,
	-30,-40,-40,-50,-50,-40,-40,-30,
	-30,-40,-40,-50,-50,-40,-40,-30,
	-30,-40,-40,-50,-50,-40,-40,-30,
	-30,-40,-40,-50,-50,-40,-40,-30,
]

const MOBILITY_WEIGHT: int = 4
const CHECK_BONUS: int = 50

# =============================================================================
# Difficulty settings
# =============================================================================

const DIFFICULTY_DEPTH: Dictionary = {
	1: 2,
	2: 3,
	3: 4,
	4: 6,
}

const DIFFICULTY_TIME_MS: Dictionary = {
	1: 500,
	2: 1500,
	3: 3000,
	4: 8000,
}

# =============================================================================
# Search state
# =============================================================================

var _nodes_searched: int = 0
var _stop_search: bool = false
var _start_time_ms: int = 0
var _time_limit_ms: int = 0
var _best_move_iterative: Dictionary = {}

# =============================================================================
# Public API
# =============================================================================

func get_best_move(engine: ChessEngine, difficulty: int) -> Dictionary:
	difficulty = clampi(difficulty, 1, 4)
	var max_depth: int = DIFFICULTY_DEPTH[difficulty]
	_time_limit_ms = DIFFICULTY_TIME_MS[difficulty]
	_start_time_ms = Time.get_ticks_msec()
	_stop_search = false
	_nodes_searched = 0
	_best_move_iterative = {}

	var legal_moves: Array[Dictionary] = engine.get_legal_moves()
	if legal_moves.is_empty():
		return {}
	if legal_moves.size() == 1:
		return legal_moves[0]

	# Iterative deepening
	for depth: int in range(1, max_depth + 1):
		if _stop_search:
			break
		var best_score: int = -999999
		var best_move: Dictionary = {}
		var ordered: Array[Dictionary] = _order_moves(engine, legal_moves)

		for move: Dictionary in ordered:
			engine.make_move(move)
			var score: int = -_alpha_beta(engine, depth - 1, -999999, -best_score)
			engine.unmake_move(move)

			if _stop_search:
				break

			if score > best_score:
				best_score = score
				best_move = move

		if not best_move.is_empty() and not _stop_search:
			_best_move_iterative = best_move

	return _best_move_iterative if not _best_move_iterative.is_empty() else legal_moves[0]

func stop_search() -> void:
	_stop_search = true

# =============================================================================
# Alpha-beta search
# =============================================================================

func _alpha_beta(engine: ChessEngine, depth: int, alpha: int, beta: int) -> int:
	_nodes_searched += 1

	# Time check every 4096 nodes
	if _nodes_searched & 4095 == 0:
		if Time.get_ticks_msec() - _start_time_ms >= _time_limit_ms:
			_stop_search = true
			return 0

	if _stop_search:
		return 0

	if depth <= 0:
		return _quiescence(engine, alpha, beta, 4)

	var legal_moves: Array[Dictionary] = engine.get_legal_moves()

	# Checkmate / stalemate
	if legal_moves.is_empty():
		if engine.is_in_check(engine.side_to_move):
			return -100000 + (100 - depth)  # Prefer shorter mates
		return 0  # Stalemate

	# Draw detection
	if engine.is_draw():
		return 0

	var ordered: Array[Dictionary] = _order_moves(engine, legal_moves)

	for move: Dictionary in ordered:
		engine.make_move(move)
		var score: int = -_alpha_beta(engine, depth - 1, -beta, -alpha)
		engine.unmake_move(move)

		if _stop_search:
			return 0

		if score >= beta:
			return beta
		if score > alpha:
			alpha = score

	return alpha

# =============================================================================
# Quiescence search
# =============================================================================

func _quiescence(engine: ChessEngine, alpha: int, beta: int, depth_remaining: int) -> int:
	_nodes_searched += 1

	var stand_pat: int = _evaluate(engine)
	if stand_pat >= beta:
		return beta
	if stand_pat > alpha:
		alpha = stand_pat

	if depth_remaining <= 0:
		return alpha

	var legal_moves: Array[Dictionary] = engine.get_legal_moves()
	var captures: Array[Dictionary] = []
	for move: Dictionary in legal_moves:
		if move["piece_captured"] != 0 or (move["flags"] & ChessEngine.MoveFlag.EN_PASSANT):
			captures.append(move)
		elif move["flags"] & ChessEngine.PROMOTION_FLAGS:
			captures.append(move)

	var ordered: Array[Dictionary] = _order_moves(engine, captures)

	for move: Dictionary in ordered:
		engine.make_move(move)
		var score: int = -_quiescence(engine, -beta, -alpha, depth_remaining - 1)
		engine.unmake_move(move)

		if _stop_search:
			return 0

		if score >= beta:
			return beta
		if score > alpha:
			alpha = score

	return alpha

# =============================================================================
# Move ordering (MVV-LVA for captures, promotions first)
# =============================================================================

func _order_moves(engine: ChessEngine, moves: Array[Dictionary]) -> Array[Dictionary]:
	var scored: Array[Dictionary] = []
	for move: Dictionary in moves:
		var score: int = 0
		var captured: int = move["piece_captured"]
		var flags: int = move["flags"]

		# Promotions
		if flags & ChessEngine.PROMOTION_FLAGS:
			score += 9000
			if flags & ChessEngine.MoveFlag.PROMOTE_QUEEN:
				score += 900

		# MVV-LVA: Most Valuable Victim - Least Valuable Attacker
		if captured != 0:
			var victim_val: int = PIECE_VALUES[ChessEngine.piece_type(captured)]
			var attacker_val: int = PIECE_VALUES[ChessEngine.piece_type(move["piece_moved"])]
			score += victim_val * 10 - attacker_val

		# Castling gets a small bonus
		if flags & (ChessEngine.MoveFlag.CASTLE_KINGSIDE | ChessEngine.MoveFlag.CASTLE_QUEENSIDE):
			score += 500

		scored.append({"move": move, "score": score})

	scored.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["score"] > b["score"])

	var result: Array[Dictionary] = []
	for entry: Dictionary in scored:
		result.append(entry["move"])
	return result

# =============================================================================
# Evaluation
# =============================================================================

func _evaluate(engine: ChessEngine) -> int:
	var score: int = 0
	var white_material: int = 0
	var black_material: int = 0

	for sq: int in range(64):
		var piece: int = engine.board[sq]
		if piece == 0:
			continue
		var type: int = ChessEngine.piece_type(piece)
		var color: int = ChessEngine.piece_color(piece)
		var val: int = PIECE_VALUES[type]
		var pst: int = _get_pst_value(type, sq, color)

		if color == ChessEngine.PieceColor.WHITE:
			score += val + pst
			white_material += val
		else:
			score -= val + pst
			black_material += val

	# Mobility evaluation — approximate using legal move count
	# We avoid generating legal moves for opponent to save time; use a simpler proxy
	if engine.side_to_move == ChessEngine.PieceColor.WHITE:
		score += _count_mobility(engine) * MOBILITY_WEIGHT
	else:
		score -= _count_mobility(engine) * MOBILITY_WEIGHT

	# Check bonus
	var opponent: int = 1 - engine.side_to_move
	if engine.is_in_check(opponent):
		if engine.side_to_move == ChessEngine.PieceColor.WHITE:
			score += CHECK_BONUS
		else:
			score -= CHECK_BONUS

	# Return score from perspective of side to move
	if engine.side_to_move == ChessEngine.PieceColor.BLACK:
		score = -score

	return score

func _count_mobility(engine: ChessEngine) -> int:
	return engine.get_legal_moves().size()

func _get_pst_value(type: int, sq: int, color: int) -> int:
	var idx: int = sq
	if color == ChessEngine.PieceColor.BLACK:
		# Mirror vertically: rank 0 <-> rank 7
		idx = (7 - ChessEngine.rank_of(sq)) * 8 + ChessEngine.file_of(sq)

	match type:
		ChessEngine.PieceType.PAWN:   return PST_PAWN[idx]
		ChessEngine.PieceType.KNIGHT: return PST_KNIGHT[idx]
		ChessEngine.PieceType.BISHOP: return PST_BISHOP[idx]
		ChessEngine.PieceType.ROOK:   return PST_ROOK[idx]
		ChessEngine.PieceType.QUEEN:  return PST_QUEEN[idx]
		ChessEngine.PieceType.KING:   return PST_KING_MG[idx]
	return 0
