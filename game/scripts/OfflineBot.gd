class_name OfflineBot
extends RefCounted

const VALUE := {"P": 100, "N": 320, "B": 330, "R": 500, "Q": 900, "K": 20000}

var color := "b"
var depth := 2

func _init(bot_color := "b", search_depth := 2) -> void:
	color = bot_color
	depth = search_depth

func choose_move(engine: ChessEngine) -> Dictionary:
	var moves := engine.legal_moves()
	if moves.is_empty():
		return {}
	var best_score := -100000000
	var best_moves: Array = []
	for move in moves:
		var child := ChessEngine.new(engine.to_fen())
		var result := child.make_move(String(move["from"]), String(move["to"]), "Q")
		if not bool(result.get("ok", false)):
			continue
		var score := -_negamax(child, depth - 1, -100000000, 100000000)
		if score > best_score:
			best_score = score
			best_moves = [move]
		elif score == best_score:
			best_moves.append(move)
	if best_moves.is_empty():
		return moves[0]
	return best_moves[randi_range(0, best_moves.size() - 1)]

func _negamax(engine: ChessEngine, remaining: int, alpha: int, beta: int) -> int:
	var status := engine.game_status()
	if bool(status["checkmate"]):
		return -900000 + (depth - remaining)
	if bool(status["draw"]):
		return 0
	if remaining <= 0:
		return _evaluate_for_side_to_move(engine)
	var value := -100000000
	for move in engine.legal_moves():
		var child := ChessEngine.new(engine.to_fen())
		var result := child.make_move(String(move["from"]), String(move["to"]), "Q")
		if not bool(result.get("ok", false)):
			continue
		var score := -_negamax(child, remaining - 1, -beta, -alpha)
		value = maxi(value, score)
		alpha = maxi(alpha, score)
		if alpha >= beta:
			break
	return value

func _evaluate_for_side_to_move(engine: ChessEngine) -> int:
	var white := 0
	var black := 0
	for value in engine.board.values():
		var piece := String(value)
		var score := int(VALUE.get(piece.substr(1, 1), 0))
		if piece.begins_with("w"):
			white += score
		else:
			black += score
	var material := white - black
	return material if engine.turn == "w" else -material
