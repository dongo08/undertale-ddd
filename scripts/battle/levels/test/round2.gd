extends BaseEnemyTurnManager


func start():

	move_soul(Vector2(320,352))
	await set_battleframe_polygon_trans([Vector2(180,260),Vector2(460,260),Vector2(460,440),Vector2(180,440)])
	var emit_pos=Vector2(320,180)
	for i in range(360):
		var dir=Vector2.DOWN
		spawn_base_bullet(emit_pos,dir.rotated(BattleRNG.randf_range(-1,1)),120)
		await BattleClock.wait_seconds(0.016)
	await BattleClock.wait_seconds(3)
	end()
