class_name GraphicsProfile
extends RefCounted

const HIGH := "high"
const PERFORMANCE := "performance"

static func apply(profile: String, root: Node) -> void:
	var high := profile == HIGH

	# Native Android uses Godot's Mobile renderer. Web remains Compatibility via
	# project-setting override. Keep gameplay identical between profiles.
	ProjectSettings.set_setting("rendering/anti_aliasing/quality/msaa_3d", 2 if high else 1)
	ProjectSettings.set_setting("rendering/lights_and_shadows/directional_shadow/size", 2048 if high else 1024)
	ProjectSettings.set_setting("rendering/lights_and_shadows/positional_shadow/atlas_size", 2048 if high else 1024)

	for node in _walk(root):
		if node is DirectionalLight3D:
			(node as DirectionalLight3D).shadow_enabled = true
		elif node is OmniLight3D:
			var light := node as OmniLight3D
			# Colored faction lights are atmosphere lights. Shadows on them are too
			# expensive for mobile and add little to board readability.
			light.shadow_enabled = false
			light.light_energy *= 1.0 if high else 0.88
		elif node is GPUParticles3D:
			var particles := node as GPUParticles3D
			particles.amount = particles.amount if high else maxi(4, particles.amount / 2)

static func recommended_profile() -> String:
	if OS.has_feature("web"):
		return PERFORMANCE
	# Default native builds to fidelity. The settings menu can switch to
	# Performance without altering game state.
	return HIGH

static func _walk(root: Node) -> Array[Node]:
	var result: Array[Node] = [root]
	for child in root.get_children():
		result.append_array(_walk(child))
	return result
