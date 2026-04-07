class_name ChessEngine
extends RefCounted

# =============================================================================
# Enums & Constants
# =============================================================================

enum PieceType { NONE = 0, PAWN = 1, ROOK = 2, KNIGHT = 3, BISHOP = 4, QUEEN = 5, KING = 6 }
enum PieceColor { WHITE = 0, BLACK = 1 }

enum MoveFlag {
	NONE = 0,
	DOUBLE_PAWN = 1,
	EN_PASSANT = 2,
	CASTLE_KINGSIDE = 4,
	CASTLE_QUEENSIDE = 8,
	PROMOTE_QUEEN = 16,
	PROMOTE_ROOK = 32,
	PROMOTE_BISHOP = 64,
	PROMOTE_KNIGHT = 128,
}

const PROMOTION_FLAGS: int = MoveFlag.PROMOTE_QUEEN | MoveFlag.PROMOTE_ROOK | MoveFlag.PROMOTE_BISHOP | MoveFlag.PROMOTE_KNIGHT

const KNIGHT_OFFSETS: Array[int] = [-17, -15, -10, -6, 6, 10, 15, 17]
const BISHOP_OFFSETS: Array[int] = [-9, -7, 7, 9]
const ROOK_OFFSETS: Array[int] = [-8, -1, 1, 8]
const QUEEN_KING_OFFSETS: Array[int] = [-9, -8, -7, -1, 1, 7, 8, 9]

# =============================================================================
# Piece encoding helpers
# =============================================================================

static func make_piece(type: int, color: int) -> int:
	return (color << 3) | type

static func piece_type(piece: int) -> int:
	return piece & 0x07

static func piece_color(piece: int) -> int:
	return (piece >> 3) & 0x01

# =============================================================================
# Board state
# =============================================================================

var board: Array[int] = []
var king_sq: Array[int] = [4, 60]  # [WHITE king sq, BLACK king sq]
var castling_rights: Array[bool] = [true, true, true, true]  # WK, WQ, BK, BQ
var en_passant_sq: int = -1
var halfmove_clock: int = 0
var fullmove_number: int = 1
var side_to_move: int = PieceColor.WHITE

var history_stack: Array[Dictionary] = []

# =============================================================================
# Coordinate helpers
# =============================================================================

static func rank_of(sq: int) -> int:
	return sq >> 3

static func file_of(sq: int) -> int:
	return sq & 7

static func sq_index(rank: int, file: int) -> int:
	return rank * 8 + file

static func is_valid_sq(sq: int) -> bool:
	return sq >= 0 and sq < 64

static func square_to_algebraic(sq: int) -> String:
	var f: int = file_of(sq)
	var r: int = rank_of(sq)
	return char(f + 97) + str(r + 1)  # 97 = 'a'

static func algebraic_to_square(s: String) -> int:
	if s.length() < 2:
		return -1
	var f: int = s.unicode_at(0) - 97
	var r: int = s.unicode_at(1) - 49  # 49 = '1'
	if f < 0 or f > 7 or r < 0 or r > 7:
		return -1
	return sq_index(r, f)

# =============================================================================
# Initialization
# =============================================================================

func _init() -> void:
	board.resize(64)
	board.fill(0)

func setup_starting_position() -> void:
	from_fen("rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1")

func clear_board() -> void:
	board.fill(0)
	king_sq = [0, 0]
	castling_rights = [false, false, false, false]
	en_passant_sq = -1
	halfmove_clock = 0
	fullmove_number = 1
	side_to_move = PieceColor.WHITE
	history_stack.clear()

# =============================================================================
# FEN
# =============================================================================

