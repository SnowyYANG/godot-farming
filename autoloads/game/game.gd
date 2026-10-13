extends Node

signal tool_changed

@export var map_ground: TileMapLayer
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

var crop_dict: Dictionary[Vector2i, Crop]

var max_time: int = 12
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
	
	var tool: ToolSelection = tool_selection_pool.get_child(0)
	selected_tool = tool
	
	var crop_model: Crop = Prefabs.crop.instantiate()
	
	for crop in crop_datas:
		var seed_selection: ToolSelection = Prefabs.tool_selection.instantiate()
		seed_selection.rect_icon.texture = crop.icon
		seed_selection.tool_type = Enums.ToolType.SEED
		seed_selection.seed_data = crop
		seed_selection_pool.add_child(seed_selection)
		
		var stock_label: StockLabel = Prefabs.stock_label.instantiate()
		var crop_anim_count = crop_model.sprite_frames.get_frame_count(crop.name) - 1
		stock_label.rect_icon.texture = crop_model.sprite_frames.get_frame_texture(crop.name, crop_anim_count)
		stock_label.name = crop.name
		stock_pool.add_child(stock_label)
	
	time = 0
	timer_time.timeout.connect(
		func ():
			time += 1
			if time > max_time:
				time = 0
				var index = 0
				for key in crop_dict.keys():
					var crop = crop_dict[key]
					var last_frame = crop.sprite_frames.get_frame_count(crop.animation) - 1
					if crop.watered:
						if crop.frame < last_frame:
							crop.frame += 1
					if crop.frame == last_frame:
						crop.harvest(index * 0.1)
					index += 1
				for cell in map_soil.get_used_cells():
					if not cell in crop_dict.keys():
						map_soil.set_cells_terrain_connect([cell], 0, -1)
				map_wet_soil.clear()
	)

func _unhandled_input(event: InputEvent) -> void:
	var coord = map_ground.local_to_map(event.position)
	var tile = map_ground.get_cell_tile_data(coord)
	var soil = map_soil.get_cell_tile_data(coord)
	
	if event is InputEventMouseMotion:
		position_hint.visible = tile != null
		position_hint.position = map_soil.map_to_local(coord) - position_hint.pivot_offset
	
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:

			match selected_tool.tool_type:
				Enums.ToolType.HOE:
					if tile:
						map_soil.set_cells_terrain_connect([coord], 0, 0)
				Enums.ToolType.WATER_CAN:
					if soil:
						map_wet_soil.set_cells_terrain_connect([coord], 0, 1)
				Enums.ToolType.SEED:
					if soil and not crop_dict.has(coord):
						var crop: Crop = Prefabs.crop.instantiate()
						crop.animation = selected_tool.seed_data.name
						crop.coord = coord
						crop_pool.add_child(crop)
						crop.position = map_soil.map_to_local(coord)
						crop_dict[coord] = crop
