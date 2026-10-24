extends SceneTree

func _init() -> void:
	var ts: TileSet = load("res://tilesets/main_tileset.tres")
	print("=== TileSet ===")
	print("  tile_size: ", ts.tile_size)
	print("  sources: ", ts.get_source_count())
	for si in ts.get_source_count():
		var sid := ts.get_source_id(si)
		var src := ts.get_source(sid)
		print("  source id=", sid, " type=", src.get_class())
		if src is TileSetAtlasSource:
			var atlas := src as TileSetAtlasSource
			print("    texture: ", atlas.texture.resource_path, " ", atlas.texture.get_size())
			print("    region: ", atlas.texture_region_size)
			print("    tiles: ", atlas.get_tiles_count())
	print("  terrain sets: ", ts.get_terrain_sets_count())
	for tset in ts.get_terrain_sets_count():
		print("  terrain_set ", tset, " mode=", ts.get_terrain_set_mode(tset), " terrains=", ts.get_terrains_count(tset))
		for t in ts.get_terrains_count(tset):
			print("    terrain ", t, ": ", ts.get_terrain_name(tset, t), "  color=", ts.get_terrain_color(tset, t))

	# 每个地形有哪些瓦片（按 peering bits 归类）
	for si in ts.get_source_count():
		var sid := ts.get_source_id(si)
		var atlas := ts.get_source(sid) as TileSetAtlasSource
		if atlas == null:
			continue
		print("=== source ", sid, " 各 terrain 的瓦片 ===")
		var by_terrain := {}
		for i in atlas.get_tiles_count():
			var coords := atlas.get_tile_id(i)
			var td := atlas.get_tile_data(coords, 0)
			var key := "%d/%d" % [td.terrain_set, td.terrain]
			if not by_terrain.has(key):
				by_terrain[key] = []
			by_terrain[key].append(str(coords))
		for k in by_terrain:
			print("  terrain ", k, " → ", by_terrain[k])

	var scene: PackedScene = load("res://autoloads/game/game.tscn")
	var inst := scene.instantiate()
	var grass := inst.get_node_or_null("Grass") as TileMapLayer
	if grass:
		var seen := {}
		for c in grass.get_used_cells():
			seen[grass.get_cell_atlas_coords(c)] = true
		print("=== Grass 层使用的瓦片坐标 ===", seen.keys())
		print("  格子数: ", grass.get_used_cells().size())
		print("  范围: ", grass.get_used_rect())
	inst.free()
	quit()
