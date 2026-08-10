extends BaseEnemyTurnManager
class_name Level1EnemyTurnManager
const SINE_BULLET = preload("uid://bqntyeeuobyrw")
const NORMAL_BULLET = preload("uid://dxgxljpu0tv8e")
const CIRCLE_FIREBALL_GROUP = preload("uid://c8a60i6no477r")




func spawn_sin_bullet(pos: Vector2,
						speed: float = 300,
						move_right: bool = true,
						scale1:Vector2=Vector2.ONE,
						period:float=4,
						amplitude: float = 200.0,
						center_x:float=320):
	var bullet = SINE_BULLET.instantiate() as SineBullet
	bullet.position = pos
	bullet.scale=scale1
	bullet.move_right = move_right
	bullet.speed = speed
	bullet.amplitude = amplitude
	add_child(bullet)
	bullet.manager = self
	bullets.append(bullet)
	return bullet
	
func spawn_base_bullet(pos: Vector2, direction: Vector2, speed: float = 300,lifetime:float=16):
	var bullet = NORMAL_BULLET.instantiate() as NormalBullet
	bullet.position = pos
	bullet.manager=self
	bullet.direction=direction
	bullet.speed=speed
	bullet.lifetime=lifetime
	add_child(bullet)
	bullets.append(bullet)
	return bullet

func spawn_circle_fireball_group(amount:int=4,rotate_v:float=3,anti:bool=false):
	var group=CIRCLE_FIREBALL_GROUP.instantiate()
	group.amount=amount
	group.rotate_v=rotate_v
	group.anti=anti
	group.explode.connect(fireball_group_exploded)
	add_child(group)
	bullets.append_array(group.bullets)
	return group
	
func fireball_group_exploded(pos:Vector2,rad:float):
	play_sound(SE_TAN_00)
	for i in range(12):
		var bullet=spawn_base_bullet(pos,Vector2.UP.rotated(TAU/12*i+rad))
		bullet.rotate(rad)
		bullet.scale*=0.5
