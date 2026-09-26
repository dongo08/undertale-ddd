extends Resource
class_name EnemyStatus
@export var id:String="1"
@export var max_hp:float=1000
@export var hp:float=1000
@export var defense:float=100
@export var attack:float=100
@export var descriptive_attack:String="100"
@export var descriptive_defense:String="100"
@export var description:String="是一个一个"
@export var invincible:bool=false
## 这个敌人自己的 ACT 选项（“查看”由代码固定放第一个，不用写在这里）
@export var acts:Array[EnemyAct]=[]
