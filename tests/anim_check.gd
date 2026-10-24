extends SceneTree
func _init() -> void:
	var ps: PackedScene = load("res://prefabs/crop/crop.tscn")
	var inst = ps.instantiate()
	var sf: SpriteFrames = inst.sprite_frames
	var names := sf.get_animation_names()
	print("动画数量: ", names.size())
	for n in names:
		var tex = sf.get_frame_texture(n, 0)
		print("  %-10s %d 帧   首帧尺寸 %s" % [n, sf.get_frame_count(n), tex.get_size() if tex else "?"])
	inst.free()
	quit()
