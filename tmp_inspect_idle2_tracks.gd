extends SceneTree


func _init() -> void:
	var animation := load("res://character/animations/idle2.res") as Animation
	if animation == null:
		print("idle2=missing")
		quit()
		return

	for track_index in range(animation.get_track_count()):
		var path := animation.track_get_path(track_index)
		var type := animation.track_get_type(track_index)
		if String(path).contains("Hips") or String(path).contains("Armature") or String(path).contains("Skeleton3D"):
			print("%s type=%s keys=%s" % [path, type, animation.track_get_key_count(track_index)])

	quit()
