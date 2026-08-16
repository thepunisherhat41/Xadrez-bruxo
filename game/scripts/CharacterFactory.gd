class_name CharacterFactory
extends RefCounted

const ASSET_ROOT := "res://assets/vendor/quaternius/"
const UAL_PATH := ASSET_ROOT + "UAL1_Standard.glb"
const MODELS := {
	"pawn_m": "Male_Peasant.gltf",
	"pawn_f": "Female_Peasant.gltf",
	"ranger_m": "Male_Ranger.gltf",
	"ranger_f": "Female_Ranger.gltf"
}

const CLASS_SCALE := {
	"P": 0.68,
	"R": 0.72,
	"N": 0.70,
	"B": 0.69,
	"Q": 0.72,
	"K": 0.73
}

static func assets_ready() -> bool:
	for filename in MODELS.values():
		if not ResourceLoader.exists(ASSET_ROOT + String(filename)):
			return false
	return ResourceLoader.exists(UAL_PATH)

static func create_piece(code: String, square: String) -> Node3D:
	if code.length() != 2 or not assets_ready():
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
	character.scale = Vector3.ONE * float(CLASS_SCALE.get(kind, 0.70))
	character.rotation.y = 0.0 if color == "w" else PI
	_enable_shadows(character)

	_add_faction_base(root, color, kind)
	_attach_motion_library(character, kind, square)
	_add_class_identity(character, color, kind)
	return root

static func play_action(piece: Node3D, action: String) -> void:
	var player := _find_animation_player(piece)
	if player == null:
		return
	var code := String(piece.get_meta("piece_code", "wP"))
	var kind := code.substr(1, 1)
	var name := "Idle"
	match action:
		"idle": name = _idle_animation(kind)
		"walk": name = "Walk"
		"run": name = "Jog_Fwd"
		"attack": name = "Spell_Simple_Shoot" if kind in ["B", "Q"] else "Sword_Attack"
		"hit": name = "Hit_Chest"
		"death": name = "Death01"
		_: name = action
	if not player.has_animation(name):
		return
	player.play(name, 0.10)
	if action in ["attack", "hit"]:
		player.queue(_idle_animation(kind))

static func _model_for(kind: String, square: String) -> String:
	match kind:
		"P":
			var file_index := "abcdefgh".find(square.substr(0, 1))
			return "pawn_m" if file_index % 2 == 0 else "pawn_f"
		"B": return "pawn_f"
		"Q": return "ranger_f"
		_: return "ranger_m"

static func _attach_motion_library(character: Node3D, kind: String, square: String) -> void:
	var ual := ResourceLoader.load(UAL_PATH) as PackedScene
	if ual == null:
		return
	var source_root := ual.instantiate()
	var source_player := _find_animation_player(source_root)
	if source_player == null:
		source_root.free()
		return
	var libraries := source_player.get_animation_library_list()
	if libraries.is_empty():
		source_root.free()
		return
	var source_library := source_player.get_animation_library(String(libraries[0]))
	if source_library == null:
		source_root.free()
		return
	var library := source_library.duplicate(true) as AnimationLibrary
	for loop_name in ["Idle", "Sword_Idle", "Spell_Simple_Idle", "Walk", "Jog_Fwd"]:
		if library.has_animation(loop_name):
			library.get_animation(loop_name).loop_mode = Animation.LOOP_LINEAR
	var player := AnimationPlayer.new()
	player.name = "Motion"
	player.root_node = NodePath("..")
	character.add_child(player)
	player.add_animation_library("", library)
	var idle := _idle_animation(kind)
	if player.has_animation(idle):
		player.play(idle)
		var animation := player.get_animation(idle)
		if animation != null and animation.length > 0.05:
			var phase := float(abs(square.hash()) % 100) / 100.0
			player.seek(animation.length * phase, true)
	source_root.free()

static func _idle_animation(kind: String) -> String:
	if kind in ["B", "Q"]:
		return "Spell_Simple_Idle"
	if kind in ["R", "N", "K"]:
		return "Sword_Idle"
	return "Idle"

static func _add_class_identity(character: Node3D, color: String, kind: String) -> void:
	var skeleton := _find_skeleton(character)
	if skeleton == null:
		return
	var steel := Color("#d4dce8") if color == "w" else Color("#27222e")
	var gold := Color("#c2a354") if color == "w" else Color("#7a5898")
	var magic := Color("#66baff") if color == "w" else Color("#ac5dff")
	match kind:
		"P":
			_attach_spear(skeleton, "hand_r", steel, gold)
		"R":
			_attach_hammer(skeleton, "hand_r", steel, gold)
			_attach_shield(skeleton, "hand_l", steel, magic)
		"N":
			_attach_sword(skeleton, "hand_r", steel, gold)
			_attach_shield(skeleton, "hand_l", steel, magic)
		"B":
			_attach_staff(skeleton, "hand_r", gold, magic)
		"Q":
			_attach_staff(skeleton, "hand_r", gold, magic)
			_attach_crown(skeleton, gold, magic, 7)
		"K":
			_attach_sword(skeleton, "hand_r", steel, gold)
			_attach_shield(skeleton, "hand_l", steel, magic)
			_attach_crown(skeleton, gold, magic, 5)

