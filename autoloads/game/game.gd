extends Node

## 地形索引：0=Grass（图集里没给瓦片）、1=Soil、2=WetSoil。
## WetSoil 是叠在 Soil 之上的 autotile：图集右半带透明部分，正好露出下面的干土，
## 所以浇水时不要删掉 Soil 的格子。
const TERRAIN_SOIL := 1
const TERRAIN_WET := 2

## 空地老化：土格连续这么多天没有作物，就长回草地
const EMPTY_SOIL_LIMIT := 2

## 底部 HUD 栏高度（像素）。世界画面只画在栏的上方，所以栏目不会压住任何作物。
const HUD_HEIGHT := 56

## 世界上方可视区（子视口）尺寸，由视口大小减掉栏目得出
var view_container: SubViewportContainer
var view: SubViewport
var world_root: Node2D
## 世界整体在子视口里的平移量（负数表示向左/上推）
var world_offset := Vector2.ZERO
var field_rect := Rect2()
var _panning := false
var day_label: Label

signal tool_changed
signal day_changed

@export var map_grass: TileMapLayer
@export var map_soil: TileMapLayer
@export var map_wet_soil: TileMapLayer
@export var tool_selection_pool: Control
@export var seed_selection_pool: Control
@export var crop_pool: Node2D
@export var crop_datas: Array[CropData]
@export var progress_time: ProgressBar
@export var timer_time: Timer
@export var stock_pool: Control
@export var position_hint: Control

var crop_dict: Dictionary[Vector2i, Crop] = {}
## 每个土格"连续没有作物"的天数
var empty_soil_days: Dictionary[Vector2i, int] = {}
var stock: Dictionary[String, int] = {}

var max_time: int = 12
var day: int = 1
var time: int:
	set(value):
		time = value
		progress_time.value = time

var selected_tool: ToolSelection:
	set(value):
		selected_tool = value
		tool_changed.emit()


func _ready() -> void:
	progress_time.max_value = max_time
	selected_tool = tool_selection_pool.get_child(0)

	for crop in crop_datas:
		var seed_selection: ToolSelection = Prefabs.tool_selection.instantiate()
		seed_selection.rect_icon.texture = crop.icon
		seed_selection.tool_type = Enums.ToolType.SEED
		seed_selection.seed_data = crop
		seed_selection_pool.add_child(seed_selection)

		var stock_label: StockLabel = Prefabs.stock_label.instantiate()
		stock_label.rect_icon.texture = crop.stages[crop.stages.size() - 1]
		stock_label.name = crop.name
		stock[crop.name] = 0
		stock_pool.add_child(stock_label)

	_build_view()
	_build_hud()

	# 调试：FARM_SHOT=/path.png 启动时自动截图并退出
	if OS.get_environment("FARM_SHOT") != "":
		_shot_and_quit()

	time = 0
	timer_time.timeout.connect(_on_tick)


