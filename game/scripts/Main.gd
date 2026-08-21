extends Node

const MODE_MENU := "menu"
const MODE_AI := "offline_ai"
const MODE_LOCAL := "offline_local"
const MODE_ONLINE := "online"
const BOARD_PLANE_Y := Arena.BOARD_Y + 0.12

var engine := ChessEngine.new()
var bot := OfflineBot.new("b", 2)
var network: NetworkClient
var arena_root: Node3D
var camera_rig: CameraRig
var squares: Dictionary = {}
var pieces: Dictionary = {}
var mode := MODE_MENU
var online_color := ""
var room_code := ""
var selected_square := ""
var legal_targets: Array[String] = []
var interaction_locked := false
var pending_online_action: Dictionary = {}

var ui_layer: CanvasLayer
var ui_root: Control
var menu_overlay: ColorRect
var orientation_overlay: ColorRect
var turn_label: Label
var room_label: Label
var status_label: Label
var white_clock: Label
var black_clock: Label
var announcement: Label
var name_input: LineEdit
var room_input: LineEdit
var resume_button: Button

var active_touches: Dictionary = {}
var touch_start := Vector2.ZERO
var touch_dragged := false
var previous_pinch_distance := 0.0

func _ready() -> void:
	DisplayServer.window_set_title("Xadrez Bruxo")
	_build_world()
	_build_ui()
	_build_network()
	_render_position()
	_update_orientation()
	get_viewport().size_changed.connect(_update_orientation)

func _build_world() -> void:
	arena_root = Node3D.new()
	arena_root.name = "CinematicArena"
	add_child(arena_root)
	var built := Arena.build(arena_root)
	squares = built["squares"]
	camera_rig = CameraRig.new()
	camera_rig.name = "CameraRig"
	arena_root.add_child(camera_rig)
	camera_rig.set_side("w", false)

func _build_network() -> void:
	network = NetworkClient.new()
	network.name = "NetworkClient"
	add_child(network)
	network.opened.connect(_on_network_opened)
	network.closed.connect(func():
		if mode == MODE_ONLINE:
			status_label.text = "CONEXÃO INTERROMPIDA"
			_show_announcement("CONEXÃO INTERROMPIDA", Color("#ff6577"), 1.8)
	)
	network.message.connect(_on_network_message)
	network.status.connect(func(text: String): status_label.text = text)

func _build_ui() -> void:
	ui_layer = CanvasLayer.new()
	add_child(ui_layer)
	ui_root = Control.new()
	ui_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_layer.add_child(ui_root)
	_build_hud()
	_build_menu()
	_build_orientation_overlay()
	_build_announcement()

func _build_hud() -> void:
	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.offset_left = -520
	panel.offset_right = 520
	panel.offset_top = 18
	panel.offset_bottom = 94
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.015, 0.02, 0.035, 0.92), 18, Color("#54462c")))
	ui_root.add_child(panel)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	panel.add_child(row)

	var menu_button := _button("☰", 64, Color("#24293a"))
	menu_button.custom_minimum_size.x = 64
	menu_button.pressed.connect(_return_to_menu)
	row.add_child(menu_button)

	var white_box := VBoxContainer.new()
	white_box.custom_minimum_size.x = 225
	row.add_child(white_box)
	var white_title := Label.new()
	white_title.text = "ORDEM ASTRAL"
	white_title.add_theme_font_size_override("font_size", 14)
	white_title.add_theme_color_override("font_color", Color("#79b6ff"))
	white_box.add_child(white_title)
	white_clock = Label.new()
	white_clock.text = "10:00"
	white_clock.add_theme_font_size_override("font_size", 26)
	white_box.add_child(white_clock)

	var center := VBoxContainer.new()
	center.custom_minimum_size.x = 330
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(center)
	turn_label = Label.new()
	turn_label.text = "ESCOLHA UM MODO"
	turn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	turn_label.add_theme_font_size_override("font_size", 15)
	turn_label.add_theme_color_override("font_color", Color("#e4c16e"))
	center.add_child(turn_label)
	room_label = Label.new()
	room_label.text = "OFFLINE DISPONÍVEL"
	room_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	room_label.add_theme_font_size_override("font_size", 12)
	room_label.add_theme_color_override("font_color", Color("#a8b3c6"))
	center.add_child(room_label)

	var black_box := VBoxContainer.new()
	black_box.custom_minimum_size.x = 225
	black_box.alignment = BoxContainer.ALIGNMENT_END
	row.add_child(black_box)
	var black_title := Label.new()
	black_title.text = "CORTE DO ECLIPSE"
	black_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	black_title.add_theme_font_size_override("font_size", 14)
	black_title.add_theme_color_override("font_color", Color("#b77aff"))
	black_box.add_child(black_title)
	black_clock = Label.new()
	black_clock.text = "10:00"
	black_clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	black_clock.add_theme_font_size_override("font_size", 26)
	black_box.add_child(black_clock)

	status_label = Label.new()
	status_label.anchor_left = 1.0
	status_label.anchor_right = 1.0
	status_label.offset_left = -340
	status_label.offset_right = -24
	status_label.offset_top = 106
	status_label.offset_bottom = 138
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status_label.text = "OFFLINE PRONTO"
	status_label.add_theme_font_size_override("font_size", 12)
	status_label.add_theme_color_override("font_color", Color("#78dab1"))
	ui_root.add_child(status_label)

