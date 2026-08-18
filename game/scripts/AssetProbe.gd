extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_probe("res://assets/vendor/quaternius/glTF/Warrior.gltf", "MECHANICS_WARRIOR")
	_probe("res://assets/vendor/pbr/ShadowkinMage.glb", "PBR_SHADOWKIN_MAGE")
	quit(0)

func _probe(path: String, label: String) -> void:
	print("=== PROBE %s ===" % label)
	var packed := load(path) as PackedScene
	if packed == null:
		print("FAILED LOAD ", path)
		return
	var root_node := packed.instantiate()
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
	root.remove_child(root_node)
	root_node.free()

func _print_tree(node: Node, depth: int) -> void:
	if depth <= 4:
		print("  ".repeat(depth), node.name, " <", node.get_class(), ">")
	for child in node.get_children():
		_print_tree(child, depth + 1)

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
