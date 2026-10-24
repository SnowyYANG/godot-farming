extends Node

## 把每种作物的每个阶段排成一行，用来核对贴图有没有被裁掉。
## 运行: godot --path . tests/crop_stages.tscn

func _ready() -> void:
	await get_tree().process_frame
	await get_tree().process_frame

	var cells := Game.map_grass.get_used_cells()
	var mid := Vector2i(0, 0)
	for c in cells:
		mid += c
	mid = Vector2i(mid.x / cells.size(), mid.y / cells.size())

	var row := 0
	for data in Game.crop_datas:
		for stage in data.stages.size():
			var coord := mid + Vector2i(stage, row)
			Game.map_soil.set_cells_terrain_connect([coord], 0, Game.TERRAIN_SOIL)
			var crop: Crop = Prefabs.crop.instantiate()
			Game.crop_pool.add_child(crop)
			crop.setup(data, coord)
			crop.position = Game.map_soil.map_to_local(coord)
			crop.frame = stage
		row += 1

	print("已摆放 %d 种作物" % Game.crop_datas.size())
