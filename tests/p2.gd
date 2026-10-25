extends Node
func _ready() -> void:
	await get_tree().process_frame
	print("TileSet tile_size: ", Game.map_soil.tile_set.tile_size)
	var ts := Game.map_soil.tile_set
	var atlas := ts.get_source(ts.get_source_id(0)) as TileSetAtlasSource
	print("soil 源 region: ", atlas.texture_region_size)
	get_tree().quit()