func from_fen(fen: String) -> void:
	clear_board()
	var parts: PackedStringArray = fen.split(" ")
	if parts.size() < 1:
		return

	# Piece placement
	var rank: int = 7
	var file: int = 0
	for ch in parts[0]:
		if ch == "/":
			rank -= 1
			file = 0
		elif ch.is_valid_int():
			file += ch.to_int()
		else:
			var color: int = PieceColor.WHITE if ch == ch.to_upper() else PieceColor.BLACK
			var type: int = _char_to_piece_type(ch.to_lower())
			var sq: int = sq_index(rank, file)
			board[sq] = make_piece(type, color)
			if type == PieceType.KING:
				king_sq[color] = sq
			file += 1

	# Side to move
	if parts.size() > 1:
		side_to_move = PieceColor.BLACK if parts[1] == "b" else PieceColor.WHITE

	# Castling
	castling_rights = [false, false, false, false]
	if parts.size() > 2 and parts[2] != "-":
		for ch in parts[2]:
			match ch:
				"K": castling_rights[0] = true
				"Q": castling_rights[1] = true
				"k": castling_rights[2] = true
				"q": castling_rights[3] = true

	# En passant
	if parts.size() > 3 and parts[3] != "-":
		en_passant_sq = algebraic_to_square(parts[3])
	else:
		en_passant_sq = -1

	# Clocks
	if parts.size() > 4:
		halfmove_clock = parts[4].to_int()
	if parts.size() > 5:
		fullmove_number = parts[5].to_int()

func to_fen() -> String:
	var fen: String = ""

	# Piece placement
	for rank: int in range(7, -1, -1):
		var empty: int = 0
		for file: int in range(8):
			var piece: int = board[sq_index(rank, file)]
			if piece == 0:
				empty += 1
			else:
				if empty > 0:
					fen += str(empty)
					empty = 0
				fen += _piece_to_char(piece)
		if empty > 0:
			fen += str(empty)
		if rank > 0:
			fen += "/"

	# Side to move
	fen += " w" if side_to_move == PieceColor.WHITE else " b"

	# Castling
	var castle_str: String = ""
	if castling_rights[0]: castle_str += "K"
	if castling_rights[1]: castle_str += "Q"
	if castling_rights[2]: castle_str += "k"
	if castling_rights[3]: castle_str += "q"
	fen += " " + (castle_str if castle_str.length() > 0 else "-")

	# En passant
	fen += " " + (square_to_algebraic(en_passant_sq) if en_passant_sq >= 0 else "-")

	# Clocks
	fen += " " + str(halfmove_clock) + " " + str(fullmove_number)
	return fen

func _char_to_piece_type(ch: String) -> int:
	match ch:
		"p": return PieceType.PAWN
		"r": return PieceType.ROOK
		"n": return PieceType.KNIGHT
		"b": return PieceType.BISHOP
		"q": return PieceType.QUEEN
		"k": return PieceType.KING
	return PieceType.NONE

func _piece_to_char(piece: int) -> String:
	var type: int = piece_type(piece)
	var color: int = piece_color(piece)
	var ch: String
	match type:
		PieceType.PAWN: ch = "p"
		PieceType.ROOK: ch = "r"
		PieceType.KNIGHT: ch = "n"
		PieceType.BISHOP: ch = "b"
		PieceType.QUEEN: ch = "q"
		PieceType.KING: ch = "k"
		_: return "?"
	return ch.to_upper() if color == PieceColor.WHITE else ch

func _promotion_flag_to_type(flag: int) -> int:
	if flag & MoveFlag.PROMOTE_QUEEN: return PieceType.QUEEN
	if flag & MoveFlag.PROMOTE_ROOK: return PieceType.ROOK
	if flag & MoveFlag.PROMOTE_BISHOP: return PieceType.BISHOP
	if flag & MoveFlag.PROMOTE_KNIGHT: return PieceType.KNIGHT
	return PieceType.QUEEN

# =============================================================================
# Move creation helper
# =============================================================================

func _create_move(from: int, to: int, flags: int = MoveFlag.NONE) -> Dictionary:
	return {
		"from_sq": from,
		"to_sq": to,
		"piece_moved": board[from],
		"piece_captured": board[to],
		"flags": flags,
	}

# =============================================================================
# Make / Unmake move
# =============================================================================

