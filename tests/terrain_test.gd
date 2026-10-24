extends Node

## 三态地形测试：grass → (锄头) soil → (水壶) wetsoil → (换天) soil
## 运行: godot --headless --path . tests/terrain_test.tscn

var pass_count := 0
var fail_count := 0


func _ready() -> void:
	await get_tree().process_frame
	await get_tree().process_frame

	_check("Grass 层有格子", Game.map_grass.get_used_cells().size() > 0,
		"格子数 %d" % Game.map_grass.get_used_cells().size())

	var coord: Vector2i = Game.map_grass.get_used_cells()[0]
	var pos: Vector2 = Game.map_grass.map_to_local(coord)
	print("\n测试格子: ", coord, "  世界坐标: ", pos)

	# 1. 锄头：草地 → 干土
	_select_tool(Enums.ToolType.HOE)
	_click(pos)
	_check("锄地后出现 Soil", Game.map_soil.get_cell_tile_data(coord) != null)
	_check("锄地后没有 WetSoil", Game.map_wet_soil.get_cell_tile_data(coord) == null)
	_check("草地仍在（土是叠加层）", Game.map_grass.get_cell_tile_data(coord) != null)

	# 2. 再锄一次：不应该有任何变化（防止叠瓦片层级错乱）
	_click(pos)
	_check("重复锄地仍只有 Soil", Game.map_soil.get_cell_tile_data(coord) != null)

	# 3. 水壶：干土 → 湿土
	_select_tool(Enums.ToolType.WATER_CAN)
	_click(pos)
	_check("浇水后出现 WetSoil", Game.map_wet_soil.get_cell_tile_data(coord) != null)
	_check("湿土是叠加，干土仍在", Game.map_soil.get_cell_tile_data(coord) != null)

	# 4. 湿土上能种
	_select_tool(Enums.ToolType.SEED)
	var before_crop: bool = Game.crop_dict.has(coord)
	_click(pos)
	_check("湿土可播种", Game.crop_dict.has(coord) and not before_crop)

	# 5. 换天：湿土 → 干土，作物保留
	Game._end_day()
	_check("换天后湿土消失", Game.map_wet_soil.get_cell_tile_data(coord) == null)
	_check("换天后变回干土", Game.map_soil.get_cell_tile_data(coord) != null)
	_check("换天后作物还在", Game.crop_dict.has(coord))


	# 6. 边缘即时刷新：相邻两格先后锄地，第一格的瓦片应当立刻变化
	print("\n[边缘即时刷新]")
	var a := Vector2i(-999, -999)
	for c in Game.map_grass.get_used_cells():
		var right := c + Vector2i(1, 0)
		if Game.map_grass.get_cell_source_id(right) != -1 \
			and Game.map_soil.get_cell_source_id(c) == -1 \
			and Game.map_soil.get_cell_source_id(right) == -1:
			a = c
			break
	if a == Vector2i(-999, -999):
		_check("找到相邻两格草地", false)
	else:
		_select_tool(Enums.ToolType.HOE)
		_click(Game.map_grass.map_to_local(a))
		var before_coords := Game.map_soil.get_cell_atlas_coords(a)
		_click(Game.map_grass.map_to_local(a + Vector2i(1, 0)))
		var after_coords := Game.map_soil.get_cell_atlas_coords(a)
		_check("锄相邻格后，原格瓦片立即更新", before_coords != after_coords,
			"%s → %s" % [before_coords, after_coords])

	print("\n=== 结果: %d 通过, %d 失败 ===" % [pass_count, fail_count])
	get_tree().quit(0 if fail_count == 0 else 1)


func _select_tool(type: int) -> void:
	for pool in [Game.tool_selection_pool, Game.seed_selection_pool]:
		for child in pool.get_children():
			if child.tool_type == type:
				Game.selected_tool = child
				return
	push_error("找不到工具 type=%d" % type)


func _click(world_pos: Vector2) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = world_pos
	Game._unhandled_input(ev)


func _check(label: String, condition: bool, detail: String = "") -> void:
	if condition:
		pass_count += 1
		print("  ✓ ", label, ("  " + detail) if detail else "")
	else:
		fail_count += 1
		print("  ✗ ", label, "  ", detail)