func _build_menu() -> void:
	menu_overlay = ColorRect.new()
	menu_overlay.color = Color(0.008, 0.010, 0.018, 0.76)
	menu_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_root.add_child(menu_overlay)

	var panel := PanelContainer.new()
	panel.anchor_left = 0.0
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = 48
	panel.offset_right = 535
	panel.offset_top = -330
	panel.offset_bottom = 330
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.018, 0.022, 0.035, 0.96), 26, Color("#735c2d")))
	menu_overlay.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 30)
	margin.add_theme_constant_override("margin_right", 30)
	margin.add_theme_constant_override("margin_top", 28)
	margin.add_theme_constant_override("margin_bottom", 28)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)

	var eyebrow := Label.new()
	eyebrow.text = "MOBILE • DARK FANTASY CHESS"
	eyebrow.add_theme_font_size_override("font_size", 12)
	eyebrow.add_theme_color_override("font_color", Color("#7aaeff"))
	column.add_child(eyebrow)
	var title := Label.new()
	title.text = "XADREZ BRUXO"
	title.add_theme_font_size_override("font_size", 42)
	title.add_theme_color_override("font_color", Color("#e4c16e"))
	column.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "Guerreiros vivos. Regras reais. Magia e estratégia."
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.add_theme_font_size_override("font_size", 14)
	subtitle.add_theme_color_override("font_color", Color("#b5bdca"))
	column.add_child(subtitle)

	var ai_button := _button("⚔  OFFLINE • VS IA", 62, Color("#263e62"))
	ai_button.pressed.connect(func(): _start_offline(MODE_AI))
	column.add_child(ai_button)
	var local_button := _button("♟  OFFLINE • 1v1 LOCAL", 62, Color("#30364a"))
	local_button.pressed.connect(func(): _start_offline(MODE_LOCAL))
	column.add_child(local_button)

	resume_button = _button("↻  CONTINUAR PARTIDA", 56, Color("#252b3d"))
	resume_button.visible = not SaveGame.load_data().is_empty()
	resume_button.pressed.connect(_resume_saved)
	column.add_child(resume_button)

	var separator := HSeparator.new()
	column.add_child(separator)
	name_input = LineEdit.new()
	name_input.placeholder_text = "Seu codinome"
	name_input.text = "Mago-%03d" % randi_range(100, 999)
	name_input.custom_minimum_size.y = 52
	column.add_child(name_input)
	var create_button := _button("✦  ONLINE • CRIAR SALA", 58, Color("#462557"))
	create_button.pressed.connect(func(): _begin_online({"type": "create"}))
	column.add_child(create_button)
	var join_row := HBoxContainer.new()
	join_row.add_theme_constant_override("separation", 10)
	column.add_child(join_row)
	room_input = LineEdit.new()
	room_input.placeholder_text = "CÓDIGO"
	room_input.max_length = 6
	room_input.custom_minimum_size = Vector2(220, 54)
	room_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	join_row.add_child(room_input)
	var join_button := _button("ENTRAR", 54, Color("#392042"))
	join_button.custom_minimum_size.x = 130
	join_button.pressed.connect(func():
		var code := room_input.text.strip_edges().to_upper()
		if code.length() != 6:
			_show_announcement("CÓDIGO INVÁLIDO", Color("#ff6677"), 1.2)
			return
		_begin_online({"type": "join", "code": code})
	)
	join_row.add_child(join_button)

