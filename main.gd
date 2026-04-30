extends Node3D

@export var move_speed := 3.0
@export var turn_speed := 10.0
@export var animation_blend_time := 0.2
@export var camera_follow_speed := 6.0
@export var character_scene: PackedScene
@export var character_shader: Shader = preload("res://shaders/pink_two_tone.gdshader")
@export var character_light_color := Color(1.0, 0.28, 1.0, 1.0)
@export var character_dark_color := Color(0.78, 0.08, 0.62, 1.0)
@export_range(0.0, 1.0, 0.01) var character_tone_threshold := 0.61
@export_range(0.0, 1.0, 0.01) var character_shade_lift := 0.51
@export_range(0.0, 1.0, 0.01) var character_shadow_strength := 0.0
@export var character_outline_enabled := true
@export var outline_id_texture: Texture2D = preload("res://character/persal/RIGGED_STICKMAN2_Material.png")

@onready var main_camera: Camera3D = $Camera3D
@onready var outline_viewport: SubViewport = $OutlineViewport
@onready var outline_camera: Camera3D = $OutlineViewport/OutlineCamera3D
@onready var floor_mesh: MeshInstance3D = $floor3D/MeshInstance3D
@onready var decor_mesh: MeshInstance3D = $decor/MeshInstance3D
@onready var outline_overlay: TextureRect = $ScreenOutline/OutlineOverlay

const CHARACTER_NODE_NAME := "root_stickman"
const OUTLINE_ID_VISUAL_LAYER := 2
const TWEAK_SETTINGS_PATH := "res://shader_tweaks.cfg"
const OUTLINE_ID_SHADER := preload("res://shaders/outline_id_mask.gdshader")

var character: Node3D
var animation_player: AnimationPlayer
var character_mesh: MeshInstance3D
var character_material: ShaderMaterial
var outline_id_materials: Dictionary = {}
var tweak_ui: CanvasLayer
var camera_offset := Vector3.ZERO
var tweak_materials: Dictionary = {}
var tweak_control_refreshers: Array[Callable] = []
var one_shot_animation: StringName = &""


func _ready() -> void:
	_setup_character()
	if not _has_character_controller_target():
		set_process(false)
		set_physics_process(false)
		set_process_unhandled_input(false)
		return

	camera_offset = main_camera.global_position - character.global_position
	main_camera.cull_mask &= ~OUTLINE_ID_VISUAL_LAYER
	outline_viewport.world_3d = get_viewport().world_3d
	_sync_outline_camera()
	_build_tweak_ui()
	animation_player.animation_finished.connect(_on_animation_finished)
	_play_animation("idle2")


func _process(_delta: float) -> void:
	_sync_outline_camera()


func _physics_process(delta: float) -> void:
	var input_vector := Vector2.ZERO

	if Input.is_key_pressed(KEY_D):
		input_vector.x += 1.0
	if Input.is_key_pressed(KEY_Q):
		input_vector.x -= 1.0
	if Input.is_key_pressed(KEY_Z):
		input_vector.y += 1.0
	if Input.is_key_pressed(KEY_S):
		input_vector.y -= 1.0

	if input_vector != Vector2.ZERO:
		input_vector = input_vector.normalized()

		var move_direction := Vector3(input_vector.x, 0.0, -input_vector.y)

		character.global_position += move_direction * move_speed * delta
		_face_direction(move_direction, delta)
		if one_shot_animation == &"":
			_play_animation("walk")
	elif one_shot_animation == &"":
		_play_animation("idle2")

	_update_camera(delta)


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return

	if tweak_ui != null and event.keycode == KEY_TAB:
		tweak_ui.visible = not tweak_ui.visible
	elif event.keycode == KEY_H:
		_trigger_one_shot(&"hiphop")
	elif event.keycode == KEY_I:
		_trigger_one_shot(&"idle2")


func _trigger_one_shot(animation_name: StringName) -> void:
	if animation_player == null or not animation_player.has_animation(animation_name):
		return
	one_shot_animation = animation_name
	animation_player.play(animation_name, animation_blend_time)


func _on_animation_finished(animation_name: StringName) -> void:
	if animation_name == one_shot_animation:
		one_shot_animation = &""


func _face_direction(direction: Vector3, delta: float) -> void:
	var target_angle := atan2(direction.x, direction.z)
	character.rotation.y = lerp_angle(character.rotation.y, target_angle, turn_speed * delta)


func _play_animation(animation_name: StringName) -> void:
	if animation_player != null and animation_player.has_animation(animation_name) and animation_player.current_animation != animation_name:
		animation_player.play(animation_name, animation_blend_time)


