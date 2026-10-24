extends Node

## 地形索引：0=Grass（图集里没给瓦片）、1=Soil、2=WetSoil。
## WetSoil 是叠在 Soil 之上的 autotile：图集右半带透明部分，正好露出下面的干土，
## 所以浇水时不要删掉 Soil 的格子。
const TERRAIN_SOIL := 1
const TERRAIN_WET := 2

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

	time = 0
	timer_time.timeout.connect(_on_tick)


## set_cells_terrain_connect 只会重算"传入的这些格子"的边缘，邻居不会自动刷新，
## 所以单独锄一格时，它和旧土的接缝要等到换天整层重算才消失。
## 这里把"目标格 + 已经存在的八邻格"一起传进去，接缝当场就对齐。
func _apply_terrain(layer: TileMapLayer, coord: Vector2i, terrain: int) -> void:
	var cells: Array[Vector2i] = [coord]
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			if dx == 0 and dy == 0:
				continue
			var n := coord + Vector2i(dx, dy)
			if layer.get_cell_source_id(n) != -1:
				cells.append(n)
	layer.set_cells_terrain_connect(cells, 0, terrain)


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
	for cell in map_soil.get_used_cells():
		map_soil.set_cells_terrain_connect([cell], 0, TERRAIN_SOIL)

	day_changed.emit()


func _unhandled_input(event: InputEvent) -> void:
	# 只处理鼠标事件：键盘/手柄事件没有 position，直接读会报
	# "Invalid access to property or key 'position' on InputEventKey"
	if not (event is InputEventMouse):
		return

	var coord: Vector2i = map_grass.local_to_map(event.position)
	var has_grass := map_grass.get_cell_tile_data(coord) != null
	var has_soil := map_soil.get_cell_tile_data(coord) != null
	var has_wet := map_wet_soil.get_cell_tile_data(coord) != null

	if event is InputEventMouseMotion:
		position_hint.visible = has_grass
		position_hint.position = map_soil.map_to_local(coord) - position_hint.pivot_offset

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
					# 草地 → 干土（已经是土或湿土就不重复锄）
					if has_grass and not has_soil and not has_wet:
						_apply_terrain(map_soil, coord, TERRAIN_SOIL)
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
