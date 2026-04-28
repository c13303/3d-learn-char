extends Node3D

@export var move_speed := 3.0
@export var turn_speed := 10.0

@onready var character: Node3D = $stickman
@onready var animation_player: AnimationPlayer = $stickman/AnimationPlayer
@onready var camera: Camera3D = $Camera3D


func _ready() -> void:
	_play_animation("idle")


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

		var camera_forward := -camera.global_transform.basis.z
		camera_forward.y = 0.0
		camera_forward = camera_forward.normalized()

		var camera_right := camera.global_transform.basis.x
		camera_right.y = 0.0
		camera_right = camera_right.normalized()

		var move_direction := camera_right * input_vector.x + camera_forward * input_vector.y
		move_direction = move_direction.normalized()

		character.global_position += move_direction * move_speed * delta
		_face_direction(move_direction, delta)
		_play_animation("walk")
	else:
		_play_animation("idle")


func _face_direction(direction: Vector3, delta: float) -> void:
	var target_angle := atan2(direction.x, direction.z)
	character.rotation.y = lerp_angle(character.rotation.y, target_angle, turn_speed * delta)


func _play_animation(animation_name: StringName) -> void:
	if animation_player.current_animation != animation_name:
		animation_player.play(animation_name)
