extends BaseBullet


var offset:float=0
@export var to_right:bool=true
var offset_speed:float=1
var direction:Vector2=Vector2.DOWN
var speed:float=300
var off_v=0.08
func _physics_process(delta: float) -> void:
	offset+=delta*off_v*speed*offset_speed
	off_v=max(0,off_v*0.981)
	position+=(direction*speed+Vector2.DOWN.rotated(offset*(-1 if to_right else 1))*speed*25*off_v)*delta
	#direction=direction.rotated(sin(offset)**3*(-1 if to_right else 1)*delta)
	rotation=direction.rotated(offset*(-1 if to_right else 1)).angle()
	super._physics_process(delta)
