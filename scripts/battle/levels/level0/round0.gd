extends Level1EnemyTurnManager
var sin_speed:float=120


func start():
	
	move_soul(Vector2(320,360))
	set_battleframe_polygon_trans([Vector2(200, 260), Vector2(440, 260), Vector2(440, 440), Vector2(200, 440)])
	await wait(1)
	generate_sine_bullet()
	generate_circle_bullet()
	
	
	
func generate_sine_bullet():
	var tween=create_tween()
	tween.tween_property(self,"sin_speed",200,0.5)
	tween.tween_property(self,"sin_speed",60,1)
	tween.tween_property(self,"sin_speed",200,1)
	tween.tween_property(self,"sin_speed",60,1)
	tween.tween_property(self,"sin_speed",150,1)
	var emit_pos=Vector2(340,30)
	for i in range(40):
		spawn_sin_bullet(emit_pos,sin_speed,false,Vector2.ONE,5)
		spawn_sin_bullet(Vector2(300,30),sin_speed+20,true,Vector2.ONE,5)
		await get_tree().create_timer(0.1).timeout
	await get_tree().create_timer(3).timeout
	end()
func generate_circle_bullet():
	await wait(1)
	var pos=Vector2(320,150)
	var bullet_interval=TAU/8
	for i in range(2):
		var speed:float=100
		var a:int=-1 if i==0 else 1
		var ro:float=bullet_interval/4*(i+1)
		for j in range(6):
			for k in range(8):
				spawn_base_bullet(pos,Vector2.RIGHT.rotated(ro+bullet_interval*k),speed)
			play_sound(SE_TAN_00)
			speed+=100
			ro+=bullet_interval/6*a
			await wait(0.166)
		await wait(1)
		
