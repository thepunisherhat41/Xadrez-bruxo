extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_probe("res://assets/vendor/quaternius/glTF/Warrior.gltf", "WARRIOR")
	_probe("res://assets/vendor/quaternius/glTF/Wizard.gltf", "WIZARD")
	quit(0)

func _probe(path: String, label: String) -> void:
	print("=== PROBE %s ===" % label)
	var packed := load(path) as PackedScene
	if packed == null:
		print("FAILED LOAD ", path)
		return
	var root_node := packed.instantiate()
	_print_tree(root_node, 0)
	for player in _find_animation_players(root_node):
		print("ANIMATION_PLAYER ", player.get_path())
		for name in player.get_animation_list():
			var animation := player.get_animation(name)
			print("ANIM ", name, " TRACKS=", animation.get_track_count())
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