func make_move(move: Dictionary) -> void:
	var saved: Dictionary = {
		"castling_rights": castling_rights.duplicate(),
		"en_passant_sq": en_passant_sq,
		"halfmove_clock": halfmove_clock,
		"piece_captured": move["piece_captured"],
	}
	history_stack.push_back(saved)

	var from_sq: int = move["from_sq"]
	var to_sq: int = move["to_sq"]
	var piece: int = move["piece_moved"]
	var flags: int = move["flags"]
	var type: int = piece_type(piece)
	var color: int = piece_color(piece)

	# Update halfmove clock
	if type == PieceType.PAWN or move["piece_captured"] != 0:
		halfmove_clock = 0
	else:
		halfmove_clock += 1

	# Clear en passant
	en_passant_sq = -1

	# Handle en passant capture
	if flags & MoveFlag.EN_PASSANT:
		var captured_sq: int = to_sq + (-8 if color == PieceColor.WHITE else 8)
		board[captured_sq] = 0

	# Handle castling
	if flags & MoveFlag.CASTLE_KINGSIDE:
		var rook_from: int = from_sq + 3
		var rook_to: int = from_sq + 1
		board[rook_to] = board[rook_from]
		board[rook_from] = 0
	elif flags & MoveFlag.CASTLE_QUEENSIDE:
		var rook_from: int = from_sq - 4
		var rook_to: int = from_sq - 1
		board[rook_to] = board[rook_from]
		board[rook_from] = 0

	# Move the piece
	board[to_sq] = piece
	board[from_sq] = 0

	# Handle promotion
	if flags & PROMOTION_FLAGS:
		var promo_type: int = _promotion_flag_to_type(flags)
		board[to_sq] = make_piece(promo_type, color)

	# Double pawn push — set en passant square
	if flags & MoveFlag.DOUBLE_PAWN:
		en_passant_sq = (from_sq + to_sq) / 2

	# Update king position
	if type == PieceType.KING:
		king_sq[color] = to_sq

	# Update castling rights
	_update_castling_rights(from_sq, to_sq)

	# Switch side
	if side_to_move == PieceColor.BLACK:
		fullmove_number += 1
	side_to_move = 1 - side_to_move

func unmake_move(move: Dictionary) -> void:
	if history_stack.is_empty():
		return

	var saved: Dictionary = history_stack.pop_back()
	var from_sq: int = move["from_sq"]
	var to_sq: int = move["to_sq"]
	var piece: int = move["piece_moved"]
	var flags: int = move["flags"]
	var type: int = piece_type(piece)
	var color: int = piece_color(piece)

	# Switch side back
	side_to_move = 1 - side_to_move
	if side_to_move == PieceColor.BLACK:
		fullmove_number -= 1

	# Move piece back
	board[from_sq] = piece
	board[to_sq] = saved["piece_captured"]

	# Undo en passant capture
	if flags & MoveFlag.EN_PASSANT:
		var captured_sq: int = to_sq + (-8 if color == PieceColor.WHITE else 8)
		var opp_pawn: int = make_piece(PieceType.PAWN, 1 - color)
		board[captured_sq] = opp_pawn
		board[to_sq] = 0

	# Undo castling
	if flags & MoveFlag.CASTLE_KINGSIDE:
		var rook_from: int = from_sq + 3
		var rook_to: int = from_sq + 1
		board[rook_from] = board[rook_to]
		board[rook_to] = 0
	elif flags & MoveFlag.CASTLE_QUEENSIDE:
		var rook_from: int = from_sq - 4
		var rook_to: int = from_sq - 1
		board[rook_from] = board[rook_to]
		board[rook_to] = 0

	# Restore king position
	if type == PieceType.KING:
		king_sq[color] = from_sq

	# Restore saved state
	castling_rights = saved["castling_rights"]
	en_passant_sq = saved["en_passant_sq"]
	halfmove_clock = saved["halfmove_clock"]

