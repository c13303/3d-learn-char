extends Node3D

@onready var animation_player: AnimationPlayer = $stickman/AnimationPlayer


func _ready() -> void:
	animation_player.play("idle")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_A:
				animation_player.play("idle")
			KEY_Z:
				animation_player.play("walk")