func _update_camera(delta: float) -> void:
	var target_position := character.global_position + camera_offset
	var weight := 1.0 - exp(-camera_follow_speed * delta)
	main_camera.global_position = main_camera.global_position.lerp(target_position, weight)


func _setup_character() -> void:
	var current_character := get_node_or_null(CHARACTER_NODE_NAME) as Node3D

	if character_scene != null:
		var scene_path := character_scene.resource_path
		if current_character == null or current_character.scene_file_path != scene_path:
			if current_character != null:
				remove_child(current_character)
				current_character.queue_free()

			current_character = character_scene.instantiate() as Node3D
			if current_character != null:
				current_character.name = CHARACTER_NODE_NAME
				add_child(current_character)

	character = current_character
	if character != null:
		animation_player = character.find_child("AnimationPlayer", true, false) as AnimationPlayer
		character_mesh = _find_first_mesh_instance(character)
		_apply_character_shader()
		_apply_character_outline_layer()


func _has_character_controller_target() -> bool:
	if character == null:
		push_warning("Main controller disabled: missing character node or character_scene.")
		return false
	if not character is Node3D:
		push_warning("Main controller disabled: selected character scene root is not Node3D.")
		return false
	if animation_player == null:
		push_warning("Main controller disabled: selected character is missing an AnimationPlayer.")
		return false
	return true


func _find_first_mesh_instance(root: Node) -> MeshInstance3D:
	if root is MeshInstance3D:
		return root

	for child: Node in root.get_children():
		var mesh := _find_first_mesh_instance(child)
		if mesh != null:
			return mesh

	return null


func _apply_character_shader() -> void:
	if character_shader == null:
		return

	if character != null and character.has_method(&"rewire_shader"):
		character_material = character.rewire_shader(
			character_shader,
			character_light_color,
			character_dark_color,
			character_tone_threshold,
			character_shade_lift,
			character_shadow_strength
		)
		if character_material != null:
			return

	character_material = ShaderMaterial.new()
	character_material.shader = character_shader
	character_material.set_shader_parameter(&"light_pink", character_light_color)
	character_material.set_shader_parameter(&"dark_pink", character_dark_color)
	character_material.set_shader_parameter(&"tone_threshold", character_tone_threshold)
	character_material.set_shader_parameter(&"shade_lift", character_shade_lift)
	character_material.set_shader_parameter(&"shadow_strength", character_shadow_strength)

	var meshes: Array[MeshInstance3D] = []
	_collect_mesh_instances(character, meshes)
	for mesh_instance: MeshInstance3D in meshes:
		var surface_count := 1
		if mesh_instance.mesh != null:
			surface_count = mesh_instance.mesh.get_surface_count()

		for surface_index: int in range(surface_count):
			mesh_instance.set_surface_override_material(surface_index, character_material)


func _collect_mesh_instances(root: Node, meshes: Array[MeshInstance3D]) -> void:
	if root is MeshInstance3D:
		var mesh_instance := root as MeshInstance3D
		if not mesh_instance.has_meta(&"outline_mask"):
			meshes.append(mesh_instance)

	for child: Node in root.get_children():
		_collect_mesh_instances(child, meshes)


func _apply_character_outline_layer() -> void:
	_clear_outline_id_masks()

	var meshes: Array[MeshInstance3D] = []
	_collect_mesh_instances(character, meshes)
	for mesh_instance: MeshInstance3D in meshes:
		mesh_instance.layers &= ~OUTLINE_ID_VISUAL_LAYER

	if not character_outline_enabled:
		return

	if outline_id_texture != null:
		for mesh_instance: MeshInstance3D in meshes:
			_add_outline_id_mask(mesh_instance, Color.WHITE, outline_id_texture)
		return

	var surface_mesh := character.find_child("Alpha_Surface", true, false) as MeshInstance3D
	var joints_mesh := character.find_child("Alpha_Joints", true, false) as MeshInstance3D
	if surface_mesh != null:
		_add_outline_id_mask(surface_mesh, Color(1.0, 0.0, 0.0, 1.0))
	if joints_mesh != null:
		_add_outline_id_mask(joints_mesh, Color(0.0, 1.0, 0.0, 1.0))
	if surface_mesh == null and joints_mesh == null:
		for mesh_instance: MeshInstance3D in meshes:
			_add_outline_id_mask(mesh_instance, Color(1.0, 0.0, 0.0, 1.0))


func _clear_outline_id_masks() -> void:
	if character == null:
		return

	for node: Node in find_children("*", "MeshInstance3D", true, false):
		if node.has_meta(&"outline_mask"):
			node.queue_free()