func _update_castling_rights(from_sq: int, to_sq: int) -> void:
	# King moves
	if from_sq == 4:   # e1
		castling_rights[0] = false
		castling_rights[1] = false
	if from_sq == 60:  # e8
		castling_rights[2] = false
		castling_rights[3] = false
	# Rook moves or captured
	if from_sq == 7 or to_sq == 7:    # h1
		castling_rights[0] = false
	if from_sq == 0 or to_sq == 0:    # a1
		castling_rights[1] = false
	if from_sq == 63 or to_sq == 63:  # h8
		castling_rights[2] = false
	if from_sq == 56 or to_sq == 56:  # a8
		castling_rights[3] = false

# =============================================================================
# Attack detection
# =============================================================================

func is_square_attacked(square: int, by_color: int) -> bool:
	# Pawn attacks
	var pawn_dir: int = -1 if by_color == PieceColor.WHITE else 1
	var pawn_piece: int = make_piece(PieceType.PAWN, by_color)
	for df: int in [-1, 1]:
		var atk_sq: int = square + pawn_dir * 8 + df
		if is_valid_sq(atk_sq) and abs(file_of(atk_sq) - file_of(square)) == 1:
			if board[atk_sq] == pawn_piece:
				return true

	# Knight attacks
	var knight_piece: int = make_piece(PieceType.KNIGHT, by_color)
	for offset: int in KNIGHT_OFFSETS:
		var atk_sq: int = square + offset
		if is_valid_sq(atk_sq) and _valid_knight_move(square, atk_sq):
			if board[atk_sq] == knight_piece:
				return true

	# King attacks
	var king_piece: int = make_piece(PieceType.KING, by_color)
	for offset: int in QUEEN_KING_OFFSETS:
		var atk_sq: int = square + offset
		if is_valid_sq(atk_sq) and _chebyshev_dist(square, atk_sq) == 1:
			if board[atk_sq] == king_piece:
				return true

	# Sliding pieces: bishop/queen diagonals
	for offset: int in BISHOP_OFFSETS:
		var sq: int = square + offset
		while is_valid_sq(sq) and _chebyshev_dist(sq - offset, sq) == 1:
			var p: int = board[sq]
			if p != 0:
				if piece_color(p) == by_color:
					var t: int = piece_type(p)
					if t == PieceType.BISHOP or t == PieceType.QUEEN:
						return true
				break
			sq += offset

	# Sliding pieces: rook/queen straights
	for offset: int in ROOK_OFFSETS:
		var sq: int = square + offset
		while is_valid_sq(sq) and _chebyshev_dist(sq - offset, sq) == 1:
			var p: int = board[sq]
			if p != 0:
				if piece_color(p) == by_color:
					var t: int = piece_type(p)
					if t == PieceType.ROOK or t == PieceType.QUEEN:
						return true
				break
			sq += offset

	return false

func _valid_knight_move(from: int, to: int) -> bool:
	var df: int = abs(file_of(from) - file_of(to))
	var dr: int = abs(rank_of(from) - rank_of(to))
	return (df == 1 and dr == 2) or (df == 2 and dr == 1)

func _chebyshev_dist(a: int, b: int) -> int:
	return maxi(abs(rank_of(a) - rank_of(b)), abs(file_of(a) - file_of(b)))

# =============================================================================
# Check / Checkmate / Stalemate / Draw
# =============================================================================

func is_in_check(color: int) -> bool:
	return is_square_attacked(king_sq[color], 1 - color)

func is_checkmate() -> bool:
	if not is_in_check(side_to_move):
		return false
	return get_legal_moves().is_empty()

func is_stalemate() -> bool:
	if is_in_check(side_to_move):
		return false
	return get_legal_moves().is_empty()

func is_draw() -> bool:
	if halfmove_clock >= 100:
		return true
	if _is_insufficient_material():
		return true
	return false

