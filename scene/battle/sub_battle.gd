extends BattleManager
class_name SubBattleManager
var battle_scene:PackedScene
func _ready() -> void:
	super._ready()
	dialog_panel.finished.disconnect(enemy_turn_bullet)

func _display_button(hide:bool=false):
	pass
