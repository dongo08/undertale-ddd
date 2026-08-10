extends SubBattleManager
@onready var color_rect: ColorRect = $CanvasLayer/ColorRect



@export var dialog1:Array[BaseDialog]
@export var dialog2:Array[BaseDialog]
func _ready() -> void:
	#await get_tree().create_timer(2).timeout
	_hide_soul()
	super._ready()
	while color_rect.color.a>0:
		color_rect.color.a-=0.01
		await get_tree().physics_frame
	dialog_panel.dialog_processed.connect(change_i)
	ResourceLoader.load_threaded_request("res://scene/battle/levels/level1/level1.tscn")
	await dialog_panel.finished
	battle_frame_text.show_dialog(dialog1)
	await battle_frame_text.finished
	battle_frame_text.hide_all()
	dialog_panel.show_dialog(dialog2)
	dialog_panel.dialog_processed.connect(change_scene)
	
func change_scene(index:int):
	if index==2:
		battle_scene=ResourceLoader.load_threaded_get("res://scene/battle/levels/level1/level1.tscn")
		BGM.play(preload("uid://cebhob2kiur6x"))
		Global.change_scene_to_packed(battle_scene)
		
func change_i(idx:int):
	match idx:
		1:
			enemy_illustration.change_illustration(1)
		3:
			enemy_illustration.change_illustration(0)
		5:
			enemy_illustration.change_illustration(3)
		6:
			enemy_illustration.change_illustration(2)
		8:
			enemy_illustration.change_illustration(3)
		9:
			enemy_illustration.change_illustration(2)
		10:
			enemy_illustration.change_illustration(0)
