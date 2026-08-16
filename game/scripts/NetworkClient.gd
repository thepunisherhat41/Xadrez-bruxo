class_name NetworkClient
extends Node

signal opened
signal closed
signal message(data: Dictionary)
signal status(text: String)

const DEFAULT_URL := "wss://xadrez-bruxo.onrender.com"
var socket := WebSocketPeer.new()
var url := DEFAULT_URL
var connecting := false

func connect_server() -> void:
	var state := socket.get_ready_state()
	if state == WebSocketPeer.STATE_OPEN:
		opened.emit()
		return
	if connecting:
		return
	connecting = true
	status.emit("CONECTANDO…")
	var err := socket.connect_to_url(url)
	if err != OK:
		connecting = false
		status.emit("FALHA DE CONEXÃO")

func disconnect_server() -> void:
	if socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		socket.close(1000, "menu")

func create_room(player_name: String) -> void:
	_send({"type": "create", "name": player_name})

func join_room(code: String, player_name: String) -> void:
	_send({"type": "join", "code": code.to_upper(), "name": player_name})

func send_move(from_square: String, to_square: String, promotion := "q") -> void:
	_send({"type": "move", "from": from_square, "to": to_square, "promotion": promotion})

func _process(_delta: float) -> void:
	socket.poll()
	var state := socket.get_ready_state()
	if state == WebSocketPeer.STATE_OPEN:
		if connecting:
			connecting = false
			status.emit("ONLINE")
			opened.emit()
		while socket.get_available_packet_count() > 0:
			var packet := socket.get_packet().get_string_from_utf8()
			var parsed = JSON.parse_string(packet)
			if parsed is Dictionary:
				message.emit(parsed)
	elif state == WebSocketPeer.STATE_CLOSED:
		if connecting:
			connecting = false
			status.emit("OFFLINE")
			closed.emit()

func _send(data: Dictionary) -> void:
	if socket.get_ready_state() != WebSocketPeer.STATE_OPEN:
		status.emit("SEM CONEXÃO")
		return
	socket.send_text(JSON.stringify(data))
