class_name CropData
extends Resource

var name: String:
	get:
		return resource_path.get_file().split(".")[0]
@export var icon: AtlasTexture
