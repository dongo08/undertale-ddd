extends CanvasLayer

@onready var control: Control = $Control
@onready var control_2: Control = $Control2

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		# 摸到屏幕就算数：有些设备 / 导出配置下 is_touchscreen_available() 会骗人
		control.show()
		return
	
	if event is InputEventKey or event is InputEventJoypadButton \
			or event is InputEventJoypadMotion:
		control.hide()
		control_2.hide()
