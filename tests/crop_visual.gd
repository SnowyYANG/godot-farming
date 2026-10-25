extends Node

## 视觉对位用：先验生长逻辑，再把各作物各阶段摆到土上截图看偏移
## 运行: FARM_SHOT=xxx.png godot --path . --windowed tests/crop_visual.tscn

const LAYOUT := [
	["cabbage", 4, 2],
	["radish", 6, 2],
	["mint", 8, 2],
	["mushroom", 10, 2],
]


func _ready() -> void:
	await get_tree().process_frame
	await get_tree().process_frame

	# —— 1. 生长逻辑：真种一格，逐天浇水，打印阶段 ——
	var grow := Vector2i(2, 12)
	Game._apply_terrain(Game.map_soil, grow, Game.TERRAIN_SOIL)
	var live: Crop = Prefabs.crop.instantiate()
	Game.crop_pool.add_child(live)
	live.setup(_find_data("cabbage"), grow)
	live.position = Game.map_soil.map_to_local(grow)
	Game.crop_dict[grow] = live
	for i in range(5):
		Game._apply_terrain(Game.map_wet_soil, grow, Game.TERRAIN_WET)
		Game._end_day()
		print("day ", i, ": frame=", live.frame, "/", live.last_stage(), " mature=", live.is_mature())

	# —— 2. 静态展示：换天把土吃掉了，重新铺土再摆作物 ——
	for entry in LAYOUT:
		var crop_name: String = entry[0]
		var row: int = entry[1]
		var x0: int = entry[2]
		var data := _find_data(crop_name)
		if data == null:
			push_error("找不到作物 %s" % crop_name)
			continue
		for i in _frame_count(crop_name):
			var coord := Vector2i(x0 + i, row)
			Game._apply_terrain(Game.map_soil, coord, Game.TERRAIN_SOIL)
			var crop: Crop = Prefabs.crop.instantiate()
			Game.crop_pool.add_child(crop)
			crop.setup(data, coord)
			crop.position = Game.map_soil.map_to_local(coord)
			crop.frame = i  # 静态展示，不注册进 crop_dict

	await get_tree().process_frame
	if OS.get_environment("FARM_SHOT") != "":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(OS.get_environment("FARM_SHOT"))
		print("shot saved")
	get_tree().quit(0)


func _find_data(crop_name: String) -> CropData:
	for d in Game.crop_datas:
		if d.name == crop_name:
			return d
	return null


func _frame_count(crop_name: String) -> int:
	var prefab: Crop = Prefabs.crop.instantiate()
	var n := prefab.sprite_frames.get_frame_count(crop_name)
	prefab.free()
	return n
