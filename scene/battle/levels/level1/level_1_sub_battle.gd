extends SubBattleManager


@export var dialog1:Array[BaseDialog]
@export var dialog2:Array[BaseDialog]
func _ready() -> void:
	#await get_tree().create_timer(2).timeout
	_hide_soul()
	BattleReplay.begin_battle("res://scene/battle/levels/level1/level1_sub_battle.tscn")
	super._ready()
	ResourceLoader.load_threaded_request("res://scene/battle/levels/level1/level1.tscn")
	await dialog_director.finished
	battle_frame_text.show_dialog(dialog1)
	await battle_frame_text.finished
	battle_frame_text.hide_all()
	dialog_director.play(dialog2)
	dialog_director.main_panel().dialog_processed.connect(change_scene)
	
func change_scene(index:int):
	if index==2:
		battle_scene=ResourceLoader.load_threaded_get("res://scene/battle/levels/level1/level1.tscn")
		BGM.play(preload("uid://cebhob2kiur6x"))
		Global.change_scene_to_packed(battle_scene)
		
# 立绘表情不再需要手写映射：round 的 dialog_list 和 dialog2 里的 ExpressionDialog 自带表情，
# Toriel 立绘节点绑定自己的对话框后会自动切换（见 scene/battle/enemy_illustration.gd）。