func _add_outline_id_mask(source: MeshInstance3D, id_color: Color, id_texture: Texture2D = null) -> void:
	var parent := source.get_parent()
	if parent == null:
		return

	var material_key := "%s:%s" % [source.name, id_texture.resource_path if id_texture != null else ""]
	if not outline_id_materials.has(material_key):
		var new_id_material := ShaderMaterial.new()
		new_id_material.shader = OUTLINE_ID_SHADER
		new_id_material.set_shader_parameter(&"id_color", id_color)
		new_id_material.set_shader_parameter(&"use_id_texture", id_texture != null)
		if id_texture != null:
			new_id_material.set_shader_parameter(&"id_texture", id_texture)
		outline_id_materials[material_key] = new_id_material

	var id_mask := source.duplicate() as MeshInstance3D
	if id_mask == null:
		return

	var id_material := outline_id_materials[material_key] as ShaderMaterial
	id_mask.name = "%s_OutlineIdMask" % source.name
	id_mask.set_meta(&"outline_mask", true)
	id_mask.layers = OUTLINE_ID_VISUAL_LAYER
	id_mask.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	id_mask.material_override = id_material

	if id_mask.mesh != null:
		for surface_index: int in range(id_mask.mesh.get_surface_count()):
			id_mask.set_surface_override_material(surface_index, id_material)

	parent.add_child(id_mask)


func _sync_outline_camera() -> void:
	outline_camera.global_transform = main_camera.global_transform
	outline_camera.projection = main_camera.projection
	outline_camera.size = main_camera.size
	outline_camera.fov = main_camera.fov
	outline_camera.near = main_camera.near
	outline_camera.far = main_camera.far


func _build_tweak_ui() -> void:
	tweak_control_refreshers.clear()

	var floor_material := floor_mesh.get_surface_override_material(0) as StandardMaterial3D
	var decor_material := decor_mesh.get_surface_override_material(0) as StandardMaterial3D
	var outline_material := outline_overlay.material as ShaderMaterial
	var had_saved_settings := FileAccess.file_exists(TWEAK_SETTINGS_PATH)

	tweak_materials = {
		"floor": floor_material,
		"decor": decor_material,
		"outline": outline_material,
		"movement": self,
	}
	if character_material != null:
		tweak_materials["character"] = character_material
	_load_tweak_settings()

	tweak_ui = CanvasLayer.new()
	tweak_ui.layer = 200
	add_child(tweak_ui)

	var panel := PanelContainer.new()
	panel.offset_left = 4.0
	panel.offset_top = 4.0
	panel.custom_minimum_size = Vector2(220.0, 0.0)
	tweak_ui.add_child(panel)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(220.0, 420.0)
	panel.add_child(scroll)

	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 2)
	scroll.add_child(list)

	_add_title(list, "Shader Tweaks  (Tab)")
	_add_tweak_buttons(list)

	if tweak_materials.has("character"):
		_add_section(list, "Character")
		_add_tweak_color_picker(list, "character", "light_pink", "light")
		_add_tweak_color_picker(list, "character", "dark_pink", "dark")
		_add_tweak_slider(list, "character", "tone_threshold", "tone", 0.0, 1.0, 0.01)
		_add_tweak_slider(list, "character", "shade_lift", "lift", 0.0, 1.0, 0.01)
		_add_tweak_slider(list, "character", "shadow_strength", "shadow", 0.0, 1.0, 0.01)

	_add_section(list, "Movement")
	_add_tweak_slider(list, "movement", "move_speed", "speed", 0.0, 20.0, 0.1)

	_add_section(list, "Floor")
	_add_tweak_color_picker(list, "floor", "base_color", "color")

	_add_section(list, "Decor")
	_add_tweak_color_picker(list, "decor", "base_color", "color")

	_add_section(list, "Outline")
	_add_tweak_color_picker(list, "outline", "outline_color", "color")
	_add_tweak_slider(list, "outline", "outline_width_px", "width", 1.0, 4.0, 1.0)
	_add_tweak_slider(list, "outline", "coverage_threshold", "coverage", 0.001, 0.02, 0.0001)

	if not had_saved_settings:
		_save_tweak_settings()


func _load_tweak_settings() -> void:
	var config := ConfigFile.new()
	var err := config.load(TWEAK_SETTINGS_PATH)
	if err != OK:
		return

	for section: String in tweak_materials:
		if not config.has_section(section):
			continue

		if not tweak_materials.has(section):
			continue

		for parameter: StringName in _tweak_parameters_for_section(section):
			if not config.has_section_key(section, String(parameter)):
				continue

			var value: Variant = config.get_value(section, String(parameter))
			_set_tweak_value(section, parameter, value)


