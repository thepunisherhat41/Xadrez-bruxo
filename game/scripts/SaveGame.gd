class_name SaveGame
extends RefCounted

const PATH := "user://xadrez_bruxo_offline.json"

static func store(engine: ChessEngine, mode: String) -> void:
	if mode == "online" or mode == "menu":
		return
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({
		"fen": engine.to_fen(),
		"mode": mode,
		"saved_at": Time.get_unix_time_from_system()
	}))

static func load_data() -> Dictionary:
	if not FileAccess.file_exists(PATH):
		return {}
	var file := FileAccess.open(PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	return parsed if parsed is Dictionary else {}

static func clear() -> void:
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
