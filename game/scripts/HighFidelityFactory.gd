class_name HighFidelityFactory
extends RefCounted

const SHADOWKIN_PATH := "res://assets/vendor/pbr/ShadowkinMage.glb"
const FORGOTTEN_KNIGHT_PATH := "res://assets/vendor/pbr/ForgottenKnight.glb"
const TARGET_MAGE_HEIGHT := 2.10
const TARGET_KNIGHT_HEIGHT := 2.24

static func mage_ready() -> bool:
	return ResourceLoader.exists(SHADOWKIN_PATH)

static func knight_ready() -> bool:
	return ResourceLoader.exists(FORGOTTEN_KNIGHT_PATH)

static func create_shadowkin(code: String) -> Node3D:
	return _create_imported_piece(SHADOWKIN_PATH, code, TARGET_MAGE_HEIGHT, "shadowkin")

static func create_forgotten_knight(code: String) -> Node3D:
	return _create_imported_piece(FORGOTTEN_KNIGHT_PATH, code, TARGET_KNIGHT_HEIGHT, "forgotten_knight")

static func _create_imported_piece(path: String, code: String, target_height: float, archetype: String) -> Node3D:
	if not ResourceLoader.exists(path):
		return null
	var packed := ResourceLoader.load(path) as PackedScene
	if packed == null:
		return null
	var imported := packed.instantiate() as Node3D
	if imported == null:
		return null

	var root := Node3D.new()
	root.name = "PBR_%s_%s" % [archetype, code]
	root.set_meta("piece_code", code)
	root.set_meta("high_fidelity", true)
	root.set_meta("archetype", archetype)
	root.set_meta("source_path", path)

	# Keep source-authored transforms intact. The normalizer is a separate parent
	# so imported GLBs can retain their own unit scale, pivots and nested rig data.
	var facing := Node3D.new()
	facing.name = "Facing"
	root.add_child(facing)
	var normalizer := Node3D.new()
	normalizer.name = "Normalizer"
	facing.add_child(normalizer)
	normalizer.add_child(imported)

	# Calculate bounds entirely from local transforms. The previous implementation
	# asked orphaned nodes for global_transform before they entered SceneTree,
	# causing Godot to return identity transforms and corrupting normalization.
	var bounds := _combined_local_bounds(imported, Transform3D.IDENTITY)
	if bounds.size.y <= 0.001:
		root.free()
		return null

	var uniform := target_height / bounds.size.y
	var center_x := bounds.position.x + bounds.size.x * 0.5
	var center_z := bounds.position.z + bounds.size.z * 0.5
	var bottom_y := bounds.position.y
	normalizer.scale = Vector3.ONE * uniform
	normalizer.position = Vector3(-center_x * uniform, -bottom_y * uniform, -center_z * uniform)

	var faction := code.substr(0, 1)
	# White and black face one another without touching the source model transform.
	facing.rotation.y = PI if faction == "w" else 0.0
	_enable_shadows(imported)
	_pose_for_combat(imported)
	_add_premium_base(root, faction)

	root.set_meta("source_height", bounds.size.y)
	root.set_meta("source_width", bounds.size.x)
	root.set_meta("source_depth", bounds.size.z)
	root.set_meta("normalization_scale", uniform)
	root.set_meta("target_height", target_height)
	return root

static func _pose_for_combat(node: Node) -> void:
	var player := _find_animation_player(node)
	if player == null:
		return

	# Prefer explicit action poses; otherwise use a non-reset pose if one exists.
	var names := player.get_animation_list()
	for animation_name in names:
		var lowered := String(animation_name).to_lower()
		if lowered.contains("actionpose") or lowered.contains("action_pose") or lowered.contains("combat"):
			player.play(animation_name)
			player.seek(0.0, true)
			player.pause()
			return
	for animation_name in names:
		var lowered := String(animation_name).to_lower()
		if lowered == "pose" or lowered.contains("idle"):
			player.play(animation_name)
			player.seek(0.0, true)
			player.pause()
			return

static func _combined_local_bounds(node: Node3D, parent_transform: Transform3D) -> AABB:
	var current_transform := parent_transform * node.transform
	var has_bounds := false
	var result := AABB()

	if node is MeshInstance3D:
		var mesh_node := node as MeshInstance3D
		if mesh_node.mesh != null:
			result = current_transform * mesh_node.get_aabb()
			has_bounds = result.size.length_squared() > 0.000001

	for child in node.get_children():
		if not child is Node3D:
			continue
		var child_box := _combined_local_bounds(child as Node3D, current_transform)
		if child_box.size.length_squared() <= 0.000001:
			continue
		if not has_bounds:
			result = child_box
			has_bounds = true
		else:
			result = result.merge(child_box)
	return result

static func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child in node.get_children():
		var found := _find_animation_player(child)
		if found != null:
			return found
	return null

static func _enable_shadows(node: Node) -> void:
	if node is GeometryInstance3D:
		(node as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	for child in node.get_children():
		_enable_shadows(child)

static func _add_premium_base(root: Node3D, faction: String) -> void:
	var accent := Color("#69b7ff") if faction == "w" else Color("#a154ff")
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.43
	torus.outer_radius = 0.475
	ring.mesh = torus
	ring.position.y = 0.035
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := StandardMaterial3D.new()
	material.albedo_color = accent
	material.emission_enabled = true
	material.emission = accent
	material.emission_energy_multiplier = 2.2
	material.metallic = 0.45
	material.roughness = 0.22
	ring.material_override = material
	root.add_child(ring)

	var light := OmniLight3D.new()
	light.position = Vector3(0, 1.0, 0.1)
	light.light_color = accent
	light.light_energy = 1.7
	light.omni_range = 3.0
	light.shadow_enabled = false
	root.add_child(light)