static func _attach_sword(skeleton: Skeleton3D, bone: String, steel: Color, gold: Color) -> void:
	var hand := _attachment(skeleton, bone, "Sword")
	if hand == null:
		return
	_add_box(hand, Vector3(0, -0.24, 0), Vector3(0.035, 0.52, 0.028), steel, Vector3(0, 0, deg_to_rad(8)))
	_add_box(hand, Vector3(0, 0.02, 0), Vector3(0.18, 0.035, 0.06), gold)

static func _attach_spear(skeleton: Skeleton3D, bone: String, steel: Color, gold: Color) -> void:
	var hand := _attachment(skeleton, bone, "Spear")
	if hand == null:
		return
	_add_cylinder(hand, Vector3(0, -0.30, 0), 0.022, 0.64, gold)
	_add_prism(hand, Vector3(0, -0.66, 0), Vector3(0.07, 0.18, 0.07), steel)

static func _attach_hammer(skeleton: Skeleton3D, bone: String, steel: Color, gold: Color) -> void:
	var hand := _attachment(skeleton, bone, "Hammer")
	if hand == null:
		return
	_add_cylinder(hand, Vector3(0, -0.25, 0), 0.026, 0.48, gold)
	_add_box(hand, Vector3(0, -0.51, 0), Vector3(0.30, 0.14, 0.16), steel)

static func _attach_staff(skeleton: Skeleton3D, bone: String, gold: Color, magic: Color) -> void:
	var hand := _attachment(skeleton, bone, "Staff")
	if hand == null:
		return
	_add_cylinder(hand, Vector3(0, -0.34, 0), 0.022, 0.70, gold)
	_add_orb(hand, Vector3(0, -0.73, 0), 0.085, magic)

static func _attach_shield(skeleton: Skeleton3D, bone: String, steel: Color, magic: Color) -> void:
	var hand := _attachment(skeleton, bone, "Shield")
	if hand == null:
		return
	var shield := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.20
	mesh.bottom_radius = 0.20
	mesh.height = 0.045
	shield.mesh = mesh
	shield.position = Vector3(0.08, -0.04, 0.02)
	shield.rotation_degrees.x = 90.0
	shield.material_override = _material(steel, 0.32, 0.72)
	hand.add_child(shield)
	_add_orb(hand, Vector3(0.08, -0.04, -0.03), 0.035, magic)

static func _attach_crown(skeleton: Skeleton3D, gold: Color, magic: Color, points: int) -> void:
	var head := _attachment(skeleton, "head", "Crown")
	if head == null:
		return
	for i in range(points):
		var angle := TAU * float(i) / float(points)
		var p := Vector3(cos(angle) * 0.105, 0.22, sin(angle) * 0.105)
		_add_prism(head, p, Vector3(0.035, 0.13, 0.035), gold)
	_add_orb(head, Vector3(0, 0.25, 0), 0.035, magic)

static func _attachment(skeleton: Skeleton3D, bone: String, node_name: String) -> BoneAttachment3D:
	if skeleton.find_bone(bone) < 0:
		return null
	var attachment := BoneAttachment3D.new()
	attachment.name = node_name
	attachment.bone_name = bone
	skeleton.add_child(attachment)
	return attachment

static func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node as Skeleton3D
	for child in node.get_children():
		var found := _find_skeleton(child)
		if found != null:
			return found
	return null

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

static func _add_faction_base(root: Node3D, color: String, kind: String) -> void:
	var accent := Color("#5aa4ff") if color == "w" else Color("#a048ff")
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	var radius := 0.39 if kind == "P" else 0.44
	torus.inner_radius = radius
	torus.outer_radius = radius + 0.035
	ring.mesh = torus
	ring.position.y = 0.025
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.material_override = _glow(accent, 2.0)
	root.add_child(ring)

static func _add_box(root: Node3D, pos: Vector3, size: Vector3, color: Color, rotation := Vector3.ZERO) -> void:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.position = pos
	node.rotation = rotation
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

static func _add_cylinder(root: Node3D, pos: Vector3, radius: float, height: float, color: Color) -> void:
	var node := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	node.mesh = mesh
	node.position = pos
	node.material_override = _material(color, 0.40, 0.62)
	root.add_child(node)

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
