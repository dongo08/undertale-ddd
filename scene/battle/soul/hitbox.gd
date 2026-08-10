extends Area2D
class_name HitBox

@export var master:CharacterBody2D

signal apply_damage(damage:float)

var hit_bullets:Array[BaseBullet]


	

func _process(delta: float) -> void:
	_check_bullet()
	
func _check_bullet():
	var nbullet:BaseBullet
	var bbullet:BaseBullet
	var obullet:BaseBullet
	var is_move:bool
	var damage:float
	if hit_bullets.is_empty():return
	for i in hit_bullets:
		if i.type==BaseBullet.Type.RED:
			apply_damage.emit(99999999)
			return
		elif i.type==BaseBullet.Type.NORMAL:
			if !(nbullet and nbullet.damage>=i.damage):
				nbullet=i
		elif i.type==BaseBullet.Type.ORANGE:
			if !(obullet and obullet.damage>=i.damage):
				obullet=i
		elif i.type==BaseBullet.Type.BLUE:
			if !(bbullet and bbullet.damage>=i.damage):
				bbullet=i
	if master:
		if master.get_real_velocity().length()>0.01:
			is_move=true
	if nbullet:
		damage=nbullet.damage
	if obullet and !is_move and obullet.damage>damage:
		damage=obullet.damage
	if bbullet and is_move and bbullet.damage>damage:
		damage=bbullet.damage
	if damage>0:
		apply_damage.emit(damage)

func _on_area_entered(area: Area2D) -> void:
	if area is BaseBullet:
		hit_bullets.append(area)


func _on_area_exited(area: Area2D) -> void:
	hit_bullets.erase(area)