func _is_insufficient_material() -> bool:
	var white_pieces: Array[int] = []
	var black_pieces: Array[int] = []

	for sq: int in range(64):
		var p: int = board[sq]
		if p == 0:
			continue
		var t: int = piece_type(p)
		if t == PieceType.KING:
			continue
		if piece_color(p) == PieceColor.WHITE:
			white_pieces.append(t)
		else:
			black_pieces.append(t)

	var total: int = white_pieces.size() + black_pieces.size()

	# K vs K
	if total == 0:
		return true
	# K+B vs K or K+N vs K
	if total == 1:
		var lone: int = white_pieces[0] if white_pieces.size() == 1 else black_pieces[0]
		if lone == PieceType.BISHOP or lone == PieceType.KNIGHT:
			return true
	# K+B vs K+B same color bishops
	if total == 2 and white_pieces.size() == 1 and black_pieces.size() == 1:
		if white_pieces[0] == PieceType.BISHOP and black_pieces[0] == PieceType.BISHOP:
			var wb_sq: int = -1
			var bb_sq: int = -1
			for sq: int in range(64):
				var p: int = board[sq]
				if p == 0:
					continue
				if piece_type(p) == PieceType.BISHOP:
					if piece_color(p) == PieceColor.WHITE:
						wb_sq = sq
					else:
						bb_sq = sq
			if wb_sq >= 0 and bb_sq >= 0:
				var wb_color: int = (rank_of(wb_sq) + file_of(wb_sq)) % 2
				var bb_color: int = (rank_of(bb_sq) + file_of(bb_sq)) % 2
				if wb_color == bb_color:
					return true
	return false

# =============================================================================
# Move generation
# =============================================================================

func get_legal_moves() -> Array[Dictionary]:
	var pseudo: Array[Dictionary] = _generate_pseudo_legal_moves()
	var legal: Array[Dictionary] = []
	for move: Dictionary in pseudo:
		make_move(move)
		if not is_in_check(1 - side_to_move):
			legal.append(move)
		unmake_move(move)
	return legal

func _generate_pseudo_legal_moves() -> Array[Dictionary]:
	var moves: Array[Dictionary] = []
	var color: int = side_to_move

	for sq: int in range(64):
		var piece: int = board[sq]
		if piece == 0 or piece_color(piece) != color:
			continue
		var type: int = piece_type(piece)
		match type:
			PieceType.PAWN:
				_generate_pawn_moves(sq, color, moves)
			PieceType.KNIGHT:
				_generate_knight_moves(sq, color, moves)
			PieceType.BISHOP:
				_generate_sliding_moves(sq, color, BISHOP_OFFSETS, moves)
			PieceType.ROOK:
				_generate_sliding_moves(sq, color, ROOK_OFFSETS, moves)
			PieceType.QUEEN:
				_generate_sliding_moves(sq, color, QUEEN_KING_OFFSETS, moves)
			PieceType.KING:
				_generate_king_moves(sq, color, moves)
	return moves

func _generate_pawn_moves(sq: int, color: int, moves: Array[Dictionary]) -> void:
	var dir: int = 1 if color == PieceColor.WHITE else -1
	var start_rank: int = 1 if color == PieceColor.WHITE else 6
	var promo_rank: int = 7 if color == PieceColor.WHITE else 0

	# Single push
	var forward: int = sq + dir * 8
	if is_valid_sq(forward) and board[forward] == 0:
		if rank_of(forward) == promo_rank:
			_add_promotion_moves(sq, forward, moves)
		else:
			moves.append(_create_move(sq, forward))

		# Double push
		if rank_of(sq) == start_rank:
			var double: int = sq + dir * 16
			if board[double] == 0:
				moves.append(_create_move(sq, double, MoveFlag.DOUBLE_PAWN))

	# Captures
	for df: int in [-1, 1]:
		var cap_sq: int = sq + dir * 8 + df
		if not is_valid_sq(cap_sq) or abs(file_of(cap_sq) - file_of(sq)) != 1:
			continue
		if board[cap_sq] != 0 and piece_color(board[cap_sq]) != color:
			if rank_of(cap_sq) == promo_rank:
				_add_promotion_moves(sq, cap_sq, moves)
			else:
				moves.append(_create_move(sq, cap_sq))
		elif cap_sq == en_passant_sq:
			var ep_move: Dictionary = _create_move(sq, cap_sq, MoveFlag.EN_PASSANT)
			ep_move["piece_captured"] = make_piece(PieceType.PAWN, 1 - color)
			moves.append(ep_move)