## set_cells_terrain_connect 只会重算"传入的这些格子"的边缘，邻居不会自动刷新，
## 所以单独锄一格时，它和旧土的接缝要等到换天整层重算才消失。
## 这里把"目标格 + 已经存在的八邻格"一起传进去，接缝当场就对齐。
func _neighbor_cells(layer: TileMapLayer, coord: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			if dx == 0 and dy == 0:
				continue
			var n := coord + Vector2i(dx, dy)
			if layer.get_cell_source_id(n) != -1:
				cells.append(n)
	return cells


func _apply_terrain(layer: TileMapLayer, coord: Vector2i, terrain: int) -> void:
	var cells: Array[Vector2i] = [coord]
	cells.append_array(_neighbor_cells(layer, coord))
	layer.set_cells_terrain_connect(cells, 0, terrain)


## 把一格土连同湿土叠加一起除掉，并让周围重新算边缘（长回草地）
func erase_soil(coord: Vector2i) -> void:
	if map_wet_soil.get_cell_source_id(coord) != -1:
		map_wet_soil.erase_cell(coord)
		var wet_neighbors := _neighbor_cells(map_wet_soil, coord)
		if not wet_neighbors.is_empty():
			map_wet_soil.set_cells_terrain_connect(wet_neighbors, 0, TERRAIN_WET)
	if map_soil.get_cell_source_id(coord) != -1:
		map_soil.erase_cell(coord)
		var soil_neighbors := _neighbor_cells(map_soil, coord)
		if not soil_neighbors.is_empty():
			map_soil.set_cells_terrain_connect(soil_neighbors, 0, TERRAIN_SOIL)
	empty_soil_days.erase(coord)


## 最外圈草地不能锄：只在草地范围向内缩一格的可耕区内允许
func is_tillable(coord: Vector2i) -> bool:
	return map_grass.get_used_rect().grow(-1).has_point(coord)


## 世界画面放进一个子视口：只占屏幕上方，底部留给栏目。
## 这样栏目永远不会压住作物，草地比屏幕大时用中键拖动看别处。
func _build_view() -> void:
	var screen := get_viewport().get_visible_rect().size
	var view_size := Vector2(screen.x, screen.y - HUD_HEIGHT)

	view_container = SubViewportContainer.new()
	view_container.name = "WorldView"
	view_container.stretch = false
	view_container.position = Vector2.ZERO
	view_container.size = view_size
	view_container.custom_minimum_size = view_size
	view_container.mouse_filter = Control.MOUSE_FILTER_IGNORE

	view = SubViewport.new()
	view.size = Vector2i(int(view_size.x), int(view_size.y))
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	view_container.add_child(view)

	world_root = Node2D.new()
	world_root.name = "WorldRoot"
	view.add_child(world_root)

	for node in [map_grass, map_soil, map_wet_soil, crop_pool]:
		node.get_parent().remove_child(node)
		world_root.add_child(node)

	var cl := CanvasLayer.new()
	cl.name = "WorldLayer"
	cl.layer = -1
	add_child(cl)
	cl.add_child(view_container)

	var used := map_grass.get_used_rect()
	field_rect = Rect2(Vector2(used.position) * 16.0, Vector2(used.size) * 16.0)
	# 先把草地摆在中间，再夹进合法范围
	world_offset = view_size * 0.5 - field_rect.get_center()
	_clamp_offset()


func _clamp_offset() -> void:
	var v := Vector2(view.size)
	world_offset.x = clamp(world_offset.x, v.x - field_rect.end.x, -field_rect.position.x)
	world_offset.y = clamp(world_offset.y, v.y - field_rect.end.y, -field_rect.position.y)


## 屏幕坐标 → 世界坐标（子视口 + 平移量）
func screen_to_world(pos: Vector2) -> Vector2:
	return pos - view_container.global_position - world_offset


## 世界坐标 → 屏幕坐标（测试与提示框用）
func world_to_screen(pos: Vector2) -> Vector2:
	return pos + world_offset + view_container.global_position


## 底部栏目：工具 / 种子 / 收成 + 时间轴，和土地完全分开
func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.name = "HudLayer"
	layer.layer = 5
	add_child(layer)

	var panel := Panel.new()
	panel.name = "Hud"
	panel.anchor_left = 0.0
	panel.anchor_right = 1.0
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_top = -HUD_HEIGHT
	panel.mouse_filter = Control.MOUSE_FILTER_STOP   # 吃掉点击，土地收不到
	layer.add_child(panel)

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.145, 0.106, 0.086, 1.0)
	sb.border_width_top = 2
	sb.border_color = Color(0.44, 0.32, 0.22, 1.0)
	panel.add_theme_stylebox_override("panel", sb)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 6
	root.offset_right = -6
	root.offset_top = 4
	root.offset_bottom = -4
	root.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_theme_constant_override("separation", 5)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(root)

	# —— 第一行：三栏 ——
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 6)
	bar.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bar)

	_hud_section(bar, "工具", tool_selection_pool)
	_hud_separator(bar)
	_hud_section(bar, "种子", seed_selection_pool)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(spacer)

	_hud_separator(bar)
	_hud_section(bar, "收成", stock_pool)

	# —— 第二行：时间轴 ——
	var time_row := HBoxContainer.new()
	time_row.add_theme_constant_override("separation", 6)
	time_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(time_row)

	day_label = Label.new()
	day_label.text = "第 %d 天" % day
	day_label.add_theme_font_size_override("font_size", 8)
	day_label.add_theme_color_override("font_color", Color(0.85, 0.78, 0.66))
	day_label.custom_minimum_size = Vector2(34, 0)
	day_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	time_row.add_child(day_label)

	progress_time.get_parent().remove_child(progress_time)
	progress_time.custom_minimum_size = Vector2(0, 10)
	progress_time.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	progress_time.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	progress_time.show_percentage = false
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.30, 0.225, 0.16, 1.0)
	bg.border_width_left = 1
	bg.border_width_top = 1
	bg.border_width_right = 1
	bg.border_width_bottom = 1
	bg.border_color = Color(0.33, 0.24, 0.17, 1.0)
	progress_time.add_theme_stylebox_override("background", bg)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.80, 0.50, 0.19, 1.0)
	progress_time.add_theme_stylebox_override("fill", fill)
	time_row.add_child(progress_time)


func _hud_section(parent: Control, title: String, pool: Control) -> void:
	# 一栏 = 标题在上、图标行在下
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 1)
	box.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	box.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(box)

	var label := Label.new()
	label.text = title
	label.add_theme_font_size_override("font_size", 8)
	label.add_theme_color_override("font_color", Color(0.72, 0.62, 0.50))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(label)

	var items := HBoxContainer.new()
	items.add_theme_constant_override("separation", 2)
	items.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(items)

	pool.get_parent().remove_child(pool)
	pool.set_anchors_preset(Control.PRESET_TOP_LEFT)
	pool.position = Vector2.ZERO
	pool.custom_minimum_size = Vector2.ZERO
	pool.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	items.add_child(pool)
	if pool is BoxContainer:
		for child in pool.get_children():
			if child is Control:
				child.size_flags_vertical = Control.SIZE_SHRINK_CENTER
				child.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN


