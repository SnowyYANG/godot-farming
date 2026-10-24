extends Node

## 打印实际被 terrain_connect 选中的瓦片坐标，用来判断湿土/干土是否选到同一套图。
## 运行: godot --headless --path . tests/terrain_coords.tscn

func _ready() -> void:
	await get_tree().process_frame
	await get_tree().process_frame

	var cells := Game.map_grass.get_used_cells()
	var mid := Vector2i(0, 0)
	for c in cells:
		mid += c
	mid = Vector2i(mid.x / cells.size(), mid.y / cells.size())

	for dx in range(4):
		for dy in range(3):
			Game.map_soil.set_cells_terrain_connect([mid + Vector2i(dx, dy)], 0, Game.TERRAIN_SOIL)
	for dx in range(2):
		for dy in range(3):
			Game.map_wet_soil.set_cells_terrain_connect([mid + Vector2i(dx, dy)], 0, Game.TERRAIN_WET)

	print("中间点: ", mid)
	for dy in range(3):
		var row := []
		for dx in range(4):
			var c := mid + Vector2i(dx, dy)
			var s := Game.map_soil.get_cell_atlas_coords(c)
			var w := Game.map_wet_soil.get_cell_atlas_coords(c)
			row.append("干(s" + str(Game.map_soil.get_cell_source_id(c)) + " " + str(s) + ")  湿(s" + str(Game.map_wet_soil.get_cell_source_id(c)) + " " + str(w) + ")")
		print("  ", row)
	get_tree().quit()
