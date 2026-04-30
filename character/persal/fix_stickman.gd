@tool
extends EditorScript

const SOURCE_GLB_PATH := "res://character/persal/RIGGED_STICKMAN2_1.glb"
const OUTPUT_SCENE_PATH := "res://character/rigged_stickman_2.tscn"
const ROOT_NODE_NAME := "root_stickman"
const ARMATURE_NAME := "Armature"
const ANIMATION_PLAYER_NAME := "AnimationPlayer"
const ANIMATION_SET_PATH := "res://character/animations/ANIMATIONSET.res"

const ARMATURE_POSITION := Vector3(0.0, 5.27, 0.0)
const ARMATURE_ROTATION_DEGREES := Vector3(6.0, 0.0, 0.0)
const ARMATURE_SCALE := Vector3(0.02, 0.02, 0.02)

const FALLBACK_ANIMATIONS := {
	&"idle2": "res://character/animations/idle2.res",
	&"walk": "res://character/animations/walking.res",
	&"hiphop": "res://character/animations/hiphop.res",
}

const CHARACTER_SHADER: Shader = preload("res://shaders/pink_two_tone.gdshader")
const LIGHT_COLOR := Color(1.0, 0.28, 1.0, 1.0)
const DARK_COLOR := Color(0.78, 0.08, 0.62, 1.0)
const TONE_THRESHOLD := 0.61
const SHADE_LIFT := 0.51
const SHADOW_STRENGTH := 0.0


func _run() -> void:
	generate_stickman_scene()


func generate_stickman_scene() -> void:
	print("fix_stickman: loading source GLB ", SOURCE_GLB_PATH)
	var source_scene := load(SOURCE_GLB_PATH) as PackedScene
	if source_scene == null:
		push_error("fix_stickman: failed to load source GLB '%s'." % SOURCE_GLB_PATH)
		return

	var source_root := source_scene.instantiate() as Node3D
	if source_root == null:
		push_error("fix_stickman: source GLB root is not Node3D.")
		return

	var scene_root := source_root.duplicate() as Node3D
	source_root.free()
	if scene_root == null:
		push_error("fix_stickman: failed to duplicate source GLB as a local scene.")
		return

	scene_root.name = ROOT_NODE_NAME
	_make_local_scene_tree(scene_root)
	print("fix_stickman: generated local scene root ", scene_root.name)

	var armature := _find_required_node3d(scene_root, ARMATURE_NAME)
	if armature == null:
		scene_root.free()
		return

	_fix_armature(scene_root, armature)
	_rewire_shader(scene_root)
	_rewire_animations(scene_root, armature)
	_save_scene(scene_root)


func _make_local_scene_tree(scene_root: Node) -> void:
	scene_root.owner = null
	for child in scene_root.get_children():
		_make_local_scene_branch(child, scene_root)


func _make_local_scene_branch(node: Node, scene_root: Node) -> void:
	node.owner = scene_root
	for child in node.get_children():
		_make_local_scene_branch(child, scene_root)


func _find_required_node3d(root: Node, node_name: String) -> Node3D:
	var node := root.find_child(node_name, true, false) as Node3D
	if node == null:
		push_error("fix_stickman: missing required Node3D '%s'." % node_name)
	return node


func _fix_armature(scene_root: Node3D, armature: Node3D) -> void:
	var armature_path := scene_root.get_path_to(armature)
	print("fix_stickman: %s before position=%s rotation=%s scale=%s" % [armature_path, armature.position, armature.rotation_degrees, armature.scale])
	armature.position = ARMATURE_POSITION
	armature.rotation_degrees = ARMATURE_ROTATION_DEGREES
	armature.scale = ARMATURE_SCALE
	armature.owner = scene_root
	print("fix_stickman: %s after position=%s rotation=%s scale=%s" % [armature_path, armature.position, armature.rotation_degrees, armature.scale])


func _rewire_shader(scene_root: Node3D) -> void:
	if CHARACTER_SHADER == null:
		push_warning("fix_stickman: missing character shader.")
		return

	var character_material := ShaderMaterial.new()
	character_material.shader = CHARACTER_SHADER
	character_material.set_shader_parameter(&"light_pink", LIGHT_COLOR)
	character_material.set_shader_parameter(&"dark_pink", DARK_COLOR)
	character_material.set_shader_parameter(&"tone_threshold", TONE_THRESHOLD)
	character_material.set_shader_parameter(&"shade_lift", SHADE_LIFT)
	character_material.set_shader_parameter(&"shadow_strength", SHADOW_STRENGTH)

	var meshes: Array[MeshInstance3D] = []
	_collect_mesh_instances(scene_root, meshes)
	print("fix_stickman: applying character material to %d mesh instances" % meshes.size())
	for mesh_instance in meshes:
		mesh_instance.material_override = character_material
		mesh_instance.owner = scene_root


