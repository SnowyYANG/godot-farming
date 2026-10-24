class_name Crop
extends AnimatedSprite2D

## 连续不浇水多少天死亡（种子消失 / 苗枯萎）
const DRY_DAYS_TO_DIE := 2

var coord: Vector2i
var data: CropData
var dry_days: int = 0
var is_withered := false
var is_golden := false
var gone := false

## 今天是否浇过水（湿土图层的瓦片就是浇水标记）
var watered: bool:
	get:
		return Game.map_wet_soil.get_cell_tile_data(coord) != null


## 由 Game 在种植时调用。各阶段的帧预置在 crop.tscn 的 SpriteFrames 里（编辑器可见），
## 这里只负责切到对应作物的动画。
func setup(crop_data: CropData, cell: Vector2i) -> void:
	data = crop_data
	coord = cell
	animation = data.name
	frame = 0
	z_index = 1


func last_stage() -> int:
	return sprite_frames.get_frame_count(data.name) - 1


func is_mature() -> bool:
	return not is_withered and frame >= last_stage()


## 每天结束调用一次
func advance_day() -> void:
	if gone or is_withered:
		return

	if watered:
		dry_days = 0
		if frame < last_stage():
			frame += 1
			_roll_golden()
	else:
		dry_days += 1
		if dry_days >= DRY_DAYS_TO_DIE:
			if frame == 0:
				_disappear()        # 种子：连续 2 天没浇水 → 消失
			else:
				_wither()           # 苗：连续 2 天没浇水 → 枯萎


func _roll_golden() -> void:
	if is_mature() and data.golden_chance > 0.0 and not data.golden.is_empty():
		if randf() < data.golden_chance:
			is_golden = true
			sprite_frames.set_frame(data.name, last_stage(), data.golden[0])
			frame = last_stage()


func _wither() -> void:
	is_withered = true
	animation = "withered"      # crop.tscn 里预置的枯萎动画
	frame = 0
	modulate = Color(0.75, 0.75, 0.7)


func _disappear() -> void:
	gone = true
	Game.crop_dict.erase(coord)
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.25)
	tween.tween_callback(queue_free)


## 收获。连种作物回到指定阶段，一次性作物飞向库存后消失。
func harvest() -> void:
	if gone or is_withered:
		return

	var amount: int = data.yield_amount * (2 if is_golden else 1)
	Game.add_stock(data.name, amount)

	if data.repeat_harvest:
		# 连种：先复制一份当前外形飞向库存（吸收动画），本体立刻回到重置阶段，
		# 否则收获动画会被"重置到小花骨朵"直接截断
		_spawn_absorb_ghost()
		is_golden = false
		animation = data.name
		frame = clampi(data.reset_stage, 0, last_stage())
		var pop := create_tween()
		pop.tween_property(self, "scale", Vector2(1.15, 0.85), 0.08)
		pop.tween_property(self, "scale", Vector2.ONE, 0.12)
		return

	gone = true
	Game.crop_dict.erase(coord)
	var target: Node = Game.stock_pool.get_node_or_null(NodePath(data.name))
	if target == null:
		queue_free()
		return
	var fly := create_tween()
	fly.set_parallel(true)
	fly.tween_property(self, "global_position", target.global_position + Vector2(4, 4), 0.4)
	fly.tween_property(self, "modulate:a", 0.0, 0.4)
	fly.chain().tween_callback(queue_free)


## 生成一个"残影"飞向库存，让连种作物也有完整的吸收动画
func _spawn_absorb_ghost() -> void:
	var target: Node = Game.stock_pool.get_node_or_null(NodePath(data.name))
	if target == null:
		return

	var texture := sprite_frames.get_frame_texture(animation, frame)
	if texture == null:
		return

	var ghost := Sprite2D.new()
	ghost.texture = texture
	ghost.global_position = global_position
	ghost.z_index = z_index + 1
	Game.crop_pool.add_child(ghost)

	var fly := ghost.create_tween()
	fly.set_parallel(true)
	fly.tween_property(ghost, "global_position", target.global_position + Vector2(4, 4), 0.4) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fly.tween_property(ghost, "modulate:a", 0.0, 0.4)
	fly.tween_property(ghost, "scale", Vector2(0.6, 0.6), 0.4)
	fly.chain().tween_callback(ghost.queue_free)
