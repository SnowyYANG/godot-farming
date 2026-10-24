extends Node

## 视觉检查用：在开局草地上锄出一块 4x3，其中 2x3 浇水，用来肉眼确认
## grass / soil / wetsoil 三层的贴图与叠放关系。
## 运行: godot --path . tests/visual_terrain.tscn

func _ready() -> void:
	await get_tree().process_frame
	await get_tree().process_frame

	var cells := Game.map_grass.get_used_cells()
	if cells.is_empty():
		push_error("草地是空的")
		return

	# 找到靠中间的一块草地
	var mid := Vector2i(0, 0)
	for c in cells:
		mid += c
	mid = Vector2i(mid.x / cells.size(), mid.y / cells.size())

	# 逐格锄（模拟玩家点击顺序），走一个 L 形
	var order := [
		Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0),
		Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1),
		Vector2i(0, 2), Vector2i(1, 2),
		Vector2i(3, 1),
	]
	for d in order:
		Game._apply_terrain(Game.map_soil, mid + d, Game.TERRAIN_SOIL)

	# 浇一格看叠加
	Game._apply_terrain(Game.map_wet_soil, mid + Vector2i(1, 0), Game.TERRAIN_WET)
	Game._apply_terrain(Game.map_wet_soil, mid + Vector2i(1, 1), Game.TERRAIN_WET)

	print("已布置：中间点 ", mid, "，干土 4x3，其中左侧 2x3 为湿土")
