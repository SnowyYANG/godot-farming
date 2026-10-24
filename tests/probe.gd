extends Node
func _ready() -> void:
	await get_tree().process_frame
	var cells := Game.map_grass.get_used_cells()
	var minx := 9999; var maxx := -9999; var miny := 9999; var maxy := -9999
	var count := 0
	for c in cells:
		var td := Game.map_grass.get_cell_tile_data(c)
		if td == null: continue
		var tname := ""
		for t in td.terrain_set:
			pass
		count += 1
		minx = min(minx, c.x); maxx = max(maxx, c.x)
		miny = min(miny, c.y); maxy = max(maxy, c.y)
	print("ground cells: ", count, " bbox: ", Vector2i(minx,miny), " .. ", Vector2i(maxx,maxy))
	print("soil cells: ", Game.map_soil.get_used_cells().size())
	# 打印几种 terrain 名字
	var seen := {}
	for c in cells:
		var td := Game.map_grass.get_cell_tile_data(c)
		if td: seen[td.terrain] = seen.get(td.terrain, 0) + 1
	print("terrain 分布: ", seen)
	get_tree().quit()
