extends Node

## 展示用：在 5 个格子上种出 5 种作物的成熟形态 + 1 个枯萎
## 运行: godot --path . tests/showcase.tscn

func _ready() -> void:
	await get_tree().process_frame
	await get_tree().process_frame

	# 地块范围是 (6,3)..(13,10)
	var coords := [Vector2i(7, 5), Vector2i(8, 5), Vector2i(9, 5), Vector2i(10, 5), Vector2i(11, 5)]

	for i in range(Game.crop_datas.size()):
		var data: CropData = Game.crop_datas[i]
		var coord: Vector2i = coords[i % coords.size()]
		Game.map_soil.set_cells_terrain_connect([coord], 0, 0)
		var crop: Crop = Prefabs.crop.instantiate()
		Game.crop_pool.add_child(crop)
		crop.setup(data, coord)
		crop.position = Game.map_soil.map_to_local(coord)
		crop.frame = crop.last_stage()      # 直接摆到成熟
		if data.name == "mint":
			crop.is_golden = true
			crop.sprite_frames.set_frame(data.name, crop.last_stage(), data.golden[0])
			crop.frame = crop.last_stage()
		Game.crop_dict[coord] = crop

	# 干土/湿土对照（锄头 = 干土，浇水 = 湿土）
	var dry := Vector2i(7, 3)
	var wet := Vector2i(9, 4)
	Game.map_soil.set_cells_terrain_connect([dry], 0, 0)
	Game.map_wet_soil.set_cells_terrain_connect([wet], 0, 1)

	# 枯萎示例
	var dead_coord := Vector2i(7, 7)
	Game.map_soil.set_cells_terrain_connect([dead_coord], 0, 0)
	var dead: Crop = Prefabs.crop.instantiate()
	Game.crop_pool.add_child(dead)
	dead.setup(Game.crop_datas[0], dead_coord)
	dead.position = Game.map_soil.map_to_local(dead_coord)
	dead._wither()
	Game.crop_dict[dead_coord] = dead
