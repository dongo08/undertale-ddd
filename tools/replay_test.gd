extends Node

## 临时测试：第 5/6 步 —— 录制 → 存档 → 读档 → 播放，逐 tick 比对状态。
## 这是"东方式回放"的最终验收：只存种子 + 按键掩码，重跑一遍必须一模一样。

const SEED := 31337
const TICKS := 240
const BATTLE_SCENE := "res://scene/battle/battle.tscn"

var failures := 0
var recorded_trace: Array = []
var played_trace: Array = []


func _ready() -> void:
	print("--- 游程压缩")
	_rle_checks()

	print("--- 录制 → 存档 → 读档")
	var path := await _record()
	_expect(not path.is_empty() and FileAccess.file_exists(path), "回放文件写出来了：%s" % path)
	var data := BattleReplay.load_replay(path)
	_expect(not data.is_empty(), "能读回来")
	if data.is_empty():
		_finish()
		return
	var header: Dictionary = data["header"]
	var frames: PackedInt32Array = data["frames"]
	_expect(header["seed"] == SEED, "种子存对了（%d）" % header["seed"])
	_expect(header["scene"] == BATTLE_SCENE, "场景存对了（%s）" % header["scene"])
	_expect(int(header["result"]) == BattleReplay.Result.WIN, "结果标成胜利了")
	_expect(frames == BattleInput.recorded_frames(), "解出来的帧和录到的帧一致（%d 帧）" % frames.size())
	_expect(not header["dropped"], "没被标记成丢帧")

	print("--- 播放并与录制时比对")
	await _play(path)
	var diff := _first_diff(recorded_trace, played_trace)
	_expect(recorded_trace.size() == TICKS and played_trace.size() == TICKS, "两边都跑满 %d tick" % TICKS)
	_expect(diff < 0, "播放与录制逐 tick 一致" + ("" if diff < 0 else "（第 %d tick 起不同）" % diff))
	if diff >= 0:
		print("    录制: ", str(recorded_trace[diff]).substr(0, 260))
		print("    播放: ", str(played_trace[diff]).substr(0, 260))
	# 校验值：录制时存的 checksum 应该等于播放结束时的 checksum
	var expected := int(header["checksum"])
	_expect(expected != 0, "录制时算出了校验值（%d）" % expected)

	_finish()


func _rle_checks() -> void:
	var frames := PackedInt32Array()
	for i in 5:
		frames.append(0)
	for i in 300:
		frames.append(3)          # 超过 255，必须切段
	for i in 3:
		frames.append(0)
	frames.append(1024)           # 高位置位
	var bytes := BattleReplay.encode_frames(frames)
	var back := BattleReplay.decode_frames(bytes, frames.size())
	_expect(back == frames, "%d 帧（含 300 连帧 + 高位置位）压缩后原样还原：%d 字节" % [frames.size(), bytes.size()])
	_expect(BattleReplay.decode_frames(bytes, 0).is_empty(), "要 0 帧就解出 0 帧")


## 用"真人按键"驱动录一遍（录制走的是设备采样那条路）
func _record() -> String:
	BattleReplay.begin_battle(BATTLE_SCENE)
	var battle: Node = (load(BATTLE_SCENE) as PackedScene).instantiate()
	add_child(battle)
	BattleRNG.begin(SEED)         # 战斗 _ready 会 begin_random，这里覆盖成固定种子
	_expect(BattleReplay.recording, "已经进入录制状态")
	for i in TICKS:
		await get_tree().physics_frame
		_apply_schedule(i)
		recorded_trace.append(_snapshot(battle))
	Input.action_release(&"accept")
	Input.action_release(&"left")
	# 走战斗自己的结束路径（会算校验值再存档，跟真人打赢一局一样）
	var ok: bool = battle.finish_replay(BattleReplay.Result.WIN)
	_expect(ok, "战斗结束时存档成功（含校验值）")
	var path := BattleReplay.last_saved_path
	battle.queue_free()
	await get_tree().process_frame
	return path


func _play(path: String) -> void:
	_expect(BattleReplay.prepare_playback(path), "prepare_playback 成功")
	var battle: Node = (load(BATTLE_SCENE) as PackedScene).instantiate()
	add_child(battle)
	for i in TICKS:
		await get_tree().physics_frame
		played_trace.append(_snapshot(battle))
	# 播放到"该结束"的地方：此处的校验值必须和录制时存的一致
	var ok: bool = battle.finish_replay(BattleReplay.Result.WIN)
	_expect(ok, "播放结束时校验值对得上")
	battle.queue_free()
	await get_tree().process_frame


## 脚本化的"真人操作"：每 30 tick 按一下 Z，每 97 tick 按一下左
func _apply_schedule(i: int) -> void:
	if i % 30 == 0:
		Input.action_press(&"accept")
	elif i % 30 == 2:
		Input.action_release(&"accept")
	if i % 97 == 0:
		Input.action_press(&"left")
	elif i % 97 == 2:
		Input.action_release(&"left")


func _snapshot(battle: Node) -> String:
	var parts := PackedStringArray()
	parts.append("st=%d" % battle.get("state"))
	parts.append("cp=%d" % battle.get("choice_progress"))
	parts.append("ri=%d" % battle.get("round_index"))
	parts.append("bi=%d" % battle.get("button_index"))
	parts.append("ci=%d" % battle.get("choice_index"))
	parts.append("hp=%.4f" % battle.battle_data.player_status.hp)
	var soul: Node2D = battle.get("soul")
	if soul:
		parts.append("soul=%.4f,%.4f" % [soul.position.x, soul.position.y])
	parts.append("rng=%d" % BattleRNG.rng.state)
	var bullets := _collect_bullets(battle)
	parts.append("nb=%d" % bullets.size())
	var hashed := mini(bullets.size(), 250)
	for i in hashed:
		var bullet = bullets[i]
		parts.append("%.4f,%.4f,%.4f,%.4f" % [bullet.position.x, bullet.position.y, bullet.rotation, bullet.lifetime])
	return "|".join(parts)


func _collect_bullets(node: Node) -> Array:
	var out: Array = []
	for child in node.get_children():
		if child is BaseBullet:
			out.append(child)
		out.append_array(_collect_bullets(child))
	return out


func _first_diff(a: Array, b: Array) -> int:
	for i in mini(a.size(), b.size()):
		if a[i] != b[i]:
			return i
	return -1 if a.size() == b.size() else mini(a.size(), b.size())


func _finish() -> void:
	print("=== %s ===" % ("全部通过" if failures == 0 else "有 %d 处问题" % failures))
	get_tree().quit(1 if failures > 0 else 0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("  [通过] ", message)
		return
	failures += 1
	push_error(message)
	print("  [失败] ", message)
