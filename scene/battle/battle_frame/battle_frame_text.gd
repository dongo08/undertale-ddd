extends Control
class_name BattleFrameText

@export var description: TypewriterLabel
@export var master: BattleManager
@export var choices: ChooseGrid


signal finished()

func _ready() -> void:
	choices.hide()
	description.typing_end.connect(_on_description_finished)

func show_dialog(dialogs: Array[BaseDialog]):
	choices.hide()
	description.show_dialog(dialogs)

func _on_description_finished():
	finished.emit()

func skip():
	description.skip()

func show_enemy_choose():
	description.hide()
	choices.show()
	for i in range(4):
		if master.battle_data.enemys.size() > i:
			choices.choices[i].text = master.battle_data.enemys[i].id
		else:
			choices.choices[i].text = ""

func get_choice_position(index: int):
	return choices.choices[index].global_position

func show_choose(type:BattleManager.Choice):
	description.hide()
	choices.show()
	match type:
		BattleManager.Choice.ENEMY:
			for i in range(4):
				if master.battle_data.enemys.size() > i:
					choices.choices[i].text = master.battle_data.enemys[i].id
				else:
					choices.choices[i].text = ""
		BattleManager.Choice.ACT:
			for i in range(4):
				if i==0:
					choices.choices[i].text ="查看"
				else:
					choices.choices[i].text = ""
		BattleManager.Choice.ITEM:
			var page=master.page_index
			for i in range(4):
				if master.battle_data.player_status.backpack.size() > i and master.battle_data.player_status.backpack[i]:
					choices.choices[i].text = master.battle_data.player_status.backpack[i].id
				else:
					choices.choices[i].text = ""
		BattleManager.Choice.MERCY:
			for i in range(4):
				if i==0:
					choices.choices[i].text ="跳过本回合"
				else:
					choices.choices[i].text = ""

func hide_all():
	choices.hide()
	description.hide()