func _save_tweak_settings() -> void:
	var config := ConfigFile.new()

	for section: String in tweak_materials:
		for parameter: StringName in _tweak_parameters_for_section(section):
			config.set_value(section, String(parameter), _get_tweak_value(section, parameter))

	var err := config.save(TWEAK_SETTINGS_PATH)
	if err != OK:
		push_warning("Could not save shader tweaks to %s. Error: %s" % [TWEAK_SETTINGS_PATH, err])


func _restore_tweak_settings() -> void:
	_load_tweak_settings()
	for refresh: Callable in tweak_control_refreshers:
		refresh.call()


func _tweak_parameters_for_section(section: String) -> Array[StringName]:
	match section:
		"character":
			return [
				&"light_pink",
				&"dark_pink",
				&"tone_threshold",
				&"shade_lift",
				&"shadow_strength",
			]
		"floor", "decor":
			return [
				&"base_color",
			]
		"outline":
			return [
				&"outline_color",
				&"outline_width_px",
				&"coverage_threshold",
			]
		"movement":
			return [
				&"move_speed",
			]

	return []


func _get_tweak_value(section: String, parameter: StringName) -> Variant:
	match section:
		"character", "outline":
			var material := tweak_materials[section] as ShaderMaterial
			return material.get_shader_parameter(parameter)
		"floor", "decor":
			var surface_material := tweak_materials[section] as StandardMaterial3D

			if parameter == &"base_color":
				return surface_material.albedo_color
		"movement":
			return get(String(parameter))

	return null


func _set_tweak_value(section: String, parameter: StringName, value: Variant) -> void:
	match section:
		"character", "outline":
			var material := tweak_materials[section] as ShaderMaterial
			material.set_shader_parameter(parameter, value)
			if parameter == &"base_color":
				material.set_shader_parameter(&"highlight_color", value)
		"floor", "decor":
			var surface_material := tweak_materials[section] as StandardMaterial3D

			if parameter == &"base_color":
				surface_material.albedo_color = value
		"movement":
			set(String(parameter), value)


func _add_title(parent: VBoxContainer, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 10)
	parent.add_child(label)


func _add_section(parent: VBoxContainer, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 9)
	parent.add_child(label)


func _add_tweak_buttons(parent: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	parent.add_child(row)

	var save_button := Button.new()
	save_button.text = "Save"
	save_button.custom_minimum_size = Vector2(92.0, 0.0)
	save_button.add_theme_font_size_override("font_size", 9)
	row.add_child(save_button)

	var restore_button := Button.new()
	restore_button.text = "Restore"
	restore_button.custom_minimum_size = Vector2(92.0, 0.0)
	restore_button.add_theme_font_size_override("font_size", 9)
	row.add_child(restore_button)

	save_button.pressed.connect(_save_tweak_settings)
	restore_button.pressed.connect(_restore_tweak_settings)


func _add_tweak_slider(
	parent: VBoxContainer,
	section: String,
	parameter: StringName,
	label_text: String,
	min_value: float,
	max_value: float,
	step: float
) -> void:
	var row := HBoxContainer.new()
	parent.add_child(row)

	var label := Label.new()
	label.custom_minimum_size = Vector2(74.0, 0.0)
	label.add_theme_font_size_override("font_size", 9)
	row.add_child(label)

	var slider := HSlider.new()
	slider.custom_minimum_size = Vector2(112.0, 0.0)
	slider.min_value = min_value
	slider.max_value = max_value
	slider.step = step
	slider.value = float(_get_tweak_value(section, parameter))
	row.add_child(slider)

	var update_label := func(value: float) -> void:
		label.text = "%s %.4f" % [label_text, value]

	var refresh := func() -> void:
		slider.set_value_no_signal(float(_get_tweak_value(section, parameter)))
		update_label.call(slider.value)

	refresh.call()
	tweak_control_refreshers.append(refresh)

	slider.value_changed.connect(func(value: float) -> void:
		_set_tweak_value(section, parameter, value)
		update_label.call(value)
	)


func _add_tweak_color_picker(
	parent: VBoxContainer,
	section: String,
	parameter: StringName,
	label_text: String
) -> void:
	var row := HBoxContainer.new()
	parent.add_child(row)

	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(74.0, 0.0)
	label.add_theme_font_size_override("font_size", 9)
	row.add_child(label)

	var picker := ColorPickerButton.new()
	picker.custom_minimum_size = Vector2(112.0, 0.0)
	row.add_child(picker)

	var refresh := func() -> void:
		picker.color = _get_tweak_value(section, parameter)

	refresh.call()
	tweak_control_refreshers.append(refresh)

	picker.color_changed.connect(func(color: Color) -> void:
		_set_tweak_value(section, parameter, color)
	)
