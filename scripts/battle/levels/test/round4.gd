extends BaseEnemyTurnManager
const PROCESS_BULLET = preload("uid://tb6vjqogt2o8")

func start():

	move_soul(Vector2(320,352))
	await set_battleframe_polygon_trans([Vector2(180,260),Vector2(460,260),Vector2(460,440),Vector2(180,440)])
	var emit_pos=Vector2(320,180)
	var time=Time.get_ticks_msec()
	
	for i in range(3000):
		var dir=Vector2.DOWN
		spawn_base_bullet(emit_pos,dir.rotated(BattleRNG.randf()))
	print(Time.get_ticks_msec()-time)
	
	await BattleClock.wait_seconds(1)
	
	time=Time.get_ticks_msec()
	for i in range(6000):
		var dir=Vector2.DOWN
		spawn_base_bullet(emit_pos,dir.rotated(BattleRNG.randf()))
	print(Time.get_ticks_msec()-time)
	
	await BattleClock.wait_seconds(3)
	end()


func spawn_base_bullet(pos: Vector2, direction: Vector2, speed: float = 60,lifetime:float=16):
	var bullet = PROCESS_BULLET.instantiate()
	bullet.position = pos
	bullet.manager=self
	bullet.direction=direction
	bullet.speed=speed
	bullet.lifetime=lifetime
	add_child(bullet)
	
	bullets.append(bullet)
	return bullet
