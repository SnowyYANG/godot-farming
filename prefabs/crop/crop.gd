class_name Crop
extends AnimatedSprite2D

var coord: Vector2i

var watered: bool:
	get:
		return Game.map_wet_soil.get_cell_tile_data(coord) != null

func harvest(delay: float) -> void:
	await get_tree().create_timer(0.6 + delay).timeout
	var target_stock: StockLabel = Game.stock_pool.get_node(str(animation))
	var pos = target_stock.global_position + Vector2(4, 4)
	await create_tween().tween_property(self, "global_position", pos, 0.4).finished
	target_stock.number += 1
	Game.crop_dict.erase(coord)
	Game.crop_pool.remove_child(self)
	queue_free()
