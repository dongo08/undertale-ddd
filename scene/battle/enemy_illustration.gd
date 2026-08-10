extends Sprite2D
class_name EnemyIllustration
@export var illustrations:Array[Texture2D]

func change_illustration(index:int):
	texture=illustrations[index]
