extends Level1EnemyTurnManager
const SINE_BULLET_2 = preload("uid://ubghr414qjmg")

var speed=120

var state:int=0
var pos1:Vector2=Vector2(300,30)
var pos2:Vector2=Vector2(340,30)

var pos3:Vector2=Vector2(190,150)
var pos4:Vector2=Vector2(450,150)

var rad:float

var group_count:int=16
var p_index=0
func start():
	
	move_soul(Vector2(320,360))
	set_battleframe_polygon_trans([Vector2(240, 280), Vector2(400, 280), Vector2(400, 440), Vector2(240, 440)])
	state=2
	await wait(1)
	state=0
	await wait(7)
	state=1
	await wait(7)
	state=2
	await wait(2)
	end()
	
func _physics_process(delta: float) -> void:
	if state<2:
		if p_index%3==0:
			spawn_sin_bullet2(pos1,false)
			spawn_sin_bullet2(pos2)
	p_index+=1
	if state==1:
		if p_index%11==0:
			play_sound(SE_TAN_00,0,-6)
			for i in range(8):
				var a=spawn_base_bullet(pos3,Vector2.RIGHT.rotated(rad+PI/4*i),speed)
				a.rotation=rad+PI/4*i-PI/2
				a.scale*=0.9
				a=spawn_base_bullet(pos4,Vector2.RIGHT.rotated(-rad+PI/4*i),speed)
				a.rotation=-rad+PI/4*i-PI/2
				a.scale*=0.9
			rad+=0.2
func spawn_sin_bullet2(pos,move_right: bool = true):
	var bullet=SINE_BULLET_2.instantiate() as SineBulletAdd
	bullet.position=pos
	bullet.move_right=move_right
	add_child(bullet)
