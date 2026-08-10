extends EnemyIllustration


func _on_control_round_start(index: int) -> void:
	if index==10:
		change_illustration(2)
	else:
		change_illustration(0)




func _on_control_enemy_round_start(index: int) -> void:
	if index==7:
		change_illustration(1)
	elif index==10:
		change_illustration(2)

func _on_control_round_end(index: int) -> void:
	if index==10:
		change_illustration(3)
