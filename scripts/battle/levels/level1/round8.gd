extends Level1EnemyTurnManager

var center:Vector2=Vector2(320,360)
var distance:float=100
var rad:float=0
var gloves:Array
const GLOVE = preload("uid://b4up8bwqk0hhb")
var velosity:float=-1

var v_tween:Tween

var state:=0

var p_index:int=0

var glove_amount:int=2

var r_interval:float

func start():
	r_interval=PI/glove_amount*2
	move_soul(Vector2(320,360))
	set_battleframe_polygon_trans([Vector2(240, 280), Vector2(400, 280), Vector2(400, 440), Vector2(240, 440)])
	
	await wait(1)
	for i in range(glove_amount):
		var glove=GLOVE.instantiate()
		#glove.scale=0.5
		gloves.append(glove)
		gloves[i].position=center+Vector2.RIGHT.rotated(rad+r_interval*i)*distance
		gloves[i].rotation=rad+r_interval*i
		add_child(glove)
		# 淡入只是画面，继续用 tween
		var fade:=create_tween()
		fade.tween_property(glove,"modulate:a",1,1).from(0)
	# 原来 state 是 tween 驱动的，改成按 tick 等（回放才不漂）
	await wait(1)
	state=1
	await wait(2)
	state=2
	await wait(12)
	state=3
	await wait(3)
	end()

func _physics_process(delta: float) -> void:
	rad+=velosity*delta
	p_index+=1
	if !gloves.is_empty():
		for i in range(glove_amount):
			gloves[i].position=center+Vector2.RIGHT.rotated(rad+r_interval*i)*distance
			gloves[i].rotation=rad+r_interval*i
	if state>0 and state<3:
		if p_index%5==0:
			for i in range(glove_amount):
				var a=spawn_base_bullet(center+Vector2.RIGHT.rotated(rad+r_interval*i)*distance,Vector2.RIGHT.rotated(rad+r_interval*i-PI),120,4)
				a.scale*=0.75
				a.rotation=rad+r_interval*i+PI/2
				a=spawn_base_bullet(center+Vector2.RIGHT.rotated(rad+r_interval*i)*distance,Vector2.RIGHT,0,3.2)
				a.scale*=0.75
	
				a=spawn_base_bullet(center+Vector2.RIGHT.rotated(rad+r_interval*i)*distance,Vector2.RIGHT.rotated(rad+r_interval*i),120,4)
				a.scale*=0.75
				a.rotation=rad+r_interval*i-PI/2
				a=spawn_base_bullet(center+Vector2.RIGHT.rotated(rad+r_interval*i)*distance,Vector2.RIGHT.rotated(rad+r_interval*i+PI/2),120,4)
				a.scale*=0.75
				a.rotation=rad+r_interval*i
				
	if state==2:
		if p_index%5==0:
			for i in range(glove_amount):
				var a=spawn_base_bullet(center+Vector2.RIGHT.rotated(rad*1.6+r_interval*i)*distance,Vector2.RIGHT.rotated(rad*1.6+r_interval*i-PI),60,4)
				a.scale*=0.75
				a.rotation=rad*1.6+r_interval*i+PI/2
				a.modulate=Color.CYAN
				a.type=BaseBullet.Type.BLUE
			
func play():
	for i in range(40):
		self_play_sound(SE_TAN_00,0,-6)
		await get_tree().physics_frame
		await get_tree().physics_frame
