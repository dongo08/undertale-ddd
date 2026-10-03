extends BaseEnemyTurnManager


func start():

	move_soul(Vector2(320,352))
	await set_battleframe_polygon_trans()
	var emit_pos=Vector2(320,100)
	for i in range(8):
		var dir=direction_to_soul(emit_pos)
		for j in range(5):
			spawn_base_bullet(emit_pos,dir.rotated((j-2)/2.0))
		await BattleClock.wait_seconds(0.5)
	await BattleClock.wait_seconds(3)
	end()
