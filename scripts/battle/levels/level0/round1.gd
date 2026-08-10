extends Level1EnemyTurnManager
var sin_speed:float=120


func start():
	
	move_soul(Vector2(320,360))
	set_battleframe_polygon_trans([Vector2(240, 280), Vector2(400, 280), Vector2(400, 440), Vector2(240, 440)])
	await wait(1)
	spawn_circle_fireball_group(4,2.5,true)
	await wait(4.5)
	spawn_circle_fireball_group(4,4.5)
	await wait(4)
	spawn_circle_fireball_group(4,3.5,true)
	await wait(0.9)
	spawn_circle_fireball_group(4,3)
	await wait(0.9)
	spawn_circle_fireball_group(4,2.5,true)
	await wait(4.5)
	end()
	
