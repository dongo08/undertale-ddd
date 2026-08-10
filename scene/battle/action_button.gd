extends TextureRect
class_name BattleActionButton
enum Type{
	FIGHT,
	ACT,
	ITEM,
	MERCY
}
@export var type:Type

signal action_selected(type:Type)
signal action_focused(type:Type)

func _gui_input(event: InputEvent) -> void:
	if event.is_action_pressed("accept"):
		action_selected.emit(type)
