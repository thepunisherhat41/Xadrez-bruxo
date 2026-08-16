class_name CharacterFactory
extends RefCounted

const ASSET_ROOT := "res://assets/vendor/quaternius/"
const MODELS := {
	"pawn_m": "Male_Peasant.gltf",
	"pawn_f": "Female_Peasant.gltf",
	"ranger_m": "Male_Ranger.gltf",
	"ranger_f": "Female_Ranger.gltf",
	"base_m": "Superhero_Male_FullBody.gltf",
	"base_f": "Superhero_Female_FullBody.gltf"
}

const CLASS_SCALE := {
	"P": 0.72,
	"R": 0.76,
	"N": 0.74,
	"B": 0.73,
	"Q": 0.76,
	"K": 0.79
}

static func assets_ready() -> bool:
	for filename in MODELS.values():
		if not ResourceLoader.exists(ASSET_ROOT + String(filename)):
			return false
	return true

static func create_piece(code: String, square: String) -> Node3D:
	if code.length() != 2:
		return null
	if not assets_ready():
		return null

	var color := code.substr(0, 1)
	var kind := code.substr(1, 1)
	var model_key := _model_for(kind, square)
	var packed := ResourceLoader.load(ASSET_ROOT + String(MODELS[model_key])) as PackedScene
	if packed == null:
		return null

	var root := Node3D.new()
	root.name = "Warrior_%s_%s" % [code, square]
	root.set_meta("piece_code", code)
	root.set_meta("square", square)
	root.set_meta("faction", "astral" if color == "w" else "eclipse")

	var character := packed.instantiate() as Node3D
	if character == null:
		return null
	character.name = "Character"
	root.add_child(character)
	character.scale = Vector3.ONE * float(CLASS_SCALE.get(kind, 0.74))
	character.rotation.y = 0.0 if color == "w" else PI
	_enable_shadows(character)

	_add_faction_base(root, color, kind)
	_add_class_identity(root, color, kind)
	return root

static func _model_for(kind: String, square: String) -> String:
	match kind:
		"P":
			var file_index := "abcdefgh".find(square.substr(0, 1))
			return "pawn_m" if file_index % 2 == 0 else "pawn_f"
		"R": return "base_m"
		"N": return "ranger_m"
		"B": return "pawn_f"
		"Q": return "ranger_f"
		"K": return "base_m"
	return "base_m"

