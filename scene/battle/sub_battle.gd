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
	if dialog_director:
		dialog_director.finished.disconnect(enemy_turn_bullet)

func _encounter():
	#return
	black.show()
	encounter_player.play()
	# 音频播完是真实时间，不能拿来当计时器：按音频长度等固定 tick（声音照放）
	var encounter_length := 0.0
	if encounter_player.stream:
		encounter_length = encounter_player.stream.get_length()
	await BattleClock.wait_seconds(encounter_length)
	_encounter_tween=create_tween()
	_encounter_tween.tween_property(black,"modulate:a",0,1)
	# 淡入只是画面；流程等 tick，不能等 tween（tween 的起点会落在两帧之间）
	await BattleClock.wait_seconds(1)


func _display_button(hide:bool=false):
	pass
