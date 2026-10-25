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

	var coord := Vector2i(-999, -999)
	for c in Game.map_grass.get_used_cells():
		if Game.is_tillable(c):
			coord = c
			break
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
			and Game.is_tillable(c) and Game.is_tillable(right) \
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


	# 7. 空土老化：连续 2 天没种植 → 长回草地
	print("\n[空土 2 天老化]")
	var empty_cell := Vector2i(-999, -999)
	for c in Game.map_grass.get_used_cells():
		if Game.map_soil.get_cell_source_id(c) == -1 and Game.is_tillable(c):
			empty_cell = c
			break
	_select_tool(Enums.ToolType.HOE)
	_click(Game.map_grass.map_to_local(empty_cell))
	_check("锄地后有土", Game.map_soil.get_cell_source_id(empty_cell) != -1)
	Game._end_day()
	_check("第 1 天结束时土还在", Game.map_soil.get_cell_source_id(empty_cell) != -1)
	Game._end_day()
	_check("第 2 天结束时土还在（连 2 天没操作还没到时限）", Game.map_soil.get_cell_source_id(empty_cell) != -1)
	Game._end_day()
	_check("第 3 天结束时土才消失（长回草地）", Game.map_soil.get_cell_source_id(empty_cell) == -1)
	_check("该格草地还在", Game.map_grass.get_cell_source_id(empty_cell) != -1)
	_check("计数已清理", not Game.empty_soil_days.has(empty_cell))

	# 8. 种了东西的土不会老化
	print("\n[种了作物不会老化]")
	var planted_cell := Vector2i(-999, -999)
	for c in Game.map_grass.get_used_cells():
		if Game.map_soil.get_cell_source_id(c) == -1 and c != empty_cell and Game.is_tillable(c):
			planted_cell = c
			break
	_click(Game.map_grass.map_to_local(planted_cell))
	_select_tool(Enums.ToolType.SEED)
	_click(Game.map_grass.map_to_local(planted_cell))
	_check("已种下作物", Game.crop_dict.has(planted_cell))
	for i in range(2):
		_apply_water(planted_cell)
		Game._end_day()
	_check("两天后土仍在", Game.map_soil.get_cell_source_id(planted_cell) != -1)


	# 9. 最外圈草地不能锄
	print("\n[最外圈不可锄]")
	var rect := Game.map_grass.get_used_rect()
	var edge := rect.position
	var inner := rect.position + Vector2i(1, 1)
	_check("最外圈不可锄", not Game.is_tillable(edge), str(edge))
	_check("向内一格可锄", Game.is_tillable(inner), str(inner))
	_click(Game.map_grass.map_to_local(edge))
	_check("对最外圈点击不出土", Game.map_soil.get_cell_source_id(edge) == -1)


	# 10. 栏目区域点不出土
	print("\n[栏目区域隔绝]")
	var hud_y := get_viewport().get_visible_rect().size.y - Game.HUD_HEIGHT + 8.0
	var probe := Vector2(8.0, hud_y)
	var before := Game.map_soil.get_used_cells().size()
	_click(probe)
	_check("栏内点击不产生土", Game.map_soil.get_used_cells().size() == before)


	# 11. 换天不应该改动已有土壤的瓦片（autotile 别被重刷换样）
	print("\n[换天不改瓦片]")
	var bx := 8
	var by := 8
	for x in range(bx, bx + 4):
		for y in range(by, by + 4):
			Game._apply_terrain(Game.map_soil, Vector2i(x, y), Game.TERRAIN_SOIL)
	await get_tree().process_frame
	var atlas_before := {}
	for cell in Game.map_soil.get_used_cells():
		atlas_before[cell] = Game.map_soil.get_cell_atlas_coords(cell)
	Game._end_day()
	await get_tree().process_frame
	var changed := 0
	for cell in Game.map_soil.get_used_cells():
		if atlas_before.has(cell) and atlas_before[cell] != Game.map_soil.get_cell_atlas_coords(cell):
			changed += 1
	_check("换天后瓦片不变", changed == 0, "变了 %d 格" % changed)

	print("\n=== 结果: %d 通过, %d 失败 ===" % [pass_count, fail_count])
	get_tree().quit(0 if fail_count == 0 else 1)


func _select_tool(type: int) -> void:
	for pool in [Game.tool_selection_pool, Game.seed_selection_pool]:
		for child in pool.get_children():
			if child.tool_type == type:
				Game.selected_tool = child
				return
	push_error("找不到工具 type=%d" % type)


func _apply_water(coord: Vector2i) -> void:
	Game._apply_terrain(Game.map_wet_soil, coord, Game.TERRAIN_WET)


func _click(world_pos: Vector2) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = Game.world_to_screen(world_pos)
	Game._unhandled_input(ev)


func _check(label: String, condition: bool, detail: String = "") -> void:
	if condition:
		pass_count += 1
		print("  ✓ ", label, ("  " + detail) if detail else "")
	else:
		fail_count += 1
		print("  ✗ ", label, "  ", detail)
