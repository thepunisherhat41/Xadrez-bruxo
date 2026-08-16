class_name CharacterFactory
extends RefCounted

const ASSET_ROOT := "res://assets/vendor/quaternius/glTF/"
const MODEL_BY_KIND := {
	"R": "Warrior.gltf",
	"N": "Ranger.gltf",
	"B": "Cleric.gltf",
	"Q": "Wizard.gltf",
	"K": "Warrior.gltf"
}
const PAWN_MODELS := ["Monk.gltf", "Rogue.gltf"]
const CLASS_SCALE := {
	"P": 0.74,
	"R": 0.80,
	"N": 0.77,
	"B": 0.77,
	"Q": 0.83,
	"K": 0.87
}

static func assets_ready() -> bool:
	for filename in ["Cleric.gltf", "Monk.gltf", "Ranger.gltf", "Rogue.gltf", "Warrior.gltf", "Wizard.gltf"]:
		if not ResourceLoader.exists(ASSET_ROOT + filename):
			return false
	return true

static func create_piece(code: String, square: String) -> Node3D:
	if code.length() != 2 or not assets_ready():
		return null
	var color := code.substr(0, 1)
	var kind := code.substr(1, 1)
	var filename := _model_for(kind, square)
	var packed := ResourceLoader.load(ASSET_ROOT + filename) as PackedScene
	if packed == null:
		return null
	var root := Node3D.new()
	root.name = "LivingPiece_%s_%s" % [code, square]
	root.set_meta("piece_code", code)
	root.set_meta("square", square)
	root.set_meta("faction", "astral" if color == "w" else "eclipse")
	var character := packed.instantiate() as Node3D
	if character == null:
		return null
	character.name = "Character"
	root.add_child(character)
	character.scale = Vector3.ONE * float(CLASS_SCALE.get(kind, 0.76))
	character.rotation.y = PI if color == "w" else 0.0
	_enable_shadows(character)
	_tint_character(character, color)
	_start_idle(character, square)
	_add_faction_base(root, color, kind)
	_add_class_sigil(root, color, kind)
	var driver := CharacterMotionDriver.new()
	driver.name = "MotionDriver"
	root.add_child(driver)
	return root

static func play_action(piece: Node3D, action: String) -> void:
	var player := _find_animation_player(piece)
	if player == null:
		return
	var hints: Array = []
	match action:
		"idle": hints = ["idle_weapon", "idle"]
		"walk": hints = ["run_weapon", "walk", "run"]
		"run": hints = ["run_weapon", "run", "walk"]
		"attack":
			var code := String(piece.get_meta("piece_code", "wP"))
			var kind := code.substr(1, 1)
			hints = ["spell1", "spell2", "staff_attack"] if kind in ["B", "Q"] else ["sword_attack", "attack", "punch"]
		"hit": hints = ["recievehit", "hit"]
		"death": hints = ["death"]
		_: hints = [action.to_lower()]
	_play_by_hints(player, hints, action in ["idle", "walk", "run"])

static func _model_for(kind: String, square: String) -> String:
	if kind == "P":
		var file_index := "abcdefgh".find(square.substr(0, 1))
		return String(PAWN_MODELS[file_index % PAWN_MODELS.size()])
	return String(MODEL_BY_KIND.get(kind, "Warrior.gltf"))

static func _start_idle(character: Node3D, square: String) -> void:
	var player := _find_animation_player(character)
	if player == null:
		return
	var chosen := _play_by_hints(player, ["idle_weapon", "idle"], true)
	if chosen.is_empty():
		return
	var animation: Animation = player.get_animation(chosen)
	if animation != null and animation.length > 0.05:
		var phase := float(abs(square.hash()) % 100) / 100.0
		player.seek(animation.length * phase, true)

static func _play_by_hints(player: AnimationPlayer, hints: Array, loop: bool) -> String:
	for hint_value in hints:
		var hint := String(hint_value)
		for animation_name in player.get_animation_list():
			var lower := String(animation_name).to_lower()
			if lower.contains(hint):
				var animation: Animation = player.get_animation(animation_name)
				if animation != null and loop:
					animation.loop_mode = Animation.LOOP_LINEAR
				player.play(animation_name, 0.10)
				return String(animation_name)
	return ""

static func _tint_character(node: Node, color: String) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh != null:
			var copy: Mesh = mesh_instance.mesh.duplicate(true) as Mesh
			var tint: Color = Color(0.88, 0.95, 1.0, 1.0) if color == "w" else Color(0.66, 0.52, 0.78, 1.0)
			for surface in range(copy.get_surface_count()):
				var material: Material = copy.surface_get_material(surface)
				if material is StandardMaterial3D:
					var adjusted := material.duplicate(true) as StandardMaterial3D
					adjusted.albedo_color = adjusted.albedo_color * tint
					copy.surface_set_material(surface, adjusted)
			mesh_instance.mesh = copy
	for child in node.get_children():
		_tint_character(child, color)

static func _add_faction_base(root: Node3D, color: String, kind: String) -> void:
	var accent := Color("#4fa6ff") if color == "w" else Color("#a24cff")
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	var radius := 0.40 if kind == "P" else 0.47
	torus.inner_radius = radius
	torus.outer_radius = radius + 0.034
	ring.mesh = torus
	ring.position.y = 0.025
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.material_override = _glow(accent, 1.8)
	root.add_child(ring)

static func _add_class_sigil(root: Node3D, color: String, kind: String) -> void:
	var accent := Color("#78c4ff") if color == "w" else Color("#c16cff")
	var metal := Color("#c5a95d") if color == "w" else Color("#786090")
	match kind:
		"K":
			_add_crown(root, Vector3(0, 2.08, 0), metal, accent, 5)
		"Q":
			_add_crown(root, Vector3(0, 2.00, 0), metal, accent, 7)
			_add_orb(root, Vector3(0.42, 1.38, 0), 0.075, accent)
		"B":
			_add_orb(root, Vector3(0, 1.82, 0), 0.085, accent)
		"R":
			_add_orb(root, Vector3(-0.34, 1.38, 0), 0.05, accent)
			_add_orb(root, Vector3(0.34, 1.38, 0), 0.05, accent)
		"N":
			_add_orb(root, Vector3(0, 1.70, -0.18), 0.055, accent)

static func _add_crown(root: Node3D, pos: Vector3, metal: Color, magic: Color, points: int) -> void:
	for i in range(points):
		var angle := TAU * float(i) / float(points)
		var spike := MeshInstance3D.new()
		var prism := PrismMesh.new()
		prism.size = Vector3(0.045, 0.16, 0.045)
		spike.mesh = prism
		spike.position = pos + Vector3(cos(angle) * 0.13, 0, sin(angle) * 0.13)
		spike.material_override = _material(metal, 0.30, 0.72)
		spike.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(spike)
	_add_orb(root, pos + Vector3(0, 0.06, 0), 0.045, magic)

static func _add_orb(root: Node3D, pos: Vector3, radius: float, color: Color) -> void:
	var node := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	node.mesh = sphere
	node.position = pos
	node.material_override = _glow(color, 2.4)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(node)

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

static func _material(color: Color, roughness: float, metallic: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	return material

static func _glow(color: Color, energy: float) -> StandardMaterial3D:
	var material := _material(color, 0.24, 0.28)
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	return material
