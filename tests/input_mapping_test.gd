extends Node

## 回归：窗口坐标 → 游戏格子的换算在拉伸（canvas_items + 整数倍 + 黑边）下是否准确
## 运行: godot --path . tests/input_mapping_test.tscn   （真窗口，不要 --headless）

var expected: Vector2i


func _ready() -> void:
	await get_tree().process_frame
	await get_tree().process_frame

	# 选一个草地、可锄、还没土的格子
	var cell := Vector2i(-999, -999)
	for c in Game.map_grass.get_used_cells():
		if not Game.is_tillable(c) or Game.map_soil.get_cell_source_id(c) != -1:
			continue
		var cp: Vector2 = Game.world_to_screen(Game.map_soil.map_to_local(c))
		# 必须落在可见世界区域内（320x184），否则注入的点击在窗口外
		if cp.x > 16.0 and cp.x < 304.0 and cp.y > 16.0 and cp.y < 168.0:
			cell = c
			break
	if cell == Vector2i(-999, -999):
		print("找不到可锄格")
		get_tree().quit(1)
		return
	expected = cell
	switch_tool(Enums.ToolType.HOE)

	var center: Vector2 = Game.map_soil.map_to_local(cell)   # 格子中心（世界坐标）
	var canvas_pos: Vector2 = Game.world_to_screen(center)  # 画布坐标（320x240 空间）
	var xf := get_viewport().get_screen_transform()
	var window_pos: Vector2 = xf * canvas_pos               # 窗口像素坐标

	print("window.size   = ", get_window().size)
	print("screen_xform  = ", xf)
	print("cell          = ", cell)
	print("canvas_pos    = ", canvas_pos)
	print("window_pos    = ", window_pos)

	# 走真实输入管线：注入窗口坐标的点击
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = window_pos
	ev.global_position = window_pos
	Input.parse_input_event(ev)
	await get_tree().process_frame
	await get_tree().process_frame

	var tilled: Array = []
	for c in Game.map_soil.get_used_cells():
		tilled.append(c)
	print("tilled cells  = ", tilled)
	print("期望 ", expected, " -> ", ("✓ 命中" if tilled.has(expected) else "✗ 偏了"))
	get_tree().quit(0 if tilled.has(expected) else 1)


func switch_tool(type: int) -> void:
	for pool in [Game.tool_selection_pool, Game.seed_selection_pool]:
		for child in pool.get_children():
			if child.tool_type == type:
				Game.selected_tool = child
				return
	push_error("找不到工具 type=%d" % type)
