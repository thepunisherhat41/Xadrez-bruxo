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
	# White queen (Wizard) can capture the black rook (Warrior) immediately.
	game.call("_start_offline", "offline_local", "4k3/8/8/4r3/4Q3/8/8/4K3 w - - 0 1")
	await create_timer(0.45).timeout
	game.call("_execute_move", "e4", "e5")
	await create_timer(0.19).timeout
	var output_dir := ProjectSettings.globalize_path("res://build/visual")
	DirAccess.make_dir_recursive_absolute(output_dir)
	var image := root.get_texture().get_image()
	if image == null or image.is_empty():
		_fail("battle frame is empty")
		return
	var error := image.save_png(output_dir.path_join("capture-duel.png"))
	if error != OK:
		_fail("could not save battle frame")
		return
	print("CINEMATIC BATTLE: PASS %dx%d" % [image.get_width(), image.get_height()])
	quit(0)

func _fail(message: String) -> void:
	push_error("BATTLE CONTRACT FAIL: " + message)
	print("CINEMATIC BATTLE: FAIL")
	quit(1)
