extends BattleManager

@export var m:GDScript
func _ready() -> void:
	set_process_input(false)
	var enemy_turn_manager=m.new() as BaseEnemyTurnManager
	enemy_turn_manager.master=self
	#enemy_turn_manager.finished.connect(enemy_turn_finished)
	add_child(enemy_turn_manager)
	enemy_turn_manager.start()
	#$WindowsFileSystem.start_hover_tracking()

func _on_windows_file_system_hover_file_changed(hover: Dictionary) -> void:
	print(hover)

#
#func _on_timer_timeout() -> void:
	#print($WindowsFileSystem.get_file_under_mouse())
