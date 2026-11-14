extends CanvasLayer
class_name TouchControls

## 手机触摸操作层：虚拟摇杆（VirtualJoystick）+ 两个功能键（TouchScreenButton）。
##
## 自动检测：
##   - 真机（DisplayServer 明确报告有触摸屏）、或者收到过触摸事件 -> 弹出
##   - 只有鼠标 / 键盘输入，而且这台机器没摸过               -> 收起（不挡画面）
##   也就是说：手机一上来就有摇杆；触屏笔记本插着鼠标也不会闪；纯键盘玩家什么都看不到。
##
## 它只负责“按出 action”，不碰任何游戏逻辑：
##   方向 -> 项目里已定义的 up / down / left / right
##   按键 -> accept（确认）和 cancel（取消）
## 战斗里的输入走 BattleInput 的物理帧采样，最终读到的还是 Input 的 action 状态，
## 所以摇杆、键盘、回放三者天然共存，回放不需要任何特判。

enum VisMode {
	AUTO,    ## 按上面的规则自动切换
	ALWAYS,  ## 一直显示，方便在编辑器里调位置
	NEVER,   ## 一直收起
}

## 摇杆接的方向键，顺序固定是 左 / 右 / 上 / 下，别改。
const JOYSTICK_ACTIONS := [&"left", &"right", &"up", &"down"]

const DEFAULT_ACCEPT_TEXTURES := [
	"res://assets/sprites/UI/spr_test_zbutton_3.png",
	"res://assets/sprites/UI/spr_test_zbutton_2.png",
]
const DEFAULT_CANCEL_TEXTURES := [
	"res://assets/sprites/UI/spr_test_xbutton_1.png",
	"res://assets/sprites/UI/spr_test_xbutton_3.png",
]

@export var visibility_mode: VisMode = VisMode.AUTO
## 摇杆底座直径（像素）；摇杆大小的手感基本就靠这个
@export var joystick_size: float = 110.0
## 摇杆头上那颗球的直径
@export var tip_size: float = 55.0
## 死区比例：手指离中心多远才算“动了”。0 = 一碰就动（十字键手感）
@export_range(0.0, 0.9, 0.01) var deadzone_ratio: float = 0.0
## 功能键图标；两个元素分别是“没按 / 按住”
@export var accept_textures: PackedStringArray = PackedStringArray()
@export var cancel_textures: PackedStringArray = PackedStringArray()
## 两个功能键接的 action（想改成别的动作就动这里）
@export var accept_action: StringName = &"accept"
@export var cancel_action: StringName = &"cancel"
## 功能键离屏幕右边 / 下边的距离
@export var buttons_margin: Vector2 = Vector2(6, 8)
## 两个功能键之间的间距
@export var buttons_gap: float = 6.0
## 摇杆横向占屏幕多宽（比例）。1.0 = 整屏都可以召出摇杆，
## 0.5 = 只有左半屏。默认整屏，因为功能键那一带已经排除了。
@export_range(0.3, 1.0, 0.05) var joystick_width_ratio: float = 1.0
## 桌面端要不要画个“左下角是摇杆”的提示（真检测到触摸屏后就不再显示）
@export var show_desktop_hint: bool = true

var _joystick: VirtualJoystick
var _action_buttons: Array[TouchScreenButton] = []
var _hint: Control

## 摇杆的触摸活动范围（画布坐标）：整屏减去功能键那一带
var _joystick_rect := Rect2()
var _last_size := Vector2.ZERO
var _controls_visible := false
## 这台机器有没有真触摸屏（启动时问一次 DisplayServer）
var _has_touchscreen := false
## 这次运行里有没有真的摸过屏幕
var _touched_once := false


func _ready() -> void:
	# 战斗可能被暂停（演出 / 暂停菜单），输入层得照常工作
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 2
	_has_touchscreen = _touchscreen_available()
	_build_hint()
	_build_joystick()
	_build_action_buttons()
	_refresh_layout()
	set_controls_visible(_should_show())


func _process(_delta: float) -> void:
	_refresh_layout()


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		# 摸到屏幕就算数：有些设备 / 导出配置下 is_touchscreen_available() 会骗人
		_touched_once = true
		if visibility_mode == VisMode.AUTO and not _controls_visible:
			set_controls_visible(true)
		return
	# 只收拾“没有触摸屏”的机器：触屏笔记本插个鼠标不该把摇杆收掉
	if visibility_mode != VisMode.AUTO or _has_touchscreen:
		return
	if event is InputEventMouse or event is InputEventKey or event is InputEventJoypadButton \
			or event is InputEventJoypadMotion:
		if _controls_visible:
			set_controls_visible(false)


