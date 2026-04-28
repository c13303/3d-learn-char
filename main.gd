extends Node3D

@export var move_speed := 3.0
@export var turn_speed := 10.0
@export var animation_blend_time := 0.2
@export var camera_follow_speed := 6.0

@onready var character: Node3D = $stickman
@onready var animation_player: AnimationPlayer = $stickman/AnimationPlayer
@onready var main_camera: Camera3D = $Camera3D
@onready var outline_viewport: SubViewport = $OutlineViewport
@onready var outline_camera: Camera3D = $OutlineViewport/OutlineCamera3D
@onready var character_mesh: MeshInstance3D = $stickman/Armature/Skeleton3D/Cube
@onready var floor_mesh: MeshInstance3D = $floor3D/MeshInstance3D
@onready var decor_mesh: MeshInstance3D = $decor/MeshInstance3D
@onready var outline_overlay: TextureRect = $ScreenOutline/OutlineOverlay

const TWEAK_SETTINGS_PATH := "res://shader_tweaks.cfg"

var tweak_ui: CanvasLayer
var camera_offset := Vector3.ZERO
var tweak_materials: Dictionary = {}
var tweak_control_refreshers: Array[Callable] = []


func _ready() -> void:
	camera_offset = main_camera.global_position - character.global_position
	outline_viewport.world_3d = get_viewport().world_3d
	_sync_outline_camera()
	_build_tweak_ui()
	_play_animation("idle")


func _process(_delta: float) -> void:
	_update_camera(_delta)
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
		_play_animation("walk")
	else:
		_play_animation("idle")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_TAB:
		tweak_ui.visible = not tweak_ui.visible


func _face_direction(direction: Vector3, delta: float) -> void:
	var target_angle := atan2(direction.x, direction.z)
	character.rotation.y = lerp_angle(character.rotation.y, target_angle, turn_speed * delta)


func _play_animation(animation_name: StringName) -> void:
	if animation_player.current_animation != animation_name:
		animation_player.play(animation_name, animation_blend_time)


func _update_camera(delta: float) -> void:
	var target_position := character.global_position + camera_offset
	var weight := 1.0 - exp(-camera_follow_speed * delta)
	main_camera.global_position = main_camera.global_position.lerp(target_position, weight)


func _sync_outline_camera() -> void:
	outline_camera.global_transform = main_camera.global_transform
	outline_camera.projection = main_camera.projection
	outline_camera.size = main_camera.size
	outline_camera.fov = main_camera.fov
	outline_camera.near = main_camera.near
	outline_camera.far = main_camera.far


