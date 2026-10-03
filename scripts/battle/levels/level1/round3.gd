extends Level1EnemyTurnManager

var center:Vector2=Vector2(320,360)
var distance:float=120
var rad:float=0
var gloves:Array
const GLOVE = preload("uid://b4up8bwqk0hhb")
var velosity:float=-1.2

var v_tween:Tween

var state:=0

var p_index:int=0

var glove_amount:int=4

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
	# 下面这些原来是一串 tween（state / velosity 直接由 tween 驱动，回放必然漂），
	# 现在全部改成按 tick 等 + 按 tick 插值
	await wait(1)
	state=1
	await wait(8)
	state=2
	await ramp_property(&"velosity",-1.2,1.0,1.0)
	play()
	state=3
	velosity=2.2
	await wait(2)
	state=4
	await wait(8)
	end()

func _physics_process(delta: float) -> void:
	rad+=velosity*delta
	p_index+=1
	if !gloves.is_empty():
		for i in range(glove_amount):
			gloves[i].position=center+Vector2.RIGHT.rotated(rad+r_interval*i)*distance
			gloves[i].rotation=rad+r_interval*i
	if state==1:
		if p_index%5==0:
			for i in range(glove_amount):
				var a=spawn_base_bullet(center+Vector2.RIGHT.rotated(rad+r_interval*i)*distance,Vector2.RIGHT.rotated(rad+r_interval*i-PI),120,1)
				a.scale*=0.5
				a.rotation=rad+r_interval*i+PI/2
				var b=spawn_base_bullet(center+Vector2.RIGHT.rotated(rad+r_interval*i)*distance,Vector2.RIGHT.rotated(rad+r_interval*i-PI),112,1)
				b.scale*=0.5
				b.rotation=rad+r_interval*i+PI/2
		if p_index%16==0:
			var r=p_index/20
			var a=spawn_base_bullet(center+Vector2.RIGHT.rotated(rad+r_interval*r)*distance,Vector2.RIGHT.rotated(rad+r_interval*r-PI),50,8)
			a.scale*=0.5
			a.rotation=rad+r_interval*r+PI/2
	elif state==3:
		distance+=220*delta
		var r=p_index%20
		if r<16:
			for i in range(2):
				var a=spawn_base_bullet(center+Vector2.RIGHT.rotated(rad+r_interval/2*r+PI*i)*distance,Vector2.RIGHT.rotated(rad+r_interval/2*r+PI*i-PI),120,12)
				a.scale*=0.5
				a.rotation=rad+r_interval/2*r+PI*i+PI/2
			
func play():
	for i in range(40):
		self_play_sound(SE_TAN_00,0,-6)
		await get_tree().physics_frame
		await get_tree().physics_frame