## 摇杆 / 按键统一开关。关掉的时候顺手把已经按下的 action 松开，
## 免得留下一堆“按住不放”的幽灵输入。
func set_controls_visible(value: bool) -> void:
	_controls_visible = value
	if _joystick:
		_joystick.visible = value
	for button in _action_buttons:
		button.visible = value
		if not value and button.is_pressed():
			Input.action_release(String(button.action))
	if not value:
		# 收起来的时候把方向 action 统一松开，免得手指正好按着、
		# 控件被收走之后留下一个永远松不开的方向
		for action in JOYSTICK_ACTIONS:
			if Input.is_action_pressed(action):
				Input.action_release(action)
	if _hint:
		_hint.visible = value and _show_hint()


func is_controls_visible() -> bool:
	return _controls_visible


## 当前这台机器算不算触摸设备
func is_touch_device() -> bool:
	return _has_touchscreen or _touched_once


# ---------------------------------------------------------------- 搭界面

func _build_joystick() -> void:
	# 引擎里没有 VirtualJoystick 的话（比如以后换版本了）不要让整个场景崩掉
	if not ClassDB.class_exists("VirtualJoystick"):
		push_warning("这个 Godot 版本没有 VirtualJoystick，触摸摇杆不会出现。")
		return
	_joystick = VirtualJoystick.new() as VirtualJoystick
	if _joystick == null:
		return
	_joystick.name = "VirtualJoystick"
	# DYNAMIC：手指按哪儿，摇杆底座就在哪儿冒出来，这是手机游戏最常见的手感
	_joystick.joystick_mode = VirtualJoystick.JOYSTICK_DYNAMIC
	# 只在摸的时候画：不摸就彻底看不见，不挡画面
	_joystick.visibility_mode = VirtualJoystick.VISIBILITY_WHEN_TOUCHED
	# 这里千万别设 IGNORE！VirtualJoystick 的接收逻辑在 _gui_input 里，
	# IGNORE 会让它整个跳过 GUI 输入，摇杆就永远不会响应（踩过一次）。
	# STOP 的代价可以接受：左半屏的触摸本来就不该传给底下的界面。
	_joystick.mouse_filter = Control.MOUSE_FILTER_STOP
	_joystick.joystick_size = joystick_size
	_joystick.tip_size = tip_size
	_joystick.deadzone_ratio = deadzone_ratio
	_joystick.clampzone_ratio = 1.0
	if ClassDB.class_has_method("VirtualJoystick", "set_actions"):
		_joystick.set_actions(JOYSTICK_ACTIONS[0], JOYSTICK_ACTIONS[1],
				JOYSTICK_ACTIONS[2], JOYSTICK_ACTIONS[3])
	else:
		_joystick.action_left = JOYSTICK_ACTIONS[0]
		_joystick.action_right = JOYSTICK_ACTIONS[1]
		_joystick.action_up = JOYSTICK_ACTIONS[2]
		_joystick.action_down = JOYSTICK_ACTIONS[3]
	add_child(_joystick)


func _build_action_buttons() -> void:
	var accept_tex := _load_textures(accept_textures, DEFAULT_ACCEPT_TEXTURES)
	var cancel_tex := _load_textures(cancel_textures, DEFAULT_CANCEL_TEXTURES)
	_action_buttons = [
		_create_action_button("AcceptButton", accept_action, accept_tex),
		_create_action_button("CancelButton", cancel_action, cancel_tex),
	]
	for button in _action_buttons:
		add_child(button)


func _create_action_button(button_name: String, action: StringName, textures: Array) -> TouchScreenButton:
	var button := TouchScreenButton.new()
	button.name = button_name
	button.action = String(action)
	# 按键的显示由我们统一管（跟摇杆一起切），
	# 不用 VISIBILITY_TOUCHSCREEN_ONLY：那个只认 DisplayServer 的判断，桌面上没法测
	button.visibility_mode = TouchScreenButton.VISIBILITY_ALWAYS
	if textures.size() >= 1:
		button.texture_normal = textures[0]
	if textures.size() >= 2:
		button.texture_pressed = textures[1]
	return button


