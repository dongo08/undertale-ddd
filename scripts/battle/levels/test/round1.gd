extends BaseEnemyTurnManager


func start():

	move_soul(Vector2(320,352))
	await set_battleframe_polygon_trans()
	var emit_pos=Vector2(320,100)
	for i in range(360):
		var dir=direction_to_soul(emit_pos)
		spawn_base_bullet(emit_pos,dir.rotated(i))
		await BattleClock.wait_seconds(0.010)
	await BattleClock.wait_seconds(3)
	end()