func _build_orientation_overlay() -> void:
	orientation_overlay = ColorRect.new()
	orientation_overlay.color = Color(0.008, 0.010, 0.018, 0.985)
	orientation_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	orientation_overlay.z_index = 100
	ui_root.add_child(orientation_overlay)
	var box := VBoxContainer.new()
	box.anchor_left = 0.5
	box.anchor_top = 0.5
	box.anchor_right = 0.5
	box.anchor_bottom = 0.5
	box.offset_left = -260
	box.offset_right = 260
	box.offset_top = -110
	box.offset_bottom = 110
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	orientation_overlay.add_child(box)
	var icon := Label.new()
	icon.text = "↻"
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon.add_theme_font_size_override("font_size", 64)
	icon.add_theme_color_override("font_color", Color("#e4c16e"))
	box.add_child(icon)
	var title := Label.new()
	title.text = "GIRE O CELULAR"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	box.add_child(title)
	var body := Label.new()
	body.text = "Xadrez Bruxo é jogado em landscape."
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_theme_font_size_override("font_size", 15)
	box.add_child(body)

func _build_announcement() -> void:
	announcement = Label.new()
	announcement.anchor_left = 0.5
	announcement.anchor_top = 0.5
	announcement.anchor_right = 0.5
	announcement.anchor_bottom = 0.5
	announcement.offset_left = -410
	announcement.offset_right = 410
	announcement.offset_top = -48
	announcement.offset_bottom = 48
	announcement.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	announcement.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	announcement.add_theme_font_size_override("font_size", 34)
	announcement.visible = false
	announcement.z_index = 50
	ui_root.add_child(announcement)

func _start_offline(next_mode: String, fen := ChessEngine.START_FEN) -> void:
	mode = next_mode
	engine.load_fen(fen)
	online_color = ""
	room_code = ""
	menu_overlay.visible = false
	interaction_locked = false
	camera_rig.set_side("w", true)
	status_label.text = "OFFLINE • SEM INTERNET"
	room_label.text = "VS IA" if mode == MODE_AI else "1v1 • MESMO APARELHO"
	_render_position()
	_update_hud()
	SaveGame.store(engine, mode)
	_show_announcement("DUELO INICIADO", Color("#e4c16e"), 1.1)

func _resume_saved() -> void:
	var data := SaveGame.load_data()
	if data.is_empty():
		return
	_start_offline(String(data.get("mode", MODE_AI)), String(data.get("fen", ChessEngine.START_FEN)))

func _return_to_menu() -> void:
	mode = MODE_MENU
	interaction_locked = false
	selected_square = ""
	legal_targets.clear()
	_clear_highlights()
	menu_overlay.visible = true
	camera_rig.set_side("w", true)
	turn_label.text = "ESCOLHA UM MODO"
	room_label.text = "OFFLINE DISPONÍVEL"
	status_label.text = "OFFLINE PRONTO"
	resume_button.visible = not SaveGame.load_data().is_empty()

func _begin_online(action: Dictionary) -> void:
	pending_online_action = action
	status_label.text = "ABRINDO PORTAL…"
	network.connect_server()

func _on_network_opened() -> void:
	if pending_online_action.is_empty():
		return
	var player_name := name_input.text.strip_edges()
	if player_name.is_empty():
		player_name = "Mago"
	if String(pending_online_action["type"]) == "create":
		network.create_room(player_name)
	else:
		network.join_room(String(pending_online_action["code"]), player_name)
	pending_online_action.clear()

