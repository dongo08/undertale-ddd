extends Node

## 临时验收：把三个战斗场景都实例化一遍，检查
##   1) 场景能加载、没有解析错误
##   2) TouchControls 起来了，摇杆 / 两个功能键都在
##   3) 旧节点路径（black = CanvasLayer/ColorRect）还能解析
## 用法：godot --path . res://tools/SceneCheck.tscn

const SCENES := [
	"res://scene/battle/battle.tscn",
	"res://scene/battle/sub_battle.tscn",
	"res://scene/battle/levels/level1/level1_sub_battle.tscn",
]

var fails := 0

func _ready() -> void:
	for path in SCENES:
		await _check(path)
	print("===== 结果：失败 ", fails, " 项 =====")
	get_tree().quit(1 if fails > 0 else 0)


func _check(path: String) -> void:
	print("--- ", path)
	var packed := ResourceLoader.load(path) as PackedScene
	if packed == null:
		_fail("场景加载失败")
		return
	var root := packed.instantiate()
	if root == null:
		_fail("实例化失败")
		return
	add_child(root)
	await get_tree().process_frame
	await get_tree().process_frame

	var tc := root.get_node_or_null("TouchControls")
	if tc == null:
		_fail("没找到 TouchControls 节点")
	else:
		print("    TouchControls: ", tc.get_class(), " script=", tc.get_script())
		var vj := tc.get_node_or_null("VirtualJoystick")
		if vj == null:
			_fail("没找到 VirtualJoystick")
		else:
			print("    摇杆: actions=", vj.action_left, "/", vj.action_right, "/",
					vj.action_up, "/", vj.action_down,
					" mode=", vj.joystick_mode, " mouse_filter=", vj.mouse_filter,
					" rect=", vj.get_global_rect())
			_ok(vj.action_left == &"left" and vj.action_right == &"right"
					and vj.action_up == &"up" and vj.action_down == &"down",
					"摇杆四个方向接对了")
			_ok(vj.mouse_filter != Control.MOUSE_FILTER_IGNORE, "摇杆没收不到输入（mouse_filter 正确）")
		var buttons: Array = tc.get_children().filter(func(c): return c is TouchScreenButton)
		print("    功能键: ", buttons.map(func(b): return b.name + "->" + b.action))
		_ok(buttons.size() == 2, "两个功能键都在")
		if buttons.size() == 2:
			var actions := buttons.map(func(b): return b.action)
			_ok("accept" in actions and "cancel" in actions, "两个键分别接了 accept / cancel")

	# 旧路径检查：black 属性指到的 ColorRect
	var black = root.get("black")
	if black == null:
		# 有的场景没这个属性
		pass
	elif black is Node:
		print("    black -> ", black.get_path())
	else:
		_fail("black 没解析成 ColorRect: " + str(black))

	root.queue_free()
	await get_tree().process_frame


func _ok(cond: bool, label: String) -> void:
	if cond:
		print("      [OK] ", label)
	else:
		_fail(label)


func _fail(label: String) -> void:
	fails += 1
	print("      [FAIL] ", label)
