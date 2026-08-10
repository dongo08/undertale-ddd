extends PanelContainer
class_name DialogPanel

@export var dialog_label: TypewriterLabel

signal finished()
signal dialog_processed(index:int)
signal single_dialog_end(index:int)

func _ready() -> void:
	hide()
	dialog_label.typing_end.connect(_on_dialog_finished)
	dialog_label.dialog_processed.connect(_on_dialog_processed)
	dialog_label.single_dialog_end.connect(_on_single_dialog_end)

func show_dialog(dialogs: Array[BaseDialog]):
	dialog_label.show_dialog(dialogs)
	show()

func close():
	dialog_label.close()
	hide()

func _on_dialog_finished():
	finished.emit()
	hide()

func _on_dialog_processed(index:int):
	dialog_processed.emit(index)
func _on_single_dialog_end(index:int):
	single_dialog_end.emit(index)
