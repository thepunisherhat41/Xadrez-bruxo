class_name Arena
extends RefCounted

const STEP := 1.55
const BOARD_SIZE := STEP * 8.0
const BOARD_Y := 0.42

static func build(parent: Node3D) -> Dictionary:
	_build_environment(parent)
	_build_platform(parent)
	var squares := _build_board(parent)
	_build_rune_channels(parent)
	_build_side_architecture(parent)
	return {"squares": squares, "step": STEP, "board_y": BOARD_Y}

static func square_position(square: String) -> Vector3:
	var file_index := "abcdefgh".find(square.substr(0, 1))
	var rank_index := int(square.substr(1, 1)) - 1
	return Vector3(
		(float(file_index) - 3.5) * STEP,
		BOARD_Y + 0.16,
		(3.5 - float(rank_index)) * STEP
	)

static func world_to_square(world: Vector3) -> String:
	var file_index := int(floor((world.x + BOARD_SIZE * 0.5) / STEP))
	var visual_rank := int(floor((world.z + BOARD_SIZE * 0.5) / STEP))
	var rank_index := 7 - visual_rank
	if file_index < 0 or file_index > 7 or rank_index < 0 or rank_index > 7:
		return ""
	return "abcdefgh".substr(file_index, 1) + str(rank_index + 1)

static func _build_environment(parent: Node3D) -> void:
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#070812")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#283348")
	env.ambient_light_energy = 0.92
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color("#151625")
	env.fog_density = 0.006
	world.environment = env
	parent.add_child(world)

	var key := DirectionalLight3D.new()
	key.light_color = Color("#d8e8ff")
	key.light_energy = 1.35
	key.shadow_enabled = true
	key.rotation_degrees = Vector3(-55, -28, 0)
	parent.add_child(key)

	var astral := OmniLight3D.new()
	astral.position = Vector3(-7.0, 4.8, 3.0)
	astral.light_color = Color("#3d8cff")
	astral.light_energy = 5.2
	astral.omni_range = 12.0
	parent.add_child(astral)

	var eclipse := OmniLight3D.new()
	eclipse.position = Vector3(7.0, 4.4, -3.0)
	eclipse.light_color = Color("#8d39ff")
	eclipse.light_energy = 4.8
	eclipse.omni_range = 12.0
	parent.add_child(eclipse)

static func _build_platform(parent: Node3D) -> void:
	var stone := _material(Color("#171923"), 0.88, 0.12)
	var edge := _material(Color("#4a4038"), 0.58, 0.46)
	_box(parent, Vector3(0, -0.02, 0), Vector3(BOARD_SIZE + 2.4, 0.80, BOARD_SIZE + 2.4), stone)
	_box(parent, Vector3(0, 0.34, 0), Vector3(BOARD_SIZE + 0.62, 0.18, BOARD_SIZE + 0.62), edge)
	_box(parent, Vector3(0, -0.58, 0), Vector3(BOARD_SIZE + 4.3, 0.36, BOARD_SIZE + 4.3), _material(Color("#0d0f16"), 0.95, 0.06))

static func _build_board(parent: Node3D) -> Dictionary:
	var light := _material(Color("#6e6a67"), 0.76, 0.18)
	var dark := _material(Color("#242631"), 0.84, 0.15)
	var squares := {}
	for rank_index in range(8):
		for file_index in range(8):
			var square := "abcdefgh".substr(file_index, 1) + str(rank_index + 1)
			var node := MeshInstance3D.new()
			var mesh := BoxMesh.new()
			mesh.size = Vector3(STEP - 0.055, 0.20, STEP - 0.055)
			node.mesh = mesh
			node.material_override = light if (file_index + rank_index) % 2 == 1 else dark
			node.position = square_position(square) - Vector3(0, 0.18, 0)
			node.set_meta("square", square)
			node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			parent.add_child(node)
			squares[square] = node
	return squares

static func _build_rune_channels(parent: Node3D) -> void:
	var astral := _emissive(Color("#348fff"), 2.1)
	var eclipse := _emissive(Color("#a34cff"), 2.15)
	var outer := BOARD_SIZE * 0.5 + 0.72
	for i in range(2):
		var ring := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = outer + float(i) * 0.42
		torus.outer_radius = torus.inner_radius + 0.045
		ring.mesh = torus
		ring.material_override = astral if i == 0 else eclipse
		ring.position.y = -0.22 - float(i) * 0.03
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(ring)
	_box(parent, Vector3(-outer, -0.14, 0), Vector3(0.045, 0.028, BOARD_SIZE * 0.72), astral)
	_box(parent, Vector3(outer, -0.14, 0), Vector3(0.045, 0.028, BOARD_SIZE * 0.72), eclipse)

static func _build_side_architecture(parent: Node3D) -> void:
	var stone := _material(Color("#11141d"), 0.94, 0.08)
	var metal := _material(Color("#3d414c"), 0.52, 0.62)
	var astral := _emissive(Color("#488fff"), 2.5)
	var eclipse := _emissive(Color("#8f45ff"), 2.5)
	var side_x := BOARD_SIZE * 0.5 + 2.2
	for side in [-1.0, 1.0]:
		var x := side_x * side
		for z in [-4.5, 0.0, 4.5]:
			_box(parent, Vector3(x, 1.40, z), Vector3(0.75, 2.8, 0.75), stone)
			_box(parent, Vector3(x, 2.86, z), Vector3(1.0, 0.16, 1.0), metal)
			var crystal := MeshInstance3D.new()
			var prism := PrismMesh.new()
			prism.size = Vector3(0.48, 1.10, 0.48)
			crystal.mesh = prism
			crystal.material_override = astral if side < 0 else eclipse
			crystal.position = Vector3(x, 3.58, z)
			crystal.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			parent.add_child(crystal)

static func _box(parent: Node3D, pos: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.position = pos
	node.material_override = material
	parent.add_child(node)
	return node

static func _material(color: Color, roughness: float, metallic: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	return material

static func _emissive(color: Color, energy: float) -> StandardMaterial3D:
	var material := _material(color, 0.28, 0.32)
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	return material
