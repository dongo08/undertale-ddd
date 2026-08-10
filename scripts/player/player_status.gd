extends Resource
class_name PlayerStatus
@export var id:String="Chara"
@export var LOVE:int=1
@export var max_hp:int=20
@export var hp:int=20:
	set(value):
		hp=value
		emit_changed()
@export var attack:float=1500
@export var backpack:Array[Item]
