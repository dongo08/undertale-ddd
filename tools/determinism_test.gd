extends Node

## 临时测试：第 4 步 —— 确定性自测
## 同一个种子 + 同一段输入跑两遍，逐物理帧比对完整状态。
## 一致 => 改造到位、可以开始录回放；不一致 => 第一处分歧的 tick 就是漏改的地方。
##
## 这里的 A 组其实就是"回放"的流程：先 begin_playback + begin(种子)，再加载场景。

const TICKS_BATTLE := 300
const TICKS_PATTERN := 150
const SEED := 20240611
## 一帧最多比对多少发子弹（长跑时子弹上千，全量比对会把测试本身拖垮）
const MAX_BULLETS_HASHED := 250

## 要单独验的真实弹幕脚本
const PATTERNS := [
	"res://scripts/battle/levels/level1/round0.gd", # 正弦 + 圆环（sin_speed 已改成按 tick 插值）
	"res://scripts/battle/levels/level1/round3.gd", # 手套绕圈（state/velosity 原先是 tween 驱动）
	"res://scripts/battle/levels/level1/round6.gd", # 眼球子弹（整条轨迹原先是 tween）
	"res://scripts/battle/levels/level1/round8.gd", # 手套绕圈（state 原先是 tween 驱动）
	"res://scripts/battle/levels/level1/round9.gd", # 随机位置 + 圆环弹 + 冲击波
	"res://scripts/battle/levels/test/round2.gd",   # 随机角度 + 360 发
]

var failures := 0


func _ready() -> void:
	print("--- A. 整场战斗（battle.tscn）跑两遍")
	var frames := _make_frames(TICKS_BATTLE)
	var a := await _run_battle(SEED, frames, TICKS_BATTLE)
	var b := await _run_battle(SEED, frames, TICKS_BATTLE)
	_expect(a.size() == TICKS_BATTLE and b.size() == TICKS_BATTLE, "两次都跑满了 %d tick" % TICKS_BATTLE)
	var d1 := _report_diff("整场战斗", a, b)
	_expect(d1 < 0, "同种子同输入：逐 tick 完全一致")
	_expect(a[TICKS_BATTLE - 1].contains("nb=") and _count_bullets_in(a[TICKS_BATTLE - 1]) > 0, "这段确实打到出弹幕的阶段了（最后一帧有 %d 发子弹）" % _count_bullets_in(a[TICKS_BATTLE - 1]))

	print("--- B. 真实弹幕脚本逐个跑两遍")
	var first_trace: Array = []
	for path: String in PATTERNS:
		var name := path.get_file()
		var r1 := await _run_pattern(path, SEED, TICKS_PATTERN)
		if first_trace.is_empty():
			first_trace = r1
		var r2 := await _run_pattern(path, SEED, TICKS_PATTERN)
		var d := _report_diff(name, r1, r2)
		_expect(d < 0, "%s：同种子逐 tick 一致（末帧 %d 发子弹）" % [name, _count_bullets_in(r1[TICKS_PATTERN - 1])])

	print("--- C. 换种子必须不一样（否则上面的测试是空的）")
	var other := await _run_pattern(PATTERNS[0], SEED + 1, TICKS_PATTERN)
	_expect(_first_diff(first_trace, other) >= 0, "换种子后弹幕就不同了")

	print("=== %s ===" % ("全部通过" if failures == 0 else "有 %d 处问题" % failures))
	get_tree().quit(1 if failures > 0 else 0)


## 整场战斗：先设好种子和输入源（回放模式），再加载场景
func _run_battle(seed_value: int, frames: PackedInt32Array, ticks: int) -> Array:
	BattleInput.begin_playback(frames)
	BattleRNG.begin(seed_value)
	var battle: Node = (load("res://scene/battle/battle.tscn") as PackedScene).instantiate()
	add_child(battle)
	var trace := await _trace(battle, ticks)
	battle.queue_free()
	await get_tree().process_frame
	BattleInput.stop()
	return trace


## 单个弹幕脚本：挂在真战斗场景下跑（战斗 _ready 会 begin_random，所以种子要在它之后设）
func _run_pattern(script_path: String, seed_value: int, ticks: int) -> Array:
	var battle: Node = (load("res://scene/battle/battle.tscn") as PackedScene).instantiate()
	add_child(battle)
	BattleRNG.begin(seed_value)
	var mgr: Node = (load(script_path) as GDScript).new()
	mgr.set("master", battle)
	battle.add_child(mgr)
	mgr.call("start")
	var trace := await _trace(battle, ticks)
	battle.queue_free()
	await get_tree().process_frame
	return trace


## 每物理帧记一份完整状态
func _trace(battle: Node, ticks: int) -> Array:
	var out: Array = []
	for i in ticks:
		await get_tree().physics_frame
		out.append(_snapshot(battle))
	return out


## 一份"可以逐字比对"的战场快照
func _snapshot(battle: Node) -> String:
	var parts := PackedStringArray()
	parts.append("st=%d" % battle.get("state"))
	parts.append("cp=%d" % battle.get("choice_progress"))
	parts.append("ri=%d" % battle.get("round_index"))
	parts.append("bi=%d" % battle.get("button_index"))
	parts.append("ci=%d" % battle.get("choice_index"))
	parts.append("pi=%d" % battle.get("page_index"))
	parts.append("hp=%.4f" % battle.battle_data.player_status.hp)
	var soul: Node2D = battle.get("soul")
	if soul:
		parts.append("soul=%.4f,%.4f" % [soul.position.x, soul.position.y])
		parts.append("vel=%.4f,%.4f" % [soul.velocity.x, soul.velocity.y])
	parts.append("rng=%d" % BattleRNG.rng.state)
	var bullets := _collect_bullets(battle)
	parts.append("nb=%d" % bullets.size())
	var hashed := mini(bullets.size(), MAX_BULLETS_HASHED)
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


func _count_bullets_in(snapshot: String) -> int:
	for piece in snapshot.split("|"):
		if piece.begins_with("nb="):
			return int(piece.substr(3))
	return -1


func _make_frames(ticks: int) -> PackedInt32Array:
	var accept_bit := 1 << BattleInput.ACTIONS.find(&"accept")
	var left_bit := 1 << BattleInput.ACTIONS.find(&"left")
	var frames := PackedInt32Array()
	for i in ticks:
		var mask := 0
		if i % 40 == 0:
			mask |= accept_bit   # 每 40 tick 按一下 Z
		if i % 137 == 0:
			mask |= left_bit     # 偶尔左右挪一下光标
		frames.append(mask)
	return frames


func _first_diff(a: Array, b: Array) -> int:
	var n := mini(a.size(), b.size())
	for i in n:
		if a[i] != b[i]:
			return i
	return -1 if a.size() == b.size() else n


func _report_diff(label: String, a: Array, b: Array) -> int:
	var diff := _first_diff(a, b)
	if diff < 0:
		print("    %s：%d tick 全部一致" % [label, a.size()])
		return -1
	print("    %s：第 %d tick 开始不同" % [label, diff])
	print("      A: ", str(a[diff]).substr(0, 400))
	print("      B: ", str(b[diff]).substr(0, 400))
	return diff


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("  [通过] ", message)
		return
	failures += 1
	push_error(message)
	print("  [失败] ", message)