func _on_network_message(data: Dictionary) -> void:
	var type := String(data.get("type", ""))
	match type:
		"room":
			mode = MODE_ONLINE
			online_color = String(data.get("color", "w"))
			room_code = String(data.get("code", ""))
			menu_overlay.visible = false
			camera_rig.set_side(online_color, true)
			room_label.text = "SALA %s • VOCÊ: %s" % [room_code, "ASTRAL" if online_color == "w" else "ECLIPSE"]
			_show_announcement("SALA %s" % room_code, Color("#e4c16e"), 1.3)
		"state":
			if data.has("fen"):
				engine.load_fen(String(data["fen"]))
				_render_position()
			_update_online_hud(data)
		"move":
			if data.has("fen"):
				await _animate_remote_move(data.get("move", {}), String(data["fen"]))
			_update_online_hud(data)
			if bool(data.get("checkmate", false)):
				_show_announcement("XEQUE-MATE", Color("#f4cf72"), 2.0)
			elif bool(data.get("check", false)):
				_show_announcement("XEQUE", Color("#ff6b80"), 1.0)
		"clock":
			_update_clocks(data.get("clocks", {}))
			turn_label.text = "TURNO • %s" % ("ASTRAL" if String(data.get("turn", "w")) == "w" else "ECLIPSE")
		"error":
			_show_announcement(String(data.get("message", "ERRO")), Color("#ff6677"), 1.8)
		"opponent-left":
			_show_announcement("OPONENTE DESCONECTOU", Color("#ff6677"), 1.8)

func _update_online_hud(data: Dictionary) -> void:
	_update_clocks(data.get("clocks", {}))
	turn_label.text = "TURNO • %s" % ("ASTRAL" if String(data.get("turn", "w")) == "w" else "ECLIPSE")
	status_label.text = "ONLINE • SERVIDOR AUTORITATIVO"

func _render_position() -> void:
	for node in pieces.values():
		if is_instance_valid(node):
			node.queue_free()
	pieces.clear()
	if not CharacterFactory.assets_ready():
		status_label.text = "ASSETS VISUAIS AUSENTES"
		return
	for square_value in engine.board.keys():
		var square := String(square_value)
		var code := engine.piece_at(square)
		var warrior := CharacterFactory.create_piece(code, square)
		if warrior == null:
			continue
		warrior.position = Arena.square_position(square)
		arena_root.add_child(warrior)
		pieces[square] = warrior
	_clear_highlights()
	selected_square = ""
	legal_targets.clear()

func _select_square(square: String) -> void:
	var piece := engine.piece_at(square)
	if piece.is_empty() or not piece.begins_with(engine.turn):
		return
	if mode == MODE_ONLINE and not piece.begins_with(online_color):
		return
	selected_square = square
	legal_targets.clear()
	for move in engine.legal_moves(square):
		legal_targets.append(String(move["to"]))
	_apply_highlights()

func _attempt_square(square: String) -> void:
	if mode == MODE_MENU or interaction_locked or square.is_empty():
		return
	if mode == MODE_ONLINE and (online_color.is_empty() or engine.turn != online_color):
		return
	if selected_square.is_empty():
		_select_square(square)
		return
	if square == selected_square:
		selected_square = ""
		legal_targets.clear()
		_clear_highlights()
		return
	if square in legal_targets:
		_execute_move(selected_square, square)
		return
	_select_square(square)

