extends PanelContainer
class_name PlayerStatusPanel
@export var player_status:PlayerStatus
@export var hp_progress_bar: TextureProgressBar 
@export var hp_text: Label
@export var id_label: Label
func init() -> void:
	player_status.changed.connect(_update_hp_bar)
	_update_hp_bar()
	id_label.text=player_status.id+" lv"+str(player_status.LOVE)
	reset_size()

func _update_hp_bar():
	hp_progress_bar.custom_minimum_size=Vector2(player_status.max_hp*1.2,20)
	hp_progress_bar.max_value=player_status.max_hp
	hp_progress_bar.value=player_status.hp
	hp_text.text=String.num(player_status.hp,0)+" / "+String.num(player_status.max_hp,0)
