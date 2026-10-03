extends BaseDialog
class_name ExpressionDialog

## 这一句对话要切换到的立绘表情名字（对应表情表里的键）。
## 留空表示这一句不动立绘，沿用上一句的表情。
@export var expression: StringName = &""

## 这句话是第几个敌人说的：对应 DialogDirector.panels 的下标，
## 也就是 battle_data.enemys 的下标。单敌人场景保持 0 就行。
@export var enemy_index: int = 0