func _execute_move(from_square: String, to_square: String) -> void:
	interaction_locked = true
	if mode == MODE_ONLINE:
		network.send_move(from_square, to_square, "q")
		interaction_locked = false
		return
	var captured := engine.piece_at(to_square)
	var result := engine.make_move(from_square, to_square, "Q")
	if not bool(result.get("ok", false)):
		interaction_locked = false
		return
	await _animate_piece_move(from_square, to_square, not captured.is_empty())
	_render_position()
	SaveGame.store(engine, mode)
	_update_hud()
	var status: Dictionary = result.get("status", {})
	if bool(status.get("checkmate", false)):
		_show_announcement("XEQUE-MATE", Color("#f4cf72"), 2.0)
	elif bool(status.get("check", false)):
		_show_announcement("XEQUE", Color("#ff6b80"), 1.0)
	interaction_locked = false
	if mode == MODE_LOCAL and not bool(status.get("game_over", false)):
		camera_rig.set_side(engine.turn, true)
	elif mode == MODE_AI and engine.turn == "b" and not bool(status.get("game_over", false)):
		await _run_ai_turn()

func _run_ai_turn() -> void:
	interaction_locked = true
	status_label.text = "IA CALCULANDO…"
	await get_tree().create_timer(0.24).timeout
	var move := bot.choose_move(engine)
	if move.is_empty():
		interaction_locked = false
		return
	var from_square := String(move["from"])
	var to_square := String(move["to"])
	var captured := not engine.piece_at(to_square).is_empty()
	var result := engine.make_move(from_square, to_square, "Q")
	await _animate_piece_move(from_square, to_square, captured)
	_render_position()
	SaveGame.store(engine, mode)
	_update_hud()
	var status: Dictionary = result.get("status", {})
	if bool(status.get("checkmate", false)):
		_show_announcement("XEQUE-MATE", Color("#f4cf72"), 2.0)
	elif bool(status.get("check", false)):
		_show_announcement("XEQUE", Color("#ff6b80"), 1.0)
	status_label.text = "OFFLINE • SEM INTERNET"
	interaction_locked = false

func _animate_piece_move(from_square: String, to_square: String, is_capture: bool) -> void:
	var moving: Node3D = pieces.get(from_square)
	var victim: Node3D = pieces.get(to_square)
	if moving == null:
		return
	var target := Arena.square_position(to_square)
	var start := moving.position
	var midpoint := (start + target) * 0.5 + Vector3(0, 0.45 if not is_capture else 0.72, 0)
	var tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(moving, "position", midpoint, 0.14)
	if is_capture and victim != null:
		camera_rig.focus_capture(target)
		tween.parallel().tween_property(victim, "scale", Vector3.ONE * 0.86, 0.08)
		tween.tween_property(victim, "scale", Vector3.ZERO, 0.16).set_trans(Tween.TRANS_BACK)
		tween.parallel().tween_property(victim, "rotation:y", victim.rotation.y + 0.7, 0.16)
		tween.tween_property(moving, "position", target, 0.15)
		Input.vibrate_handheld(45)
		_show_announcement("CAPTURA", Color("#e8b25a"), 0.55)
	else:
		tween.tween_property(moving, "position", target, 0.15)
		Input.vibrate_handheld(18)
	await tween.finished

func _animate_remote_move(move_data, next_fen: String) -> void:
	interaction_locked = true
	if move_data is Dictionary:
		var from_square := String(move_data.get("from", ""))
		var to_square := String(move_data.get("to", ""))
		var is_capture := move_data.get("captured", null) != null
		if pieces.has(from_square):
			await _animate_piece_move(from_square, to_square, is_capture)
	engine.load_fen(next_fen)
	_render_position()
	interaction_locked = false

func _update_hud() -> void:
	var status := engine.game_status()
	turn_label.text = "TURNO • %s" % ("ASTRAL" if engine.turn == "w" else "ECLIPSE")
	if bool(status["checkmate"]):
		turn_label.text = "XEQUE-MATE"
	elif bool(status["draw"]):
		turn_label.text = "EMPATE"

func _update_clocks(clocks: Dictionary) -> void:
	white_clock.text = _format_clock(int(clocks.get("w", 600000)))
	black_clock.text = _format_clock(int(clocks.get("b", 600000)))

func _format_clock(ms: int) -> String:
	var total_seconds := maxi(0, ms / 1000)
	return "%02d:%02d" % [total_seconds / 60, total_seconds % 60]

