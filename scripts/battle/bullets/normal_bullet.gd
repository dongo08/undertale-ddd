extends BaseBullet
class_name NormalBullet


@export var direction:Vector2=Vector2.DOWN
@export var speed:float=300




func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	position+=direction*speed*delta