func _add_promotion_moves(from: int, to: int, moves: Array[Dictionary]) -> void:
	for flag: int in [MoveFlag.PROMOTE_QUEEN, MoveFlag.PROMOTE_ROOK, MoveFlag.PROMOTE_BISHOP, MoveFlag.PROMOTE_KNIGHT]:
		moves.append(_create_move(from, to, flag))

func _generate_knight_moves(sq: int, color: int, moves: Array[Dictionary]) -> void:
	for offset: int in KNIGHT_OFFSETS:
		var to: int = sq + offset
		if not is_valid_sq(to) or not _valid_knight_move(sq, to):
			continue
		var target: int = board[to]
		if target == 0 or piece_color(target) != color:
			moves.append(_create_move(sq, to))

func _generate_sliding_moves(sq: int, color: int, offsets: Array[int], moves: Array[Dictionary]) -> void:
	for offset: int in offsets:
		var to: int = sq + offset
		while is_valid_sq(to) and _chebyshev_dist(to - offset, to) == 1:
			var target: int = board[to]
			if target == 0:
				moves.append(_create_move(sq, to))
			elif piece_color(target) != color:
				moves.append(_create_move(sq, to))
				break
			else:
				break
			to += offset

func _generate_king_moves(sq: int, color: int, moves: Array[Dictionary]) -> void:
	for offset: int in QUEEN_KING_OFFSETS:
		var to: int = sq + offset
		if not is_valid_sq(to) or _chebyshev_dist(sq, to) != 1:
			continue
		var target: int = board[to]
		if target == 0 or piece_color(target) != color:
			moves.append(_create_move(sq, to))

	# Castling
	if is_in_check(color):
		return

	var base_rank: int = 0 if color == PieceColor.WHITE else 7
	var king_sq_expected: int = sq_index(base_rank, 4)
	if sq != king_sq_expected:
		return

	var ks_idx: int = 0 if color == PieceColor.WHITE else 2
	var qs_idx: int = 1 if color == PieceColor.WHITE else 3

	# Kingside
	if castling_rights[ks_idx]:
		var f_sq: int = sq_index(base_rank, 5)
		var g_sq: int = sq_index(base_rank, 6)
		var rook_sq: int = sq_index(base_rank, 7)
		if board[f_sq] == 0 and board[g_sq] == 0:
			if board[rook_sq] == make_piece(PieceType.ROOK, color):
				if not is_square_attacked(f_sq, 1 - color) and not is_square_attacked(g_sq, 1 - color):
					moves.append(_create_move(sq, g_sq, MoveFlag.CASTLE_KINGSIDE))

	# Queenside
	if castling_rights[qs_idx]:
		var d_sq: int = sq_index(base_rank, 3)
		var c_sq: int = sq_index(base_rank, 2)
		var b_sq: int = sq_index(base_rank, 1)
		var rook_sq: int = sq_index(base_rank, 0)
		if board[d_sq] == 0 and board[c_sq] == 0 and board[b_sq] == 0:
			if board[rook_sq] == make_piece(PieceType.ROOK, color):
				if not is_square_attacked(d_sq, 1 - color) and not is_square_attacked(c_sq, 1 - color):
					moves.append(_create_move(sq, c_sq, MoveFlag.CASTLE_QUEENSIDE))

# =============================================================================
# Standard Algebraic Notation
# =============================================================================