func _apply_highlights() -> void:
	_clear_highlights()
	if squares.has(selected_square):
		(squares[selected_square] as MeshInstance3D).material_overlay = _highlight(Color("#e7c05f"), 0.34, 1.5)
	for target in legal_targets:
		if not squares.has(target):
			continue
		var capture := not engine.piece_at(target).is_empty()
		(squares[target] as MeshInstance3D).material_overlay = _highlight(Color("#ff6278") if capture else Color("#4da7ff"), 0.28, 1.2)

func _clear_highlights() -> void:
	for node in squares.values():
		if is_instance_valid(node):
			(node as MeshInstance3D).material_overlay = null

func _highlight(color: Color, alpha: float, energy: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(color.r, color.g, color.b, alpha)
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	return material

func _unhandled_input(event: InputEvent) -> void:
	if orientation_overlay.visible:
		return
	if event is InputEventScreenTouch:
		_handle_touch(event)
	elif event is InputEventScreenDrag:
		_handle_drag(event)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_attempt_square(_screen_to_square(event.position))
	elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE):
		camera_rig.orbit(event.relative.x)

func _handle_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		active_touches[event.index] = event.position
		if active_touches.size() == 1:
			touch_start = event.position
			touch_dragged = false
		elif active_touches.size() == 2:
			previous_pinch_distance = _touch_distance()
	else:
		if active_touches.size() == 1 and not touch_dragged:
			_attempt_square(_screen_to_square(event.position))
		active_touches.erase(event.index)
		if active_touches.size() < 2:
			previous_pinch_distance = 0.0

func _handle_drag(event: InputEventScreenDrag) -> void:
	active_touches[event.index] = event.position
	if active_touches.size() >= 2:
		var current := _touch_distance()
		if previous_pinch_distance > 0.0:
			camera_rig.zoom_by((previous_pinch_distance - current) * 0.0009)
		previous_pinch_distance = current
		touch_dragged = true
		return
	if event.position.distance_to(touch_start) > 18.0:
		touch_dragged = true
		camera_rig.orbit(event.relative.x)

func _touch_distance() -> float:
	var values := active_touches.values()
	if values.size() < 2:
		return 0.0
	return Vector2(values[0]).distance_to(Vector2(values[1]))

func _screen_to_square(screen_position: Vector2) -> String:
	if camera_rig.camera == null:
		return ""
	var origin := camera_rig.camera.project_ray_origin(screen_position)
	var direction := camera_rig.camera.project_ray_normal(screen_position)
	if abs(direction.y) < 0.0001:
		return ""
	var t := (BOARD_PLANE_Y - origin.y) / direction.y
	if t < 0.0:
		return ""
	return Arena.world_to_square(origin + direction * t)

func _update_orientation() -> void:
	var size := get_viewport().get_visible_rect().size
	orientation_overlay.visible = size.y > size.x

func _show_announcement(text: String, color: Color, seconds: float) -> void:
	announcement.text = text
	announcement.add_theme_color_override("font_color", color)
	announcement.modulate = Color(1, 1, 1, 0)
	announcement.scale = Vector2(0.90, 0.90)
	announcement.visible = true
	var intro := create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	intro.tween_property(announcement, "modulate:a", 1.0, 0.12)
	intro.tween_property(announcement, "scale", Vector2.ONE, 0.12)
	await get_tree().create_timer(seconds).timeout
	var outro := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	outro.tween_property(announcement, "modulate:a", 0.0, 0.18)
	outro.finished.connect(func(): announcement.visible = false)

func _button(text: String, height: float, color: Color) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = height
	button.add_theme_font_size_override("font_size", 15)
	button.add_theme_stylebox_override("normal", _panel_style(color, 14))
	button.add_theme_stylebox_override("hover", _panel_style(color.lightened(0.07), 14))
	button.add_theme_stylebox_override("pressed", _panel_style(color.darkened(0.10), 14))
	return button

func _panel_style(color: Color, radius: int, border := Color(0,0,0,0)) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	if border.a > 0.0:
		style.border_width_left = 1
		style.border_width_right = 1
		style.border_width_top = 1
		style.border_width_bottom = 1
		style.border_color = border
	return style
