extends Resource
class_name EnemyRound
## 一轮敌人的对话。元素可以是单句（默认第 0 个敌人说的），
## 也可以是 DialogBatch（一批同时说的对话，里面每句自己指定敌人）。
@export var dialog_list:Array[BaseDialog]
@export var battleframe_text:BaseDialog
@export var manager:GDScript
