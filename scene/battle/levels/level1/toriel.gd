extends EnemyIllustration

## 立绘表情由表情表资源（resource/portraits/toriel_expressions.tres）里的“表情 -> 图片”决定，
## 这里只负责按回合切换表情，不再按下标切图。
## 括号内是迁移前的 illustrations 下标，方便对照。

func _on_control_round_start(index: int) -> void:
	if index==10:
		change_expression(ExpressionSet.WORRIED) # 原下标 2
	else:
		change_expression(ExpressionSet.NORMAL) # 原下标 0





func _on_control_enemy_round_start(index: int) -> void:
	if index==7:
		change_expression(ExpressionSet.EYES_CLOSED) # 原下标 1
	elif index==10:
		change_expression(ExpressionSet.WORRIED) # 原下标 2

func _on_control_round_end(index: int) -> void:
	if index==10:
		change_expression(ExpressionSet.DEFEATED) # 原下标 3
