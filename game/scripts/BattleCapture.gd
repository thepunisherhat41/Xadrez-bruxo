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

	# Keep the real game shell, arena and HUD, but replace the white queen only
	# with the high-fidelity PBR candidate. This lets us judge art direction
	# without prematurely promoting the candidate to all 32 runtime pieces.
	game.call("_start_offline", "offline_local", "4k3/8/8/4r3/4Q3/8/8/4K3 w - - 0 1")
	await create_timer(0.35).timeout

	var pieces: Dictionary = game.get("pieces")
	var old_queen: Node3D = pieces.get("e4")
	if old_queen != null:
		old_queen.queue_free()
		await process_frame

	var mage := HighFidelityFactory.create_shadowkin("wQ")
	if mage == null:
		_fail("PBR Shadowkin mage did not instantiate")
		return
	mage.position = Arena.square_position("e4")
	var arena_root: Node3D = game.get("arena_root")
	arena_root.add_child(mage)

	var target := Arena.square_position("e5")
	_add_magic_impact(arena_root, (mage.position + target) * 0.5 + Vector3(0, 1.05, 0))
	var camera_rig: CameraRig = game.get("camera_rig")
	camera_rig.focus_capture(target)
	await create_timer(0.17).timeout

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
	print("CINEMATIC BATTLE: PASS %dx%d PBR_MAGE=true" % [image.get_width(), image.get_height()])
	quit(0)

func _add_magic_impact(parent: Node3D, position: Vector3) -> void:
	var violet := Color("#8e4cff")
	var white_hot := Color("#e8ddff")

	var core := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.17
	sphere.height = 0.34
	core.mesh = sphere
	core.position = position
	core.material_override = _glow(white_hot, 5.8)
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(core)

	for i in range(3):
		var ring := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 0.30 + float(i) * 0.16
		torus.outer_radius = torus.inner_radius + 0.032
		ring.mesh = torus
		ring.position = position
		ring.rotation_degrees = Vector3(90.0, float(i) * 28.0, float(i) * 17.0)
		ring.material_override = _glow(violet, 3.5 - float(i) * 0.45)
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(ring)

	var light := OmniLight3D.new()
	light.position = position
	light.light_color = violet
	light.light_energy = 6.5
	light.omni_range = 5.0
	light.shadow_enabled = false
	parent.add_child(light)

func _glow(color: Color, energy: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	material.metallic = 0.15
	material.roughness = 0.12
	return material

func _fail(message: String) -> void:
	push_error("BATTLE CONTRACT FAIL: " + message)
	print("CINEMATIC BATTLE: FAIL")
	quit(1)
