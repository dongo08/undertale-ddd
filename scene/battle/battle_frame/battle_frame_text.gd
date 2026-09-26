extends Control
class_name BattleFrameText

@export var description: TypewriterLabel
@export var master: BattleManager
@export var choices: ChooseGrid


signal finished()
## 即将显示的这句对话，转发给立绘节点用来切换表情。
signal dialog_started(dialog: BaseDialog)

func _ready() -> void:
	choices.hide()
	description.typing_end.connect(_on_description_finished)
	description.dialog_started.connect(_on_description_dialog_started)

func show_dialog(dialogs: Array[BaseDialog]):
	choices.hide()
	description.show_dialog(dialogs)

func _on_description_finished():
	finished.emit()
func _on_description_dialog_started(dialog: BaseDialog):
	dialog_started.emit(dialog)

func skip():
	description.skip()


func get_choice_position(index: int):
	return choices.choices[index].global_position

func show_choose(type:BattleManager.Choice):
	description.hide()
	choices.show()
	match type:
		BattleManager.Choice.ENEMY:
			# 只列活着的敌人（死掉的不占格子，后面的往上顶）
			var selectable:=master.selectable_enemies
			for i in choices.choices.size():
				var enemy:EnemyStatus=null
				if i<selectable.size():
					enemy=master.enemy_at(selectable[i])
				choices.choices[i].text = ("* "+enemy.id) if enemy else ""
		BattleManager.Choice.ACT:
			# 第一个固定是“查看”，后面是这个敌人自己的 ACT
			var acts:=master.act_list_for(master.act_enemy_index)
			for i in choices.choices.size():
				choices.choices[i].text = ("* "+acts[i]) if i<acts.size() else ""
		BattleManager.Choice.ITEM:
			var page:=master.page_index
			for i in range(4):
				var idx:int=i+page*4
				if master.battle_data.player_status.backpack.size() > idx and master.battle_data.player_status.backpack[idx]:
					choices.choices[i].text ="* "+ tr(master.battle_data.player_status.backpack[idx].id)
				else:
					choices.choices[i].text = ""
			choices.choices.back().text="  第 "+str(page+1)+" 页"
		BattleManager.Choice.MERCY:
			for i in choices.choices.size():
				if i==0:
					choices.choices[i].text ="* "+"跳过本回合"
				else:
					choices.choices[i].text = ""

func hide_all():
	choices.hide()
	description.hide()
