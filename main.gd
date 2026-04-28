extends Node3D

@export var move_speed := 3.0
@export var turn_speed := 10.0
@export var animation_blend_time := 0.2

@onready var character: Node3D = $stickman
@onready var animation_player: AnimationPlayer = $stickman/AnimationPlayer
@onready var main_camera: Camera3D = $Camera3D
@onready var outline_viewport: SubViewport = $OutlineViewport
@onready var outline_camera: Camera3D = $OutlineViewport/OutlineCamera3D
@onready var character_mesh: MeshInstance3D = $stickman/Armature/Skeleton3D/Cube
@onready var floor_mesh: MeshInstance3D = $floor3D/MeshInstance3D
@onready var outline_overlay: TextureRect = $ScreenOutline/OutlineOverlay

var tweak_ui: CanvasLayer


func _ready() -> void:
	outline_viewport.world_3d = get_viewport().world_3d
	_sync_outline_camera()
	_build_tweak_ui()
	_play_animation("idle")


func _process(_delta: float) -> void:
	_sync_outline_camera()
	_update_floor_light_center()


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


func _update_floor_light_center() -> void:
	var floor_material := floor_mesh.get_surface_override_material(0) as ShaderMaterial
	floor_material.set_shader_parameter("light_center", character.global_position)


func _sync_outline_camera() -> void:
	outline_camera.global_transform = main_camera.global_transform
	outline_camera.projection = main_camera.projection
	outline_camera.size = main_camera.size
	outline_camera.fov = main_camera.fov
	outline_camera.near = main_camera.near
	outline_camera.far = main_camera.far


func _build_tweak_ui() -> void:
	var character_material := character_mesh.get_surface_override_material(0) as ShaderMaterial
	var floor_material := floor_mesh.get_surface_override_material(0) as ShaderMaterial
	var outline_material := outline_overlay.material as ShaderMaterial

	tweak_ui = CanvasLayer.new()
	tweak_ui.layer = 200
	add_child(tweak_ui)

	var panel := PanelContainer.new()
	panel.offset_left = 12.0
	panel.offset_top = 12.0
	panel.custom_minimum_size = Vector2(310.0, 0.0)
	tweak_ui.add_child(panel)

	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 5)
	panel.add_child(list)

	_add_title(list, "Shader Tweaks  (Tab)")

	_add_section(list, "Character")
	_add_shader_slider(list, character_material, "tone_threshold", "tone", 0.0, 1.0, 0.01)
	_add_shader_slider(list, character_material, "shade_lift", "lift", 0.0, 1.0, 0.01)
	_add_shader_slider(list, character_material, "shadow_strength", "shadow", 0.0, 1.0, 0.01)

	_add_section(list, "Environment Lines")
	_add_shader_slider(list, floor_material, "light_radius", "light", 0.5, 12.0, 0.1)
	_add_shader_slider(list, floor_material, "shade_radius", "shade", 0.5, 20.0, 0.1)
	_add_shader_slider(list, floor_material, "hatch_spacing_px", "spacing", 2.0, 12.0, 1.0)
	_add_shader_slider(list, floor_material, "hatch_width_px", "width", 1.0, 8.0, 1.0)

	_add_section(list, "Outline")
	_add_shader_slider(list, outline_material, "outline_width_px", "width", 1.0, 4.0, 1.0)
	_add_shader_slider(list, outline_material, "coverage_threshold", "coverage", 0.001, 0.02, 0.0001)


func _add_title(parent: VBoxContainer, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 14)
	parent.add_child(label)


func _add_section(parent: VBoxContainer, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 12)
	parent.add_child(label)


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
	label.custom_minimum_size = Vector2(112.0, 0.0)
	row.add_child(label)

	var slider := HSlider.new()
	slider.custom_minimum_size = Vector2(150.0, 0.0)
	slider.min_value = min_value
	slider.max_value = max_value
	slider.step = step
	slider.value = float(material.get_shader_parameter(parameter))
	row.add_child(slider)

	var update_label := func(value: float) -> void:
		label.text = "%s %.4f" % [label_text, value]

	update_label.call(slider.value)
	slider.value_changed.connect(func(value: float) -> void:
		material.set_shader_parameter(parameter, value)
		update_label.call(value)
	)
