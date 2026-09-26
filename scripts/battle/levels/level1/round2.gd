extends Level1EnemyTurnManager
var sin_speed:float=120

const ROUND_2_BULLET = preload("uid://dphe4qnwkf38j")
var pos=Vector2(320,150)
var distance=50
var rad:float=0
var process:int=0
var f=false

func start():
	
	move_soul(Vector2(320,360))
	set_battleframe_polygon_trans([Vector2(180, 280), Vector2(460, 280), Vector2(460, 440), Vector2(180, 440)])
	await wait(1)
	f=true
	generate_circle_bullet()
	
	
	
func _physics_process(delta: float) -> void:
	if f:
		process+=1
		rad+=delta*-3.72
		if process%3==0:
			var bullet=spawn_base_bullet(pos+Vector2.RIGHT.rotated(rad)*distance,Vector2.RIGHT.rotated(rad+PI/2),100,5)
			bullet.scale*=0.5
			var bullet2=spawn_base_bullet(pos+Vector2.RIGHT.rotated(rad)*distance,Vector2.RIGHT.rotated(rad),100,5)
			bullet2.scale*=0.5
			var bullet3=spawn_base_bullet(pos+Vector2.RIGHT.rotated(rad-PI)*distance,Vector2.RIGHT.rotated(rad-PI+PI/2),100,5)
			bullet3.scale*=0.5
			var bullet4=spawn_base_bullet(pos+Vector2.RIGHT.rotated(rad-PI)*distance,Vector2.RIGHT.rotated(rad-PI),100,5)
			bullet4.scale*=0.5
			self_play_sound(SE_TAN_00,0,-6)
func generate_circle_bullet():
	
	var bullet_interval=TAU/16
	for i in range(2):
		for j in range(24):
			var speed:float=300
			for k in range(16):
				spawn_2_bullet(pos,Vector2.RIGHT.rotated(bullet_interval*k),speed+i*100,i,0.7 if i else 1)
			if j%2:
				play_sound(SE_TAN_00)
			await wait(0.1)
		await wait(0.8)
	for j in range(24):
		var speed:float=300
		for k in range(16):
			spawn_2_bullet(pos,Vector2.RIGHT.rotated(bullet_interval*k-bullet_interval),speed+100,true)
			spawn_2_bullet(pos,Vector2.RIGHT.rotated(bullet_interval*k+bullet_interval),speed,false)
		if j%2:
			play_sound(SE_TAN_00)
		await wait(0.1)
	f=false
	await wait(2)
	end()
	
func spawn_2_bullet(pos,direction,speed,to_right:bool=true,ofspeed:float=1):
	var bullet = ROUND_2_BULLET.instantiate() as BaseBullet
	bullet.position = pos
	bullet.manager=self
	bullet.direction=direction
	bullet.speed=speed
	bullet.to_right=to_right
	bullet.offset_speed=ofspeed
	add_child(bullet)
	bullets.append(bullet)
	return bullet
