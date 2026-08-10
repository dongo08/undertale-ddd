extends AnimatedSprite2D
class_name AttackCursor

signal attack(factor:float,best:bool)
signal miss()
@export var speed:float=300
var state:int=0
func _ready() -> void:
	set_physics_process(false)
	pause()
	hide()

func start(posx:int=640):
	position=Vector2(posx,356)
	show()
	stop()
	state=0
	set_physics_process(true)
	

func _physics_process(delta: float) -> void:
	if state==0:
		position.x-=speed*delta
		self_modulate.a=min((320-abs(position.x-320))/100,1)
		if position.x<20:
			miss.emit()
			state=1
			
		

func effect():
	if abs(position.x-320)<=8:
		position.x=320
		attack.emit(1,true)
	else:
		attack.emit((400-abs(position.x-320))/400,false)
	play("default")
	self_modulate.a=1
	state=1

func end():
	pause()
	hide()
	set_physics_process(false)
