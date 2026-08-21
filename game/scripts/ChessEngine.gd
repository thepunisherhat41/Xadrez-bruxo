class_name ChessEngine
extends RefCounted

const START_FEN := "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"
const FILES := "abcdefgh"

var board: Dictionary = {}
var turn := "w"
var castling := "KQkq"
var en_passant := "-"
var halfmove := 0
var fullmove := 1
var repetition: Dictionary = {}

func _init(fen := START_FEN) -> void:
	load_fen(fen)

func load_fen(fen: String) -> void:
	board.clear()
	var parts := fen.strip_edges().split(" ")
	var ranks := String(parts[0]).split("/")
	for row in range(8):
		var file_index := 0
		for token in String(ranks[row]):
			if token.is_valid_int():
				file_index += int(token)
			else:
				var color := "w" if token == token.to_upper() else "b"
				var kind := token.to_upper()
				var square := FILES.substr(file_index, 1) + str(8 - row)
				board[square] = color + kind
				file_index += 1
	turn = String(parts[1]) if parts.size() > 1 else "w"
	castling = String(parts[2]) if parts.size() > 2 else "-"
	en_passant = String(parts[3]) if parts.size() > 3 else "-"
	halfmove = int(parts[4]) if parts.size() > 4 else 0
	fullmove = int(parts[5]) if parts.size() > 5 else 1
	repetition.clear()
	_record_repetition()

func piece_at(square: String) -> String:
	return String(board.get(square, ""))

func legal_moves(from_square := "") -> Array:
	var moves: Array = []
	for square_value in board.keys():
		var square := String(square_value)
		var piece := piece_at(square)
		if not piece.begins_with(turn):
			continue
		if not from_square.is_empty() and square != from_square:
			continue
		for move in _pseudo_moves(square, piece):
			if not _move_leaves_king_in_check(move, turn):
				moves.append(move)
	return moves

func make_move(from_square: String, to_square: String, promotion := "Q") -> Dictionary:
	var chosen: Dictionary = {}
	for move in legal_moves(from_square):
		if String(move.get("to", "")) != to_square:
			continue
		if bool(move.get("promotion", false)):
			move["promote_to"] = promotion.to_upper()
		chosen = move
		break
	if chosen.is_empty():
		return {"ok": false, "error": "illegal_move"}
	var captured := piece_at(to_square)
	_apply_move(chosen, true)
	return {
		"ok": true,
		"move": chosen,
		"captured": captured,
		"fen": to_fen(),
		"status": game_status()
	}

func game_status() -> Dictionary:
	var moves := legal_moves()
	var check := is_in_check(turn)
	var checkmate := check and moves.is_empty()
	var stalemate := not check and moves.is_empty()
	var repetition_draw := int(repetition.get(_position_key(), 0)) >= 3
	var fifty_move := halfmove >= 100
	var insufficient := _insufficient_material()
	var draw := stalemate or repetition_draw or fifty_move or insufficient
	return {
		"check": check,
		"checkmate": checkmate,
		"stalemate": stalemate,
		"draw": draw,
		"game_over": checkmate or draw,
		"winner": _other(turn) if checkmate else ""
	}

func is_in_check(color: String) -> bool:
	var king_square := ""
	for square_value in board.keys():
		var square := String(square_value)
		if piece_at(square) == color + "K":
			king_square = square
			break
	if king_square.is_empty():
		return true
	return _square_attacked(king_square, _other(color))

func to_fen() -> String:
	var rank_parts: Array[String] = []
	for rank in range(8, 0, -1):
		var empty := 0
		var text := ""
		for file_index in range(8):
			var square := FILES.substr(file_index, 1) + str(rank)
			var piece := piece_at(square)
			if piece.is_empty():
				empty += 1
				continue
			if empty > 0:
				text += str(empty)
				empty = 0
			var kind := piece.substr(1, 1)
			text += kind if piece.begins_with("w") else kind.to_lower()
		if empty > 0:
			text += str(empty)
		rank_parts.append(text)
	return "/".join(rank_parts) + " %s %s %s %d %d" % [turn, castling if not castling.is_empty() else "-", en_passant, halfmove, fullmove]

func _pseudo_moves(square: String, piece: String) -> Array:
	var kind := piece.substr(1, 1)
	match kind:
		"P": return _pawn_moves(square, piece)
		"N": return _jump_moves(square, piece, [[1,2],[2,1],[2,-1],[1,-2],[-1,-2],[-2,-1],[-2,1],[-1,2]])
		"B": return _slide_moves(square, piece, [[1,1],[1,-1],[-1,1],[-1,-1]])
		"R": return _slide_moves(square, piece, [[1,0],[-1,0],[0,1],[0,-1]])
		"Q": return _slide_moves(square, piece, [[1,0],[-1,0],[0,1],[0,-1],[1,1],[1,-1],[-1,1],[-1,-1]])
		"K": return _king_moves(square, piece)
	return []

