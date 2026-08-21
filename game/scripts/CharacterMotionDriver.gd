class_name CharacterMotionDriver
extends Node

var piece: Node3D
var last_position := Vector3.ZERO
var base_y := 0.0
var current_action := ""
var death_started := false

func _ready() -> void:
	piece = get_parent() as Node3D
	if piece == null:
		set_process(false)
		return
	last_position = piece.global_position
	base_y = piece.position.y
	_set_action("idle")

func _process(delta: float) -> void:
	if piece == null or delta <= 0.0:
		return
	if death_started:
		return
	if piece.scale.length() < 0.38:
		death_started = true
		_set_action("death", true)
		return
	var distance := piece.global_position.distance_to(last_position)
	var speed := distance / delta
	var lift := piece.position.y - base_y
	last_position = piece.global_position
	if lift > 0.48 and speed > 0.08:
		_set_action("attack")
	elif speed > 0.10:
		_set_action("walk")
	else:
		_set_action("idle")

func _set_action(action: String, force := false) -> void:
	if not force and action == current_action:
		return
	current_action = action
	CharacterFactory.play_action(piece, action)
