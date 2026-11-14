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
@export var autofree:bool=true
@export var can_destory:bool=false
var manager: BaseEnemyTurnManager

func _physics_process(delta: float) -> void:
	lifetime-=delta
	if lifetime<0:
		queue_free()
	if autofree:
		var texture:Sprite2D
		for i in get_children():
			if i is Sprite2D:
				texture=i
				break
		if !(Rect2(position+texture.get_rect().position,texture.get_rect().size)).intersects(get_tree().root.get_visible_rect()):
			clear()

func disable_collision():
	for i in get_children():
		if i is CollisionShape2D:
			i.disabled=true

func destroy():
	disable_collision()
	set_physics_process(false)
	await destroy_animate()
	clear()
	
func destroy_animate():
	pass
	
	
func clear():
	queue_free()
