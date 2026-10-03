extends BaseBullet


@export var direction:Vector2=Vector2.DOWN
@export var speed:float=300




func _physics_process(delta: float) -> void:
	position+=direction*speed*delta