func _hud_separator(parent: Control) -> void:
	var line := ColorRect.new()
	line.color = Color(0.32, 0.23, 0.17, 1.0)
	line.custom_minimum_size = Vector2(1, 0)
	line.size_flags_vertical = Control.SIZE_FILL
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(line)


func _shot_and_quit() -> void:
	await get_tree().create_timer(2.0).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OS.get_environment("FARM_SHOT"))
	get_tree().quit()


func add_stock(crop_name: String, amount: int = 1) -> void:
	stock[crop_name] = stock.get(crop_name, 0) + amount
	var label: StockLabel = stock_pool.get_node_or_null(NodePath(crop_name))
	if label:
		label.number = stock[crop_name]


func _on_tick() -> void:
	time += 1
	if time > max_time:
		time = 0
		_end_day()


## 一天结束：推进所有作物，结算浇水/枯萎/收获，然后湿土变回干土
func _end_day() -> void:
	day += 1
	if day_label != null:
		day_label.text = "第 %d 天" % day
	var dead: Array[Vector2i] = []

	for coord in crop_dict.keys():
		var crop: Crop = crop_dict[coord]
		if not is_instance_valid(crop):
			dead.append(coord)
			continue

		crop.advance_day()

		if crop.gone:
			dead.append(coord)

	for coord in dead:
		crop_dict.erase(coord)

	# 换天：湿土叠加层整体清掉，干土保持（作物留在原地，只是不再算浇水）
	map_wet_soil.clear()

	# 空土老化：连续 EMPTY_SOIL_LIMIT 天没有作物 → 长回草地
	var to_clear: Array[Vector2i] = []
	for cell in map_soil.get_used_cells():
		if crop_dict.has(cell):
			empty_soil_days.erase(cell)
			continue
		var days: int = empty_soil_days.get(cell, 0) + 1
		if days >= EMPTY_SOIL_LIMIT:
			to_clear.append(cell)
		else:
			empty_soil_days[cell] = days
	for cell in to_clear:
		erase_soil(cell)

	for cell in map_soil.get_used_cells():
		map_soil.set_cells_terrain_connect([cell], 0, TERRAIN_SOIL)

	day_changed.emit()


func _unhandled_input(event: InputEvent) -> void:
	# 只处理鼠标事件：键盘/手柄事件没有 position，直接读会报
	# "Invalid access to property or key 'position' on InputEventKey"
	if not (event is InputEventMouse):
		return

	# 底部栏目与土地隔绝：栏内的点击不参与耕作/浇水/播种
	if event.position.y > get_viewport().get_visible_rect().size.y - HUD_HEIGHT:
		return

	# 中键拖动平移世界（草地比可视区大）
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_MIDDLE:
		_panning = event.pressed
		return
	if event is InputEventMouseMotion and _panning:
		world_offset += event.relative
		_clamp_offset()
		return

	var world_pos := screen_to_world(event.position)
	var coord: Vector2i = map_grass.local_to_map(world_pos)
	var has_grass := map_grass.get_cell_tile_data(coord) != null
	var has_soil := map_soil.get_cell_tile_data(coord) != null
	var has_wet := map_wet_soil.get_cell_tile_data(coord) != null

	if event is InputEventMouseMotion:
		position_hint.visible = has_grass
		position_hint.position = map_soil.map_to_local(coord) + world_offset - position_hint.pivot_offset

	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:

			# 成熟作物：点一下收获（连种作物回到指定阶段，金花额外 +1）
			if crop_dict.has(coord):
				var planted: Crop = crop_dict[coord]
				if planted.is_mature():
					planted.harvest()
					return

			match selected_tool.tool_type:
				Enums.ToolType.HOE:
					# 草地 → 干土（已经是土或湿土就不重复锄；最外圈草地不许锄）
					if has_grass and not has_soil and not has_wet and is_tillable(coord):
						_apply_terrain(map_soil, coord, TERRAIN_SOIL)
						empty_soil_days[coord] = 0
				Enums.ToolType.WATER_CAN:
					# 干土 → 湿土：Soil 保留，WetSoil 作为 autotile 叠加在上面
					if has_soil and not has_wet:
						_apply_terrain(map_wet_soil, coord, TERRAIN_WET)
				Enums.ToolType.SEED:
					# 干土或湿土都能种
					if (has_soil or has_wet) and not crop_dict.has(coord):
						var crop: Crop = Prefabs.crop.instantiate()
						crop_pool.add_child(crop)
						crop.setup(selected_tool.seed_data, coord)
						crop.position = map_soil.map_to_local(coord)
						crop_dict[coord] = crop
						empty_soil_days.erase(coord)
