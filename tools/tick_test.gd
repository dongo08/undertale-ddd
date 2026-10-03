extends Node

## 临时测试：第 3 步（定时器 → tick、逻辑从渲染帧搬到物理帧）

var failures := 0


func _ready() -> void:
	print("--- 子弹按物理帧走，不按渲染帧")
	var bullet := NormalBullet.new()
	bullet.speed = 300.0
	bullet.direction = Vector2.DOWN
	bullet.lifetime = 100.0
	add_child(bullet)
	var start_y := bullet.position.y
	var f0 := Engine.get_physics_frames()
	await BattleClock.wait_ticks(30)
	var ticks := Engine.get_physics_frames() - f0
	var moved := bullet.position.y - start_y
	_expect(ticks >= 28, "等到了物理帧（%d tick）" % ticks)
	# 每 tick 走 5.0（300/60）：用"步数"而不是帧号差来比，差 1 是帧边界
	var steps := roundi(moved / 5.0)
	_expect(absf(moved - steps * 5.0) < 0.001, "位移是每 tick 5.0 的整数倍（%d 步 × 5.0 = %.1f）" % [steps, moved])
	_expect(steps >= ticks - 1 and steps <= ticks, "走了 %d 步，与 %d 个物理帧一致（±1 是边界）" % [steps, ticks])
	bullet.queue_free()

	print("--- 正弦子弹也在物理帧里")
	var sine := SineBullet.new()
	sine.speed = 120.0
	sine.amplitude = 200.0
	sine.center_x = 320.0
	sine.period = 4.0
	sine.position = Vector2(320.0, 0.0)
	sine.lifetime = 100.0
	add_child(sine)
	var s0 := sine.position
	var f1 := Engine.get_physics_frames()
	await BattleClock.wait_ticks(20)
	var st := Engine.get_physics_frames() - f1
	_expect(is_equal_approx(sine.position.y - s0.y, st * 120.0 / 60.0), "正弦子弹竖直位移按 tick（%.2f）" % (sine.position.y - s0.y))
	_expect(not is_equal_approx(sine.position.x, s0.x), "水平方向有正弦摆动")
	sine.queue_free()

	print("--- 打字机按 tick 走（不再吃真实时间）")
	var label := TypewriterLabel.new()
	add_child(label)
	var dialog := BaseDialog.new()
	dialog.content = "十个字符的台词吧"
	var f2 := Engine.get_physics_frames()
	label.show_dialog([dialog])
	# 单句台词打完不会发 typing_end（要再按一次 Z 才结束），所以盯 _running
	for i in 600:
		if not label.get("_running"):
			break
		await get_tree().physics_frame
	var type_ticks := Engine.get_physics_frames() - f2
	var chars := dialog.content.length()
	_expect(type_ticks >= chars * 2 - 2 and type_ticks <= chars * 2 + 2, "%d 个字符用了 %d tick（≈2 tick/字符）" % [chars, type_ticks])
	label.queue_free()

	print("--- 弹幕脚本里的 await wait(1) 也走 tick")
	var battle: Node = (load("res://scene/battle/battle.tscn") as PackedScene).instantiate()
	add_child(battle)
	var mgr: Node = (load("res://scripts/battle/levels/level1/round4.gd") as GDScript).new()
	mgr.set("master", battle)
	battle.add_child(mgr)
	var f3 := Engine.get_physics_frames()
	mgr.call("start")
	var waited := -1
	for i in 600:
		if mgr.get("state") == 1:
			waited = Engine.get_physics_frames() - f3
			break
		await get_tree().physics_frame
	_expect(waited >= 55 and waited <= 70, "start() 里的 wait(1) 花了 %d tick（≈60）" % waited)
	battle.queue_free()
	await get_tree().process_frame

	print("=== %s ===" % ("全部通过" if failures == 0 else "有 %d 处问题" % failures))
	get_tree().quit(1 if failures > 0 else 0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("  [通过] ", message)
		return
	failures += 1
	push_error(message)
	print("  [失败] ", message)
