extends SceneTree

const DUEL_FEN := "4k3/8/8/4n3/4Q3/8/8/4K3 w - - 0 1"
const MAGE_SQUARE := "e4"
const KNIGHT_SQUARE := "e5"

var output_dir := ""

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

	# Keep the real game shell, arena and HUD, but replace exactly two combatants
	# with high-fidelity PBR candidates. The visual gate is intentionally tiny:
	# prove one premium duel before multiplying an art mistake across 32 pieces.
	game.call("_start_offline", "offline_local", DUEL_FEN)
	await create_timer(0.35).timeout

	var pieces: Dictionary = game.get("pieces")
	_remove_runtime_piece(pieces, MAGE_SQUARE)
	_remove_runtime_piece(pieces, KNIGHT_SQUARE)
	await process_frame

	var mage := HighFidelityFactory.create_shadowkin("wQ")
	if mage == null:
		_fail("PBR Shadowkin mage did not instantiate")
		return
	var knight := HighFidelityFactory.create_forgotten_knight("bN")
	if knight == null:
		_fail("PBR Forgotten Knight did not instantiate")
		return

	var arena_root: Node3D = game.get("arena_root")
	if arena_root == null:
		_fail("arena_root is unavailable")
		return
	arena_root.add_child(mage)
	arena_root.add_child(knight)
	mage.position = Arena.square_position(MAGE_SQUARE)
	knight.position = Arena.square_position(KNIGHT_SQUARE)
	pieces[MAGE_SQUARE] = mage
	pieces[KNIGHT_SQUARE] = knight
	await process_frame

	output_dir = ProjectSettings.globalize_path("res://build/visual")
	DirAccess.make_dir_recursive_absolute(output_dir)

	var camera_rig: CameraRig = game.get("camera_rig")
	if camera_rig == null or camera_rig.camera == null:
		_fail("camera rig is unavailable")
		return

	# Close-ups are contractual evidence. If the staged source, import transform,
	# materials or orientation are wrong, these images make it impossible for a
	# flattering wide shot to hide the problem.
	_frame_subject(camera_rig.camera, mage.global_position, knight.global_position, -1.0)
	await _save_frame("capture-pbr-mage.png")

	_frame_subject(camera_rig.camera, knight.global_position, mage.global_position, 1.0)
	await _save_frame("capture-pbr-knight.png")

	# Then judge them together in the board context with restrained magical VFX.
	var midpoint := (mage.global_position + knight.global_position) * 0.5
	_add_magic_impact(arena_root, midpoint + Vector3(0, 1.05, 0))
	_frame_duel(camera_rig.camera, mage.global_position, knight.global_position)
	await _save_frame("capture-duel.png")

	print(
		"CINEMATIC BATTLE: PASS PBR_MAGE=true PBR_KNIGHT=true mage_scale=%.4f knight_scale=%.4f" % [
			float(mage.get_meta("normalization_scale", 0.0)),
			float(knight.get_meta("normalization_scale", 0.0))
		]
	)
	quit(0)

func _remove_runtime_piece(pieces: Dictionary, square: String) -> void:
	var existing: Node = pieces.get(square)
	pieces.erase(square)
	if existing == null or not is_instance_valid(existing):
		return
	var parent := existing.get_parent()
	if parent != null:
		parent.remove_child(existing)
	# Immediate free is deliberate. queue_free() left the old procedural piece
	# alive for the rest of the frame and made prior visual QA ambiguous.
	existing.free()

func _frame_subject(camera: Camera3D, subject: Vector3, opponent: Vector3, side: float) -> void:
	var duel_axis := opponent - subject
	duel_axis.y = 0.0
	if duel_axis.length_squared() < 0.0001:
		duel_axis = Vector3(0, 0, -1)
	duel_axis = duel_axis.normalized()
	var lateral := Vector3(-duel_axis.z, 0.0, duel_axis.x) * side
	camera.global_position = subject - duel_axis * 4.15 + lateral * 2.15 + Vector3.UP * 2.25
	camera.fov = 34.0
	camera.look_at(subject + Vector3.UP * 1.05, Vector3.UP)

func _frame_duel(camera: Camera3D, mage_pos: Vector3, knight_pos: Vector3) -> void:
	var midpoint := (mage_pos + knight_pos) * 0.5
	var duel_axis := knight_pos - mage_pos
	duel_axis.y = 0.0
	if duel_axis.length_squared() < 0.0001:
		duel_axis = Vector3(0, 0, -1)
	duel_axis = duel_axis.normalized()
	var lateral := Vector3(-duel_axis.z, 0.0, duel_axis.x)
	camera.global_position = midpoint - duel_axis * 5.4 + lateral * 4.35 + Vector3.UP * 2.75
	camera.fov = 39.0
	camera.look_at(midpoint + Vector3.UP * 1.0, Vector3.UP)

func _save_frame(filename: String) -> void:
	await process_frame
	await process_frame
	var image := root.get_texture().get_image()
	if image == null or image.is_empty():
		_fail("frame is empty: " + filename)
		return
	var error := image.save_png(output_dir.path_join(filename))
	if error != OK:
		_fail("could not save frame: " + filename)
		return
	print("VISUAL_EVIDENCE ", filename, " ", image.get_width(), "x", image.get_height())

func _add_magic_impact(parent: Node3D, position: Vector3) -> void:
	var violet := Color("#8e4cff")
	var white_hot := Color("#e8ddff")

	var core := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.14
	sphere.height = 0.28
	core.mesh = sphere
	core.position = position
	core.material_override = _glow(white_hot, 4.4)
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(core)

	for i in range(2):
		var ring := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 0.27 + float(i) * 0.17
		torus.outer_radius = torus.inner_radius + 0.028
		ring.mesh = torus
		ring.position = position
		ring.rotation_degrees = Vector3(90.0, float(i) * 28.0, float(i) * 17.0)
		ring.material_override = _glow(violet, 2.7 - float(i) * 0.4)
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(ring)

	var light := OmniLight3D.new()
	light.position = position
	light.light_color = violet
	light.light_energy = 4.0
	light.omni_range = 4.0
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
