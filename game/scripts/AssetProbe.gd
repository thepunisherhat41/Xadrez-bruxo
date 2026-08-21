extends SceneTree

var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_probe("res://assets/vendor/quaternius/glTF/Warrior.gltf", "MECHANICS_WARRIOR", false)
	_probe("res://assets/vendor/pbr/ShadowkinMage.glb", "PBR_SHADOWKIN_MAGE", true)
	_probe("res://assets/vendor/pbr/ForgottenKnight.glb", "PBR_FORGOTTEN_KNIGHT", true)
	if failures > 0:
		print("ASSET PROBE: FAIL count=", failures)
		quit(1)
		return
	print("ASSET PROBE: PASS PBR_MAGE=true PBR_KNIGHT=true")
	quit(0)

func _probe(path: String, label: String, required: bool) -> void:
	print("=== PROBE %s ===" % label)
	var packed := load(path) as PackedScene
	if packed == null:
		print("FAILED LOAD ", path)
		if required:
			failures += 1
		return
	var root_node := packed.instantiate() as Node3D
	if root_node == null:
		print("FAILED ROOT NODE ", path)
		if required:
			failures += 1
		return
	root.add_child(root_node)
	_print_tree(root_node, 0)
	var animation_count := 0
	for player in _find_animation_players(root_node):
		print("ANIMATION_PLAYER ", player.get_path())
		for name in player.get_animation_list():
			var animation := player.get_animation(name)
			animation_count += 1
			print("ANIM ", name, " TRACKS=", animation.get_track_count(), " LENGTH=", animation.length)
	var mesh_stats := _mesh_stats(root_node)
	print("MESH_STATS surfaces=", mesh_stats["surfaces"], " vertices=", mesh_stats["vertices"], " animations=", animation_count)
	_print_spatial_diagnostics(root_node)
	if required and (int(mesh_stats["surfaces"]) <= 0 or int(mesh_stats["vertices"]) <= 0):
		print("FAILED EMPTY MODEL ", path)
		failures += 1
	root.remove_child(root_node)
	root_node.free()

func _print_tree(node: Node, depth: int) -> void:
	if depth <= 7:
		if node is Node3D:
			var node3d := node as Node3D
			print(
				"  ".repeat(depth), node.name, " <", node.get_class(), ">",
				" pos=", node3d.position,
				" scale=", node3d.scale
			)
		else:
			print("  ".repeat(depth), node.name, " <", node.get_class(), ">")
	for child in node.get_children():
		_print_tree(child, depth + 1)

func _print_spatial_diagnostics(root_node: Node3D) -> void:
	var mesh_bounds := _combined_tree_bounds(root_node, root_node)
	print("TREE_MESH_BOUNDS pos=", mesh_bounds.position, " size=", mesh_bounds.size)
	for skeleton in _find_skeletons(root_node):
		var skeleton_to_root := root_node.global_transform.affine_inverse() * skeleton.global_transform
		var bone_bounds := _skeleton_rest_bounds(skeleton, skeleton_to_root)
		print(
			"SKELETON_DIAGNOSTIC path=", skeleton.get_path(),
			" bones=", skeleton.get_bone_count(),
			" local_origin=", skeleton_to_root.origin,
			" local_scale=", skeleton_to_root.basis.get_scale(),
			" rest_pos=", bone_bounds.position,
			" rest_size=", bone_bounds.size
		)

func _combined_tree_bounds(node: Node, basis_root: Node3D) -> AABB:
	var has_bounds := false
	var result := AABB()
	if node is MeshInstance3D:
		var mesh_node := node as MeshInstance3D
		if mesh_node.mesh != null:
			var relative := basis_root.global_transform.affine_inverse() * mesh_node.global_transform
			result = relative * mesh_node.get_aabb()
			has_bounds = result.size.length_squared() > 0.000001
	for child in node.get_children():
		var child_box := _combined_tree_bounds(child, basis_root)
		if child_box.size.length_squared() <= 0.000001:
			continue
		if not has_bounds:
			result = child_box
			has_bounds = true
		else:
			result = result.merge(child_box)
	return result

func _find_skeletons(node: Node) -> Array[Skeleton3D]:
	var result: Array[Skeleton3D] = []
	if node is Skeleton3D:
		result.append(node as Skeleton3D)
	for child in node.get_children():
		result.append_array(_find_skeletons(child))
	return result

func _skeleton_rest_bounds(skeleton: Skeleton3D, skeleton_to_root: Transform3D) -> AABB:
	if skeleton.get_bone_count() <= 0:
		return AABB()
	var globals: Array[Transform3D] = []
	globals.resize(skeleton.get_bone_count())
	var minimum := Vector3(INF, INF, INF)
	var maximum := Vector3(-INF, -INF, -INF)
	for index in range(skeleton.get_bone_count()):
		var rest := skeleton.get_bone_rest(index)
		var parent := skeleton.get_bone_parent(index)
		var global_rest := rest if parent < 0 else globals[parent] * rest
		globals[index] = global_rest
		var point := skeleton_to_root * global_rest.origin
		minimum = minimum.min(point)
		maximum = maximum.max(point)
	return AABB(minimum, maximum - minimum)

func _find_animation_players(node: Node) -> Array[AnimationPlayer]:
	var result: Array[AnimationPlayer] = []
	if node is AnimationPlayer:
		result.append(node as AnimationPlayer)
	for child in node.get_children():
		result.append_array(_find_animation_players(child))
	return result

func _mesh_stats(node: Node) -> Dictionary:
	var surfaces := 0
	var vertices := 0
	if node is MeshInstance3D:
		var mesh := (node as MeshInstance3D).mesh
		if mesh != null:
			surfaces += mesh.get_surface_count()
			for surface in range(mesh.get_surface_count()):
				var arrays := mesh.surface_get_arrays(surface)
				if arrays.size() > Mesh.ARRAY_VERTEX and arrays[Mesh.ARRAY_VERTEX] is PackedVector3Array:
					vertices += (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	for child in node.get_children():
		var child_stats := _mesh_stats(child)
		surfaces += int(child_stats["surfaces"])
		vertices += int(child_stats["vertices"])
	return {"surfaces": surfaces, "vertices": vertices}
