class_name HighFidelityFactory
extends RefCounted

const SHADOWKIN_PATH := "res://assets/vendor/pbr/ShadowkinMage.glb"
const FORGOTTEN_KNIGHT_PATH := "res://assets/vendor/pbr/ForgottenKnight.glb"
const TARGET_MAGE_HEIGHT := 2.10
const TARGET_KNIGHT_HEIGHT := 2.24
const RIG_BOUNDS_RATIO := 1.75

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
	# so imported GLBs retain source scale, pivots, skin and nested rig data.
	var facing := Node3D.new()
	facing.name = "Facing"
	root.add_child(facing)
	var normalizer := Node3D.new()
	normalizer.name = "Normalizer"
	facing.add_child(normalizer)
	normalizer.add_child(imported)

	var mesh_bounds := _combined_local_bounds(imported, Transform3D.IDENTITY)
	if mesh_bounds.size.y <= 0.001:
		root.free()
		return null

	# A skinned GLB can report a mesh AABB in bind/object space that has little
	# relationship to the posed character. Shadowkin is a concrete example: its
	# imported mesh AABB is ~0.41 high while the 152-bone rest rig is ~1.92 high.
	# In that case normalizing from the mesh made the runtime character ~5x too
	# large and displaced. Prefer the skeleton rest envelope only when it is
	# clearly more representative; ordinary/static assets keep mesh bounds.
	var rig_probe := _largest_skeleton_rest_bounds(imported, Transform3D.IDENTITY)
	var rig_bounds: AABB = rig_probe.get("bounds", AABB())
	var use_rig_bounds := (
		rig_bounds.size.y > 0.001
		and rig_bounds.size.y > mesh_bounds.size.y * RIG_BOUNDS_RATIO
	)
	var bounds := rig_bounds if use_rig_bounds else mesh_bounds
	var normalization_basis := "skeleton_rest" if use_rig_bounds else "mesh"

	var uniform := target_height / bounds.size.y
	var center_x := bounds.position.x + bounds.size.x * 0.5
	var center_z := bounds.position.z + bounds.size.z * 0.5
	var bottom_y := bounds.position.y
	normalizer.scale = Vector3.ONE * uniform
	normalizer.position = Vector3(-center_x * uniform, -bottom_y * uniform, -center_z * uniform)

	var faction := code.substr(0, 1)
	facing.rotation.y = PI if faction == "w" else 0.0
	_enable_shadows(imported)
	_pose_for_combat(imported)
	_add_premium_base(root, faction)

	root.set_meta("source_height", bounds.size.y)
	root.set_meta("source_width", bounds.size.x)
	root.set_meta("source_depth", bounds.size.z)
	root.set_meta("mesh_source_height", mesh_bounds.size.y)
	root.set_meta("rig_source_height", rig_bounds.size.y)
	root.set_meta("normalization_basis", normalization_basis)
	root.set_meta("normalization_scale", uniform)
	root.set_meta("target_height", target_height)
	return root

static func _pose_for_combat(node: Node) -> void:
	var player := _find_animation_player(node)
	if player == null:
		return
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

static func _largest_skeleton_rest_bounds(node: Node3D, parent_transform: Transform3D) -> Dictionary:
	var current_transform := parent_transform * node.transform
	var best_bounds := AABB()
	var best_bones := 0
	if node is Skeleton3D:
		var skeleton := node as Skeleton3D
		var candidate := _skeleton_rest_bounds(skeleton, current_transform)
		if candidate.size.y > best_bounds.size.y:
			best_bounds = candidate
			best_bones = skeleton.get_bone_count()
	for child in node.get_children():
		if not child is Node3D:
			continue
		var child_probe := _largest_skeleton_rest_bounds(child as Node3D, current_transform)
		var child_bounds: AABB = child_probe.get("bounds", AABB())
		if child_bounds.size.y > best_bounds.size.y:
			best_bounds = child_bounds
			best_bones = int(child_probe.get("bones", 0))
	return {"bounds": best_bounds, "bones": best_bones}

static func _skeleton_rest_bounds(skeleton: Skeleton3D, skeleton_transform: Transform3D) -> AABB:
	var bone_count := skeleton.get_bone_count()
	if bone_count <= 0:
		return AABB()
	var global_rests: Array[Transform3D] = []
	global_rests.resize(bone_count)
	var minimum := Vector3(INF, INF, INF)
	var maximum := Vector3(-INF, -INF, -INF)
	for index in range(bone_count):
		var rest := skeleton.get_bone_rest(index)
		var parent := skeleton.get_bone_parent(index)
		var global_rest := rest if parent < 0 else global_rests[parent] * rest
		global_rests[index] = global_rest
		var point := skeleton_transform * global_rest.origin
		minimum = minimum.min(point)
		maximum = maximum.max(point)
	return AABB(minimum, maximum - minimum)

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
