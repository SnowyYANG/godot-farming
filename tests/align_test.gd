extends Node
## 渲染对位测试（需要窗口，不能 --headless）：
## 锄一格，截图找出这格土实际画在哪，跟 world_to_screen(map_to_local) 比。
## 之前 world_offset 只算给输入、没作用到 world_root，结果点击整体偏移近两格。

const CELL := Vector2i(10, 10)


func _ready() -> void:
	await get_tree().process_frame
	Game._apply_terrain(Game.map_soil, CELL, Game.TERRAIN_SOIL)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw

	var img := get_viewport().get_texture().get_image()
	var expect := Game.world_to_screen(Game.map_soil.map_to_local(CELL))
	var found := _find_soil_center(img, int(get_viewport().get_visible_rect().size.y) - Game.HUD_HEIGHT)

	if found == Vector2.ZERO:
		print("✗ 画面上找不到那格土")
		get_tree().quit(1)
		return

	var dx := absf(found.x - expect.x)
	var dy := absf(found.y - expect.y)
	var ok := dx <= 2.0 and dy <= 2.0
	print("期望 ", expect, " 实际 ", found, " 偏差 ", Vector2(dx, dy))
	print("点击对位: ", "✅ 通过" if ok else "✗ 偏了")
	get_tree().quit(0 if ok else 1)


func _find_soil_center(img: Image, max_y: int) -> Vector2:
	var xs_min := 99999
	var xs_max := -1
	var ys_min := 99999
	var ys_max := -1
	for y in range(max_y):
		for x in range(img.get_width()):
			var c := img.get_pixel(x, y)
			if c.r > 0.70 and c.r < 0.93 and c.g > 0.50 and c.g < 0.72 and c.b > 0.30 and c.b < 0.60 and c.r > c.g and c.g > c.b:
				xs_min = mini(xs_min, x)
				xs_max = maxi(xs_max, x)
				ys_min = mini(ys_min, y)
				ys_max = maxi(ys_max, y)
	if xs_max < 0:
		return Vector2.ZERO
	return Vector2((xs_min + xs_max) / 2.0, (ys_min + ys_max) / 2.0)
