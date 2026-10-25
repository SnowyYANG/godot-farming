extends Node

## 无头测试：验证 5 种作物的生长 / 连种 / 枯萎 / 消失 / 金花规则
## 运行: godot --headless --path . tests/day_test.tscn

const WET_TERRAIN := 2
const SOIL_TERRAIN := 1

var pass_count := 0
var fail_count := 0


func _ready() -> void:
	await get_tree().process_frame
	await get_tree().process_frame

	var crops := {}
	for data in Game.crop_datas:
		crops[data.name] = data
	print("载入作物: ", crops.keys())

	_test_cabbage_growth(crops["cabbage"])
	_test_seed_dries_out(crops["cabbage"])
	_test_seedling_withers(crops["cabbage"])
	_test_mushroom_repeat(crops["mushroom"])
	_test_mint_repeat(crops["mint"])
	_test_golden(crops["mint"])

	_test_day_length()
	_test_ripe_withers()
	_test_bgm()
	_test_watered_soil_not_aging()
	_test_input_events()
	await _test_clear_withered()
	await _test_absorb_ghost()

	print("\n=== 结果: %d 通过, %d 失败 ===" % [pass_count, fail_count])
	get_tree().quit(0 if fail_count == 0 else 1)


func _check(label: String, condition: bool, detail: String = "") -> void:
	if condition:
		pass_count += 1
		print("  ✓ ", label, ("  " + detail) if detail else "")
	else:
		fail_count += 1
		print("  ✗ ", label, "  ", detail)


func _make_soil(coord: Vector2i) -> void:
	Game.map_soil.set_cells_terrain_connect([coord], 0, SOIL_TERRAIN)


func _plant(data: CropData, coord: Vector2i) -> Crop:
	_make_soil(coord)
	var crop: Crop = Prefabs.crop.instantiate()
	Game.crop_pool.add_child(crop)
	crop.setup(data, coord)
	crop.position = Game.map_soil.map_to_local(coord)
	Game.crop_dict[coord] = crop
	return crop


func _water(coord: Vector2i, wet: bool = true) -> void:
	if wet:
		Game.map_wet_soil.set_cells_terrain_connect([coord], 0, WET_TERRAIN)


func _new_game_stock() -> void:
	Game.stock.clear()
	for key in Game.stock:
		pass


# ── A. 正常生长：每天浇水，最后成熟并收获 ─────────────────────────
func _test_cabbage_growth(data: CropData) -> void:
	print("\n[A] 卷心菜 正常生长")
	var coord := Vector2i(0, 0)
	var crop := _plant(data, coord)
	_check("初始在阶段 0", crop.frame == 0, "frame=%d" % crop.frame)

	var before: int = Game.stock.get("cabbage", 0)
	for i in range(4):
		_water(coord)
		Game._end_day()

	_check("4 天后成熟待收", crop.is_mature(), "frame=%d" % crop.frame)
	crop.harvest()
	_check("点击收获 +1", Game.stock.get("cabbage", 0) == before + 1,
		"库存 %d → %d" % [before, Game.stock.get("cabbage", 0)])
	_check("收获后作物从地块移除", not Game.crop_dict.has(coord))


# ── B. 种子 2 天不浇水 → 消失 ─────────────────────────────────────
func _test_seed_dries_out(data: CropData) -> void:
	print("\n[B] 种子 2 天不浇水 → 消失")
	var coord := Vector2i(1, 0)
	var crop := _plant(data, coord)
	Game._end_day()
	_check("1 天没浇水还在", is_instance_valid(crop) and not crop.gone, "dry_days=%d" % crop.dry_days)
	Game._end_day()
	_check("2 天没浇水还在（还没到时限）", is_instance_valid(crop) and not crop.gone, "dry_days=%d" % crop.dry_days)
	Game._end_day()
	_check("3 天没浇水后才消失", crop.gone == true, "dry_days=%d" % crop.dry_days)


# ── C. 苗 2 天不浇水 → 枯萎 ───────────────────────────────────────
func _test_seedling_withers(data: CropData) -> void:
	print("\n[C] 苗 2 天不浇水 → 枯萎")
	var coord := Vector2i(2, 0)
	var crop := _plant(data, coord)
	_water(coord); Game._end_day()          # 先长到阶段 1
	_check("长到阶段 1", crop.frame == 1, "frame=%d" % crop.frame)
	Game._end_day()                          # 干第 1 天
	_check("干 1 天未枯萎", not crop.is_withered)
	Game._end_day()                          # 干第 2 天
	_check("干 2 天仍未枯萎", not crop.is_withered, "dry_days=%d" % crop.dry_days)
	Game._end_day()                          # 干第 3 天
	_check("干 3 天才枯萎", crop.is_withered == true, "dry_days=%d" % crop.dry_days)


