extends Node
func _ready() -> void:
	await get_tree().process_frame
	var ts := Game.map_soil.tile_set
	var atlas := ts.get_source(ts.get_source_id(0)) as TileSetAtlasSource
	print("tile_size: ", ts.tile_size)
	print("region: ", atlas.texture_region_size)
	print("贴图: ", atlas.texture.get_size())
	var c := Vector2i(6, 3)
	Game.map_soil.set_cells_terrain_connect([c], 0, 0)
	Game.map_wet_soil.set_cells_terrain_connect([c + Vector2i(0,1)], 0, 1)
	print("干土 tile: ", Game.map_soil.get_cell_atlas_coords(c))
	print("湿土 tile: ", Game.map_wet_soil.get_cell_atlas_coords(c + Vector2i(0,1)))
	get_tree().quit()