func _build_tweak_ui() -> void:
	tweak_control_refreshers.clear()

	var character_material := character_mesh.get_surface_override_material(0) as ShaderMaterial
	var floor_material := floor_mesh.get_surface_override_material(0) as ShaderMaterial
	var decor_material := decor_mesh.get_surface_override_material(0) as ShaderMaterial
	var outline_material := outline_overlay.material as ShaderMaterial
	var had_saved_settings := FileAccess.file_exists(TWEAK_SETTINGS_PATH)

	tweak_materials = {
		"character": character_material,
		"floor": floor_material,
		"decor": decor_material,
		"outline": outline_material,
	}
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

	_add_section(list, "Character")
	_add_shader_color_picker(list, character_material, "light_pink", "light")
	_add_shader_color_picker(list, character_material, "dark_pink", "dark")
	_add_shader_slider(list, character_material, "tone_threshold", "tone", 0.0, 1.0, 0.01)
	_add_shader_slider(list, character_material, "shade_lift", "lift", 0.0, 1.0, 0.01)
	_add_shader_slider(list, character_material, "shadow_strength", "shadow", 0.0, 1.0, 0.01)

	_add_section(list, "Floor")
	_add_shader_color_picker(list, floor_material, "base_color", "color")
	_add_shader_color_picker(list, floor_material, "ink_color", "lines")
	_add_shader_slider(list, floor_material, "hatch_threshold", "hatch", 0.0, 1.0, 0.01)
	_add_shader_slider(list, floor_material, "black_threshold", "black", 0.0, 1.0, 0.01)
	_add_shader_slider(list, floor_material, "shade_lift", "lift", 0.0, 1.0, 0.01)
	_add_shader_slider(list, floor_material, "shadow_strength", "shadow", 0.0, 1.0, 0.01)
	_add_shader_slider(list, floor_material, "hatch_spacing_px", "spacing", 2.0, 12.0, 1.0)
	_add_shader_slider(list, floor_material, "hatch_width_px", "width", 1.0, 8.0, 1.0)

	_add_section(list, "Decor")
	_add_shader_color_picker(list, decor_material, "base_color", "color")
	_add_shader_color_picker(list, decor_material, "ink_color", "lines")
	_add_shader_slider(list, decor_material, "hatch_threshold", "hatch", 0.0, 1.0, 0.01)
	_add_shader_slider(list, decor_material, "black_threshold", "black", 0.0, 1.0, 0.01)
	_add_shader_slider(list, decor_material, "shade_lift", "lift", 0.0, 1.0, 0.01)
	_add_shader_slider(list, decor_material, "shadow_strength", "shadow", 0.0, 1.0, 0.01)
	_add_shader_slider(list, decor_material, "hatch_spacing_px", "spacing", 2.0, 12.0, 1.0)
	_add_shader_slider(list, decor_material, "hatch_width_px", "width", 1.0, 8.0, 1.0)

	_add_section(list, "Outline")
	_add_shader_color_picker(list, outline_material, "outline_color", "color")
	_add_shader_slider(list, outline_material, "outline_width_px", "width", 1.0, 4.0, 1.0)
	_add_shader_slider(list, outline_material, "coverage_threshold", "coverage", 0.001, 0.02, 0.0001)

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

		var material := tweak_materials[section] as ShaderMaterial
		if material == null:
			continue

		for parameter: StringName in _tweak_parameters_for_section(section):
			if not config.has_section_key(section, String(parameter)):
				continue

			var value: Variant = config.get_value(section, String(parameter))
			material.set_shader_parameter(parameter, value)
			if parameter == &"base_color":
				material.set_shader_parameter(&"highlight_color", value)


func _save_tweak_settings() -> void:
	var config := ConfigFile.new()

	for section: String in tweak_materials:
		var material := tweak_materials[section] as ShaderMaterial
		if material == null:
			continue

		for parameter: StringName in _tweak_parameters_for_section(section):
			config.set_value(section, String(parameter), material.get_shader_parameter(parameter))

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
				&"ink_color",
				&"hatch_threshold",
				&"black_threshold",
				&"shade_lift",
				&"shadow_strength",
				&"hatch_spacing_px",
				&"hatch_width_px",
			]
		"outline":
			return [
				&"outline_color",
				&"outline_width_px",
				&"coverage_threshold",
			]

	return []


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


func _add_shader_slider(
	parent: VBoxContainer,
	material: ShaderMaterial,
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
	slider.value = float(material.get_shader_parameter(parameter))
	row.add_child(slider)

	var update_label := func(value: float) -> void:
		label.text = "%s %.4f" % [label_text, value]

	var refresh := func() -> void:
		slider.set_value_no_signal(float(material.get_shader_parameter(parameter)))
		update_label.call(slider.value)

	refresh.call()
	tweak_control_refreshers.append(refresh)

	slider.value_changed.connect(func(value: float) -> void:
		material.set_shader_parameter(parameter, value)
		update_label.call(value)
	)


func _add_shader_color_picker(
	parent: VBoxContainer,
	material: ShaderMaterial,
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
		picker.color = material.get_shader_parameter(parameter)

	refresh.call()
	tweak_control_refreshers.append(refresh)

	picker.color_changed.connect(func(color: Color) -> void:
		material.set_shader_parameter(parameter, color)
		if parameter == &"base_color":
			material.set_shader_parameter("highlight_color", color)
	)