# ── D. 蘑菇连种：收获后回到第二个堆堆 ─────────────────────────────
func _test_mushroom_repeat(data: CropData) -> void:
	print("\n[D] 蘑菇连种")
	var coord := Vector2i(3, 0)
	var crop := _plant(data, coord)
	var before: int = Game.stock.get("mushroom", 0)
	for i in range(4):
		_water(coord)
		Game._end_day()
	crop.harvest()
	_check("收获次数 +1", Game.stock.get("mushroom", 0) == before + 1,
		"库存 %d" % Game.stock.get("mushroom", 0))
	_check("仍在地块上（连种）", Game.crop_dict.has(coord) and not crop.gone)
	_check("回到 reset_stage=%d" % data.reset_stage, crop.frame == data.reset_stage,
		"frame=%d" % crop.frame)

	var before2: int = Game.stock.get("mushroom", 0)
	for i in range(4):
		_water(coord)
		Game._end_day()
	crop.harvest()
	_check("再收一次", Game.stock.get("mushroom", 0) == before2 + 1,
		"库存 %d" % Game.stock.get("mushroom", 0))


# ── E. 薄荷连种：收获后回到小花骨朵 ───────────────────────────────
func _test_mint_repeat(data: CropData) -> void:
	print("\n[E] 薄荷连种")
	var coord := Vector2i(4, 0)
	var crop := _plant(data, coord)
	for i in range(6):
		_water(coord)
		Game._end_day()
	crop.harvest()
	_check("仍在地块上", Game.crop_dict.has(coord) and not crop.gone)
	_check("回到小花骨朵阶段 %d" % data.reset_stage, crop.frame == data.reset_stage,
		"frame=%d" % crop.frame)
	_check("薄荷有 3%% 金花概率", is_equal_approx(data.golden_chance, 0.03),
		"golden_chance=%.2f" % data.golden_chance)
	_check("金花贴图已配置", data.golden.size() == 2, "%d 张" % data.golden.size())


# ── F. 金花：把概率临时设成 100% 验证流程 ─────────────────────────
func _test_golden(data: CropData) -> void:
	print("\n[F] 金花流程（概率临时 100%）")
	var coord := Vector2i(5, 0)
	var saved: float = data.golden_chance
	data.golden_chance = 1.0
	var crop := _plant(data, coord)
	var before: int = Game.stock.get("mint", 0)
	for i in range(6):
		_water(coord)
		Game._end_day()
	_check("成熟时变金花", crop.is_golden == true)
	crop.harvest()
	_check("金花收获 +2", Game.stock.get("mint", 0) == before + 2,
		"库存 %d → %d" % [before, Game.stock.get("mint", 0)])
	data.golden_chance = saved


