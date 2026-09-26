extends BattleManager
class_name SubBattleManager
var battle_scene:PackedScene
@export var encounter_player: AudioStreamPlayer
@export var black: ColorRect
var _encounter_tween:Tween
func _ready() -> void:
	soul.player_status=battle_data.player_status
	player_status.player_status=battle_data.player_status
	player_status.init()
	battle_frame_text.hide_all()
	_hide_soul()
	set_process_input(false)
	await _encounter()
	set_process_input(true)
	super._ready()
	dialog_finished.disconnect(enemy_turn_bullet)

func _encounter():
	#return
	black.show()
	encounter_player.play()
	await encounter_player.finished
	_encounter_tween=create_tween()
	_encounter_tween.tween_property(black,"modulate:a",0,1)
	await _encounter_tween.finished


func _display_button(hide:bool=false):
	pass
