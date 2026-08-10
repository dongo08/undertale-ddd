extends BaseBullet


var offset:float=0
@export var to_right:bool=true
var offset_speed:float=1
var direction:Vector2
var speed:float

func _physics_process(delta: float) -> void:
	offset+=delta*0.018*speed*offset_speed
	position+=(direction*speed+direction.rotated(offset*(-1 if to_right else 1))*100)*delta
	#direction=direction.rotated(sin(offset)**3*(-1 if to_right else 1)*delta)
	rotation=direction.rotated(offset*(-1 if to_right else 1)).angle()
	super._physics_process(delta)
