extends Node2D

## 临时验收脚本：无头跑 TouchControls，用合成触摸事件验证
##   1) 自动检测：一开始收起，摸一下屏幕后弹出，键鼠输入再收起
##   2) 摇杆：往四个方向摸，按出的是不是 left/right/up/down
##   3) 功能键：两个 TouchScreenButton 分别按出 accept / cancel（含双指同时按）
## 用法：godot --headless --path . res://tools/TouchControlsSim.tscn

const DIRS := [&"up", &"down", &"left", &"right"]

var tc: TouchControls
var _dir_state := {}
var _fail := 0
var _checked := 0


func _ready() -> void:
	tc = TouchControls.new()
	tc.visibility_mode = TouchControls.VisMode.AUTO
	add_child(tc)
	await _tick(2)
	# 直接把摇杆收到的原始事件打出来：它到底收到没收到、坐标是多少
	var vj := tc.get_node_or_null("VirtualJoystick")
	print("### 找到摇杆: ", vj, " 类型=", vj.get_class() if vj else "-",
			" rect=", vj.get_global_rect() if vj else "-")
	if vj:
		vj.connect("gui_input", func(e): print("      [vj gui_input] ", e.as_text()))
		vj.set_process_input(true)
	print("### 起始 (无触摸设备): 可见=", tc.is_controls_visible(), " (期望 false)")
	_check(tc.is_controls_visible() == false, "起始应该收起")

	# ---- 1) 鼠标输入不该把它叫出来 ----
	_mouse(Vector2(300, 300), true)
	await _tick(2)
	print("### 收到鼠标: 可见=", tc.is_controls_visible(), " (期望 false)")
	_check(tc.is_controls_visible() == false, "鼠标不该叫出摇杆")

	# ---- 2) 摸一下 -> 弹出 ----
	await _touch(0, Vector2(150, 300), true, "第一次触摸")
	print("### 触摸后: 可见=", tc.is_controls_visible(), " (期望 true)")
	_check(tc.is_controls_visible(), "触摸后应该弹出")

	# ---- 3) 摇杆四个方向 ----
	await _drag(0, Vector2(150 + 50, 300), "向右")
	_check_dir("向右", [&"right"])
	await _drag(0, Vector2(150 - 50, 300), "向左")
	_check_dir("向左", [&"left"])
	await _drag(0, Vector2(150, 300 - 50), "向上")
	_check_dir("向上", [&"up"])
	await _drag(0, Vector2(150, 300 + 50), "向下")
	_check_dir("向下", [&"down"])
	# 斜着推：两个方向应该同时按下
	await _drag(0, Vector2(150 + 40, 300 + 40), "右下斜")
	_check_dir("右下斜", [&"down", &"right"])
	# 松手应该全部松开
	await _touch(0, Vector2(150 + 40, 300 + 40), false, "松手")
	_check_dir("松手", [])

	# ---- 4) 功能键所在的那一条不该召出摇杆 ----
	await _touch(1, Vector2(500, 460), true, "摸右下的按键区")
	print("### 按键区触摸后摇杆方向=", _pressed_dirs(), " (期望 [])")
	_check(_pressed_dirs().is_empty(), "按键区不该召出摇杆")
	# 顺手把这个手指拿来测右边的功能键：先松开
	await _touch(1, Vector2(500, 460), false, "松开按键区")

	# ---- 5) 两个功能键 ----
	var buttons := tc._action_buttons
	var accept_pos := buttons[0].position + buttons[0].texture_normal.get_size() * 0.5
	var cancel_pos := buttons[1].position + buttons[1].texture_normal.get_size() * 0.5
	print("### 按键位置 accept=", accept_pos, " cancel=", cancel_pos)

	await _touch(2, accept_pos, true, "按 accept 键")
	_check_action("accept 按下", &"accept", true)
	_check_action("cancel 此时不该按下", &"cancel", false)
	await _touch(3, cancel_pos, true, "双指再按 cancel 键")
	_check_action("双指时 accept 仍按下", &"accept", true)
	_check_action("双指时 cancel 按下", &"cancel", true)
	await _touch(2, accept_pos, false, "松开 accept 键")
	_check_action("松开后 accept 弹起", &"accept", false)
	_check_action("cancel 应该还按着", &"cancel", true)
	await _touch(3, cancel_pos, false, "松开 cancel 键")
	_check_action("松开后 cancel 弹起", &"cancel", false)

	# ---- 6) 键鼠输入把控件收起来，并确保不留幽灵输入 ----
	_mouse(Vector2(300, 300), true)
	await _tick(2)
	print("### 键鼠输入后: 可见=", tc.is_controls_visible(), " (期望 false)")
	_check(tc.is_controls_visible() == false, "键鼠输入后应该收起")

	print("### ===== 结果: 检查 ", _checked, " 项，失败 ", _fail, " 项 =====")
	get_tree().quit(1 if _fail > 0 else 0)


# ---------------------------------------------------------------- 断言

func _check(ok: bool, label: String) -> void:
	_checked += 1
	if ok:
		print("    [OK] ", label)
	else:
		_fail += 1
		print("    [FAIL] ", label)


func _check_dir(label: String, expected: Array) -> void:
	var now := _pressed_dirs()
	var want := expected.duplicate()
	want.sort()
	now.sort()
	_check(now == want, "%s -> 按着=%s 期望=%s" % [label, now, want])


func _check_action(label: String, action: StringName, expected: bool) -> void:
	var now := Input.is_action_pressed(action)
	_check(now == expected, "%s (实际=%s 期望=%s)" % [label, now, expected])


func _pressed_dirs() -> Array:
	var out := []
	for d in DIRS:
		if Input.is_action_pressed(d):
			out.append(d)
	return out


# ---------------------------------------------------------------- 事件注入

func _tick(n: int) -> void:
	for i in n:
		await get_tree().process_frame


## 触摸坐标用画布坐标（640x480）给；注入时换算成窗口坐标（真实平台上事件
## 就是窗口坐标，引擎再按拉伸比例换算回画布坐标）。
## 注意必须用 viewport.push_input：Input.parse_input_event 在这个拉伸配置下
## 和 push_input 走的是不同的坐标处理路径，测不出来。
func _to_window(pos: Vector2) -> Vector2:
	return get_viewport().get_final_transform() * pos


func _inject(event: InputEvent) -> void:
	get_viewport().push_input(event)


func _touch(index: int, pos: Vector2, pressed: bool, label: String) -> void:
	var e := InputEventScreenTouch.new()
	e.index = index
	e.position = _to_window(pos)
	e.pressed = pressed
	_inject(e)
	await _tick(3)
	print("### ", label, " @", pos, " -> 可见=", tc.is_controls_visible(), " 方向=", _pressed_dirs())


func _drag(index: int, pos: Vector2, label: String) -> void:
	var e := InputEventScreenDrag.new()
	e.index = index
	e.position = _to_window(pos)
	_inject(e)
	await _tick(3)
	print("### 拖动 ", label, " -> 方向=", _pressed_dirs())


func _mouse(pos: Vector2, pressed: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = pressed
	e.position = _to_window(pos)
	_inject(e)
