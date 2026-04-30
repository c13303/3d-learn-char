extends RefCounted

const SOURCE_GLB_PATH := "res://character/persal/RIGGED_STICKMAN2_1.glb"
const OUTPUT_SCENE_PATH := "res://character/rigged_stickman_2.tscn"
const ROOT_NODE_NAME := "root_stickman"
const ARMATURE_NAME := "Armature"
const ANIMATION_PLAYER_NAME := "AnimationPlayer"

const ARMATURE_POSITION := Vector3(0.0, 5.27, 0.0)
const ARMATURE_ROTATION_DEGREES := Vector3(6.0, 0.0, 0.0)
const ARMATURE_SCALE := Vector3(0.02, 0.02, 0.02)

const ANIMATIONS_DIR := "res://character/animations/"

const ANIMATION_FPS := 30.0
const TRIM_END_FRAMES := {
	&"walk": 1,
	&"run": 5
}

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


func _rewire_animations(scene_root: Node3D, armature: Node3D) -> void:
	var animation_library := _load_or_build_animation_set()
	if animation_library == null:
		push_error("fix_stickman: no animation library available.")
		return

	var animation_player := _find_or_create_animation_player(scene_root, armature)
	for library_name: StringName in animation_player.get_animation_library_list():
		print("fix_stickman: removing animation library '", library_name, "'")
		animation_player.remove_animation_library(library_name)

	_apply_trim_end_frames(animation_library)

	animation_player.root_node = NodePath("..")
	animation_player.add_animation_library(&"", animation_library)
	animation_player.owner = scene_root

	print(
		"fix_stickman: assigned %d animations to %s with root %s" %
		[animation_library.get_animation_list().size(), scene_root.get_path_to(animation_player), animation_player.root_node]
	)
	for animation_name: StringName in animation_library.get_animation_list():
		print("fix_stickman: animation available: ", animation_name)


func _apply_trim_end_frames(animation_library: AnimationLibrary) -> void:
	for animation_name: StringName in TRIM_END_FRAMES:
		var frames_to_skip: int = TRIM_END_FRAMES[animation_name]
		if frames_to_skip <= 0:
			continue
		if not animation_library.has_animation(animation_name):
			push_warning("fix_stickman: cannot trim '%s', animation not in library." % animation_name)
			continue

		var animation := animation_library.get_animation(animation_name)
		var trimmed := animation.duplicate() as Animation
		var new_length := trimmed.length - (float(frames_to_skip) / ANIMATION_FPS)
		if new_length <= 0.0:
			push_warning("fix_stickman: trim of %d frames would zero '%s' (length %f)." % [frames_to_skip, animation_name, trimmed.length])
			continue

		trimmed.length = new_length
		trimmed.loop_mode = Animation.LOOP_LINEAR
		animation_library.remove_animation(animation_name)
		animation_library.add_animation(animation_name, trimmed)
		print("fix_stickman: trimmed '%s' by %d frame(s) -> length %f" % [animation_name, frames_to_skip, new_length])


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
	_refresh_editor_filesystem()

	print("fix_stickman: scanning ", ANIMATIONS_DIR, " for animations")
	var animation_library := AnimationLibrary.new()
	var animation_paths := _scan_animation_paths(ANIMATIONS_DIR)
	for animation_path: String in animation_paths:
		var animation_name := StringName(animation_path.get_file().get_basename())
		var animation := load(animation_path) as Animation
		if animation == null:
			push_warning("fix_stickman: failed to load animation at '%s'." % animation_path)
			continue
		animation_library.add_animation(animation_name, animation)
		print("fix_stickman: imported animation '%s' from '%s'" % [animation_name, animation_path])

	if animation_library.get_animation_list().is_empty():
		push_error("fix_stickman: no animations found in '%s'." % ANIMATIONS_DIR)
		return null

	return animation_library


func _scan_animation_paths(dir_path: String) -> Array[String]:
	var paths: Array[String] = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		push_error("fix_stickman: could not open '%s'." % dir_path)
		return paths

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.get_extension() == "res":
			var basename := file_name.get_basename()
			if basename != "ANIMATIONSET":
				paths.append(dir_path.path_join(file_name))
		file_name = dir.get_next()
	dir.list_dir_end()
	paths.sort()
	return paths


func _refresh_editor_filesystem() -> void:
	if not Engine.is_editor_hint():
		return
	if not Engine.has_singleton("EditorInterface"):
		return

	var editor_interface := Engine.get_singleton("EditorInterface")
	if editor_interface == null:
		return
	if not editor_interface.has_method("get_resource_filesystem"):
		return

	var resource_filesystem: Object = editor_interface.call("get_resource_filesystem")
	if resource_filesystem == null:
		return
	if not resource_filesystem.has_method("scan"):
		return

	resource_filesystem.call("scan")


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
