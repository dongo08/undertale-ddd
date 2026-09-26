extends PanelContainer
class_name DialogPanel

@export var dialog_label: TypewriterLabel

signal finished()
signal dialog_processed(index:int)
signal single_dialog_end(index:int)
## 即将显示的这句对话，转发给立绘节点用来切换表情。
signal dialog_started(dialog: BaseDialog)

func _ready() -> void:
	hide()
	if dialog_label == null:
		push_warning("%s 没有接 dialog_label，这个对话面板用不了。" % name)
		return
	dialog_label.typing_end.connect(_on_dialog_finished)
	dialog_label.dialog_processed.connect(_on_dialog_processed)
	dialog_label.single_dialog_end.connect(_on_single_dialog_end)
	dialog_label.dialog_started.connect(_on_dialog_started)

func show_dialog(dialogs: Array[BaseDialog]):
	if dialog_label == null:
		push_warning("%s 没有接 dialog_label，没法显示对话。" % name)
		return
	dialog_label.show_dialog(dialogs)
	show()

func close():
	if dialog_label:
		dialog_label.close()
	hide()

func _on_dialog_finished():
	# 先收起来再发信号：导演可能在这个信号里立刻在这块面板上开下一批对话，
	# 收尾的 hide() 要是排在后面就会把刚开的那段藏掉
	hide()
	finished.emit()

func _on_dialog_processed(index:int):
	dialog_processed.emit(index)
func _on_single_dialog_end(index:int):
	single_dialog_end.emit(index)
func _on_dialog_started(dialog: BaseDialog):
	dialog_started.emit(dialog)
