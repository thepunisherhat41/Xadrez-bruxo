class_name CameraRig
extends Node3D

var camera: Camera3D
var side := "w"
var yaw_offset := deg_to_rad(-6.5)
var zoom := 1.0
var tactical_distance := 15.55
var tactical_height := 8.85
var look_target := Vector3(0, 0.66, -0.22)

func _ready() -> void:
	camera = Camera3D.new()
	camera.fov = 42.5
	camera.near = 0.15
	camera.far = 120.0
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	add_child(camera)
	_apply()

func set_side(next_side: String, animated := true) -> void:
	side = next_side
	var target_rotation := 0.0 if side == "w" else PI
	if animated:
		var tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(self, "rotation:y", target_rotation, 0.42)
	else:
		rotation.y = target_rotation

func orbit(delta_x: float) -> void:
	yaw_offset = clampf(yaw_offset + delta_x * 0.0012, deg_to_rad(-13.0), deg_to_rad(7.0))
	_apply()

func zoom_by(delta: float) -> void:
	zoom = clampf(zoom + delta, 0.94, 1.10)
	_apply()

func reset_view() -> void:
	yaw_offset = deg_to_rad(-6.5)
	zoom = 1.0
	_apply()

func focus_capture(world_position: Vector3) -> Tween:
	var original_position := camera.position
	var original_fov := camera.fov
	var focus := Vector3(world_position.x * 0.60, 0.88, world_position.z * 0.60)
	var close_distance := 11.55 * zoom
	var close_height := 6.35 * zoom
	var close_pos := Vector3(sin(yaw_offset) * close_distance, close_height, cos(yaw_offset) * close_distance)
	camera.look_at(focus, Vector3.UP)

	var tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.set_parallel(true)
	tween.tween_property(camera, "position", close_pos, 0.20)
	tween.tween_property(camera, "fov", 44.5, 0.20)
	tween.set_parallel(false)
	tween.tween_interval(0.30)
	tween.set_parallel(true)
	tween.tween_property(camera, "position", original_position, 0.28)
	tween.tween_property(camera, "fov", original_fov, 0.28)
	tween.set_parallel(false)
	tween.finished.connect(func(): _apply())
	return tween

func _apply() -> void:
	if camera == null:
		return
	var distance := tactical_distance * zoom
	var height := tactical_height * zoom
	camera.position = Vector3(sin(yaw_offset) * distance, height, cos(yaw_offset) * distance)
	camera.look_at(look_target, Vector3.UP)
