extends BaseBullet
var center_pos:Vector2=Vector2(320,360)
var strength:bool
var is_up:bool
var duration:float=2
var tween:Tween
var next_pos:Vector2
func _ready() -> void:
	tween=create_tween()
	var x_dist:float
	var y_dist:float
	if is_up:
		x_dist=220
		if strength:
			y_dist=100
		else:
			y_dist=140
			duration=1.8
	else:
		x_dist=-220
		if strength:
			y_dist=-100
		else:
			y_dist=-140
			duration=1.8
	position=Vector2(center_pos.x+x_dist,center_pos.y)
	tween.tween_property(self,"next_pos:x",center_pos.x+x_dist,duration).from(center_pos.x-x_dist)
	tween.parallel().tween_property(self,"next_pos:y",center_pos.y+y_dist,duration/2).from(center_pos.y).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(self,"next_pos:y",center_pos.y,duration/2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN).set_delay(duration/2)
	tween.tween_callback(queue_free)
func _process(delta: float) -> void:
	var angle=(next_pos-position).angle()-PI/2
	rotation=angle
	position=next_pos
