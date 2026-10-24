extends Node
func _ready() -> void:
	await get_tree().process_frame
	var c := Vector2i(6, 3)
	Game.map_soil.set_cells_terrain_connect([c], 0, 0)
	Game.map_wet_soil.set_cells_terrain_connect([c], 0, 1)
	print("soil tile: ", Game.map_soil.get_cell_atlas_coords(c))
	print("wet tile : ", Game.map_wet_soil.get_cell_atlas_coords(c))
	print("wet 层 modulate: ", Game.map_wet_soil.modulate)
	print("wet 层 tile_set 源数: ", Game.map_wet_soil.tile_set.get_source_count())
	get_tree().quit()