func move_to_san(move: Dictionary) -> String:
	var flags: int = move["flags"]
	if flags & MoveFlag.CASTLE_KINGSIDE:
		return "O-O"
	if flags & MoveFlag.CASTLE_QUEENSIDE:
		return "O-O-O"

	var piece: int = move["piece_moved"]
	var type: int = piece_type(piece)
	var from_sq: int = move["from_sq"]
	var to_sq: int = move["to_sq"]
	var san: String = ""

	if type != PieceType.PAWN:
		san += _piece_type_char(type)
		san += _disambiguate(move)
	else:
		if move["piece_captured"] != 0 or (flags & MoveFlag.EN_PASSANT):
			san += char(file_of(from_sq) + 97)

	if move["piece_captured"] != 0 or (flags & MoveFlag.EN_PASSANT):
		san += "x"

	san += square_to_algebraic(to_sq)

	if flags & PROMOTION_FLAGS:
		san += "=" + _piece_type_char(_promotion_flag_to_type(flags))

	# Check / checkmate
	make_move(move)
	if is_in_check(side_to_move):
		if is_checkmate():
			san += "#"
		else:
			san += "+"
	unmake_move(move)

	return san

func _piece_type_char(type: int) -> String:
	match type:
		PieceType.KNIGHT: return "N"
		PieceType.BISHOP: return "B"
		PieceType.ROOK: return "R"
		PieceType.QUEEN: return "Q"
		PieceType.KING: return "K"
	return ""

func _disambiguate(move: Dictionary) -> String:
	var from_sq: int = move["from_sq"]
	var to_sq: int = move["to_sq"]
	var piece: int = move["piece_moved"]
	var type: int = piece_type(piece)
	var color: int = piece_color(piece)

	var same_target: Array[int] = []
	for sq: int in range(64):
		if sq == from_sq:
			continue
		var p: int = board[sq]
		if p == 0 or piece_type(p) != type or piece_color(p) != color:
			continue
		# Check if this piece can also reach to_sq
		var test_move: Dictionary = _create_move(sq, to_sq)
		if _is_pseudo_legal_move(test_move):
			make_move(test_move)
			var leaves_in_check: bool = is_in_check(1 - side_to_move)
			unmake_move(test_move)
			if not leaves_in_check:
				same_target.append(sq)

	if same_target.is_empty():
		return ""

	var need_file: bool = false
	var need_rank: bool = false
	for sq: int in same_target:
		if file_of(sq) == file_of(from_sq):
			need_rank = true
		if rank_of(sq) == rank_of(from_sq):
			need_file = true

	if not need_file and not need_rank:
		need_file = true

	var result: String = ""
	if need_file:
		result += char(file_of(from_sq) + 97)
	if need_rank:
		result += str(rank_of(from_sq) + 1)
	return result

func _is_pseudo_legal_move(move: Dictionary) -> bool:
	var piece: int = move["piece_moved"]
	var type: int = piece_type(piece)
	var from: int = move["from_sq"]
	var to: int = move["to_sq"]
	var target: int = board[to]

	if target != 0 and piece_color(target) == piece_color(piece):
		return false

	match type:
		PieceType.KNIGHT:
			return _valid_knight_move(from, to)
		PieceType.BISHOP:
			return _is_diagonal(from, to) and _is_path_clear(from, to)
		PieceType.ROOK:
			return _is_straight(from, to) and _is_path_clear(from, to)
		PieceType.QUEEN:
			return (_is_diagonal(from, to) or _is_straight(from, to)) and _is_path_clear(from, to)
		PieceType.KING:
			return _chebyshev_dist(from, to) == 1
	return false

func _is_diagonal(from: int, to: int) -> bool:
	var dr: int = abs(rank_of(from) - rank_of(to))
	var df: int = abs(file_of(from) - file_of(to))
	return dr == df and dr > 0

func _is_straight(from: int, to: int) -> bool:
	return rank_of(from) == rank_of(to) or file_of(from) == file_of(to)

func _is_path_clear(from: int, to: int) -> bool:
	var dr: int = signi(rank_of(to) - rank_of(from))
	var df: int = signi(file_of(to) - file_of(from))
	var offset: int = dr * 8 + df
	var sq: int = from + offset
	while sq != to:
		if board[sq] != 0:
			return false
		sq += offset
	return true
