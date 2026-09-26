extends Level1EnemyTurnManager
var sin_speed:float=120

const ROUND_7_BULLET = preload("uid://cas06lfdkcj87")

var pos1=Vector2(230,40)
var pos2=Vector2(410,40)
var distance=50
var rad:float=0
var process:int=0
var fan_count:int=32
func start():
	
	move_soul(Vector2(320,360))
	set_battleframe_polygon_trans([Vector2(180, 280), Vector2(460, 280), Vector2(460, 440), Vector2(180, 440)])
	await wait(2)

	generate_circle_bullet()
	await wait(1)
	generate_fan_bullet()
	
	
	
func generate_fan_bullet():
	var interval:float=PI/fan_count
	
	for i in range(3):
		for j in range(-1,2,2):
			for k in range(fan_count):
				for l in range(2):
					var a=spawn_base_bullet(pos1,Vector2.LEFT.rotated(rad),100*(l+1))
					a.scale*=0.5
					a=spawn_base_bullet(pos2,Vector2.RIGHT.rotated(-rad),100*(l+1))
					a.scale*=0.5
				rad+=PI/fan_count*j
				self_play_sound(SE_TAN_00,0,-6)
				await wait(0.06)
			rad+=0.05
func generate_circle_bullet():
	
	var bullet_interval=TAU/16
	for i in range(112):
		var speed:float=200
		for k in range(16):
			spawn_7_bullet(pos1,Vector2.RIGHT.rotated(bullet_interval*k+bullet_interval/2.5),speed,true)
			spawn_7_bullet(pos2,Vector2.RIGHT.rotated(bullet_interval*k-bullet_interval/2.5),speed,false)
		play_sound(SE_TAN_00,0,-6)
		await wait(0.12)
	await wait(2)
	end()
	
func spawn_7_bullet(pos,direction,speed,to_right:bool=true,ofspeed:float=1):
	var bullet = ROUND_7_BULLET.instantiate() as BaseBullet
	bullet.position = pos
	bullet.manager=self
	bullet.direction=direction
	bullet.speed=speed
	bullet.to_right=to_right
	bullet.offset_speed=ofspeed
	add_child(bullet)
	bullets.append(bullet)
	return bullet
