class_name ToolSelection
extends PanelContainer

@export var tool_type: Enums.ToolType
@export var rect_icon: TextureRect
@export var select_frame: Control
@export var hover_frame: Control
var seed_data: CropData

func _ready() -> void:
	Game.tool_changed.connect(
		func():
			select_frame.visible = Game.selected_tool == self
	)
	mouse_entered.connect(
		func ():
			hover_frame.visible = true
	)
	mouse_exited.connect(
		func ():
			hover_frame.visible = false
	)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			Game.selected_tool = self
