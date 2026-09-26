extends Resource
class_name EnemyAct

## 敌人身上的一个 ACT 选项（每个敌人可以有自己的 ACT 列表）。
## ACT 列表里永远先显示“查看”，这里的选项排在它后面。

## 列表里显示的名字
@export var act_name: String = ""
## 选了这个选项之后显示在战斗文本框里的内容，留空就什么都不显示
@export var dialog: BaseDialog
