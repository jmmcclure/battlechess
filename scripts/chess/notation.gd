class_name ChessNotation
extends RefCounted
## Converts chess moves to/from Standard Algebraic Notation (SAN) and tracks game history.

var move_history: Array[String] = []
var full_move_list: Array[Dictionary] = []


func clear() -> void:
	move_history.clear()
	full_move_list.clear()


func add_move(move: Dictionary, engine: RefCounted) -> String:
	var san := move_to_san(move, engine)
	move_history.append(san)
	full_move_list.append(move)
	return san


func move_to_san(move: Dictionary, engine: RefCounted) -> String:
	var from_sq: int = move["from_sq"]
	var to_sq: int = move["to_sq"]
	var piece_type: int = move.get("piece_moved", 0) & 7
	var flags: int = move.get("flags", 0)
	var captured: int = move.get("piece_captured", 0)
	var result := ""

	# Castling
	if flags & 4:  # Kingside
		result = "O-O"
	elif flags & 8:  # Queenside
		result = "O-O-O"
	else:
		# Piece letter (not for pawns)
		var piece_letters := ["", "", "R", "N", "B", "Q", "K"]
		if piece_type > 1:
			result += piece_letters[piece_type]

		# Disambiguation would go here (checking if multiple pieces of same type can reach target)
		# Simplified: include file for pawn captures
		if piece_type == 1 and captured > 0:
			result += _file_letter(from_sq % 8)

		# Capture indicator
		if captured > 0:
			result += "x"

		# Target square
		result += _square_name(to_sq)

		# Promotion
		if flags & 16:
			result += "=Q"
		elif flags & 32:
			result += "=R"
		elif flags & 64:
			result += "=B"
		elif flags & 128:
			result += "=N"

	# Check/checkmate indicators (would need engine state after move)
	# These get appended externally if needed

	return result


func get_formatted_history() -> String:
	var result := ""
	for i in range(move_history.size()):
		if i % 2 == 0:
			result += "%d. " % (i / 2 + 1)
		result += move_history[i]
		if i % 2 == 0:
			result += " "
		else:
			result += "\n"
	return result


func get_pgn(white_name: String = "White", black_name: String = "Black",
		result: String = "*") -> String:
	var pgn := ""
	pgn += "[White \"%s\"]\n" % white_name
	pgn += "[Black \"%s\"]\n" % black_name
	pgn += "[Result \"%s\"]\n" % result
	pgn += "\n"
	pgn += get_formatted_history()
	pgn += result
	return pgn


func _square_name(sq: int) -> String:
	var file := sq % 8
	var rank := sq / 8
	return _file_letter(file) + str(rank + 1)


func _file_letter(file: int) -> String:
	return char("a".unicode_at(0) + file)
