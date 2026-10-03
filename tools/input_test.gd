extends Node

## 临时测试：BattleClock / BattleInput 输入层（用 godot res://tools/InputTest.tscn 跑，autoload 才是正常的）

var failures := 0


func _ready() -> void:
	print("--- autoload")
	_expect(BattleInput != null and BattleClock != null, "BattleInput / BattleClock 都加载了")
	_expect(BattleInput.mode == BattleInput.Mode.LIVE, "默认是 LIVE 模式")

	print("--- 采样：按下 -> 只真一帧")
	await BattleClock.wait_ticks(1) # 先过掉第一帧，避免"还没采样过"的边界
	Input.action_press(&"accept")
	await get_tree().physics_frame
	_expect(BattleInput.pressed(&"accept"), "按下后 pressed = true")
	_expect(BattleInput.just_pressed(&"accept"), "第一帧 just_pressed = true")
	await get_tree().physics_frame
	_expect(not BattleInput.just_pressed(&"accept"), "第二帧 just_pressed = false")
	Input.action_release(&"accept")
	await get_tree().physics_frame
	_expect(not BattleInput.pressed(&"accept"), "松开后 pressed = false")

	print("--- 方向向量")
	Input.action_press(&"right")
	await get_tree().physics_frame
	_expect(BattleInput.vector(&"left", &"right", &"up", &"down") == Vector2.RIGHT, "只按右 -> (1,0)")
	Input.action_press(&"down")
	await get_tree().physics_frame
	var diag := BattleInput.vector(&"left", &"right", &"up", &"down")
	_expect(is_equal_approx(diag.length(), 1.0) and diag.x > 0 and diag.y > 0, "右下 -> 单位斜向量 %s" % diag)
	Input.action_release(&"right")
	Input.action_release(&"down")
	await get_tree().physics_frame

	print("--- 菜单长按重复")
	Input.action_press(&"left")
	await get_tree().physics_frame
	var repeats := 0
	for i in 60:
		if BattleInput.repeated(&"left"):
			repeats += 1
		await get_tree().physics_frame
	Input.action_release(&"left")
	await get_tree().physics_frame
	_expect(repeats >= 5, "长按 60 帧会重复（实际 %d 次）" % repeats)
	_expect(not BattleInput.repeated(&"left"), "松开后不再重复")

	print("--- BattleClock")
	var before := Engine.get_physics_frames()
	await BattleClock.wait_ticks(5)
	_expect(Engine.get_physics_frames() - before == 5, "wait_ticks(5) 正好等 5 个物理帧")
	_expect(BattleClock.seconds_to_ticks(0.1) == 6, "0.1 秒 = 6 tick")
	_expect(BattleClock.seconds_to_ticks(3.0) == 180, "3 秒 = 180 tick")

	print("--- 真场景：tick 输入驱动战斗")
	var battle: Node = (load("res://scene/battle/battle.tscn") as PackedScene).instantiate()
	add_child(battle)
	await get_tree().process_frame
	await BattleClock.wait_ticks(2)
	_expect(battle.get("state") == battle.BattleState.ACTION, "初始在 ACTION")
	_expect(battle.get("choice_progress") == battle.Choice.NONE, "初始没有进任何列表")

	Input.action_press(&"accept") # 模拟真人按 Z
	await BattleClock.wait_ticks(3)
	_expect(battle.get("state") == battle.BattleState.FIGHT, "按 Z 后进入 FIGHT（tick 输入生效）")
	_expect(battle.get("choice_progress") == battle.Choice.ENEMY, "并且进了选敌列表")

	await BattleClock.wait_ticks(40)
	_expect(battle.get("choice_progress") == battle.Choice.ENEMY, "按住不放不会连续触发（just_pressed 只一次）")
	Input.action_release(&"accept")
	await BattleClock.wait_ticks(2)

	print("--- 回放模式：真人按键进不来")
	BattleInput.begin_playback(PackedInt32Array([0, 0, 0, 0]))
	Input.action_press(&"accept")
	await BattleClock.wait_ticks(10)
	_expect(battle.get("choice_progress") == battle.Choice.ENEMY, "回放模式下真人按键被忽略")
	Input.action_release(&"accept")

	print("--- 回放模式：录下来的帧会执行")
	var recorded := PackedInt32Array()
	for i in 20:
		recorded.append(0)
	recorded[5] = 1 << BattleInput.ACTIONS.find(&"accept")
	BattleInput.begin_playback(recorded)
	await BattleClock.wait_ticks(15)
	_expect(battle.get("choice_progress") == battle.Choice.NONE, "回放里第 5 帧的 accept 生效了（退出选敌列表）")
	BattleInput.stop()
	await BattleClock.wait_ticks(2)
	_expect(BattleInput.mode == BattleInput.Mode.LIVE, "stop() 回到 LIVE")

	print("--- 打字机：tick 输入推进对话")
	var panel := DialogPanel.new()
	var label := TypewriterLabel.new()
	panel.dialog_label = label
	panel.add_child(label)
	add_child(panel)
	var line0 := BaseDialog.new()
	line0.content = "第一句"
	var line1 := BaseDialog.new()
	line1.content = "第二句"
	await BattleClock.wait_ticks(1)
	panel.show_dialog([line0, line1])
	_expect(label.get("dialog_index") == 1, "显示后停在第 1 句")
	await _wait_typing(label)
	Input.action_press(&"accept")
	await BattleClock.wait_ticks(2)
	Input.action_release(&"accept")
	await BattleClock.wait_ticks(1)
	_expect(label.get("dialog_index") == 2, "按 Z 进入第 2 句（tick 输入推进对话）")
	_expect(label.text == "第二句", "文本也换了")
	await _wait_typing(label)
	Input.action_press(&"accept")
	await BattleClock.wait_ticks(2)
	Input.action_release(&"accept")
	await BattleClock.wait_ticks(1)
	_expect(not panel.visible, "第 2 句按完 Z 后收起来")
	panel.queue_free()

	print("=== %s ===" % ("全部通过" if failures == 0 else "有 %d 处问题" % failures))
	get_tree().quit(1 if failures > 0 else 0)


## 等打字机打完（现在还是真实时间驱动，第 3 步才会改成 tick）
func _wait_typing(label: TypewriterLabel) -> void:
	for i in 120:
		if not label.get("_running"):
			return
		await get_tree().process_frame


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("  [通过] ", message)
		return
	failures += 1
	push_error(message)
	print("  [失败] ", message)
