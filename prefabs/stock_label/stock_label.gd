class_name StockLabel
extends HBoxContainer

@export var rect_icon: TextureRect
@export var label_number: Label

var number: int:
	set(value):
		number = value
		label_number.text = str(number)
