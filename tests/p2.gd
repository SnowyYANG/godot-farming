extends Node
func _ready() -> void:
	await get_tree().process_frame
	print("TileSet tile_size: ", Game.map_soil.tile_set.tile_size)
	print("soil 源 region: ", Game.map_soil.tile_set.get_source(0).texture_region_size)
	get_tree().quit()
