extends Node

## 复现 + 回归：一块土中间/边缘的一格消失后，周围八邻必须当场按 peering 改口
## 运行: godot --headless --path . tests/erase_retile_test.tscn

var pass_count := 0
var fail_count := 0


func _ready() -> void:
	await get_tree().process_frame
	await get_tree().process_frame

	# —— 场景 1：3x3 中间一格消失 ——
	var center := _find_block(3)
	if center == Vector2i(-999, -999):
		print("找不到 3x3 连续可锄空地")
		get_tree().quit(1)
		return
	print("场景1 3x3 中心: ", center)
	_fill_block(center, 3)
	_audit("铺好之后")
	Game.erase_soil(center)
	await get_tree().process_frame
	_check("中间格已空", Game.map_soil.get_cell_source_id(center) == -1)
	_audit("擦掉中间后")

	# —— 场景 2：5x5 里擦掉边角（两邻一侧角） ——
	var big := _find_block(5)
	if big != Vector2i(-999, -999):
		print("\n场景2 5x5 中心: ", big)
		_fill_block(big, 5)
		_audit("铺好之后")
		var corner: Vector2i = big + Vector2i(2, 2)
		Game.erase_soil(corner)
		await get_tree().process_frame
		_check("边角格已空", Game.map_soil.get_cell_source_id(corner) == -1)
		_audit("擦掉边角后")

		# —— 场景 3：擦掉后再锄回去，边缘要重新接上 ——
		print("\n场景3 洞重新锄回去")
		Game._apply_terrain(Game.map_soil, corner, Game.TERRAIN_SOIL)
		await get_tree().process_frame
		_audit("重新锄回后")

		# —— 场景 4：湿土叠加层同样要跟着重铺 ——
		print("\n场景4 湿土叠加层")
		for dx in range(-1, 2):
			for dy in range(-1, 2):
				Game._apply_terrain(Game.map_wet_soil, big + Vector2i(1 + dx, 1 + dy), Game.TERRAIN_WET)
		await get_tree().process_frame
		var wet_center: Vector2i = big + Vector2i(1, 1)
		Game.erase_soil(wet_center)
		await get_tree().process_frame
		var wet_bad := _audit_layer(Game.map_wet_soil, Game.TERRAIN_WET, [wet_center])
		_check("湿土层擦除后 peering 与邻居一致", wet_bad.is_empty(), str(wet_bad.slice(0, 4)))

		# —— 场景 5：一次掏空 2x2 的洞（多格连着消失） ——
		print("\n场景5 2x2 洞")
		Game.erase_soil(big + Vector2i(1, 1))
		Game.erase_soil(big + Vector2i(2, 1))
		Game.erase_soil(big + Vector2i(1, 2))
		Game.erase_soil(big + Vector2i(2, 2))
		await get_tree().process_frame
		_audit("掏空 2x2 后")
	else:
		print("\n找不到 5x5 连续可锄空地，跳过场景 2/3/4/5")

	print("\n=== 结果: %d 通过, %d 失败 ===" % [pass_count, fail_count])
	get_tree().quit(0 if fail_count == 0 else 1)


## 全层审计：每一格瓦片里写的 peering，必须和"八邻到底在不在"算出来的掩码一致
func _audit(label: String) -> void:
	var bad := _audit_layer(Game.map_soil, Game.TERRAIN_SOIL, [])
	var cells := Game.map_soil.get_used_cells().size()
	_check("%s：%d 格瓦片与邻居一致" % [label, cells], bad.is_empty(), str(bad.slice(0, 6)))


func _audit_layer(layer: TileMapLayer, terrain: int, skip: Array) -> Array:
	var bits: Array = Game._TERRAIN_BITS
	var dirs: Array = Game._TERRAIN_DIRS
	var bad := []
	for c in layer.get_used_cells():
		if skip.has(c):
			continue
		var td := layer.get_cell_tile_data(c)
		if td == null or td.terrain != terrain:
			continue
		var want := 0
		for k in dirs.size():
			var ntd := layer.get_cell_tile_data(c + dirs[k])
			if ntd != null and ntd.terrain == terrain:
				want |= 1 << k
		want = Game._canonical_mask(want)
		var have := 0
		for k in bits.size():
			var bit: int = bits[k]
			if td.is_valid_terrain_peering_bit(bit) and td.get_terrain_peering_bit(bit) == terrain:
				have |= 1 << k
		if want != have:
			bad.append([str(c), "期望%08s" % _bin(want), "实际%08s" % _bin(have),
				str(layer.get_cell_atlas_coords(c))])
	return bad


func _bin(mask: int) -> String:
	var s := ""
	for k in range(7, -1, -1):
		s += "1" if mask & (1 << k) else "0"
	return s


func _fill_block(origin: Vector2i, size: int) -> void:
	var half := int(size / 2)
	for dx in range(-half, half + 1):
		for dy in range(-half, half + 1):
			Game._apply_terrain(Game.map_soil, origin + Vector2i(dx, dy), Game.TERRAIN_SOIL)


## 找一块 size x size 全是草地、可锄、还没有土的空地，返回中心格
func _find_block(size: int) -> Vector2i:
	var half := int(size / 2)
	for c in Game.map_grass.get_used_cells():
		var ok := true
		for dx in range(-half, half + 1):
			for dy in range(-half, half + 1):
				var n := c + Vector2i(dx, dy)
				if not Game.is_tillable(n) or Game.map_grass.get_cell_source_id(n) == -1 \
					or Game.map_soil.get_cell_source_id(n) != -1:
					ok = false
					break
			if not ok:
				break
		if ok:
			return c
	return Vector2i(-999, -999)


func _check(label: String, condition: bool, detail: String = "") -> void:
	if condition:
		pass_count += 1
		print("  ✓ ", label, ("  " + detail) if detail else "")
	else:
		fail_count += 1
		print("  ✗ ", label, "  ", detail)