func _pawn_moves(square: String, piece: String) -> Array:
	var moves: Array = []
	var color := piece.substr(0, 1)
	var pos := _coords(square)
	var dir := 1 if color == "w" else -1
	var start_rank := 1 if color == "w" else 6
	var promo_rank := 7 if color == "w" else 0
	var one := Vector2i(pos.x, pos.y + dir)
	if _inside(one) and piece_at(_square(one)).is_empty():
		moves.append(_move(square, _square(one), one.y == promo_rank))
		var two := Vector2i(pos.x, pos.y + dir * 2)
		if pos.y == start_rank and piece_at(_square(two)).is_empty():
			var double_move := _move(square, _square(two))
			double_move["double_pawn"] = true
			moves.append(double_move)
	for dx in [-1, 1]:
		var target := Vector2i(pos.x + dx, pos.y + dir)
		if not _inside(target):
			continue
		var target_square := _square(target)
		var victim := piece_at(target_square)
		if not victim.is_empty() and victim.substr(0, 1) != color:
			var capture := _move(square, target_square, target.y == promo_rank)
			capture["capture"] = true
			moves.append(capture)
		elif target_square == en_passant:
			var ep := _move(square, target_square)
			ep["en_passant"] = true
			moves.append(ep)
	return moves

func _jump_moves(square: String, piece: String, offsets: Array) -> Array:
	var moves: Array = []
	var color := piece.substr(0, 1)
	var pos := _coords(square)
	for offset in offsets:
		var target := Vector2i(pos.x + int(offset[0]), pos.y + int(offset[1]))
		if not _inside(target):
			continue
		var target_square := _square(target)
		var victim := piece_at(target_square)
		if victim.is_empty() or victim.substr(0, 1) != color:
			var item := _move(square, target_square)
			item["capture"] = not victim.is_empty()
			moves.append(item)
	return moves

func _slide_moves(square: String, piece: String, directions: Array) -> Array:
	var moves: Array = []
	var color := piece.substr(0, 1)
	var pos := _coords(square)
	for direction in directions:
		var dx := int(direction[0])
		var dy := int(direction[1])
		var target := Vector2i(pos.x + dx, pos.y + dy)
		while _inside(target):
			var target_square := _square(target)
			var victim := piece_at(target_square)
			if victim.is_empty():
				moves.append(_move(square, target_square))
			else:
				if victim.substr(0, 1) != color:
					var capture := _move(square, target_square)
					capture["capture"] = true
					moves.append(capture)
				break
			target += Vector2i(dx, dy)
	return moves

func _king_moves(square: String, piece: String) -> Array:
	var moves := _jump_moves(square, piece, [[1,0],[-1,0],[0,1],[0,-1],[1,1],[1,-1],[-1,1],[-1,-1]])
	var color := piece.substr(0, 1)
	if is_in_check(color):
		return moves
	var rank := "1" if color == "w" else "8"
	var king_side := "K" if color == "w" else "k"
	var queen_side := "Q" if color == "w" else "q"
	if castling.contains(king_side):
		var f := "f" + rank
		var g := "g" + rank
		var rook := "h" + rank
		if piece_at(f).is_empty() and piece_at(g).is_empty() and piece_at(rook) == color + "R":
			if not _square_attacked(f, _other(color)) and not _square_attacked(g, _other(color)):
				var castle := _move(square, g)
				castle["castle"] = "king"
				moves.append(castle)
	if castling.contains(queen_side):
		var d := "d" + rank
		var c := "c" + rank
		var b := "b" + rank
		var rook_q := "a" + rank
		if piece_at(d).is_empty() and piece_at(c).is_empty() and piece_at(b).is_empty() and piece_at(rook_q) == color + "R":
			if not _square_attacked(d, _other(color)) and not _square_attacked(c, _other(color)):
				var castle_q := _move(square, c)
				castle_q["castle"] = "queen"
				moves.append(castle_q)
	return moves

func _square_attacked(square: String, by_color: String) -> bool:
	for from_value in board.keys():
		var from_square := String(from_value)
		var piece := piece_at(from_square)
		if not piece.begins_with(by_color):
			continue
		var kind := piece.substr(1, 1)
		if kind == "P":
			var pos := _coords(from_square)
			var dir := 1 if by_color == "w" else -1
			for dx in [-1, 1]:
				var t := Vector2i(pos.x + dx, pos.y + dir)
				if _inside(t) and _square(t) == square:
					return true
		elif kind == "K":
			var king_pos := _coords(from_square)
			var target_pos := _coords(square)
			if maxi(abs(king_pos.x - target_pos.x), abs(king_pos.y - target_pos.y)) == 1:
				return true
		else:
			for move in _pseudo_moves_without_castle(from_square, piece):
				if String(move.get("to", "")) == square:
					return true
	return false