static func _enable_shadows(node: Node) -> void:
	if node is GeometryInstance3D:
		(node as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	for child in node.get_children():
		_enable_shadows(child)

static func _add_faction_base(root: Node3D, color: String, kind: String) -> void:
	var accent := Color("#5aa4ff") if color == "w" else Color("#a048ff")
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	var radius := 0.43 if kind == "P" else 0.49
	torus.inner_radius = radius
	torus.outer_radius = radius + 0.045
	ring.mesh = torus
	ring.position.y = 0.025
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.material_override = _glow(accent, 2.1)
	root.add_child(ring)

static func _add_class_identity(root: Node3D, color: String, kind: String) -> void:
	var steel := Color("#c7d2df") if color == "w" else Color("#25202f")
	var gold := Color("#c8a755") if color == "w" else Color("#71518f")
	var magic := Color("#64b8ff") if color == "w" else Color("#a45cff")
	match kind:
		"P":
			_add_spear(root, Vector3(0.34, 0.78, 0.02), steel, gold)
		"R":
			_add_shoulders(root, steel)
			_add_hammer(root, Vector3(0.42, 0.78, 0), steel, gold)
		"N":
			_add_sword(root, Vector3(0.38, 0.88, 0), steel, gold)
			_add_shield(root, Vector3(-0.34, 0.88, 0), steel, magic)
		"B":
			_add_staff(root, Vector3(0.40, 0.88, 0), gold, magic)
			_add_orb(root, Vector3(0.0, 1.72, 0.0), 0.10, magic)
		"Q":
			_add_crown(root, Vector3(0, 1.78, 0), gold, magic, 7)
			_add_staff(root, Vector3(0.42, 0.90, 0), gold, magic)
		"K":
			_add_crown(root, Vector3(0, 1.88, 0), gold, magic, 5)
			_add_sword(root, Vector3(0.42, 0.92, 0), steel, gold)
			_add_shield(root, Vector3(-0.38, 0.90, 0), steel, magic)

static func _add_spear(root: Node3D, pos: Vector3, steel: Color, gold: Color) -> void:
	_add_cylinder(root, pos, Vector3(0.045, 0.82, 0.045), gold)
	_add_prism(root, pos + Vector3(0, 0.98, 0), Vector3(0.10, 0.34, 0.10), steel)

static func _add_hammer(root: Node3D, pos: Vector3, steel: Color, gold: Color) -> void:
	_add_cylinder(root, pos, Vector3(0.055, 0.72, 0.055), gold)
	_add_box(root, pos + Vector3(0, 0.76, 0), Vector3(0.50, 0.20, 0.22), steel)

static func _add_sword(root: Node3D, pos: Vector3, steel: Color, gold: Color) -> void:
	_add_box(root, pos + Vector3(0, 0.45, 0), Vector3(0.055, 0.86, 0.045), steel)
	_add_box(root, pos + Vector3(0, 0.03, 0), Vector3(0.28, 0.06, 0.09), gold)

static func _add_staff(root: Node3D, pos: Vector3, gold: Color, magic: Color) -> void:
	_add_cylinder(root, pos, Vector3(0.045, 0.86, 0.045), gold)
	_add_orb(root, pos + Vector3(0, 0.98, 0), 0.11, magic)

static func _add_shield(root: Node3D, pos: Vector3, steel: Color, magic: Color) -> void:
	var shield := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.28
	cylinder.bottom_radius = 0.28
	cylinder.height = 0.08
	shield.mesh = cylinder
	shield.position = pos
	shield.rotation_degrees.x = 90.0
	shield.material_override = _material(steel, 0.32, 0.72)
	root.add_child(shield)
	_add_orb(root, pos + Vector3(0, 0, -0.07), 0.055, magic)

static func _add_shoulders(root: Node3D, steel: Color) -> void:
	_add_box(root, Vector3(-0.30, 1.28, 0), Vector3(0.28, 0.18, 0.34), steel)
	_add_box(root, Vector3(0.30, 1.28, 0), Vector3(0.28, 0.18, 0.34), steel)

static func _add_crown(root: Node3D, pos: Vector3, gold: Color, magic: Color, points: int) -> void:
	for i in range(points):
		var angle := TAU * float(i) / float(points)
		var p := pos + Vector3(cos(angle) * 0.16, 0, sin(angle) * 0.16)
		_add_prism(root, p, Vector3(0.055, 0.22, 0.055), gold)
	_add_orb(root, pos + Vector3(0, 0.10, 0), 0.065, magic)

static func _add_orb(root: Node3D, pos: Vector3, radius: float, color: Color) -> void:
	var node := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	node.mesh = sphere
	node.position = pos
	node.material_override = _glow(color, 2.8)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(node)

static func _add_box(root: Node3D, pos: Vector3, size: Vector3, color: Color) -> void:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.position = pos
	node.material_override = _material(color, 0.34, 0.68)
	root.add_child(node)

static func _add_prism(root: Node3D, pos: Vector3, size: Vector3, color: Color) -> void:
	var node := MeshInstance3D.new()
	var mesh := PrismMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.position = pos
	node.material_override = _material(color, 0.30, 0.72)
	root.add_child(node)

static func _add_cylinder(root: Node3D, pos: Vector3, size: Vector3, color: Color) -> void:
	var node := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = size.x
	mesh.bottom_radius = size.x
	mesh.height = size.y * 2.0
	node.mesh = mesh
	node.position = pos
	node.material_override = _material(color, 0.40, 0.62)
	root.add_child(node)

static func _material(color: Color, roughness: float, metallic: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	return material

static func _glow(color: Color, energy: float) -> StandardMaterial3D:
	var material := _material(color, 0.25, 0.30)
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	return material