# ── J. 一天的长度 = max_time 拍，正好 30 拍换一次天 ───────────────
func _test_day_length() -> void:
	print("
[J] 一天时长")
	_check("max_time 默认 30 拍", Game.max_time == 30, "max_time=%d" % Game.max_time)
	_check("Timer_Time 一拍 1 秒", is_equal_approx(Game.timer_time.wait_time, 1.0),
		"wait_time=%.2f" % Game.timer_time.wait_time)
	var d0 := Game.day
	Game.time = 0
	for i in range(Game.max_time - 1):
		Game._on_tick()
	_check("第 %d 拍之前还没换天" % (Game.max_time - 1), Game.day == d0,
		"day %d → %d" % [d0, Game.day])
	Game._on_tick()
	_check("第 %d 拍准时换天（一天 = 30 秒）" % Game.max_time, Game.day == d0 + 1,
		"day %d → %d" % [d0, Game.day])


# ── K. 枯萎作物：点一下渐隐消失，不产出 ─────────────────────────
func _test_clear_withered() -> void:
	print("
[K] 枯萎作物点一下渐隐消失")
	var coord := Vector2i(9, 0)
	var crop := _plant(Game.crop_datas[0], coord)
	_water(coord)
	Game._end_day()
	for i in range(3):
		Game._end_day()
	_check("已枯萎", crop.is_withered and not crop.gone,
		"withered=%s gone=%s" % [crop.is_withered, crop.gone])
	if not crop.is_withered:
		return

	var stock_before: int = Game.stock.get("cabbage", 0)
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = Game.world_to_screen(Game.map_soil.map_to_local(coord))
	Game._unhandled_input(ev)

	_check("点击后立刻从 crop_dict 移除", not Game.crop_dict.has(coord))
	_check("枯萎作物没有产出", Game.stock.get("cabbage", 0) == stock_before,
		"库存 %d" % Game.stock.get("cabbage", 0))
	_check("不是瞬间消失（渐变开始，仍存在）", is_instance_valid(crop))
	await get_tree().create_timer(0.28).timeout
	var mid_ok := is_instance_valid(crop) and crop.modulate.a < 1.0 and crop.modulate.a > 0.0
	_check("渐变中：半透明", mid_ok, "alpha=%.2f" % (crop.modulate.a if is_instance_valid(crop) else -1.0))
	await get_tree().create_timer(0.6).timeout
	_check("渐变结束后被销毁", not is_instance_valid(crop))


# ── I. 空土当天浇过水 = 操作过，不该算进老化天数 ─────────────────
func _test_watered_soil_not_aging() -> void:
	print("
[I] 空土浇过水就不老化")
	var coord := Vector2i(8, 0)
	Game._apply_terrain(Game.map_soil, coord, Game.TERRAIN_SOIL)
	Game.empty_soil_days[coord] = 0
	for i in range(4):
		_water(coord)
		Game._end_day()
	_check("连浇 4 天水的空土还在", Game.map_soil.get_cell_source_id(coord) != -1,
		"days=%d" % Game.empty_soil_days.get(coord, -1))
	Game._end_day()
	Game._end_day()
	_check("停手 2 天还在", Game.map_soil.get_cell_source_id(coord) != -1)
	Game._end_day()
	_check("停手第 3 天结算才长回草地", Game.map_soil.get_cell_source_id(coord) == -1)


# ── G. 输入事件：键盘事件不能崩，鼠标事件正常 ────────────────────
func _test_input_events() -> void:
	print("\n[G] 输入事件健壮性")
	# 键盘按下事件（没有 position）——曾经会报 Invalid access to property 'position'
	var key := InputEventKey.new()
	key.keycode = KEY_A
	key.pressed = true
	Game._unhandled_input(key)
	pass_count += 1
	print("  ✓ 键盘事件不报错")

	# 鼠标移动事件
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(200, 200)
	Game._unhandled_input(motion)
	pass_count += 1
	print("  ✓ 鼠标移动事件正常")

	# 鼠标点击事件
	var click := InputEventMouseButton.new()
	click.position = Vector2(200, 200)
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	Game._unhandled_input(click)
	pass_count += 1
	print("  ✓ 鼠标点击事件正常")


# ── H. 连种作物的吸收动画：收获时生成残影，飞完消失 ──────────────
func _test_absorb_ghost() -> void:
	print("\n[H] 连种收获的吸收动画")
	await get_tree().create_timer(0.8).timeout   # 先等前面测试的残影飞完
	var coord := Vector2i(6, 0)
	var crop := _plant(Game.crop_datas[1], coord)   # mushroom，连种
	crop.frame = crop.last_stage()

	var before := _ghost_count()

	crop.harvest()

	var after := _ghost_count()
	_check("收获时生成吸收残影", after == before + 1, "残影 %d → %d" % [before, after])
	_check("本体立刻回到重置阶段", crop.frame == Game.crop_datas[1].reset_stage,
		"frame=%d" % crop.frame)

	await get_tree().create_timer(0.7).timeout
	var later := _ghost_count()
	_check("残影飞完后自动销毁", later == 0, "剩余 %d" % later)


## 残影挂在 HUD 层（世界在 SubViewport 里，挂世界层会被裁掉）
func _ghost_count() -> int:
	var hud: Node = Game.get_node_or_null(^"HudLayer")
	if hud == null:
		return 0
	var n := 0
	for child in hud.get_children():
		if child is Sprite2D and is_instance_valid(child):
			n += 1
	return n


# ── L. 成熟后放着不收：第 3 天结算就过熟枯萎 ──────────────────────
func _test_ripe_withers() -> void:
	print("\n[L] 成熟后不收 → 第 3 天枯萎")
	var coord := Vector2i(10, 0)
	var crop := _plant(Game.crop_datas[0], coord)   # cabbage，成果帧 2
	_water(coord); Game._end_day()
	_water(coord); Game._end_day()
	_check("已经成熟", crop.is_mature() and not crop.is_withered,
		"frame=%d" % crop.frame)
	# 之后一直浇水，看能不能靠浇水续命
	_water(coord); Game._end_day()
	_check("放着第 1 天：还在", not crop.is_withered, "ripe=%d" % crop.ripe_days)
	_water(coord); Game._end_day()
	_check("放着第 2 天：还在（还没到时限）", not crop.is_withered, "ripe=%d" % crop.ripe_days)
	_water(coord); Game._end_day()
	_check("放着第 3 天：过熟枯萎（浇水也救不回来）", crop.is_withered,
		"ripe=%d withered=%s" % [crop.ripe_days, crop.is_withered])


# ── M. 背景音乐：加载到、循环、在播 ──────────────────────────────
func _test_bgm() -> void:
	print("\n[M] 背景音乐")
	var player := Game.get_node_or_null(^"Bgm") as AudioStreamPlayer
	_check("game.tscn 里有 Bgm 节点", player != null)
	if player == null:
		return
	var stream := player.stream
	_check("Bgm 挂了音频流", stream != null, str(stream))
	if stream == null:
		return
	_check("音频流是 ogg 类型", stream is AudioStreamOggVorbis, stream.get_class())
	var ogg := stream as AudioStreamOggVorbis
	_check("循环已开启", ogg.loop == true)
	_check("时长 > 5 秒", stream.get_length() > 5.0, "%.1f 秒" % stream.get_length())
	_check("autoplay 已开启", player.autoplay == true)
	_check("正在播放", player.playing == true)
