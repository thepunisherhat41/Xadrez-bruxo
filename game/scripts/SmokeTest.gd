extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var engine := ChessEngine.new()
	_assert(engine.legal_moves().size() == 20, "initial position should have 20 legal moves")
	_assert(bool(engine.make_move("e2", "e4").get("ok", false)), "e2e4 should be legal")
	_assert(engine.turn == "b", "turn should switch")

	var ep := ChessEngine.new("rnbqkbnr/pppp1ppp/8/4p3/3P4/8/PPP1PPPP/RNBQKBNR w KQkq e6 0 2")
	_assert(bool(ep.make_move("d4", "e5").get("ok", false)), "normal pawn capture-like advance should work where legal")

	var castle := ChessEngine.new("r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1")
	_assert(bool(castle.make_move("e1", "g1").get("ok", false)), "white king-side castle should work")
	_assert(castle.piece_at("f1") == "wR", "rook should move on castling")

	var promotion := ChessEngine.new("4k3/P7/8/8/8/8/8/4K3 w - - 0 1")
	_assert(bool(promotion.make_move("a7", "a8", "Q").get("ok", false)), "promotion should work")
	_assert(promotion.piece_at("a8") == "wQ", "promotion should create queen")

	var mate := ChessEngine.new()
	mate.make_move("f2", "f3")
	mate.make_move("e7", "e5")
	mate.make_move("g2", "g4")
	mate.make_move("d8", "h4")
	_assert(bool(mate.game_status()["checkmate"]), "fool's mate should be checkmate")

	var bot_engine := ChessEngine.new()
	bot_engine.make_move("e2", "e4")
	var bot := OfflineBot.new("b", 1)
	var choice := bot.choose_move(bot_engine)
	_assert(not choice.is_empty(), "offline AI should choose a move")

	print("CINEMATIC CHESS SMOKE: PASS")
	quit(0)

func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error("SMOKE FAIL: " + message)
	print("CINEMATIC CHESS SMOKE: FAIL")
	quit(1)
