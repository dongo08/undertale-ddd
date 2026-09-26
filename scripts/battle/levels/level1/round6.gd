extends Level1EnemyTurnManager
var sin_speed:float=120
const EYE_BULLET = preload("uid://dldd71h5h11td")
var center_pos:Vector2=Vector2(320,360)
var x_dist:float=220

func start():
	
	move_soul(Vector2(320,360))
	set_battleframe_polygon_trans([Vector2(240, 280), Vector2(400, 280), Vector2(400, 440), Vector2(240, 440)])
	await wait(1)
	_generate_eye_fireball()
	await wait(2)
	_generate_eye_fireball_end()
	await _generate_round_fireball()
	end()
	
func _generate_round_fireball():
	spawn_circle_fireball_group(8,2.5,true)
	await wait(2)
	spawn_circle_fireball_group(8,4.5)
	await wait(2)
	spawn_circle_fireball_group(8,3.5,true)
	await wait(0.9)
	spawn_circle_fireball_group(8,3)
	await wait(0.9)
	spawn_circle_fireball_group(8,3)
	await wait(0.5)
	spawn_circle_fireball_group(8,2.5,true)
	await wait(4.5)

func _generate_eye_fireball():
	while true:
		spawn_eye_bullet(true,true)
		spawn_eye_bullet(false,true)
		spawn_eye_bullet(true,false)
		spawn_eye_bullet(false,false)
		self_play_sound(SE_TAN_00,0,-12)
		await wait(0.1)
func _generate_eye_fireball_end():
	while true:
		spawn_base_bullet(center_pos+Vector2(x_dist,0),Vector2.RIGHT.rotated(0.9),300,2)
		spawn_base_bullet(center_pos+Vector2(x_dist,0),Vector2.RIGHT.rotated(0.4),300,2)
		spawn_base_bullet(center_pos+Vector2(x_dist,0),Vector2.RIGHT.rotated(-0.4),300,2)
		spawn_base_bullet(center_pos+Vector2(x_dist,0),Vector2.RIGHT.rotated(-0.9),300,2)
		spawn_base_bullet(center_pos+Vector2(x_dist,0),Vector2.RIGHT.rotated(-0.1),300,2)
		spawn_base_bullet(center_pos+Vector2(-x_dist,0),Vector2.LEFT.rotated(0.9),300,2)
		spawn_base_bullet(center_pos+Vector2(-x_dist,0),Vector2.LEFT.rotated(0.4),300,2)
		spawn_base_bullet(center_pos+Vector2(-x_dist,0),Vector2.LEFT.rotated(-0.1),300,2)
		spawn_base_bullet(center_pos+Vector2(-x_dist,0),Vector2.LEFT.rotated(-0.4),300,2)
		spawn_base_bullet(center_pos+Vector2(-x_dist,0),Vector2.LEFT.rotated(-0.9),300,2)
		await wait(0.1)


	

func spawn_eye_bullet(is_up:bool,strength:bool):
	var bullet=EYE_BULLET.instantiate() 
	bullet.is_up=is_up
	bullet.strength=strength
	add_child(bullet)
