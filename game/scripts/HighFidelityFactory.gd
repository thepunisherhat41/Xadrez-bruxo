class_name HighFidelityFactory
extends RefCounted

const SHADOWKIN_PATH := "res://assets/vendor/pbr/ShadowkinMage.glb"
const TARGET_MAGE_HEIGHT := 2.10

static func mage_ready() -> bool:
	return ResourceLoader.exists(SHADOWKIN_PATH)

static func create_shadowkin(code: String) -> Node3D:
	if not mage_ready():
		return null
	var packed := ResourceLoader.load(SHADOWKIN_PATH) as PackedScene
	if packed == null:
		return null
	var imported := packed.instantiate() as Node3D
	if imported == null:
		return null

	var root := Node3D.new()
	root.name = "PBR_Shadowkin_%s" % code
	root.set_meta("piece_code", code)
	root.set_meta("high_fidelity", true)
	root.add_child(imported)

	# Normalize independently from whatever source-unit convention the asset used.
	var bounds := _combined_bounds(imported, imported)
	if bounds.size.y > 0.001:
		var uniform := TARGET_MAGE_HEIGHT / bounds.size.y
		imported.scale = Vector3.ONE * uniform
		# Recenter feet at y=0 and horizontal center at the piece origin.
		var scaled_pos := bounds.position * uniform
		var scaled_size := bounds.size * uniform
		imported.position = Vector3(
			-(scaled_pos.x + scaled_size.x * 0.5),
			-scaled_pos.y,
			-(scaled_pos.z + scaled_size.z * 0.5)
		)

	var faction := code.substr(0, 1)
	imported.rotation.y = PI if faction == "w" else 0.0
	_enable_shadows(imported)
	_pose_for_combat(imported)
	_add_premium_base(root, faction)
	return root

static func _pose_for_combat(node: Node) -> void:
	var player := _find_animation_player(node)
	if player == null:
		return
	for animation_name in player.get_animation_list():
		if String(animation_name).to_lower().contains("actionpose"):
			player.play(animation_name)
			player.seek(0.0, true)
			player.pause()
			return

static func _combined_bounds(node: Node, basis_root: Node3D) -> AABB:
	var first := true
	var result := AABB()
	if node is MeshInstance3D:
		var mesh_node := node as MeshInstance3D
		if mesh_node.mesh != null:
			var relative := basis_root.global_transform.affine_inverse() * mesh_node.global_transform
			var box := relative * mesh_node.get_aabb()
			result = box
			first = false
	for child in node.get_children():
		if not child is Node3D:
			continue
		var child_box := _combined_bounds(child, basis_root)
		if child_box.size.length_squared() <= 0.000001:
			continue
		if first:
			result = child_box
			first = false
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
