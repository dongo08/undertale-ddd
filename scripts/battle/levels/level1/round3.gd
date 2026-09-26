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
	v_tween=create_tween()
	for i in range(glove_amount):
		var glove=GLOVE.instantiate()
		#glove.scale=0.5
		gloves.append(glove)
		gloves[i].position=center+Vector2.RIGHT.rotated(rad+r_interval*i)*distance
		gloves[i].rotation=rad+r_interval*i
		add_child(glove)
		v_tween.parallel().tween_property(glove,"modulate:a",1,1).from(0)
	
	v_tween.tween_property(self,"state",1,0)
	v_tween.tween_property(self,"state",2,0).set_delay(8)
	v_tween.tween_property(self,"velosity",1,1)
	v_tween.tween_callback(play)
	v_tween.tween_property(self,"state",3,0)
	v_tween.tween_property(self,"velosity",2.2,0)
	v_tween.tween_property(self,"state",4,0).set_delay(2)
	v_tween.tween_callback(end).set_delay(8)

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
