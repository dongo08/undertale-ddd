extends Node

## 临时测试：BattleRNG（第 2 步：随机数种子化）

var failures := 0


func _ready() -> void:
	print("--- BattleRNG 基本性质")
	BattleRNG.begin(12345)
	var a := _sample(5)
	BattleRNG.begin(12345)
	var b := _sample(5)
	_expect(a == b, "同种子 -> 同样的序列")
	BattleRNG.begin(999)
	var c := _sample(5)
	_expect(a != c, "不同种子 -> 不同序列")

	BattleRNG.begin_random()
	var s1 := BattleRNG.used_seed
	BattleRNG.begin_random()
	var s2 := BattleRNG.used_seed
	_expect(s1 != s2, "begin_random 每次给不同种子（%d / %d）" % [s1, s2])
	_expect(BattleRNG.used_seed == s2, "used_seed 记住了本局种子")

	print("--- 伤害随机走战斗随机")
	var bar: Node = (load("res://scene/battle/battle_frame/attack_bar.tscn") as PackedScene).instantiate()
	add_child(bar)
	BattleRNG.begin(777)
	var d1: float = bar.call("_calculate_damage", 100.0, 1.0, 50.0, 100.0)
	BattleRNG.begin(777)
	var d2: float = bar.call("_calculate_damage", 100.0, 1.0, 50.0, 100.0)
	BattleRNG.begin(778)
	var d3: float = bar.call("_calculate_damage", 100.0, 1.0, 50.0, 100.0)
	_expect(is_equal_approx(d1, d2), "同种子 -> 伤害一样（%.3f）" % d1)
	_expect(not is_equal_approx(d1, d3), "换种子 -> 伤害变了（%.3f vs %.3f）" % [d1, d3])
	bar.queue_free()

	print("--- 真实弹幕脚本可复现（level1/round4 的 rad1/rad2）")
	var r1 := await _probe_round4(4242)
	var r2 := await _probe_round4(4242)
	var r3 := await _probe_round4(4243)
	_expect(r1[2] == 1 and r2[2] == 1, "两次都跑到了抽随机的阶段（state=%d/%d）" % [r1[2], r2[2]])
	_expect(r1 == r2, "同种子 -> 抽出来的 rad 完全一致 %s" % [r1])
	_expect(r1 != r3, "换种子 -> rad 不同 %s vs %s" % [r1, r3])

	print("=== %s ===" % ("全部通过" if failures == 0 else "有 %d 处问题" % failures))
	get_tree().quit(1 if failures > 0 else 0)


func _sample(count: int) -> Array:
	var out: Array = []
	for i in count:
		out.append(BattleRNG.randf())
	return out


## 真的把一轮弹幕跑起来，读它抽到的随机角度
func _probe_round4(seed_value: int) -> Array:
	var battle: Node = (load("res://scene/battle/battle.tscn") as PackedScene).instantiate()
	add_child(battle) # 战斗 _ready 里会 begin_random()，所以种子要在它之后再设
	BattleRNG.begin(seed_value)
	var mgr: Node = (load("res://scripts/battle/levels/level1/round4.gd") as GDScript).new()
	mgr.set("master", battle)
	battle.add_child(mgr)
	mgr.call("start")
	for i in 600:
		if mgr.get("state") == 1:
			break
		await get_tree().process_frame
	var result: Array = [mgr.get("rad1"), mgr.get("rad2"), mgr.get("state")]
	battle.queue_free()
	await get_tree().process_frame
	return result


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("  [通过] ", message)
		return
	failures += 1
	push_error(message)
	print("  [失败] ", message)