func _pseudo_moves_without_castle(square: String, piece: String) -> Array:
	var kind := piece.substr(1, 1)
	if kind == "K":
		return _jump_moves(square, piece, [[1,0],[-1,0],[0,1],[0,-1],[1,1],[1,-1],[-1,1],[-1,-1]])
	if kind == "P":
		return []
	return _pseudo_moves(square, piece)

func _move_leaves_king_in_check(move: Dictionary, color: String) -> bool:
	var snapshot_board := board.duplicate(true)
	var snapshot_turn := turn
	var snapshot_castling := castling
	var snapshot_ep := en_passant
	var snapshot_halfmove := halfmove
	var snapshot_fullmove := fullmove
	_apply_move(move, false)
	var result := is_in_check(color)
	board = snapshot_board
	turn = snapshot_turn
	castling = snapshot_castling
	en_passant = snapshot_ep
	halfmove = snapshot_halfmove
	fullmove = snapshot_fullmove
	return result

func _apply_move(move: Dictionary, track_history: bool) -> void:
	var from_square := String(move["from"])
	var to_square := String(move["to"])
	var piece := piece_at(from_square)
	var color := piece.substr(0, 1)
	var kind := piece.substr(1, 1)
	var captured := piece_at(to_square)

	board.erase(from_square)
	if bool(move.get("en_passant", false)):
		var to_pos := _coords(to_square)
		var victim_pos := Vector2i(to_pos.x, to_pos.y - (1 if color == "w" else -1))
		board.erase(_square(victim_pos))
	if move.has("castle"):
		var rank := "1" if color == "w" else "8"
		if String(move["castle"]) == "king":
			board["f" + rank] = board.get("h" + rank, "")
			board.erase("h" + rank)
		else:
			board["d" + rank] = board.get("a" + rank, "")
			board.erase("a" + rank)

	if bool(move.get("promotion", false)):
		piece = color + String(move.get("promote_to", "Q")).to_upper()
	board[to_square] = piece

	if kind == "K":
		castling = castling.replace("K", "").replace("Q", "") if color == "w" else castling.replace("k", "").replace("q", "")
	if from_square == "a1" or to_square == "a1": castling = castling.replace("Q", "")
	if from_square == "h1" or to_square == "h1": castling = castling.replace("K", "")
	if from_square == "a8" or to_square == "a8": castling = castling.replace("q", "")
	if from_square == "h8" or to_square == "h8": castling = castling.replace("k", "")

	en_passant = "-"
	if bool(move.get("double_pawn", false)):
		var from_pos := _coords(from_square)
		var to_pos := _coords(to_square)
		en_passant = _square(Vector2i(from_pos.x, (from_pos.y + to_pos.y) / 2))

	if kind == "P" or not captured.is_empty() or bool(move.get("en_passant", false)):
		halfmove = 0
	else:
		halfmove += 1
	if color == "b":
		fullmove += 1
	turn = _other(turn)
	if track_history:
		_record_repetition()

func _insufficient_material() -> bool:
	var non_kings: Array[String] = []
	for value in board.values():
		var piece := String(value)
		if piece.substr(1, 1) != "K":
			non_kings.append(piece)
	if non_kings.is_empty():
		return true
	if non_kings.size() == 1 and non_kings[0].substr(1, 1) in ["B", "N"]:
		return true
	return false

func _position_key() -> String:
	var fen_parts := to_fen().split(" ")
	return "%s %s %s %s" % [fen_parts[0], fen_parts[1], fen_parts[2], fen_parts[3]]

func _record_repetition() -> void:
	var key := _position_key()
	repetition[key] = int(repetition.get(key, 0)) + 1

func _move(from_square: String, to_square: String, promotion := false) -> Dictionary:
	return {"from": from_square, "to": to_square, "promotion": promotion}

func _coords(square: String) -> Vector2i:
	return Vector2i(FILES.find(square.substr(0, 1)), int(square.substr(1, 1)) - 1)

func _square(pos: Vector2i) -> String:
	return FILES.substr(pos.x, 1) + str(pos.y + 1)

func _inside(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < 8 and pos.y >= 0 and pos.y < 8

func _other(color: String) -> String:
	return "b" if color == "w" else "w"
