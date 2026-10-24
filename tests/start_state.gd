extends Node

## 开局状态检查：应该只有草地，没有土/湿土
func _ready() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var grass := Game.map_grass.get_used_cells().size()
	var soil := Game.map_soil.get_used_cells().size()
	var wet := Game.map_wet_soil.get_used_cells().size()
	print("开局格子数 → grass=%d soil=%d wet=%d" % [grass, soil, wet])
	print("判定: ", "✅ 一片绿" if grass > 0 and soil == 0 and wet == 0 else "❌ 还有土")
	get_tree().quit(0 if (grass > 0 and soil == 0 and wet == 0) else 1)
