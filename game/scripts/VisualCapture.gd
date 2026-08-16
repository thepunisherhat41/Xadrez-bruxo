extends SceneTree

func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	var packed := load("res://scenes/Main.tscn") as PackedScene
	if packed == null:
		_fail("Main.tscn did not load")
		return
	var game := packed.instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	game.call("_start_offline", "offline_ai")
	await create_timer(1.65).timeout

	var pieces: Dictionary = game.get("pieces")
	if pieces.size() != 32:
		_fail("expected 32 adult warrior nodes, got %d" % pieces.size())
		return

	var camera_rig = game.get("camera_rig")
	var camera: Camera3D = camera_rig.camera
	var viewport_size := root.get_visible_rect().size
	if viewport_size.x <= viewport_size.y:
		_fail("visual validation is not landscape")
		return

	var corners := ["a1", "h1", "a8", "h8"]
	for square in corners:
		var screen := camera.unproject_position(Arena.square_position(square))
		if screen.x < 0 or screen.x > viewport_size.x or screen.y < 85 or screen.y > viewport_size.y:
			_fail("board corner %s is outside safe gameplay framing: %s" % [square, screen])
			return

	var output_dir := ProjectSettings.globalize_path("res://build/visual")
	DirAccess.make_dir_recursive_absolute(output_dir)
	var image := root.get_texture().get_image()
	if image == null or image.is_empty():
		_fail("viewport image is empty")
		return
	var error := image.save_png(output_dir.path_join("gameplay-landscape.png"))
	if error != OK:
		_fail("could not save screenshot")
		return
	print("CINEMATIC VISUAL: PASS %dx%d pieces=%d" % [image.get_width(), image.get_height(), pieces.size()])
	quit(0)

func _fail(message: String) -> void:
	push_error("VISUAL CONTRACT FAIL: " + message)
	print("CINEMATIC VISUAL: FAIL")
	quit(1)
