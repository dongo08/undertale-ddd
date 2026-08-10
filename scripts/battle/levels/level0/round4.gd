extends Level1EnemyTurnManager

var speed=300

var state:int=0
var pos1:Vector2
var pos2:Vector2

var rad1:float
var rad2:float

var group_count:int=16
var p_index=0
func start():
	
	move_soul(Vector2(320,360))
	set_battleframe_polygon_trans([Vector2(180, 280), Vector2(460, 280), Vector2(460, 440), Vector2(180, 440)])
	await wait(1)
	pos1=Vector2(210,150)
	pos2=Vector2(430,150)
	rad1=randf()*PI
	rad2=randf()*PI
	state=1
	await wait(3)
	state=0
	await wait(1)
	pos1=Vector2(240,250)
	pos2=Vector2(410,60)
	rad1=randf()*PI
	rad2=randf()*PI
	state=1
	await wait(3)
	state=0
	await wait(1)
	pos1=Vector2(240,60)
	pos2=Vector2(400,260)
	rad1=randf()*PI
	rad2=randf()*PI
	state=1
	await wait(3)
	state=0
	await wait(1)
	end()
	
func _physics_process(delta: float) -> void:
	p_index+=1
	if state==1:
		for i in range(group_count/4):
			spawn_base_bullet(pos1,Vector2.ONE.rotated( rad1 + i*TAU/group_count*4 + TAU/ group_count*p_index),300,4)
			spawn_base_bullet(pos2,Vector2.ONE.rotated( rad2 + i*TAU/group_count*4 + TAU/ group_count*p_index),300,4)
			self_play_sound(SE_TAN_00,0,-6)