func _build_hint() -> void:
	_hint = Control.new()
	_hint.name = "Hint"
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.visible = false
	_hint.draw.connect(_draw_hint)
	add_child(_hint)


## 从导出的路径加载贴图；路径空着或者加载失败就用默认的两张
func _load_textures(custom: PackedStringArray, fallback: Array) -> Array:
	var out: Array = []
	for path in custom:
		var loaded := ResourceLoader.load(path)
		if loaded is Texture2D:
			out.append(loaded)
	if out.size() < 2:
		out.clear()
		for path in fallback:
			out.append(ResourceLoader.load(path))
	return out


# ---------------------------------------------------------------- 布局 / 绘制

func _refresh_layout() -> void:
	var size := _canvas_size()
	if size == Vector2.ZERO:
		# 窗口还没就绪也会走到这儿；下个 _process 自然会再来一次
		return
	if size == _last_size:
		return
	_last_size = size
	# 先算好功能键的位置，摇杆的触摸区域要避开它们
	var accept_button := _action_buttons[0] if _action_buttons.size() >= 2 else null
	var cancel_button := _action_buttons[1] if _action_buttons.size() >= 2 else null
	var accept_size := _button_draw_size(accept_button)
	var cancel_size := _button_draw_size(cancel_button)
	if accept_button:
		# TouchScreenButton 是 Node2D（不是 Control），只能给绝对坐标，
		# 所以按画布尺寸自己算右下角
		accept_button.position = Vector2(
				size.x - buttons_margin.x - accept_size.x,
				size.y - buttons_margin.y - accept_size.y)
		cancel_button.position = Vector2(
				accept_button.position.x - buttons_gap - cancel_size.x,
				size.y - buttons_margin.y - cancel_size.y)

	# 摇杆的活动范围：整屏都行，但功能键那一带要让出来。
	# DYNAMIC 模式的命中判定是拿控件矩形算的，所以缩矩形 = 缩响应范围。
	var zone_height := size.y
	if accept_button:
		# 按键那一条（从最上面那个按键的顶边往下）留给按键
		zone_height = clampf(accept_button.position.y, 1.0, size.y)
	_joystick_rect = Rect2(Vector2.ZERO,
			Vector2(size.x * joystick_width_ratio, zone_height))
	if _joystick:
		_joystick.position = _joystick_rect.position
		_joystick.size = _joystick_rect.size
	if _hint:
		_hint.size = size
		_hint.queue_redraw()


## 画布尺寸（这个工程是 640x480）。
##
## 关于坐标系：平台的触摸事件是窗口坐标，但引擎在 Input / GUI 里就按拉伸比例
## 换算回画布坐标了，Control 和 TouchScreenButton 的命中判定用的都是画布坐标。
## 所以这里（以及 _draw_hint）统一用画布坐标，窗口是 1x 还是 2x 都不用管。
func _canvas_size() -> Vector2:
	return get_viewport().get_visible_rect().size


func _button_draw_size(button: TouchScreenButton) -> Vector2:
	if button and button.texture_normal:
		return button.texture_normal.get_size() * button.scale
	return Vector2(22, 33)


func _draw_hint() -> void:
	if _last_size == Vector2.ZERO:
		return
	var center := Vector2(_last_size.x * 0.16, _last_size.y * 0.82)
	var radius := joystick_size * 0.5
	_hint.draw_arc(center, radius, 0.0, TAU, 40, Color(1, 1, 1, 0.16), 2.0, true)
	_hint.draw_circle(center, tip_size * 0.5, Color(1, 1, 1, 0.10))
	var reach := radius + 6.0
	for dir in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		_hint.draw_line(center + dir * (radius * 0.35), center + dir * reach,
				Color(1, 1, 1, 0.16), 2.0, true)


# ---------------------------------------------------------------- 内部判定

func _should_show() -> bool:
	match visibility_mode:
		VisMode.ALWAYS:
			return true
		VisMode.NEVER:
			return false
		_:
			return is_touch_device()


func _show_hint() -> bool:
	if not show_desktop_hint:
		return false
	# 真机有触摸屏的话，玩家自己就知道该怎么按，不用提示
	return not _has_touchscreen


func _touchscreen_available() -> bool:
	return DisplayServer.has_feature(DisplayServer.FEATURE_TOUCHSCREEN) \
			and DisplayServer.is_touchscreen_available()
