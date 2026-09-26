extends Level1EnemyTurnManager
const SHOCK = preload("uid://cc31pb8a313ns")
const MUS_SFX_RAINBOWBEAM_1 = preload("uid://dploktvc7tqkp")
var pos0=Vector2(320,150)
var pos1=Vector2(210,40)
var pos2=Vector2(430,40)
var state:int=0
var shock1=SHOCK.instantiate() as ColorRect
var shock2=SHOCK.instantiate() as ColorRect
var rad:float
var p_index:int
func start():
	
	move_soul(Vector2(320,360))
	set_battleframe_polygon_trans([Vector2(240, 280), Vector2(400, 280), Vector2(400, 440), Vector2(240, 440)])
	
	await wait(1)
	play_sound(MUS_SFX_RAINBOWBEAM_1)
	add_child(shock1)
	add_child(shock2)
	create_explode_effect(pos1,Vector2.ONE*0.6)
	create_explode_effect(pos2,Vector2.ONE*0.6)
	shock1.position=pos1-Vector2(shock1.size.x/2,0)
	shock2.position=pos2-Vector2(shock1.size.x/2,0)
	var tween=create_tween()
	tween.tween_method(set_height,0.0,1.0,0.5)
	await wait(1)
	state=1
	await wait(1)
	state=2
	await wait(7)
	state=3
	await wait(1)
	generate_circle_bullet()
	await wait(2)
	state=4
	await wait(1)
	end()

func generate_circle_bullet():
	for i in range(6):
		for j in range(-1,2,2):
			var pos=pos0+Vector2(j*(100+randf_range(0,100)),randf_range(-100,100))
			spawn_bullet_circle(pos,32,200,Vector2.ONE*0.5)
			play_sound(SE_TAN_02,0,-6)
			await wait(0.18)

func _physics_process(delta: float) -> void:
	p_index+=1
	if state>0 and state<4:
		if p_index%8==0:
			var pos=pos1
			for i in range(4):
				var a=spawn_base_bullet(Vector2(pos.x,480),Vector2.UP.rotated((i-1.5)/1.5),300,3)
				a.rotation=(i-1.5)/1.5-PI
			pos=pos2
			for i in range(4):
				var a=spawn_base_bullet(Vector2(pos.x,480),Vector2.UP.rotated((i-1.5)/1.5),300,3)
				a.rotation=(i-1.5)/1.5-PI
		
		
	if state==2:
		var pos=pos0+Vector2.ONE.rotated(randf()*TAU)*randf_range(-20,20)
		var rota=randf()*TAU
		var a=spawn_base_bullet(pos,Vector2.UP.rotated(rota),120)
		a.rotation=rota-PI
		a.scale*=0.5
		
		
	if state>0 and state<3:
		if p_index%2==0:
			var a=spawn_base_bullet(pos1,Vector2.UP.rotated(rad),300,3)
			a.rotation=rad-PI
			a.type=BaseBullet.Type.ORANGE
			a.modulate=Color.ORANGE
			a=spawn_base_bullet(pos2,Vector2.UP.rotated(-rad),300,3)
			a.rotation=rad-PI
			a.type=BaseBullet.Type.ORANGE
			a.modulate=Color.ORANGE
		rad+=2*delta
		if p_index%4==0:
			self_play_sound(SE_TAN_00,0,-6)
func set_height(height:float):
	shock1.material.set_shader_parameter("bar_height",height)
	shock2.material.set_shader_parameter("bar_height",height)
