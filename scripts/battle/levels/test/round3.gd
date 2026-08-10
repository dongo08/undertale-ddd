extends BaseEnemyTurnManager


func start():

	move_soul(Vector2(320,352))
	await set_battleframe_polygon_trans([Vector2(180,260),Vector2(460,260),Vector2(460,440),Vector2(180,440)])
	var emit_pos=Vector2(320,180)
	for i in range(3000):
		var dir=Vector2.DOWN
		spawn_base_bullet(emit_pos,dir.rotated(randf()*TAU))
		await get_tree().create_timer(0.003).timeout
	await get_tree().create_timer(3).timeout
	end()
