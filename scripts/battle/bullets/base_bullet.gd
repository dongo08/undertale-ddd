extends Area2D
class_name BaseBullet

enum Type{
	NORMAL,
	BLUE,
	ORANGE,
	RED
}

@export var damage:float=2
@export var lifetime:float=16
@export var type:Type
var manager: BaseEnemyTurnManager

func _physics_process(delta: float) -> void:
	lifetime-=delta
	if lifetime<0:
		queue_free()