func _rewire_animations(scene_root: Node3D, armature: Node3D) -> void:
	var animation_library := _load_or_build_animation_set()
	if animation_library == null:
		push_error("fix_stickman: no animation library available.")
		return

	var animation_player := _find_or_create_animation_player(scene_root, armature)
	for library_name: StringName in animation_player.get_animation_library_list():
		print("fix_stickman: removing animation library '", library_name, "'")
		animation_player.remove_animation_library(library_name)

	animation_player.root_node = NodePath("..")
	animation_player.add_animation_library(&"", animation_library)
	animation_player.owner = scene_root

	print(
		"fix_stickman: assigned %d animations to %s with root %s" %
		[animation_library.get_animation_list().size(), scene_root.get_path_to(animation_player), animation_player.root_node]
	)
	for animation_name: StringName in animation_library.get_animation_list():
		print("fix_stickman: animation available: ", animation_name)


func _find_or_create_animation_player(scene_root: Node3D, armature: Node3D) -> AnimationPlayer:
	var animation_player := armature.get_node_or_null(ANIMATION_PLAYER_NAME) as AnimationPlayer
	if animation_player != null:
		print("fix_stickman: reused animation player ", scene_root.get_path_to(animation_player))
		return animation_player

	animation_player = AnimationPlayer.new()
	animation_player.name = ANIMATION_PLAYER_NAME
	armature.add_child(animation_player)
	animation_player.owner = scene_root
	print("fix_stickman: created animation player ", scene_root.get_path_to(animation_player))
	return animation_player


func _load_or_build_animation_set() -> AnimationLibrary:
	if ResourceLoader.exists(ANIMATION_SET_PATH):
		print("fix_stickman: loading animation set ", ANIMATION_SET_PATH)
		var existing_library := load(ANIMATION_SET_PATH) as AnimationLibrary
		if existing_library != null:
			print("fix_stickman: loaded animation set with %d animations" % existing_library.get_animation_list().size())
			return existing_library
		push_warning("fix_stickman: '%s' exists but is not an AnimationLibrary." % ANIMATION_SET_PATH)

	print("fix_stickman: animation set missing or invalid, refreshing editor filesystem")
	_refresh_editor_filesystem()
	if ResourceLoader.exists(ANIMATION_SET_PATH):
		print("fix_stickman: loading animation set after refresh ", ANIMATION_SET_PATH)
		var imported_library := load(ANIMATION_SET_PATH) as AnimationLibrary
		if imported_library != null:
			print("fix_stickman: loaded animation set with %d animations" % imported_library.get_animation_list().size())
			return imported_library

	print("fix_stickman: building animation set from fallback animations")
	var animation_library := AnimationLibrary.new()
	for animation_name: StringName in FALLBACK_ANIMATIONS:
		var animation_path: String = FALLBACK_ANIMATIONS[animation_name]
		if not ResourceLoader.exists(animation_path):
			push_warning("fix_stickman: missing animation '%s' at '%s'." % [animation_name, animation_path])
			continue

		var animation := load(animation_path) as Animation
		if animation == null:
			push_warning("fix_stickman: failed to load animation '%s' from '%s'." % [animation_name, animation_path])
			continue

		animation_library.add_animation(animation_name, animation)
		print("fix_stickman: imported animation '%s' from '%s'" % [animation_name, animation_path])

	if animation_library.get_animation_list().is_empty():
		push_error("fix_stickman: fallback animation set is empty.")
		return null

	var save_error := ResourceSaver.save(animation_library, ANIMATION_SET_PATH)
	if save_error != OK:
		push_warning("fix_stickman: failed to save '%s' (error %d)." % [ANIMATION_SET_PATH, save_error])
	else:
		print("fix_stickman: saved generated animation set ", ANIMATION_SET_PATH)

	return animation_library


func _refresh_editor_filesystem() -> void:
	if not Engine.is_editor_hint():
		return

	var editor_interface := get_editor_interface()
	if editor_interface == null:
		return

	var resource_filesystem := editor_interface.get_resource_filesystem()
	if resource_filesystem == null:
		return

	resource_filesystem.scan()


func _save_scene(scene_root: Node3D) -> void:
	print("fix_stickman: packing local character scene")
	var save_scene := PackedScene.new()
	var pack_error := save_scene.pack(scene_root)
	if pack_error != OK:
		push_error("fix_stickman: failed to pack scene, error %d." % pack_error)
		scene_root.free()
		return

	var save_error := ResourceSaver.save(save_scene, OUTPUT_SCENE_PATH)
	if save_error != OK:
		push_error("fix_stickman: failed to save scene, error %d." % save_error)
		scene_root.free()
		return

	scene_root.free()
	print("fix_stickman: generated and saved ", OUTPUT_SCENE_PATH)


func _collect_mesh_instances(root: Node, meshes: Array[MeshInstance3D]) -> void:
	if root is MeshInstance3D:
		meshes.append(root as MeshInstance3D)

	for child in root.get_children():
		_collect_mesh_instances(child, meshes)
